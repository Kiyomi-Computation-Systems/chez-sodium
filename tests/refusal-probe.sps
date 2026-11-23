#!r6rs
;;; tests/refusal-probe.sps: loads libsodium as chez-sodium does, in a
;;; process of its own, and prints what happened as data, one datum per
;;; line, for the tests/test-library-loading-*.sps suites, through
;;; tests/library-loading.sls, to read. It is not a suite: its name lies outside the
;;; tests/test-*.sps glob, so make test never runs it directly (ADR-0011).
;;;
;;;   refusal-probe.sps [--then-override PATH] [--marker NAME] [--message yes]
;;;                     [--init-before yes] [--init-after yes] [--wipe N]
;;;
;;; It references loaded-libsodium three times, each inside its guard. The
;;; first reference prints what happened:
;;;
;;;   loaded:   (loaded . PATH) (source . SYMBOL) (version . STRING)
;;;             (major . N) (minor . N) (init . N), (chez-sodium private
;;;             native)'s record of the load, and the exit status is 0
;;;   refused:  (reason . SYMBOL) (who . WHO) (path . P) (source . S)
;;;             (detail . D) (candidates . LIST) (irritants . LIST), and the
;;;             exit status is 1. WHO is the condition's &who. LIST of
;;;             irritants is the condition's &irritants, or #f when it has
;;;             none. With --message, (message . TEXT) follows: the
;;;             condition's &message, which tests/preflight.sps prints as
;;;             its remedy. Tests never assert it as text (ADR-0006);
;;;             test-library-loading-preflight compares preflight's remedy
;;;             line with it
;;;   anything else raised: (raised WHO TYPES), and the exit status is 2.
;;;             WHO is the condition's &who, or #f; TYPES lists, by name, the
;;;             condition types it is, in a fixed order: serious, error,
;;;             violation, assertion, warning, who, message, irritants,
;;;             library-unavailable. Never its text (ADR-0006)
;;;
;;; With --then-override, CHEZ_SODIUM_LIBRARY is set to PATH after the
;;; first reference, and (then-override . VALUE) shows what getenv then
;;; reads. The two later references print one line, (again . (A B)). Each is
;;; `same` when the reference answered what the first did: the very
;;; condition (eq?) for a refusal or a raise, an equal? record for a load,
;;; since loaded-libsodium answers a fresh list at each call; else
;;; (loaded PATH), (refused REASON) or (raised WHO TYPES). That a load ran
;;; once is shown by the decoy's call log, whole, beside it.
;;;
;;; With --init-before, before anything of chez-sodium's runs, the probe loads
;;; CHEZ_SODIUM_LIBRARY itself, binds sodium_init on its own, and calls it:
;;; (init-before . N) is the first line, or (init-before raised WHO TYPES).
;;; With --init-after, once the first reference has loaded and the later
;;; two are done, it calls sodium_init directly once more: (init-after . N),
;;; right after the (again . ...) line. Both are for the real libsodium: a
;;; decoy would log the probe's own calls.
;;;
;;; With --wipe N, once the first reference has loaded, the probe makes a
;;; block of N bytes of A (call-with-bytes, inside call-in-section) and
;;; frees it: (wipe . ok), or (wipe raised WHO TYPES), after (again . ...).
;;; The decoy's log then holds the wipe's call.
;;;
;;; Then (counts . ALIST): (chez-sodium private counters)' native-counts,
;;; read once the references are done. The counters count per process, and a
;;; suite's suite-exit-status reads only its own, so this process prints its
;;; counts, and its suite requires every one zero, refusals included
;;; (ADR-0011).
;;;
;;; With --marker, (marker . present) or (marker . absent) follows: whether
;;; this process has the entry point NAME, as foreign-entry? answers.
;;;
;;; Then (valgrind . yes) or (valgrind . no): whether this process runs under
;;; Valgrind's memcheck, read from /proc/self/maps, which then maps memcheck's
;;; preload. Under make test-memory, the test-library-loading suites run
;;; this probe through the gate's own Valgrind, and require yes there and no
;;; elsewhere, so a child the gate should check that ran outside it fails its
;;; row (ADR-0011).
;;;
;;; Last comes (calls . LOG) when the most recently loaded library has the
;;; entry point decoy_calls, as tests/decoy-libsodium.c does: its call log,
;;; read byte by byte from the address the call returns, never through
;;; Chez's string type (ADR-0001).
;;;
;;; Why eval, and no import of (chez-sodium private native): Chez runs the
;;; libraries a program imports before the program's body, so a guard in the
;;; body never sees a raise from an imported library's body.
;;; Native's body is the load. So this program evaluates (loaded-libsodium)
;;; in native's environment inside the guard, and the load runs within it.
;;; The libraries it imports load nothing: conditions define types and
;;; procedures, and the counters count.
(import (rnrs)
        (only (chezscheme) eval environment foreign-entry? foreign-procedure foreign-ref
              load-shared-object putenv getenv)
        (chez-sodium private conditions)
        (chez-sodium private counters))

;; show : Symbol Any -> Void
;; One datum, (KEY . VALUE), on a line of its own.
(define (show key value)
  (write (cons key value))
  (newline))

;; condition-types : Any -> (Listof Symbol)
;; The names of the condition types OBJ is, in a fixed order; none for what
;; is no condition.
(define (condition-types obj)
  (if (condition? obj)
      (let loop ((rest (list (cons 'serious serious-condition?) (cons 'error error?)
                             (cons 'violation violation?) (cons 'assertion assertion-violation?)
                             (cons 'warning warning?) (cons 'who who-condition?)
                             (cons 'message message-condition?)
                             (cons 'irritants irritants-condition?)
                             (cons 'library-unavailable sodium-library-unavailable?)))
                 (found '()))
        (cond ((null? rest) (reverse found))
              (((cdar rest) obj) (loop (cdr rest) (cons (caar rest) found)))
              (else (loop (cdr rest) found))))
      '()))

;; raised-facts : Any -> (List (U Symbol #f) (Listof Symbol))
;; What a raise is, without its text: its &who, or #f, and its types.
(define (raised-facts obj)
  (list (and (condition? obj) (who-condition? obj) (condition-who obj))
        (condition-types obj)))

;; option : String -> (U String #f)
;; The argument after NAME on the command line, or #f.
(define (option name)
  (let loop ((args (cdr (command-line))))
    (cond ((or (null? args) (null? (cdr args))) #f)
          ((string=? (car args) name) (cadr args))
          (else (loop (cdr args))))))

(define native (environment '(rnrs) '(chez-sodium private native)))

;; direct-init : -> Integer
;; sodium_init, bound here and called: the probe's own binding.
(define (direct-init)
  ((eval '(foreign-procedure "sodium_init" () int) (environment '(chezscheme)))))

;; reference : -> (Pairof Symbol Any)
;; One reference to loaded-libsodium: (loaded . INFO), (refused . CONDITION)
;; or (raised . OBJECT).
(define (reference)
  (guard (e ((sodium-library-unavailable? e) (cons 'refused e))
            (#t (cons 'raised e)))
    (cons 'loaded (eval '(loaded-libsodium) native))))

;; later : (Pairof Symbol Any) (Pairof Symbol Any) -> Any
;; What a later reference did, against the first.
(define (later first answer)
  (cond ((and (eq? (car answer) 'loaded) (eq? (car first) 'loaded)
              (equal? (cdr answer) (cdr first)))
         'same)
        ((eq? (cdr answer) (cdr first)) 'same)
        ((eq? (car answer) 'loaded) (list 'loaded (cdr (assq 'path (cdr answer)))))
        ((eq? (car answer) 'refused)
         (list 'refused (sodium-library-unavailable-reason (cdr answer))))
        (else (cons 'raised (raised-facts (cdr answer))))))

;; read-c-string : Natural -> String
;; The NUL-terminated bytes at ADDRESS, decoded as UTF-8.
(define (read-c-string address)
  (let* ((n (let scan ((i 0))
              (if (eqv? (foreign-ref 'unsigned-8 address i) 0) i (scan (+ i 1)))))
         (bytes (make-bytevector n)))
    (let fill ((i 0))
      (when (< i n)
        (bytevector-u8-set! bytes i (foreign-ref 'unsigned-8 address i))
        (fill (+ i 1))))
    (utf8->string bytes)))

;; under-valgrind? : -> Boolean
;; Whether /proc/self/maps maps memcheck's preload; #f when it cannot be
;; read.
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

;; --init-before: the probe's own load and call, before the first reference.
(when (option "--init-before")
  (show 'init-before
        (guard (e (#t (cons 'raised (raised-facts e))))
          (load-shared-object (getenv "CHEZ_SODIUM_LIBRARY"))
          (direct-init))))

(define first (reference))

(define status
  (case (car first)
    ((loaded)
     (let ((info (cdr first)))
       (for-each (lambda (key)
                   (show (if (eq? key 'path) 'loaded key) (cdr (assq key info))))
                 '(path source version major minor init))
       0))
    ((refused)
     (let ((e (cdr first)))
       (show 'reason (sodium-library-unavailable-reason e))
       (show 'who (and (who-condition? e) (condition-who e)))
       (show 'path (sodium-library-unavailable-path e))
       (show 'source (sodium-library-unavailable-source e))
       (show 'detail (sodium-library-unavailable-detail e))
       (show 'candidates (sodium-library-unavailable-candidates e))
       (show 'irritants (and (irritants-condition? e) (condition-irritants e)))
       (when (option "--message")
         (show 'message (and (message-condition? e) (condition-message e))))
       1))
    (else
     (show 'raised (raised-facts (cdr first)))
     2)))

(let ((path (option "--then-override")))
  (when path
    (putenv "CHEZ_SODIUM_LIBRARY" path)
    (show 'then-override (getenv "CHEZ_SODIUM_LIBRARY"))))

(let* ((second (reference))
       (third (reference)))
  (show 'again (list (later first second) (later first third))))

(when (and (option "--init-after") (eq? (car first) 'loaded))
  (show 'init-after (guard (e (#t (cons 'raised (raised-facts e)))) (direct-init))))

(let ((n (option "--wipe")))
  (when (and n (eq? (car first) 'loaded))
    (show 'wipe
          (guard (e (#t (cons 'raised (raised-facts e))))
            (eval `(call-in-section
                    (lambda ()
                      (call-with-bytes 'probe (make-bytevector ,(string->number n) 65)
                                       (lambda (address) 'ok))))
                  native)))))

(show 'counts (native-counts))

(let ((marker (option "--marker")))
  (when marker
    (show 'marker (if (foreign-entry? marker) 'present 'absent))))

(show 'valgrind (if (under-valgrind?) 'yes 'no))

(when (foreign-entry? "decoy_calls")
  (show 'calls (read-c-string ((foreign-procedure "decoy_calls" () uptr)))))

(exit status)
