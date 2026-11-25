#!r6rs
;;; tests/collect-probe.sps: one verb call blocked in C on a FIFO while another
;;; thread's collection finishes, in a process of its own, for
;;; tests/test-collect-safe.sps. It is not a suite: its name lies outside the
;;; tests/test-*.sps glob, so make test never runs it directly (ADR-0011).
;;;
;;;   collect-probe.sps VERB
;;;
;;; VERB is password-hash, password-verify, or control. It runs against the
;;; decoy under CHEZ_SODIUM_DECOY=pwhash-blocks, with CHEZ_SODIUM_LIBRARY
;;; naming it, both set by the suite. The decoy's two collect-safe calls each
;;; create the marker "$CHEZ_SODIUM_DECOY_FIFO.entered", then open the FIFO that
;;; variable names for reading, which blocks until a writer opens it.
;;;
;;; What it does, in order:
;;;   1. it references the library, before any thread is forked;
;;;   2. it makes a FIFO in a fresh directory, with a marker of its own;
;;;   3. it starts the watchdog, a shell outside this process, so that no
;;;      rendezvous can stop it. It polls, bounded, for the decoy's marker,
;;;      sleeps 1 s, then 10 s, leaves a file, and opens the FIFO read-write.
;;;      Were the marker never to appear, it still opens the FIFO once, and
;;;      ends. It also ends, without opening the FIFO, at its next check once
;;;      this process is gone: a kill from outside leaves it at most one nap,
;;;      10 s, behind;
;;;   4. it forks a thread that calls the verb, which holds its whole extent in
;;;      one critical section, and blocks in C;
;;;   5. it polls for the decoy's marker, then pauses 1 s, so the call is in C;
;;;   6. it runs collect-rendezvous, records the milliseconds it took, and opens
;;;      the FIFO read-write, which releases the call;
;;;   7. it waits, bounded, for the thread's answer, kills the watchdog, and
;;;      checks with kill -0 that its pid is gone.
;;;
;;; Its directory and the watchdog go on every exit path of the run: its end, a
;;; refusal and a raise. Only a kill from outside leaves the directory, under
;;; the TMPDIR the suite gave it.
;;;
;;; A write-only open blocks until a reader opens the FIFO, and the decoy reads
;;; it once, so the second writer would block for ever. A read-write open
;;; never blocks, and releases a waiting reader.
;;;
;;; VERB control skips the library's verbs: the thread calls the decoy's
;;; crypto_pwhash_str_verify through a PLAIN binding this file makes, inside
;;; critical-section, on blocks this file makes. A plain call keeps its thread
;;; active, so the rendezvous waits for it, and only the watchdog can release
;;; it. That is the standing control: the row that reads collector for the real
;;; verbs would read it for a probe that could not tell.
;;;
;;; It prints one datum per line:
;;;   (verb . VERB)
;;;   (released-by . collector|watchdog|nobody)   who opened the FIFO first
;;;   (rendezvous-ms . N)                         collect-rendezvous's time
;;;   (watchdog-gone . #t|#f)                     whether the watchdog's pid is gone
;;;   (answer . ANSWER)                           what the call answered, or
;;;                                               (raised TEXT), or hung
;;;   (counts . ALIST)                            the library's native counts
;;;   (valgrind . yes|no)                         whether memcheck runs it
(import (rnrs)
        (only (chezscheme) collect-rendezvous critical-section current-time display-condition time-second time-nanosecond
              foreign-alloc foreign-free foreign-procedure foreign-set! fork-thread
              get-process-id getenv make-mutex make-time mkdir putenv sleep system with-mutex)
        (chez-sodium private counters)
        (chez-sodium private native)
        (chez-sodium private password-verbs))

;; show : Any -> Void
(define (show datum)
  (write datum)
  (newline))

;; pause : Natural -> Void
;; MS milliseconds.
(define (pause ms)
  (sleep (make-time 'time-duration (* (mod ms 1000) 1000000) (div ms 1000))))

;; now-ms : -> Natural
(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000 (time-second t)) (div (time-nanosecond t) 1000000))))

;; wait-until : (-> Any) Natural -> Boolean
;; DONE? every 10 ms, at most STEPS times.
(define (wait-until done? steps)
  (let loop ((i 0))
    (cond ((done?) #t)
          ((= i steps) #f)
          (else (pause 10) (loop (+ i 1))))))

;; under-valgrind? : -> Boolean
(define (under-valgrind?)
  (guard (e (#t #f))
    (let ((maps (call-with-port
                 (open-file-input-port "/proc/self/maps" (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 get-string-all))
          (needle "vgpreload_memcheck"))
      (let ((n (string-length maps)) (m (string-length needle)))
        (let loop ((i 0))
          (cond ((> (+ i m) n) #f)
                ((string=? (substring maps i (+ i m)) needle) #t)
                (else (loop (+ i 1)))))))))

;; text-of : Any -> String
(define (text-of obj)
  (call-with-string-output-port
   (lambda (p) (if (condition? obj) (display-condition obj p) (write obj p)))))

;; --- the verb to run ------------------------------------------------------------

(define verb-name
  (let ((args (cdr (command-line))))
    (if (and (= (length args) 1) (member (car args) '("password-hash" "password-verify" "control")))
        (car args)
        (begin (display "usage: collect-probe.sps password-hash|password-verify|control\n"
                        (current-error-port))
               (exit 2)))))

;; The decoy's hash string for the control build.
(define decoy-hash
  "$argon2id$v=19$m=8,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGE")

;; The call's own limits are the library's minimum.
(define limits
  (make-password-limits pwhash-opslimit-min (div pwhash-memlimit-min 1024)))

;; c-block : String -> Natural
;; A NUL-terminated block of TEXT's ASCII, for the control's own call.
(define (c-block text)
  (let* ((bytes (string->utf8 text))
         (n (bytevector-length bytes))
         (block (foreign-alloc (+ n 1))))
    (do ((i 0 (+ i 1))) ((= i n))
      (foreign-set! 'unsigned-8 block i (bytevector-u8-ref bytes i)))
    (foreign-set! 'unsigned-8 block n 0)
    block))

;; Step 1: the library, referenced once, from this thread, before any fork. The
;; control's binding is made after it, so the decoy is loaded when it resolves.
(define referenced (sodium-version))

;; plain-verify : Natural Natural Natural -> Integer
;; The decoy's crypto_pwhash_str_verify, bound PLAIN.
(define plain-verify
  (foreign-procedure "crypto_pwhash_str_verify" (uptr uptr unsigned-64) int))

;; call-verb : -> Any
;; What the thread runs: the verb, or the control's plain call, whole.
(define (call-verb)
  (cond ((string=? verb-name "password-hash") (password-hash "pw" limits))
        ((string=? verb-name "password-verify") (password-verify decoy-hash "pw"))
        (else
         (let* ((s (c-block decoy-hash))
                (p (c-block "pw"))
                (answer (critical-section (plain-verify s p 2))))
           (foreign-free s)
           (foreign-free p)
           answer))))

;; --- the directory, the FIFO, the marker ---------------------------------------------

;; Step 2: a fresh directory of this call's own.
(define dir
  (let ((made (string-append (or (getenv "TMPDIR") "/tmp") "/collect-probe-"
                             (number->string (get-process-id)) "-"
                             (number->string (now-ms)))))
    (mkdir made #o700)
    made))

(define fifo (string-append dir "/blocking.fifo"))
(define entered (string-append fifo ".entered"))
(define fired (string-append dir "/watchdog-fired"))
(define watchdog-script (string-append dir "/watchdog.sh"))
(define watchdog-pid-file (string-append dir "/watchdog.pid"))

;; cleanup! : -> Void
;; Kills the watchdog and removes the directory. Safe to run twice.
(define (cleanup!)
  (stop-watchdog!)
  (system (string-append "rm -rf '" dir "'")))

(unless (zero? (system (string-append "mkfifo '" fifo "'")))
  (display "mkfifo failed\n" (current-error-port))
  (system (string-append "rm -rf '" dir "'"))
  (exit 2))

;; The decoy reads the FIFO's name when each call is made.
(putenv "CHEZ_SODIUM_DECOY_FIFO" fifo)

;; release! : -> Void
;; A read-write open of the FIFO: it never blocks, and lets a waiting reader go.
(define (release!)
  (system (string-append ": 1<>'" fifo "'")))

(call-with-output-file watchdog-script
  (lambda (port)
    (display (string-append
              "fifo=$1 entered=$2 fired=$3 parent=$4\n"
              "trap 'kill $s 2>/dev/null; exit 0' TERM\n"
              "nap() { sleep $1 & s=$!; wait $s; kill -0 \"$parent\" 2>/dev/null || exit 0; }\n"
              "i=0\n"
              "while [ ! -e \"$entered\" ] && [ $i -lt 900 ]; do nap 0.1; i=$((i+1)); done\n"
              "if [ -e \"$entered\" ]; then nap 1; nap 10; : > \"$fired\"; fi\n"
              ": 1<>\"$fifo\"\n")
             port)))

;; start-watchdog! : -> Void
;; The watchdog, in a shell of its own, with its pid in a file.
(define (start-watchdog!)
  (system (string-append "sh '" watchdog-script "' '" fifo "' '" entered "' '" fired "' "
                         (number->string (get-process-id))
                         " </dev/null >/dev/null 2>&1 & echo $! > '" watchdog-pid-file "'")))

;; stop-watchdog! : -> Void
(define (stop-watchdog!)
  (when (file-exists? watchdog-pid-file)
    (system (string-append "kill $(cat '" watchdog-pid-file "') 2>/dev/null; true"))
    (pause 100)))

;; watchdog-gone? : -> Boolean
;; Whether kill -0 finds no process at the watchdog's pid.
(define (watchdog-gone?)
  (not (zero? (system (string-append "kill -0 $(cat '" watchdog-pid-file "') 2>/dev/null")))))

;; --- the run -----------------------------------------------------------------------

(define lock (make-mutex))
(define answer-box #f)

(start-watchdog!)

(define (run)
  ;; Step 4: the thread. What it raises is its answer.
  (fork-thread
   (lambda ()
     (let ((a (guard (e (#t (list 'raised (text-of e))))
                (call-verb))))
       (critical-section (with-mutex lock (set! answer-box (list 'answer a)))))))

  (let* ((entered? (wait-until (lambda () (file-exists? entered)) 6000)))
    ;; Step 5: once the marker is there, 1 s.
    (when entered? (pause 1000))
    ;; Step 6: the rendezvous, its time, then the release.
    (let ((rendezvous-ms
           (if entered?
               (let ((t0 (now-ms)))
                 (collect-rendezvous)
                 (- (now-ms) t0))
               'no-rendezvous)))
      (release!)
      ;; Step 7: the answer, bounded; then the watchdog dies.
      (let* ((answered? (wait-until (lambda () (critical-section (with-mutex lock answer-box))) 3000))
             (released-by (cond ((not entered?) 'nobody)
                                ((file-exists? fired) 'watchdog)
                                (else 'collector))))
        (stop-watchdog!)
        (show (cons 'verb verb-name))
        (show (cons 'watchdog-gone (watchdog-gone?)))
        (show (cons 'released-by released-by))
        (show (cons 'rendezvous-ms rendezvous-ms))
        (show (cons 'answer (if answered? (cadr (critical-section (with-mutex lock answer-box))) 'hung)))
        (show (cons 'counts (native-counts)))
        (show (cons 'valgrind (if (under-valgrind?) 'yes 'no))))))
  (cleanup!))

(guard (e (#t (cleanup!) (raise e)))
  (run))
(exit 0)
