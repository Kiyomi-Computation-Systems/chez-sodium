#!r6rs
;;; The suite for what libsodium answers when it cannot get the memory it
;;; asks for: crypto_pwhash_str answers -1, so password-hash raises
;;; &sodium-failed with code -1; crypto_pwhash_str_verify answers -1, so
;;; password-verify answers #f, as it does for a wrong password.
;;;
;;; Both need a process whose address space is capped: ulimit -v. Valgrind
;;; cannot run under a cap, so each child here runs outside the memory gate,
;;; started with capture-command, not gated-command, and the gate does not
;;; see it (ADR-0011). Each child prints (valgrind . no), read from
;;; /proc/self/maps, and this suite asserts it: the point of the rows is that
;;; Valgrind is not there. The gate's variables are unset for each child, since
;;; under the gate this suite's own LD_PRELOAD holds Valgrind's preloads.
;;; This suite's own process hashes nothing, and runs under the gate like any.
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
        (only (chezscheme) getenv)
        (chez-sodium-testing))

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

;; run-child : (U Natural #f) String ... -> (U (List Integer String String) (List 'raised String))
;; The probe in MODE and ARGS, under ulimit -v CAP when CAP is a number, else
;; uncapped. The gate's variables are unset for it.
(define (run-child cap . mode+args)
  (guard (e (#t (list 'raised (describe e))))
    (capture-command
     (append (list "env" "-u" "CHEZ_SODIUM_GATE_CHILD" "-u" "LD_PRELOAD")
             (if cap
                 (list "sh" "-c" (string-append "ulimit -v " (number->string cap) "; exec \"$@\"") "sh")
                 '())
             (list (getenv "CHEZ") "--libdirs" "src:tests:build/scheme-libs"
                   "--program" "tests/no-memory-probe.sps")
             mode+args))))

;; output-of : Any -> (U String Any)
;; A child's whole answer as (STATUS STDOUT STDERR), kept whole for a row.
(define (stdout-of run)
  (if (and (pair? run) (integer? (car run))) (cadr run) ""))

;; first-datum : String -> Any
;; The first datum of TEXT, or 'unreadable.
(define (first-datum text)
  (guard (e (#t 'unreadable))
    (read (open-string-input-port text))))

(define interactive-run (run-child cap-kib "hash-interactive"))
(define sensitive-run (run-child cap-kib "hash-sensitive"))
(define make-run (run-child #f "make-sensitive"))

;; The hash the uncapped child made, or #f.
(define sensitive-hash
  (let ((d (first-datum (stdout-of make-run))))
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

(define no-valgrind "(valgrind . no)\n")

(test-begin "no-memory")

(test-equal "password-hash at 'interactive, 64 MiB, succeeds under the 512 MiB cap: the cap is not what stops 'sensitive; the child ran outside Valgrind"
  (list 0
        (string-append "(hash ok \"$argon2id$v=19$m=65536,t=2,p=1$\")\n" no-valgrind)
        "")
  interactive-run)

(test-equal "password-hash at 'sensitive, 1 GiB, under the 512 MiB cap raises &sodium-failed, function crypto_pwhash_str, code -1; the child ran outside Valgrind"
  (list 0
        (string-append "(hash raised \"crypto_pwhash_str\" -1)\n" no-valgrind)
        "")
  sensitive-run)

(test-equal "a 'sensitive hash is made with no cap, the control for the verify rows, and the child ran outside Valgrind"
  (list 0 #t no-valgrind "")
  (if (and (pair? make-run) (integer? (car make-run)))
      (list (car make-run) hash-made?
            ;; the second line of the child's output
            (let* ((out (cadr make-run))
                   (n (string-length out))
                   (k (string-length no-valgrind)))
              (if (>= n k) (substring out (- n k) n) out))
            (caddr make-run))
      make-run))

(test-equal "password-verify of a 'sensitive hash with its right password answers #f under the 512 MiB cap, where libsodium answers -1 for no memory, and raises nothing; the child ran outside Valgrind"
  (list 0 (string-append "(verify #f)\n" no-valgrind) "")
  capped-verify-run)

(test-equal "password-verify of the same hash with the same password answers #t with no cap, and raises nothing; the child ran outside Valgrind"
  (list 0 (string-append "(verify #t)\n" no-valgrind) "")
  free-verify-run)

(test-end "no-memory")

(exit (suite-exit-status runner))
