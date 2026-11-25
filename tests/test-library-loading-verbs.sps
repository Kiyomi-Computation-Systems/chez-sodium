#!r6rs
;;; One of the suites that load libsodium end to end through a decoy
;;; (ADR-0002, ADR-0006, ADR-0007, ADR-0011): this one runs the verbs of
;;; (chez-sodium private byte-verbs) against the control build, one child a
;;; switch, through tests/verb-probe.sps. The decoy logs each call it gets, and
;;; every block a verb frees is wiped by a sodium_memzero call, so a verb's
;;; whole extent is in the log: what reaches C, with which lengths and which
;;; pointers, and, as an empty growth, what does not.
;;;
;;; Each call's line is (OUTCOME GROWTH): its answer, a refusal as
;;; (refused WHO IRRITANTS), or a &sodium-failed as (failed WHO FUNCTION CODE),
;;; then the log's growth as one string, asserted whole. A pointer is p, and
;;; never NULL, at a length of 0 too. Every call runs under an inner guard for
;;; something else, inside a catch-all guard, as a caller meets a verb.
;;;
;;;   the control      random-bytes 0 calls no C; random-bytes 5 calls
;;;                    randombytes_buf over 5 bytes, A5 each; blake2b keyed and
;;;                    unkeyed call crypto_generichash with its size, its input's
;;;                    length and its key's, 0 for none; the compare calls
;;;                    sodium_memcmp over the whole length, and over no length
;;;                    when the lengths differ; every refusal's growth is empty
;;;   sizes-other      the decoy's five sizes are 33, 8, 80, 9 and 81, which no
;;;                    release answers: the default size is 33, sizes 7 and 81
;;;                    are refused and 8 and 80 accepted, keys of 8 and 82 bytes
;;;                    are refused and 9 and 81 accepted. A size written in the
;;;                    verbs instead of read from libsodium fails one
;;;   generichash-fails, generichash-other
;;;                    crypto_generichash answering -1, and 1: blake2b raises a
;;;                    &sodium-failed whose code is the answer, through the
;;;                    probe's inner guard
;;;   memcmp-other     sodium_memcmp answering 1 for equal operands: the compare
;;;                    answers #f, since only 0 is a match
;;;
;;; More children read the load's constants, which no verb call can tell apart
;;; against the real library, where opslimit_max and passwd_max both answer
;;; 4294967295 and so do their macros:
;;;
;;;   the oracle        the C oracle (tests/libsodium-oracle.c), run against the
;;;                     control build under sizes-other, under
;;;                     pwhash-limits-other and with no switch. Against the real
;;;                     library each size function answers what its twins do, so
;;;                     no row there can tell the oracle's line for one from
;;;                     another's; here the five size answers differ, and under
;;;                     pwhash-limits-other so do the fourteen constants, the
;;;                     ops maximum 9 and the password maximum 100 apart. Each
;;;                     line is held to its own function and its own macro
;;;   the probe         tests/refusal-probe.sps --constants, under
;;;                     pwhash-limits-other: native's fourteen recorded
;;;                     constants, each under its own key
;;;
;;; The oracle's switch is set in this process's environment, which is safe in
;;; any order: every verb row's child sets or unsets its own.
;;;
;;; Under the memory gate each child runs under a Valgrind of its own
;;; (ADR-0011), so this suite runs 10 children, at most 14. Each child's counts
;;; are required zero, and each says whether it ran under Valgrind, which a row
;;; requires yes exactly when the gate asked.
;;;
;;; This process itself never loads libsodium, and requires as much at its
;;; end. No expected value is #f for something that can raise: a verb's #f
;;; is a line's outcome, printed by a child, and a raise in a row's actual
;;; expression is computed under a guard. Effects run in order, through let*,
;;; named lets and for-each, never map.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (library-loading)
        (libsodium-oracle)
        (only (chezscheme) file-directory? foreign-entry? getenv putenv))

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

(test-begin "library-loading-verbs")

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

;; --- expected lines ------------------------------------------------------------------------

;; the lines' parts. A block is at least one byte, so a length of 0 has a
;; block of one, and its wipe is over one byte.

;; block-of : Natural -> Natural
(define (block-of n) (max 1 n))

;; num : Natural -> String
(define (num n) (number->string n))

;; random-log : Natural -> String
;; randombytes_buf over N bytes, then the wipe of its block.
(define (random-log n)
  (string-append "randombytes_buf(p," (num n) ") sodium_memzero(p," (num n) ")"))

;; hash-log : Natural Natural Natural -> String
;; crypto_generichash into OUT bytes, over IN bytes of input and KEY bytes of
;; key, then the wipes: the output's block, the key's, the input's. An input or
;; key of no bytes has a block of one.
(define (hash-log out in key)
  (string-append "crypto_generichash(p," (num out) ",p," (num in) ",p," (num key) ") "
                 "sodium_memzero(p," (num out) ") "
                 "sodium_memzero(p," (num (block-of key)) ") "
                 "sodium_memzero(p," (num (block-of in)) ")"))

;; compare-log : Natural -> String
;; sodium_memcmp over N bytes, then the wipes of the two blocks.
(define (compare-log n)
  (string-append "sodium_memcmp(p,p," (num n) ") "
                 "sodium_memzero(p," (num (block-of n)) ") "
                 "sodium_memzero(p," (num (block-of n)) ")"))

;; a5 : Natural -> Bytevector
;; What the decoy leaves in an output of N bytes.
(define (a5 n) (make-bytevector n #xA5))

;; line : Any String -> (List Any String)
(define (line outcome growth) (list outcome growth))

;; refused-line : Symbol Any ... -> (List Any String)
;; A refusal calls no C: its growth is empty.
(define (refused-line who . irritants)
  (line (list 'refused who irritants) ""))

(define kind-symbol '(kind symbol))
(define kind-bytevector '(kind bytevector))

;; table-calls : (Listof (Pair String (List Any String))) -> (Listof String)
;; The calls of a table of (CALL . LINE), in order.
(define (table-calls table) (map car table))

;; table-lines : (Listof (Pair String (List Any String))) -> (Listof (List Any String))
;; The lines of a table of (CALL . LINE), in order.
(define (table-lines table) (map cdr table))

;; --- the control: answers ----------------------------------------------------------------------

(define control-answers
  (list
   ;; random-bytes
   (cons "(random-bytes 0)" (line (make-bytevector 0) ""))
   (cons "(random-bytes 5)" (line (a5 5) (random-log 5)))
   (cons "(bytevector-length (random-bytes 65536))" (line 65536 (random-log 65536)))
   ;; blake2b, unkeyed and keyed, each size and input length
   (cons "(blake2b (make-bytevector 3 1))" (line (a5 32) (hash-log 32 3 0)))
   (cons "(blake2b (make-bytevector 3 1) 32 (make-bytevector 16 7))"
         (line (a5 32) (hash-log 32 3 16)))
   (cons "(blake2b (make-bytevector 0) 32)" (line (a5 32) (hash-log 32 0 0)))
   (cons "(blake2b (make-bytevector 3 1) 64 (make-bytevector 64 1))"
         (line (a5 64) (hash-log 64 3 64)))
   (cons "(blake2b (make-bytevector 1 1) 16 (make-bytevector 16 1))"
         (line (a5 16) (hash-log 16 1 16)))
   (cons "(bytevector-length (blake2b (make-bytevector 65536 1)))"
         (line 32 (hash-log 32 65536 0)))
   ;; the compare
   (cons "(constant-time-bytevector=? (make-bytevector 3 1) (make-bytevector 3 1))"
         (line #t (compare-log 3)))
   (cons "(constant-time-bytevector=? (make-bytevector 3 1) (make-bytevector 3 2))"
         (line #f (compare-log 3)))
   (cons "(constant-time-bytevector=? (make-bytevector 0) (make-bytevector 0))" (line #t (compare-log 0)))
   (cons "(constant-time-bytevector=? (make-bytevector 65536 1) (make-bytevector 65536 1))"
         (line #t (compare-log 65536)))
   (cons "(constant-time-bytevector=? (make-bytevector 3 1) (make-bytevector 4 1))" (line #f ""))
   (cons "(constant-time-bytevector=? (make-bytevector 0) (make-bytevector 1 1))" (line #f ""))
   (cons "(constant-time-bytevector=? (make-bytevector 65536 1) (make-bytevector 1 1))" (line #f ""))))

(verb-row #f (table-calls control-answers)
  "random-bytes 0 calls no C; the others call it with their whole lengths, p everywhere, none NULL, at lengths of 0 too; a pair of other lengths calls none"
  (table-lines control-answers))

;; --- the control: every refusal, no growth -------------------------------------------------------

(define control-refusals
  (list
   (cons "(random-bytes -1)" (refused-line 'random-bytes 'not-a-natural 'n -1))
   (cons "(random-bytes 65537)" (refused-line 'random-bytes 'over-the-cap 'n 65537))
   (cons "(blake2b (quote hunter2))" (refused-line 'blake2b 'not-a-bytevector 'input kind-symbol))
   (cons "(blake2b (make-bytevector 65537 1))"
         (refused-line 'blake2b 'over-the-cap 'input kind-bytevector))
   (cons "(blake2b (make-bytevector 3 1) (quote big))"
         (refused-line 'blake2b 'not-a-natural 'size 'big))
   (cons "(blake2b (make-bytevector 3 1) 15)" (refused-line 'blake2b 'size-out-of-range 'size 15))
   (cons "(blake2b (make-bytevector 3 1) 65)" (refused-line 'blake2b 'size-out-of-range 'size 65))
   (cons "(blake2b (make-bytevector 3 1) 32 (quote oops))"
         (refused-line 'blake2b 'not-a-bytevector 'key kind-symbol))
   (cons "(blake2b (make-bytevector 3 1) 32 (make-bytevector 0))"
         (refused-line 'blake2b 'empty-key 'key kind-bytevector))
   (cons "(blake2b (make-bytevector 3 1) 32 (make-bytevector 15 1))"
         (refused-line 'blake2b 'key-length-out-of-range 'key kind-bytevector))
   (cons "(blake2b (make-bytevector 3 1) 32 (make-bytevector 65 1))"
         (refused-line 'blake2b 'key-length-out-of-range 'key kind-bytevector))
   (cons "(blake2b (make-bytevector 3 1) 32 (make-bytevector 65537 1))"
         (refused-line 'blake2b 'key-length-out-of-range 'key kind-bytevector))
   (cons "(constant-time-bytevector=? (quote hunter2) (make-bytevector 1 1))"
         (refused-line 'constant-time-bytevector=? 'not-a-bytevector 'a kind-symbol))
   (cons "(constant-time-bytevector=? (make-bytevector 65537 1) (make-bytevector 1 1))"
         (refused-line 'constant-time-bytevector=? 'over-the-cap 'a kind-bytevector))
   (cons "(constant-time-bytevector=? (make-bytevector 1 1) (quote oops))"
         (refused-line 'constant-time-bytevector=? 'not-a-bytevector 'b kind-symbol))
   (cons "(constant-time-bytevector=? (make-bytevector 1 1) (make-bytevector 65537 1))"
         (refused-line 'constant-time-bytevector=? 'over-the-cap 'b kind-bytevector))
   (cons "(constant-time-bytevector=? (make-bytevector 65537 1) (make-bytevector 65537 1))"
         (refused-line 'constant-time-bytevector=? 'over-the-cap 'a kind-bytevector))))

(verb-row #f (table-calls control-refusals)
  "every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no block, no call, no wipe; the over-long b is refused though a is short"
  (table-lines control-refusals))

;; --- sizes-other: the sizes are libsodium's ------------------------------------------------------

(define sizes-other-table
  (list
   (cons "(blake2b (make-bytevector 3 1))" (line (a5 33) (hash-log 33 3 0)))
   (cons "(blake2b (make-bytevector 3 1) 7)" (refused-line 'blake2b 'size-out-of-range 'size 7))
   (cons "(blake2b (make-bytevector 3 1) 81)" (refused-line 'blake2b 'size-out-of-range 'size 81))
   (cons "(blake2b (make-bytevector 3 1) 8)" (line (a5 8) (hash-log 8 3 0)))
   (cons "(blake2b (make-bytevector 3 1) 80)" (line (a5 80) (hash-log 80 3 0)))
   (cons "(blake2b (make-bytevector 3 1) 65)" (line (a5 65) (hash-log 65 3 0)))
   (cons "(blake2b (make-bytevector 3 1) 33 (make-bytevector 8 1))"
         (refused-line 'blake2b 'key-length-out-of-range 'key kind-bytevector))
   (cons "(blake2b (make-bytevector 3 1) 33 (make-bytevector 82 1))"
         (refused-line 'blake2b 'key-length-out-of-range 'key kind-bytevector))
   (cons "(blake2b (make-bytevector 3 1) 33 (make-bytevector 9 1))"
         (line (a5 33) (hash-log 33 3 9)))
   (cons "(blake2b (make-bytevector 3 1) 33 (make-bytevector 81 1))"
         (line (a5 33) (hash-log 33 3 81)))
   (cons "(blake2b (make-bytevector 3 1) 33 (make-bytevector 15 1))"
         (line (a5 33) (hash-log 33 3 15)))))

(verb-row "sizes-other" (table-calls sizes-other-table)
  "the default size is 33; sizes 7 and 81 are refused, 8, 65 and 80 accepted; keys of 8 and 82 are refused, 9, 15 and 81 accepted; each log line whole, so a length that goes to the wrong place shows"
  (table-lines sizes-other-table))

;; --- crypto_generichash's other answers -------------------------------------------------

;; failed-line : Integer Natural Natural Natural -> (List Any String)
;; A &sodium-failed of blake2b over crypto_generichash, its code the answer;
;; the call was made, and its blocks wiped.
(define (failed-line code out in key)
  (line (list 'failed 'blake2b "crypto_generichash" code) (hash-log out in key)))

(define (failing-table code)
  (list
   (cons "(blake2b (make-bytevector 3 1))" (failed-line code 32 3 0))
   (cons "(blake2b (make-bytevector 3 1) 32 (make-bytevector 16 7))" (failed-line code 32 3 16))
   (cons "(random-bytes 5)" (line (a5 5) (random-log 5)))))

(verb-row "generichash-fails" (table-calls (failing-table -1))
  "crypto_generichash answering -1 is a &sodium-failed of blake2b, function crypto_generichash, code -1, raised after the section through the inner guard for something else; random-bytes is unaffected"
  (table-lines (failing-table -1)))

(verb-row "generichash-other" (table-calls (failing-table 1))
  "crypto_generichash answering 1 is a &sodium-failed too, code 1: any answer but 0 fails, and the code is the answer"
  (table-lines (failing-table 1)))

;; --- memcmp-other --------------------------------------------------------------------------------

(define memcmp-other-table
  (list
   (cons "(constant-time-bytevector=? (make-bytevector 3 1) (make-bytevector 3 1))"
         (line #f (compare-log 3)))
   (cons "(constant-time-bytevector=? (make-bytevector 3 1) (make-bytevector 3 2))"
         (line #f (compare-log 3)))
   (cons "(constant-time-bytevector=? (make-bytevector 3 1) (make-bytevector 4 1))" (line #f ""))
   (cons "(constant-time-bytevector=? (make-bytevector 0) (make-bytevector 0))" (line #t (compare-log 0)))))

(verb-row "memcmp-other" (table-calls memcmp-other-table)
  "sodium_memcmp answering 1 for equal operands is no match: the compare answers #f, and #t only for 0, as at length 0"
  (table-lines memcmp-other-table))

;; --- the C oracle against the decoy -----------------------------------------------------------

;; oracle-under : String -> Any
;; libsodium-oracle's answer for the control build with CHEZ_SODIUM_DECOY set
;; to SWITCH: what the oracle reads in the decoy's functions and macros. The
;; empty value is no switch, and behaves as the control.
(define (oracle-under switch)
  (guard (e (#t (list 'raised (describe e))))
    (if (eqv? (compiled-status "control") 0)
        (begin (putenv "CHEZ_SODIUM_DECOY" switch)
               (libsodium-oracle getenv (so-of "control")))
        (list 'not-compiled (compiled-status "control")))))

;; oracle-constant-lines : (Listof Any) (Listof Any) -> (Listof Any)
;; The oracle's fourteen lines, in step 7's order: (NAME F M) for each, F from
;; FUNCTIONS, the decoy's answers, M from MACROS, the header's. The prefix's
;; line is (pwhash-strprefix "F" "M").
(define (oracle-constant-lines functions macros)
  (map (lambda (name f m) (list name f m)) constants-keys functions macros))

;; the header's macros: the releases' own, which are the control's answers.
(define header-constants control-constants)

;; The oracle's output whole: the report, the five size lines, the fourteen
;; constant lines, then Valgrind's line, as the gate asked.
(define (oracle-answer sizes constants)
  (append (list (cons 'version (car floor-values)) '(major . 10) '(minor . 3) '(init 0 0))
          (map (lambda (name f m) (list name f m))
               '(generichash-bytes generichash-bytes-min generichash-bytes-max
                 generichash-keybytes-min generichash-keybytes-max)
               sizes '(32 16 64 16 64))
          constants
          (list valgrind-line)))

;; Each (NAME F M): F the decoy's answer through its function, M the header's
;; macro. The decoy answers 33, 8, 80, 9 and 81; the header says 32, 16, 64, 16
;; and 64: no two of the ten are alike but in the macros' pairs, so a line read
;; through another function shows. The constants are the control's, F and M
;; equal.
(test-equal "the C oracle on the control build under sizes-other: its output whole, each size line the decoy's answer for its own function and the header's macro for it, the fourteen constant lines the control's, and Valgrind's line as the gate asked"
  (oracle-answer '(33 8 80 9 81)
                 (oracle-constant-lines control-constants header-constants))
  (oracle-under "sizes-other"))

;; Under pwhash-limits-other the decoy's fourteen differ from the header's, and
;; from each other: opslimit_max answers 9 and passwd_max 100, where the header's
;; macros are both 4294967295, so a line read through its twin's function shows.
(test-equal "the C oracle on the control build under pwhash-limits-other: its output whole, each constant line the decoy's answer for its own function and the header's macro for it, the twins opslimit_max and passwd_max apart"
  (oracle-answer '(32 16 64 16 64)
                 (oracle-constant-lines other-constants header-constants))
  (oracle-under "pwhash-limits-other"))

(test-equal "the C oracle on the control build with no switch: its output whole, each constant line the control's, F and M alike"
  (oracle-answer '(32 16 64 16 64)
                 (oracle-constant-lines control-constants header-constants))
  (oracle-under ""))

;; --- native's constants against the decoy ---------------------------------------------------

(decoy-row "control" "pwhash-limits-other" '("--sizes" "yes" "--constants" "yes")
  "native's fourteen recorded constants under pwhash-limits-other, each under its own key: the twins opslimit_max 9 and passwd_max 100 apart, the prefix the decoy's, and the load's calls in order"
  (lambda (so)
    (loaded so 'override
            (with-constants (with-sizes control-report control-sizes) other-constants)
            (loaded-calls "pwhash-limits-other"))))

;; --- this process --------------------------------------------------------------------------------

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

(test-end "library-loading-verbs")

(exit (suite-exit-status runner))
