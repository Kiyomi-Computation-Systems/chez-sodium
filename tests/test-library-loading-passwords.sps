#!r6rs
;;; One of the suites that load libsodium end to end through a decoy
;;; (ADR-0002, ADR-0006, ADR-0007, ADR-0009, ADR-0011): this one runs the
;;; password verbs of (chez-sodium private password-verbs) against the control
;;; build, one child a switch, through tests/verb-probe.sps. The decoy logs
;;; each call it gets, and every block a verb frees is wiped by a
;;; sodium_memzero call, so a verb's whole extent is in the log: what reaches
;;; C, with which lengths, and, as an empty growth, what does not.
;;;
;;; Each call's line is (OUTCOME GROWTH): its answer, a refusal as
;;; (refused WHO IRRITANTS), or a &sodium-failed as (failed WHO FUNCTION CODE),
;;; then the log's growth as one string, asserted whole. A pointer is p, and a
;;; hash string's is p[L], L its length. Every call runs under an inner guard
;;; for something else, inside a catch-all guard, as a caller meets a verb.
;;;
;;;   the control      password-hash reaches crypto_pwhash_str with its
;;;                    password's UTF-8 length, the preset's numbers or the
;;;                    limits given, in memory bytes, and wipes the out block of
;;;                    128 bytes, then the password's block; password-verify and
;;;                    password-needs-rehash? reach C with p[L], L the hash
;;;                    string's length; the empty password is a pointer to a
;;;                    one-byte block and a length of 0. Every refusal, and
;;;                    every answer that needs no C, grows the log by nothing
;;;   pwhash-str-fails, pwhash-str-other
;;;                    crypto_pwhash_str answering -1, and 1: password-hash
;;;                    raises a &sodium-failed with that code, through the
;;;                    probe's inner guard for something else
;;;   pwhash-str-unreadable
;;;                    crypto_pwhash_str answering 0 and leaving no string:
;;;                    a &sodium-failed with code 0
;;;   pwhash-str-empty crypto_pwhash_str answering 0 and leaving an empty
;;;                    string: a &sodium-failed with code 0 too
;;;   verify-other     crypto_pwhash_str_verify answering 1: password-verify
;;;                    answers #f
;;;   pwhash-limits-other
;;;                    the decoy's fourteen constants are none a release's: ops
;;;                    from 2 to 9 and memory from 16 to 1024 KiB are accepted
;;;                    one inside each edge and refused one outside it, a
;;;                    password of 1 to 100 bytes is accepted and of 0 and 101
;;;                    refused, a password over the cap is refused as over the
;;;                    cap, the presets are the decoy's, the out block is its
;;;                    160 bytes and its string is read whole at 140 characters,
;;;                    and the prefix is its $argon2i$. A constant written in
;;;                    the verbs instead of read from libsodium fails one of
;;;                    these. The refusal of a length prints the same for every
;;;                    password, whatever its content or length
;;;   strprefix-null   crypto_pwhash_strprefix answering NULL: no hash is
;;;                    current, and no C is called to say so
;;;
;;; One more child, on the control, runs the probe's --rehash-change-sweep:
;;; password-needs-rehash? under an engine at each fuel, its hash string changed
;;; at each expiry, whose log tells which path each run took.
;;;
;;; Under the memory gate each child runs under a Valgrind of its own
;;; (ADR-0011), so this suite runs 14 children, at most 14. Each child's counts
;;; are required zero, and each says whether it ran under Valgrind, which a row
;;; requires yes exactly when the gate asked.
;;;
;;; This process itself never loads libsodium, and requires as much at its end.
;;; No expected value is #f for something that can raise: a verb's #f is a
;;; line's outcome, printed by a child, and a raise in a row's actual
;;; expression is computed under a guard. Effects run in order, through let*,
;;; named lets and for-each, never map.
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

(test-begin "library-loading-passwords")

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

;; num : Natural -> String
(define (num n) (number->string n))

;; block-of : Natural -> Natural
;; A block is at least one byte, so a length of 0 has a block of one, and its
;; wipe is over one byte.
(define (block-of n) (max 1 n))

;; line : Any String -> (List Any String)
(define (line outcome growth) (list outcome growth))

;; refused-line : Symbol Any ... -> (List Any String)
;; A refusal calls no C: its growth is empty.
(define (refused-line who . irritants)
  (line (list 'refused who irritants) ""))

;; failed-line : Integer String -> (List Any String)
;; A &sodium-failed of password-hash over crypto_pwhash_str, its code the
;; answer; the call was made, and its blocks wiped.
(define (failed-line code growth)
  (line (list 'failed 'password-hash "crypto_pwhash_str" code) growth))

(define kind-symbol '(kind symbol))
(define kind-string '(kind string))

;; w : String -> String
;; S as a Scheme string literal, for a call's text.
(define (w s)
  (call-with-string-output-port (lambda (port) (write s port))))

;; the decoy's fixed hash strings: the control's of 93 characters, and
;; pwhash-limits-other's of 140. The 136-character hash is libsodium's own,
;; which verifies for the password "pw".
(define control-hash
  "$argon2id$v=19$m=8,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGE")
(define other-hash
  "$argon2i$v=19$m=16,t=2,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndG")
(define long-hash
  "$argon2id$v=19$m=8,t=1,p=1$EyYDv0QsQbeigj9AAWd4og$2h21FCkx8IoVDEl4/mLnPx/13x3VOsaGEEcSznsHWANOIbT5yNoNpmiSmo3WFrwrB8CHtsaXS9cT0QGGUfFzow")

(test-equal "the decoy's strings are 93 and 140 characters, and libsodium's long hash 136"
  '(93 140 136)
  (list (string-length control-hash) (string-length other-hash) (string-length long-hash)))

;; hash-log : Natural Natural Natural Natural -> String
;; crypto_pwhash_str over a password of PN bytes at OPS and MEM, then the wipes:
;; the out block of STRBYTES, then the password's block, which is made first.
(define (hash-log pn ops mem strbytes)
  (string-append "crypto_pwhash_str(p,p," (num pn) "," (num ops) "," (num mem) ") "
                 "sodium_memzero(p," (num strbytes) ") "
                 "sodium_memzero(p," (num (block-of pn)) ")"))

;; verify-log : Natural Natural -> String
;; crypto_pwhash_str_verify over a hash string of LEN characters and a password
;; of PN bytes, then the wipes: the password's block, then the string's, which is
;; made first, LEN + 1 bytes.
(define (verify-log len pn)
  (string-append "crypto_pwhash_str_verify(p[" (num len) "],p," (num pn) ") "
                 "sodium_memzero(p," (num (block-of pn)) ") "
                 "sodium_memzero(p," (num (+ len 1)) ")"))

;; rehash-log : Natural Natural Natural -> String
(define (rehash-log len ops mem)
  (string-append "crypto_pwhash_str_needs_rehash(p[" (num len) "]," (num ops) "," (num mem) ") "
                 "sodium_memzero(p," (num (+ len 1)) ")"))

;; table-calls, table-lines : (Listof (Pair String (List Any String))) -> (Listof ...)
(define (table-calls table) (map car table))
(define (table-lines table) (map cdr table))

;; the control's presets: ops, then memory in bytes
(define interactive-ops 2)
(define interactive-mem 67108864)
(define moderate-ops 3)
(define moderate-mem 268435456)
(define sensitive-ops 4)
(define sensitive-mem 1073741824)

;; utf8 passwords as calls spell them, and their UTF-8 lengths: a-umlaut and
;; the euro sign take two and three bytes, so 5; four emoji of four bytes, 16.
(define mixed-call "(string (integer->char 228) (integer->char 8364))")
(define mixed-bytes 5)
(define emoji-call "(make-string 4 (integer->char 128512))")
(define emoji-bytes 16)
(define euros-call "(string-append (make-string 21845 (integer->char 8364)) \"x\")")

;; --- the control: answers --------------------------------------------------------------------

(define control-answers
  (list
   ;; password-hash: the limits, each preset, the default
   (cons "(password-hash \"pw\" (make-password-limits 2 16))"
         (line control-hash (hash-log 2 2 16384 128)))
   (cons "(password-hash \"pw\" (make-password-limits 1 8))"
         (line control-hash (hash-log 2 1 8192 128)))
   (cons "(password-hash \"pw\" (make-password-limits 4294967295 4294967295))"
         (line control-hash (hash-log 2 4294967295 4398046510080 128)))
   (cons "(password-hash \"pw\")"
         (line control-hash (hash-log 2 interactive-ops interactive-mem 128)))
   (cons "(password-hash \"pw\" (quote interactive))"
         (line control-hash (hash-log 2 interactive-ops interactive-mem 128)))
   (cons "(password-hash \"pw\" (quote moderate))"
         (line control-hash (hash-log 2 moderate-ops moderate-mem 128)))
   (cons "(password-hash \"pw\" (quote sensitive))"
         (line control-hash (hash-log 2 sensitive-ops sensitive-mem 128)))
   ;; the length is the UTF-8 bytes, not the characters
   (cons (string-append "(password-hash " mixed-call ")")
         (line control-hash (hash-log mixed-bytes interactive-ops interactive-mem 128)))
   (cons (string-append "(password-hash " emoji-call ")")
         (line control-hash (hash-log emoji-bytes interactive-ops interactive-mem 128)))
   ;; the empty password: a pointer, never NULL, and a length of 0
   (cons "(password-hash \"\")"
         (line control-hash (hash-log 0 interactive-ops interactive-mem 128)))
   ;; the cap's edge, in bytes
   (cons "(password-hash (make-string 65536 #\\a))"
         (line control-hash (hash-log 65536 interactive-ops interactive-mem 128)))
   (cons (string-append "(password-hash " euros-call ")")
         (line control-hash (hash-log 65536 interactive-ops interactive-mem 128)))
   ;; password-verify: p[L], L the hash string's length, whatever it is
   (cons (string-append "(password-verify " (w control-hash) " \"pw\")")
         (line #t (verify-log 93 2)))
   (cons (string-append "(password-verify " (w control-hash) " \"\")")
         (line #t (verify-log 93 0)))
   (cons (string-append "(password-verify " (w control-hash) " " mixed-call ")")
         (line #t (verify-log 93 mixed-bytes)))
   (cons (string-append "(password-verify " (w long-hash) " \"pw\")")
         (line #t (verify-log 136 2)))
   (cons (string-append "(password-verify (make-string 65536 #\\a) \"pw\")")
         (line #t (verify-log 65536 2)))
   ;; password-needs-rehash?: the limits, each preset, the default
   (cons (string-append "(password-needs-rehash? " (w control-hash) " (make-password-limits 2 16))")
         (line #f (rehash-log 93 2 16384)))
   (cons (string-append "(password-needs-rehash? " (w control-hash) ")")
         (line #f (rehash-log 93 interactive-ops interactive-mem)))
   (cons (string-append "(password-needs-rehash? " (w control-hash) " (quote moderate))")
         (line #f (rehash-log 93 moderate-ops moderate-mem)))
   (cons (string-append "(password-needs-rehash? " (w control-hash) " (quote sensitive))")
         (line #f (rehash-log 93 sensitive-ops sensitive-mem)))
   (cons (string-append "(password-needs-rehash? " (w long-hash) ")")
         (line #f (rehash-log 136 interactive-ops interactive-mem)))
   ;; the constructor reaches no C
   (cons "(begin (make-password-limits 2 16) (quote made))" (line 'made ""))))

(verb-row #f (table-calls control-answers)
  "password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the out block's 128 bytes wiped before the password's; verify and needs-rehash reach it with p[L]; the empty password is a block of one with a length of 0; the cap's edge in bytes; the constructor reaches none"
  (table-lines control-answers))

;; --- the control: every refusal, and every answer that needs no C: no growth ------------------

(define pre-check-calls
  (list
   (cons "(password-verify \"\" \"pw\")" (line #f ""))
   (cons "(password-verify \"garbage text\" \"pw\")" (line #f ""))
   (cons (string-append "(password-verify (string-append " (w control-hash)
                        " (string (integer->char 0)) \"junk\") \"pw\")")
         (line #f ""))
   (cons (string-append "(password-verify (string-append " (w control-hash)
                        " (string (integer->char 233))) \"pw\")")
         (line #f ""))
   (cons "(password-verify (string-append \"$argon2id$v=19$m=8,t=1,p=1$\" (string (integer->char 128)) \"aaaa\") \"pw\")"
         (line #f ""))
   (cons "(password-verify (make-string 65537 #\\a) \"pw\")" (line #f ""))
   (cons "(password-needs-rehash? \"\")" (line #t ""))
   (cons "(password-needs-rehash? \"garbage\")" (line #t ""))
   (cons "(password-needs-rehash? \"$argon2id$\")" (line #t ""))
   (cons (string-append "(password-needs-rehash? (string-append " (w control-hash) " \" \"))")
         (line #t ""))
   (cons (string-append "(password-needs-rehash? (string-append " (w control-hash)
                        " (string (integer->char 0)) \"junk\"))")
         (line #t ""))
   (cons "(password-needs-rehash? (make-string 65537 #\\a))" (line #t ""))
   (cons (string-append "(password-needs-rehash? " (w other-hash) ")") (line #t ""))
   (cons "(password-needs-rehash? \"$argon2id$v=19$m=8,t=1,p=4$c2FsdHNhbHRzYWx0c2FsdA$dGFndA\")"
         (line #t ""))
   (cons "(password-needs-rehash? \"$argon2id$v=19$m=8,t=1,p=10$c2FsdHNhbHRzYWx0c2FsdA$dGFndA\")"
         (line #t ""))
   (cons "(password-needs-rehash? \"$argon2id$m=8,t=1,p=1$c2FsdHNhbHRzYWx0c2FsdA$dGFndA\")"
         (line #t ""))
   (cons "(password-needs-rehash? \"$argon2id$v=19$m=8,t=1,p=1$\")" (line #t ""))))

(define control-refusals
  (list
   (cons "(password-hash (quote hunter2))" (refused-line 'password-hash 'not-a-string 'password kind-symbol))
   (cons "(password-hash 42)" (refused-line 'password-hash 'not-a-string 'password '(kind number)))
   (cons "(password-hash #f)" (refused-line 'password-hash 'not-a-string 'password '(kind boolean)))
   (cons "(password-hash (quote (1 2)))" (refused-line 'password-hash 'not-a-string 'password '(kind list)))
   (cons "(password-hash (make-bytevector 1 1))"
         (refused-line 'password-hash 'not-a-string 'password '(kind bytevector)))
   (cons "(password-hash (make-string 65537 #\\a))"
         (refused-line 'password-hash 'over-the-cap 'password kind-string))
   (cons "(password-hash (string-append (make-string 21845 (integer->char 8364)) \"xx\"))"
         (refused-line 'password-hash 'over-the-cap 'password kind-string))
   (cons "(password-hash (make-string 32769 (integer->char 233)))"
         (refused-line 'password-hash 'over-the-cap 'password kind-string))
   (cons "(password-hash \"pw\" (quote fast))"
         (refused-line 'password-hash 'not-password-limits 'limits 'fast))
   (cons "(password-hash \"pw\" 42)" (refused-line 'password-hash 'not-password-limits 'limits 42))
   (cons "(password-hash \"pw\" \"interactive\")"
         (refused-line 'password-hash 'not-password-limits 'limits kind-string))
   (cons "(password-hash \"pw\" (quote (2 16)))"
         (refused-line 'password-hash 'not-password-limits 'limits '(2 16)))
   (cons "(password-hash \"pw\" #f)" (refused-line 'password-hash 'not-password-limits 'limits #f))
   (cons "(password-hash (quote hunter2) (quote fast))"
         (refused-line 'password-hash 'not-a-string 'password kind-symbol))
   (cons "(password-hash (make-string 65537 #\\a) (quote fast))"
         (refused-line 'password-hash 'over-the-cap 'password kind-string))
   (cons "(password-verify (quote hunter2) \"pw\")"
         (refused-line 'password-verify 'not-a-string 'hash kind-symbol))
   (cons "(password-verify 42 \"pw\")" (refused-line 'password-verify 'not-a-string 'hash '(kind number)))
   (cons "(password-verify \"\" (quote x))"
         (refused-line 'password-verify 'not-a-string 'password kind-symbol))
   (cons "(password-verify (string (integer->char 0) #\\b) 42)"
         (refused-line 'password-verify 'not-a-string 'password '(kind number)))
   (cons "(password-verify (quote x) (quote y))"
         (refused-line 'password-verify 'not-a-string 'hash kind-symbol))
   (cons "(password-verify \"\" (make-string 65537 #\\a))"
         (refused-line 'password-verify 'over-the-cap 'password kind-string))
   (cons "(password-verify (string-append \"a\" (string (integer->char 0))) (make-string 32769 (integer->char 233)))"
         (refused-line 'password-verify 'over-the-cap 'password kind-string))
   (cons "(password-needs-rehash? (quote x))"
         (refused-line 'password-needs-rehash? 'not-a-string 'hash kind-symbol))
   (cons "(password-needs-rehash? #f)"
         (refused-line 'password-needs-rehash? 'not-a-string 'hash '(kind boolean)))
   (cons "(password-needs-rehash? \"garbage\" (quote fast))"
         (refused-line 'password-needs-rehash? 'not-password-limits 'limits 'fast))
   (cons "(password-needs-rehash? \"\" 42)"
         (refused-line 'password-needs-rehash? 'not-password-limits 'limits 42))
   (cons "(password-needs-rehash? (quote x) (quote fast))"
         (refused-line 'password-needs-rehash? 'not-a-string 'hash kind-symbol))
   (cons "(make-password-limits 0 16)"
         (refused-line 'make-password-limits 'ops-out-of-range 'ops 0))
   (cons "(make-password-limits 4294967296 16)"
         (refused-line 'make-password-limits 'ops-out-of-range 'ops 4294967296))
   (cons "(make-password-limits (quote x) 16)"
         (refused-line 'make-password-limits 'not-a-natural 'ops 'x))
   (cons "(make-password-limits 2 7)"
         (refused-line 'make-password-limits 'memory-out-of-range 'memory-kib 7))
   (cons "(make-password-limits 2 4294967296)"
         (refused-line 'make-password-limits 'memory-out-of-range 'memory-kib 4294967296))
   (cons "(make-password-limits 2 \"16\")"
         (refused-line 'make-password-limits 'not-a-natural 'memory-kib kind-string))
   (cons "(make-password-limits 2 1.5)"
         (refused-line 'make-password-limits 'not-a-natural 'memory-kib 1.5))))

(define no-c-table (append control-refusals pre-check-calls))

(verb-row #f (table-calls no-c-table)
  "every refusal of the table is (refused WHO IRRITANTS) whole, a refusal comes before another's pre-check; a hash string that fails the pre-check, or the shape check, is #f from password-verify and #t from password-needs-rehash?, a byte of 0x80 and a NUL among them; and the log gains nothing: no block, no call, no wipe"
  (table-lines no-c-table))

;; --- crypto_pwhash_str's other answers (row 17) ------------------------------------------------

(define (failing-table code)
  (list
   (cons "(password-hash \"pw\" (make-password-limits 2 16))"
         (failed-line code (hash-log 2 2 16384 128)))
   (cons "(password-hash \"\")" (failed-line code (hash-log 0 interactive-ops interactive-mem 128)))
   (cons (string-append "(password-verify " (w control-hash) " \"pw\")")
         (line #t (verify-log 93 2)))
   (cons (string-append "(password-needs-rehash? " (w control-hash) ")")
         (line #f (rehash-log 93 interactive-ops interactive-mem)))))

(verb-row "pwhash-str-fails" (table-calls (failing-table -1))
  "crypto_pwhash_str answering -1 is a &sodium-failed of password-hash, function crypto_pwhash_str, code -1, raised after the section through the inner guard for something else, with both blocks wiped; verify and needs-rehash are unaffected"
  (table-lines (failing-table -1)))

(verb-row "pwhash-str-other" (table-calls (failing-table 1))
  "crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any answer but 0 fails, and the code is the answer"
  (table-lines (failing-table 1)))

(verb-row "pwhash-str-unreadable" (table-calls (failing-table 0))
  "crypto_pwhash_str answering 0 and leaving no string is a &sodium-failed with code 0, the blocks wiped"
  (table-lines (failing-table 0)))

;; --- verify-other --------------------------------------------------------------------------------

(define verify-other-table
  (list
   (cons (string-append "(password-verify " (w control-hash) " \"pw\")")
         (line #f (verify-log 93 2)))
   (cons (string-append "(password-verify " (w control-hash) " \"\")")
         (line #f (verify-log 93 0)))
   (cons "(password-hash \"pw\")"
         (line control-hash (hash-log 2 interactive-ops interactive-mem 128)))
   (cons (string-append "(password-needs-rehash? " (w control-hash) ")")
         (line #f (rehash-log 93 interactive-ops interactive-mem)))))

(verb-row "verify-other" (table-calls verify-other-table)
  "crypto_pwhash_str_verify answering 1 is #f, with nothing raised: any answer but 0 is no match; the other two verbs are unaffected"
  (table-lines verify-other-table))

;; --- strprefix-null --------------------------------------------------------------------------------

(define prefix-null-table
  (list
   (cons (string-append "(password-needs-rehash? " (w control-hash) ")") (line #t ""))
   (cons (string-append "(password-needs-rehash? " (w control-hash) " (quote sensitive))") (line #t ""))
   (cons "(password-hash \"pw\")"
         (line control-hash (hash-log 2 interactive-ops interactive-mem 128)))
   (cons (string-append "(password-verify " (w control-hash) " \"pw\")") (line #t (verify-log 93 2)))))

(verb-row "strprefix-null" (table-calls prefix-null-table)
  "a NULL prefix is recorded as #f: password-needs-rehash? answers #t for a good hash, at every preset, without calling C; the other two verbs are unaffected"
  (table-lines prefix-null-table))

;; --- pwhash-limits-other: the constants are libsodium's ----------------------------------------
;; The decoy's constants: strbytes 160; ops 2 to 9, presets 5, 6 and 7; memory
;; 16 to 1024 KiB, presets 24576, 32768 and 40960 bytes; passwords 1 to 100
;; bytes; the prefix $argon2i$. No release has any, so a number written in the
;; verbs instead of read from libsodium fails a row.

(define other-interactive '(5 24576))
(define other-moderate '(6 32768))
(define other-sensitive '(7 40960))

;; other-hash-log : Natural Natural Natural -> String
;; crypto_pwhash_str under pwhash-limits-other: the out block is 160 bytes.
(define (other-hash-log pn ops mem) (hash-log pn ops mem 160))

(define length-refusal
  (refused-line 'password-hash 'length-out-of-range 'password kind-string))
(define verify-length-refusal
  (refused-line 'password-verify 'length-out-of-range 'password kind-string))

(define ranges-table
  (list
   ;; the constructor's ranges, one outside each edge and at it
   (cons "(make-password-limits 1 16)" (refused-line 'make-password-limits 'ops-out-of-range 'ops 1))
   (cons "(make-password-limits 10 16)" (refused-line 'make-password-limits 'ops-out-of-range 'ops 10))
   (cons "(begin (make-password-limits 2 16) (quote made))" (line 'made ""))
   (cons "(begin (make-password-limits 9 16) (quote made))" (line 'made ""))
   (cons "(make-password-limits 2 15)"
         (refused-line 'make-password-limits 'memory-out-of-range 'memory-kib 15))
   (cons "(make-password-limits 2 1025)"
         (refused-line 'make-password-limits 'memory-out-of-range 'memory-kib 1025))
   (cons "(begin (make-password-limits 2 1024) (quote made))" (line 'made ""))
   (cons "(password-hash \"pw\" (make-password-limits 9 1024))"
         (line other-hash (other-hash-log 2 9 1048576)))
   ;; a password's UTF-8 length: 1 to 100 accepted, 0 and 101 refused
   (cons "(password-hash \"\")" length-refusal)
   (cons "(password-hash (make-string 101 #\\a))" length-refusal)
   (cons "(password-hash (make-string 1 #\\a))"
         (line other-hash (other-hash-log 1 5 24576)))
   (cons "(password-hash (make-string 100 #\\a))"
         (line other-hash (other-hash-log 100 5 24576)))
   (cons "(password-hash (string-append (make-string 33 (integer->char 8364)) \"xx\"))" length-refusal)
   (cons "(password-hash (string-append (make-string 33 (integer->char 8364)) \"x\"))"
         (line other-hash (other-hash-log 100 5 24576)))
   (cons "(password-hash (make-string 50 (integer->char 233)))"
         (line other-hash (other-hash-log 100 5 24576)))
   (cons "(password-hash (make-string 51 (integer->char 233)))" length-refusal)
   ;; the cap comes before the range
   (cons "(password-hash (make-string 65537 #\\a))"
         (refused-line 'password-hash 'over-the-cap 'password kind-string))
   (cons "(password-verify \"x\" (make-string 65537 #\\a))"
         (refused-line 'password-verify 'over-the-cap 'password kind-string))
   ;; the same range for password-verify, and a refusal before its pre-check
   (cons (string-append "(password-verify " (w other-hash) " \"\")") verify-length-refusal)
   (cons (string-append "(password-verify " (w other-hash) " (make-string 101 #\\a))")
         verify-length-refusal)
   (cons (string-append "(password-verify " (w other-hash) " (make-string 100 #\\a))")
         (line #t (verify-log 140 100)))
   (cons (string-append "(password-verify " (w other-hash) " \"a\")")
         (line #t (verify-log 140 1)))
   (cons "(password-verify \"\" \"\")" verify-length-refusal)
   (cons "(password-verify \"\" (make-string 101 #\\a))" verify-length-refusal)
   (cons "(password-verify \"\" \"a\")" (line #f ""))))

(verb-row "pwhash-limits-other" (table-calls ranges-table)
  "ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 and 1024 accepted; a password of 0 and 101 bytes is refused as length-out-of-range, 1 and 100 accepted, counted in UTF-8 bytes; 65537 bytes is over-the-cap, not out of range; the refusal comes before verify's pre-check"
  (table-lines ranges-table))

(define presets-table
  (list
   (cons "(password-hash \"pw\")" (line other-hash (other-hash-log 2 5 24576)))
   (cons "(password-hash \"pw\" (quote interactive))" (line other-hash (other-hash-log 2 5 24576)))
   (cons "(password-hash \"pw\" (quote moderate))" (line other-hash (other-hash-log 2 6 32768)))
   (cons "(password-hash \"pw\" (quote sensitive))" (line other-hash (other-hash-log 2 7 40960)))
   (cons "(string-length (password-hash \"pw\"))" (line 140 (other-hash-log 2 5 24576)))
   (cons (string-append "(password-needs-rehash? " (w other-hash) " (quote interactive))")
         (line #f (rehash-log 140 5 24576)))
   (cons (string-append "(password-needs-rehash? " (w other-hash) " (quote moderate))")
         (line #f (rehash-log 140 6 32768)))
   (cons (string-append "(password-needs-rehash? " (w other-hash) " (quote sensitive))")
         (line #f (rehash-log 140 7 40960)))
   (cons (string-append "(password-needs-rehash? " (w other-hash) " (make-password-limits 2 16))")
         (line #f (rehash-log 140 2 16384)))))

(verb-row "pwhash-limits-other" (table-calls presets-table)
  "each preset hashes at the decoy's numbers, read from the log line; the out block is the decoy's 160 bytes, and its 140-character string is read whole; needs-rehash reaches C at those numbers"
  (table-lines presets-table))

(define prefix-table
  (list
   (cons (string-append "(password-needs-rehash? " (w other-hash) ")")
         (line #f (rehash-log 140 5 24576)))
   (cons (string-append "(password-needs-rehash? " (w control-hash) ")") (line #t ""))
   (cons (string-append "(password-needs-rehash? " (w control-hash) " (quote sensitive))") (line #t ""))
   (cons "(password-needs-rehash? \"$argon2i$v=19$m=16,t=2,p=4$c2FsdHNhbHRzYWx0c2FsdA$dGFndA\")"
         (line #t ""))
   (cons (string-append "(password-verify " (w other-hash) " \"pw\")") (line #t (verify-log 140 2)))))

(verb-row "pwhash-limits-other" (table-calls prefix-table)
  "the prefix is the decoy's $argon2i$: an argon2i-shaped string reaches C and answers #f, an argon2id one answers #t without C, and so does an argon2i one that reads p=4"
  (table-lines prefix-table))

;; --- R16: length-out-of-range, printed -----------------------------------------------------------
;; The refusal of a length prints the same for every password: two of the same
;; UTF-8 length, one not ASCII, with other characters, and one of another
;; length, each through the probe's option that prints the whole condition,
;; message included.

;; hunter-string : Natural -> String
(define (hunter-string n)
  (let loop ((i 0) (chars '()))
    (if (= i n)
        (list->string (reverse chars))
        (loop (+ i 1) (cons (string-ref "hunter2" (mod i 7)) chars)))))

(define non-ascii-101-call "(string-append (make-string 33 (integer->char 8364)) \"xx\")")

;; printed-lines : (Listof String) -> (U (List Integer (Listof Any) String) (List 'raised String))
;; The probe's answer for CALLS under pwhash-limits-other with --describe.
(define (printed-lines calls)
  (if (eqv? (compiled-status "control") 0)
      (verb-probe-with (cons (override (so-of "control")) (switch-args "pwhash-limits-other"))
                       (cons "--describe" calls))
      (list 'not-compiled (compiled-status "control"))))

;; texts-of : (List Integer (Listof Any) String) -> (Listof Any)
;; The text each call printed, with an empty growth, or the line itself.
(define (texts-of answer)
  (if (and (pair? answer) (eqv? (car answer) 0) (list? (cadr answer)))
      (let loop ((lines (cadr answer)) (found '()))
        (cond ((null? lines) (reverse found))
              ((and (pair? (car lines)) (pair? (caar lines)) (eq? (caaar lines) 'described)
                    (equal? (cadar lines) ""))
               (loop (cdr lines) (cons (cadr (caar lines)) found)))
              (else (loop (cdr lines) found))))
      (list 'unexpected answer)))

;; occurs-in? : String String -> Boolean
(define (occurs-in? needle text)
  (let ((n (string-length text)) (m (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring text i (+ i m)) needle) #t)
            (else (loop (+ i 1)))))))

(define hunter-101 (w (hunter-string 101)))
(define hunter-102 (w (hunter-string 102)))

(define hash-answer
  (printed-lines
   (list (string-append "(password-hash " hunter-101 ")")
         (string-append "(password-hash " non-ascii-101-call ")")
         (string-append "(password-hash " hunter-102 ")"))))

(define verify-answer
  (printed-lines
   (list (string-append "(password-verify " (w other-hash) " " hunter-101 ")")
         (string-append "(password-verify " (w other-hash) " " non-ascii-101-call ")")
         (string-append "(password-verify " (w other-hash) " " hunter-102 ")"))))

(test-equal "R16 the probe's --describe answers, for three passwords each of password-hash and password-verify, status 0, the three texts, an empty stderr, every count zero and the gate's Valgrind line"
  (list (list 0 3 "" (list no-native-objects valgrind-line))
        (list 0 3 "" (list no-native-objects valgrind-line)))
  (map (lambda (answer)
         (if (and (pair? answer) (eqv? (car answer) 0) (list? (cadr answer))
                  (>= (length (cadr answer)) 2))
             (list (car answer) (length (texts-of answer)) (caddr answer)
                   (list-tail (cadr answer) (- (length (cadr answer)) 2)))
             (list 'unexpected answer)))
       (list hash-answer verify-answer)))

(test-equal "R16 password-hash of 101 ASCII characters, of 101 bytes with non-ASCII characters, and of 102 bytes: the printed refusal is the same text for all three"
  '(same same)
  (let ((texts (texts-of hash-answer)))
    (if (and (= (length texts) 3) (for-all string? texts))
        (list (if (equal? (car texts) (cadr texts)) 'same (list 'differs (cadr texts)))
              (if (equal? (car texts) (caddr texts)) 'same (list 'differs (caddr texts))))
        (list 'unexpected texts))))

(test-equal "R16 password-verify of 101 ASCII characters, of 101 bytes with non-ASCII characters, and of 102 bytes: the printed refusal is the same text for all three"
  '(same same)
  (let ((texts (texts-of verify-answer)))
    (if (and (= (length texts) 3) (for-all string? texts))
        (list (if (equal? (car texts) (cadr texts)) 'same (list 'differs (cadr texts)))
              (if (equal? (car texts) (caddr texts)) 'same (list 'differs (caddr texts))))
        (list 'unexpected texts))))

(test-equal "R16 the printed refusal states the bound, 1 to 100 bytes, and its rule, and holds none of the secret's text, its length in bytes or characters, nor its non-ASCII character"
  '((#t #t) (#t #t))
  (map (lambda (answer)
         (let ((texts (texts-of answer)))
           (if (and (pair? texts) (string? (car texts)))
               (let ((text (car texts)))
                 (list (and (occurs-in? "1 to 100 bytes" text) (occurs-in? "length-out-of-range" text))
                       (not (or (occurs-in? "hunter2" text) (occurs-in? "101" text)
                                (occurs-in? "102" text) (occurs-in? "\x20AC;" text)
                                (occurs-in? "104 117 110" text)))))
               (list 'unexpected texts))))
       (list hash-answer verify-answer)))

;; --- password-hash returns no string C left empty ------------------------------------------------------

(verb-row "pwhash-str-empty" (table-calls (failing-table 0))
  "crypto_pwhash_str answering 0 with a 0 at index 0 of its block, an empty string, is a &sodium-failed with code 0, the blocks wiped, as for no string"
  (table-lines (failing-table 0)))

;; --- password-needs-rehash? of a hash changed during the call ---------------------------------------------
;; The probe runs it under an engine at each fuel from 1, setting a character
;; of the hash string to U+007F at each expiry. A run whose growth is the
;; hash block's wipe alone took the changed path; one with a
;; crypto_pwhash_str_needs_rehash line reached C; one with no growth failed
;; the pre-check.

(define sweep-answer
  (if (eqv? (compiled-status "control") 0)
      (verb-probe-with (cons (override (so-of "control")) (switch-args #f))
                       (list "--rehash-change-sweep"))
      (list 'not-compiled (compiled-status "control"))))

;; sweep-runs : -> (U (Listof (List Any String)) Symbol)
;; The sweep's (OUTCOME GROWTH) lines, or a symbol saying it was not as expected.
(define (sweep-runs)
  (if (and (pair? sweep-answer) (eqv? (car sweep-answer) 0) (list? (cadr sweep-answer))
           (equal? (caddr sweep-answer) "") (>= (length (cadr sweep-answer)) 3))
      (let* ((lines (cadr sweep-answer)) (n (length lines)))
        (if (equal? (list-tail lines (- n 2)) (list no-native-objects valgrind-line))
            (let ((runs (list-head lines (- n 2))))
              (if (for-all (lambda (r) (and (list? r) (= (length r) 2) (string? (cadr r)))) runs)
                  runs
                  'bad-lines))
            'no-footer))
      'probe-failed))

(define sweep-lines (sweep-runs))

(test-equal "password-needs-rehash? of a hash changed at each expiry of an engine, at every fuel from 1: each run answers #t or #f and none raises"
  'all-answered
  (if (and (list? sweep-lines) (>= (length sweep-lines) 3))
      (let ((bad (filter (lambda (r) (not (member (car r) '((answered #t) (answered #f))))) sweep-lines)))
        (if (null? bad) 'all-answered (list 'other bad)))
      (list 'unexpected sweep-lines sweep-answer)))

(test-equal "password-needs-rehash? of a hash changed during the call: every run that only wiped the hash string's block, calling no crypto_pwhash_str_needs_rehash, answers #t, and at least one such run exists"
  'changed-runs-all-true
  (if (list? sweep-lines)
      (let ((changed (filter (lambda (r)
                               (and (occurs-in? "sodium_memzero(p,94)" (cadr r))
                                    (not (occurs-in? "crypto_pwhash_str_needs_rehash" (cadr r)))))
                             sweep-lines)))
        (cond ((null? changed) 'no-changed-run)
              ((for-all (lambda (r) (equal? (car r) '(answered #t))) changed) 'changed-runs-all-true)
              (else (list 'changed-run-not-true changed))))
      (list 'unexpected sweep-lines)))

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

(test-end "library-loading-passwords")

(exit (suite-exit-status runner))
