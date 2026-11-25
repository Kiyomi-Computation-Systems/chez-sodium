#!r6rs
;;; The suite for what libsodium answers when it cannot get the memory it
;;; asks for: crypto_pwhash_str answers -1, so password-hash raises
;;; &sodium-failed with code -1; crypto_pwhash_str_verify answers -1, so
;;; password-verify answers #f, as it does for a wrong password.
;;;
;;; Both need a process whose address space is capped: ulimit -v. Each child
;;; is started through gated-command, so under the memory gate it runs under
;;; the gate's own Valgrind, and the gate reads its log; the cap sits outside
;;; Valgrind, which runs Chez itself. Each child prints its native counts and
;;; whether it ran under Valgrind, and this suite asserts both: every count
;;; zero, and yes exactly when the gate asked.
;;; This suite's own process hashes nothing and never loads libsodium.
;;;
;;; The cap is 512 MiB, 524288 KiB. Chez and libsodium load under it, a hash
;;; at 'interactive (64 MiB) succeeds, and one at 'sensitive (1 GiB) cannot get
;;; its memory. The 'interactive row, under the same cap, shows the cap is the
;;; cause. The verify rows use a real 'sensitive hash, made by a child with no
;;; cap: with the right password it verifies #f under the cap, and #t without.
;;; Each answer comes from a guard with a sentinel of its own, so a raise or a
;;; wrong answer fails the row.
(import (rnrs)
        (srfi :64)
        (only (chezscheme) foreign-entry? getenv)
        (chez-sodium-testing)
        (library-loading))

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

;; The cap, in KiB.
(define cap-kib 524288)

;; run-child : (U Natural #f) String ... -> (U (List Integer (Listof Any) String) (List 'raised String))
;; The probe in MODE and ARGS, as the gate runs a child, under ulimit -v CAP
;; when CAP is a number, else uncapped: its exit status, what it printed as
;; data, and its stderr.
(define (run-child cap . mode+args)
  (guard (e (#t (list 'raised (describe e))))
    (as-data
     (capture-command
      (append (if cap
                  (list "sh" "-c" (string-append "ulimit -v " (number->string cap) "; exec \"$@\"") "sh")
                  '())
              (gated-command getenv
                             (append (list chez "--libdirs" "src:tests:build/scheme-libs"
                                           "--program" "tests/no-memory-probe.sps")
                                     mode+args)))))))

;; answer-of : (U (List Integer (Listof Any) String) Any) -> (U (Listof Any) Any)
;; A child's printed data, or the whole run when it is not one.
(define (answer-of run)
  (if (and (pair? run) (integer? (car run)) (pair? (cdr run)) (list? (cadr run)))
      (cadr run)
      run))

;; whole : Datum -> Expected
;; A child's whole answer: status 0, its DATUM, every count zero, whether it
;; ran under Valgrind, and an empty stderr.
(define (whole datum)
  (list 0 (list datum no-native-objects valgrind-line) ""))

(define interactive-run (run-child cap-kib "hash-interactive"))
(define sensitive-run (run-child cap-kib "hash-sensitive"))
(define make-run (run-child #f "make-sensitive"))

;; The hash the uncapped child made, or #f.
(define sensitive-hash
  (let ((d (let ((l (answer-of make-run))) (if (pair? l) (car l) 'unreadable))))
    (if (and (pair? d) (eq? (car d) 'made) (pair? (cdr d)) (string? (cadr d)))
        (cadr d)
        #f)))

(define sensitive-prefix "$argon2id$v=19$m=1048576,t=4,p=1$")
(define (prefix? p s)
  (and (string? s) (>= (string-length s) (string-length p))
       (string=? p (substring s 0 (string-length p)))))
(define hash-made?
  (prefix? sensitive-prefix sensitive-hash))

;; Both verifies are run only on a hash that was made, so a hash that is not
;; one cannot make the capped row answer #f for the wrong reason.
(define capped-verify-run
  (if hash-made? (run-child cap-kib "verify" sensitive-hash) 'no-hash))
(define free-verify-run
  (if hash-made? (run-child #f "verify" sensitive-hash) 'no-hash))

(test-begin "no-memory")

(test-equal "password-hash at 'interactive, 64 MiB, succeeds under the 512 MiB cap: the cap is not what stops 'sensitive; no native object is live, and Valgrind runs the child when the gate asks"
  (whole '(hash ok "$argon2id$v=19$m=65536,t=2,p=1$"))
  interactive-run)

(test-equal "password-hash at 'sensitive, 1 GiB, under the 512 MiB cap raises &sodium-failed, function crypto_pwhash_str, code -1; no native object is live, and Valgrind runs the child when the gate asks"
  (whole '(hash raised "crypto_pwhash_str" -1))
  sensitive-run)

(test-equal "a 'sensitive hash is made with no cap, the control for the verify rows; no native object is live, and Valgrind runs the child when the gate asks"
  (list 0 #t (list no-native-objects valgrind-line) "")
  (if (and (pair? make-run) (integer? (car make-run)) (list? (cadr make-run)) (pair? (cadr make-run)))
      (list (car make-run) hash-made? (cdr (cadr make-run)) (caddr make-run))
      make-run))

(test-equal "password-verify of a 'sensitive hash with its right password answers #f under the 512 MiB cap, where libsodium answers -1 for no memory, and raises nothing; no native object is live, and Valgrind runs the child when the gate asks"
  (whole '(verify #f))
  capped-verify-run)

(test-equal "password-verify of the same hash with the same password answers #t with no cap, and raises nothing; no native object is live, and Valgrind runs the child when the gate asks"
  (whole '(verify #t))
  free-verify-run)

(test-equal "this suite's own process never loaded a libsodium"
  'not-loaded
  (if (foreign-entry? "sodium_version_string") 'loaded 'not-loaded))

(test-end "no-memory")

(exit (suite-exit-status runner))
