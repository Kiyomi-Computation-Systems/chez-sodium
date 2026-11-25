#!r6rs
;;; One of the suites that load libsodium end to end through a decoy
;;; (ADR-0002, ADR-0006, ADR-0007, ADR-0009, ADR-0011): this one holds the
;;; memory range make-password-limits answers, which is a rounding. The range is
;;; memlimit_min / 1024 rounded up to memlimit_max / 1024 rounded down, and
;;; every release and every other switch has whole KiB, so no value there can
;;; tell the rounding. Under pwhash-limits-odd the two memlimits are 16385 and
;;; 1048575 bytes, neither a whole KiB, so the range is 17 to 1023: 16 is
;;; refused although 16 KiB is 16384 bytes, 1024 although 1 MiB is 1048576, and
;;; 17 and 1023 are accepted. A hash at 17 KiB reaches C at 17408 bytes.
;;;
;;; Each call's line is (OUTCOME GROWTH), as in the password verbs' suite: its
;;; answer or its refusal as (refused WHO IRRITANTS), then the log's growth as
;;; one string, asserted whole. A last child prints the refusal whole, through
;;; the probe's --describe, for its message.
;;;
;;; Under the memory gate each child runs under a Valgrind of its own
;;; (ADR-0011), so this suite runs 2 children, at most 14. Each child's counts
;;; are required zero, and each says whether it ran under Valgrind, which a row
;;; requires yes exactly when the gate asked.
;;;
;;; This process itself never loads libsodium, and requires as much at its end.

(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (library-loading)
        (only (chezscheme) file-directory? foreign-entry? list-head))

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

(test-begin "library-loading-password-limits")

;; The Makefile exports CHEZ, so this suite spawns the Chez that runs it.
;; Without it nothing below can run: fail, never skip.
(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the floors ----------------------------------------------

(define scratch
  (guard (e (#t #f))
    (make-process-temp-directory)))

(test-equal "mktemp -d made a scratch directory"
  'made
  (if (and (absolute? scratch) (file-directory? scratch)) 'made 'not-made))

(unless (and (absolute? scratch) (file-directory? scratch))
  (exit 1))

(define (in-scratch name) (string-append scratch "/" name))

(define floor-values (read-floor-values))

(test-equal "packaging/floors.sexp gives the decoy its versions: the floor, and the version one patch below it"
  'read
  (if (and (= (length floor-values) 2) (string? (car floor-values))) 'read floor-values))

(unless (string? (car floor-values))
  (exit 1))

;; builds : (Listof (Pairof String (Listof String)))
;; The one build this suite's rows use: the switches are the children's.
(define builds (decoy-builds (quote ("control"))))

(define (so-of build) (in-scratch (string-append build ".so")))

;; compiled : (Listof (Pairof String Any))
(define compiled (compile-decoys so-of floor-values builds))

(define (compiled-status build) (decoy-status compiled build))

;; decoy-row : String (U String #f) (Listof String) String (String -> Expected) -> Void
;; (library-loading)'s decoy-row-in, on this suite's one build.
(define (decoy-row build switch args description expected)
  (decoy-row-in so-of compiled-status build switch args description expected))

(define control-report (report (car floor-values) 10 3 0))

;; verb-row : (U String #f) (Listof String) String (Listof Any) -> Void
;; (library-loading)'s verb-row-in, on this suite's one build.
(define (verb-row switch calls description lines)
  (verb-row-in so-of compiled-status "control" switch calls description lines))



;; line : Any String -> (List Any String)
(define (line outcome growth) (list outcome growth))

;; refused-line : Symbol Any ... -> (List Any String)
;; A refusal calls no C: its growth is empty.
(define (refused-line who . irritants)
  (line (list 'refused who irritants) ""))

(define (num n) (number->string n))

(define other-hash
  "$argon2i$v=19$m=16,t=2,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndG")

;; hash-log : Natural Natural Natural -> String
;; crypto_pwhash_str over a password of PN bytes at OPS and MEM bytes, then the
;; wipes: the out block of 160 bytes, then the password's block.
(define (hash-log pn ops mem)
  (string-append "crypto_pwhash_str(p,p," (num pn) "," (num ops) "," (num mem) ") "
                 "sodium_memzero(p,160) "
                 "sodium_memzero(p," (num (max 1 pn)) ")"))

;; occurs-in? : String String -> Boolean
(define (occurs-in? needle text)
  (let ((n (string-length text)) (m (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring text i (+ i m)) needle) #t)
            (else (loop (+ i 1)))))))

;; --- pwhash-limits-odd: the range is rounded inward ---------------------------------------------

(define limits-table
  (list
   (cons "(make-password-limits 2 16)"
         (refused-line 'make-password-limits 'memory-out-of-range 'memory-kib 16))
   (cons "(begin (make-password-limits 2 17) (quote made))" (line 'made ""))
   (cons "(begin (make-password-limits 2 1023) (quote made))" (line 'made ""))
   (cons "(make-password-limits 2 1024)"
         (refused-line 'make-password-limits 'memory-out-of-range 'memory-kib 1024))
   (cons "(password-hash \"pw\" (make-password-limits 2 17))"
         (line other-hash (hash-log 2 2 17408)))))

(verb-row "pwhash-limits-odd" (map car limits-table)
  "memlimits of 16385 and 1048575 bytes: 16 and 1024 KiB are refused, 17 and 1023 accepted, and a hash at 17 KiB reaches C at 17408 bytes"
  (map cdr limits-table))

;; The refusal printed whole, through the probe's --describe.
(define described-answer
  (if (eqv? (compiled-status "control") 0)
      (verb-probe-with (cons (override (so-of "control")) (switch-args "pwhash-limits-odd"))
                       (list "--describe" "(make-password-limits 2 16)" "(make-password-limits 2 1024)"))
      (list 'not-compiled (compiled-status "control"))))

;; described-texts : -> (Listof Any)
;; The text of each call's refusal, or the answer itself when not as expected.
(define (described-texts)
  (if (and (pair? described-answer) (eqv? (car described-answer) 0)
           (list? (cadr described-answer)) (>= (length (cadr described-answer)) 4))
      (let ((lines (cadr described-answer)))
        (map (lambda (l)
               (if (and (pair? l) (pair? (car l)) (eq? (caar l) 'described) (equal? (cadr l) ""))
                   (cadr (car l))
                   (list 'unexpected l)))
             (list-head lines 2)))
      (list 'unexpected described-answer)))

(test-equal "the refusal of memory-kib 16 and of 1024 states the range, 17 to 1023, and its rule"
  '((#t #t) (#t #t))
  (map (lambda (text)
         (if (string? text)
             (list (occurs-in? "17 to 1023" text) (occurs-in? "memory-out-of-range" text))
             (list 'unexpected text)))
       (described-texts)))

(test-equal "the refused make-password-limits calls print with every count zero and the gate's Valgrind line"
  (list no-native-objects valgrind-line)
  (if (and (pair? described-answer) (list? (cadr described-answer)))
      (list-tail (cadr described-answer) (- (length (cadr described-answer)) 2))
      (list 'unexpected described-answer)))

;; --- this process ---------------------------------------------------------------------------

(test-equal "this suite's own process never loaded a libsodium, nor a decoy"
  '(not-loaded not-loaded)
  (list (if (foreign-entry? "sodium_version_string") 'loaded 'not-loaded)
        (if (foreign-entry? "decoy_calls") 'loaded 'not-loaded)))

(test-equal "the scratch directory is removed"
  '(done removed)
  (let* ((removal (guard (e (#t (list 'raised (describe e))))
                    (remove-temp-directory scratch)
                    'done))
         (left (if (file-directory? scratch) 'left 'removed)))
    (list removal left)))

(test-end "library-loading-password-limits")

(exit (suite-exit-status runner))
