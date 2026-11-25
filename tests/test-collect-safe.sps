#!r6rs
;;; The suite for the two collect-safe calls of the password verbs,
;;; crypto_pwhash_str and crypto_pwhash_str_verify, by behaviour (ADR-0011).
;;;
;;; A call that can block or run long is __collect_safe, so that another
;;; thread's collection finishes while it runs. Here each verb is called from a
;;; thread, inside the verb's critical section, against the decoy under
;;; pwhash-blocks, whose two calls block on a FIFO. Another thread's
;;; collect-rendezvous must then finish, and that thread releases the call. Were
;;; the binding plain, the rendezvous would wait for the call, and only the
;;; watchdog shell, outside the process, could release it.
;;;
;;;   password-hash    released by the collector, the rendezvous within 5 s,
;;;                    the decoy's hash string, no live block
;;;   password-verify  the same, answering #t
;;;   the control      tests/collect-probe.sps' own PLAIN binding of the
;;;                    decoy's crypto_pwhash_str_verify, called the same way:
;;;                    released by the watchdog. It is what shows the verbs'
;;;                    rows can read anything but collector
;;;
;;; Each row is a child, tests/collect-probe.sps, in a process of its own, with
;;; a FIFO and a marker of its own. Under the memory gate it runs under a
;;; Valgrind of its own, and says so; a row requires yes exactly when the gate
;;; asked. This process never loads libsodium. What a child raises is data in
;;; its answer, and everything here that can raise is computed under a guard.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (library-loading)
        (only (chezscheme) file-directory? getenv))

;; SRFI-64 sets no exit status. This suite's last line turns the runner's
;; counts into one.
(define runner (test-runner-simple))
(test-runner-current runner)

;; The simple runner names a failing test but not its values. Print both.
(let ((simple-end (test-runner-on-test-end runner)))
  (test-runner-on-test-end! runner
    (lambda (r)
      (simple-end r)
      (when (memq (test-result-kind r) '(fail xpass))
        (display "  expected: ")
        (write (test-result-ref r 'expected-value))
        (newline)
        (display "  actual:   ")
        (write (test-result-ref r 'actual-value))
        (newline)))))

(test-begin "collect-safe")

(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the decoy --------------------------------------------

(define scratch
  (guard (e (#t #f))
    (make-process-temp-directory)))

(test-equal "mktemp -d made a scratch directory"
  'made
  (if (and (absolute? scratch) (file-directory? scratch)) 'made 'not-made))

(unless (and (absolute? scratch) (file-directory? scratch))
  (exit 1))

(define floor-values (read-floor-values))

(test-equal "packaging/floors.sexp gives the decoy its versions: the floor, and the version one patch below it"
  'read
  (if (and (= (length floor-values) 2) (string? (car floor-values))) 'read floor-values))

(unless (string? (car floor-values))
  (exit 1))

(define (so-of build) (string-append scratch "/" build ".so"))

(define compiled (compile-decoys so-of floor-values (decoy-builds '("control"))))

(test-equal "the decoy's control build compiles"
  0
  (decoy-status compiled "control"))

;; --- the child --------------------------------------------------------------------------

;; The decoy's hash string for the control build, what crypto_pwhash_str writes.
(define decoy-hash
  "$argon2id$v=19$m=8,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGE")

;; run-probe : String -> (U (List Integer (Listof Any) String) (List 'raised String))
;; tests/collect-probe.sps for VERB on the decoy under pwhash-blocks: its exit
;; status, what it printed as data, and its stderr. timeout sits outside the
;; gate's Valgrind, which runs Chez itself, and kills a child that hangs after
;; limit-seconds. The child's directory is under the scratch directory, so a
;; killed child leaves nothing outside it.
(define limit-seconds "180")

(define (run-probe verb)
  (guard (e (#t (list 'raised (describe e))))
    (as-data (capture-command
              (append (list "timeout" limit-seconds "env"
                            (override (so-of "control")) "CHEZ_SODIUM_DECOY=pwhash-blocks"
                            (string-append "TMPDIR=" scratch))
                      (gated-command getenv
                                     (list chez "--libdirs" "src" "--program"
                                           "tests/collect-probe.sps" verb)))))))

;; fact : (Listof Any) Symbol -> Any
;; The value the child printed under KEY, or the symbol missing.
(define (fact lines key)
  (let ((hit (and (list? lines) (assq key (filter pair? lines)))))
    (if hit (cdr hit) 'missing)))

;; milliseconds : (Listof Any) -> Any
;; The rendezvous time the child recorded, shown to the person running the suite.
(define (milliseconds lines)
  (fact lines 'rendezvous-ms))

;; summary : String Natural -> (U (List ...) Any)
;; What a child answered, boiled down to what the rows assert: its status, its
;; stderr, the verb it ran, who released the call, #t when the rendezvous took
;; under BOUND ms as UNDER? says (UNDER? #f: at least BOUND), the call's answer,
;; the counts and the Valgrind line. A child that raised, or printed no data, is its raise.
(define (summary verb bound under?)
  (let ((answer (run-probe verb)))
    (if (and (list? answer) (eqv? (length answer) 3) (list? (cadr answer)))
        (let* ((lines (cadr answer))
               (ms (milliseconds lines)))
          (display (string-append "  " verb ": rendezvous " (if (number? ms) (number->string ms) "?")
                                  " ms\n"))
          (list (car answer) (caddr answer)
                (fact lines 'verb) (fact lines 'released-by)
                (if (integer? ms) (eq? (< ms bound) under?) 'no-time)
                (fact lines 'answer)
                (cons 'counts (fact lines 'counts)) (cons 'valgrind (fact lines 'valgrind))))
        answer)))

;; expected : String Symbol Any -> Expected
(define (expected verb released-by answer)
  (list 0 "" verb released-by #t answer no-native-objects valgrind-line))

;; --- the rows ----------------------------------------------------------------------------

(test-equal "password-hash is __collect_safe: blocked in the decoy's crypto_pwhash_str on a FIFO, inside the verb's critical section, it lets another thread's collect-rendezvous finish in under 5 s, and that thread releases it; it answers the decoy's hash string, no block is live, and the child runs under Valgrind exactly when the gate asked"
  (expected "password-hash" 'collector decoy-hash)
  (guard (e (#t (list 'raised (describe e))))
    (summary "password-hash" 5000 #t)))

(test-equal "password-verify is __collect_safe: blocked in the decoy's crypto_pwhash_str_verify on a FIFO, inside the verb's critical section, it lets another thread's collect-rendezvous finish in under 5 s, and that thread releases it; it answers #t, no block is live, and the child runs under Valgrind exactly when the gate asked"
  (expected "password-verify" 'collector #t)
  (guard (e (#t (list 'raised (describe e))))
    (summary "password-verify" 5000 #t)))

;; The control: a plain binding, called inside critical-section. The watchdog
;; releases the call, never the collector, and the call answers 0, the decoy's
;; verify answer. That the watchdog released it is what shows the plain call
;; held the collection. The rendezvous time is not asserted here: a collection
;; the child's own allocation starts between the marker and the explicit
;; rendezvous waits for the blocked call itself, and the explicit rendezvous
;; then takes no time at all. A bound of 0 with UNDER? #f holds for every time.
(test-equal "the standing control: a PLAIN binding of the decoy's crypto_pwhash_str_verify, called inside critical-section, is released by the watchdog, never the collector"
  (expected "control" 'watchdog 0)
  (guard (e (#t (list 'raised (describe e))))
    (summary "control" 0 #f)))

(test-equal "the scratch directory is removed"
  '(done removed)
  (let* ((removal (guard (e (#t (list 'raised (describe e))))
                    (remove-temp-directory scratch)
                    'done))
         (left (if (file-directory? scratch) 'left 'removed)))
    (list removal left)))

(test-end "collect-safe")

(exit (suite-exit-status runner))
