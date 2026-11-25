#!r6rs
;;; The suite for (chez-sodium private password-verbs): password-hash,
;;; password-verify, password-needs-rehash? and make-password-limits, against
;;; the library this suite loads, in a process of its own. make test-memory
;;; runs it under Valgrind.
;;;
;;; password-verbs' body is native's load, which a guard in a program cannot
;;; catch from an import, so this suite reaches each verb through eval, under a
;;; guard: with a library that cannot load, every row is still named and the rows
;;; that need the library fail, where an import would kill the suite before its
;;; first line. A top-level
;;; definition that uses a verb holds a fallback value when the verb cannot
;;; run, so none raises, and the rows built on it fail by name.
;;;
;;;   R3   a non-ASCII password hashes and verifies, and its last character
;;;        changed does not
;;;   R5   (make-password-limits 2 16) gives m=16,t=2,p=1
;;;   R6   hand-written preset strings: each current at its own preset and
;;;        stale at the other two
;;;   R7   one hash at the default limits reads m=65536,t=2
;;;   R8   password-needs-rehash?: each rule that makes a hash stale, on strings
;;;        libsodium itself answers 0 for, so only the binding's rule can
;;;        answer #t
;;;   R9   a hash that fails the pre-check is #f from password-verify and #t
;;;        from password-needs-rehash?, for strings libsodium would accept
;;;   R11  the empty password
;;;   R12  a password holding a NUL is hashed whole
;;;   R15  every refusal, its who and irritants whole, and the order the checks
;;;        run in
;;;   R16  a secret is shown by its kind alone, and each refusal that states a
;;;        bound prints the same for other contents and lengths
;;;   R18  each verb under an engine at every fuel from 1 until it completes;
;;;        and each verb that holds a string, with another thread's write
;;;        simulated at each expiry: password-hash and password-verify give
;;;        changed-during-call, and password-needs-rehash? answers #t
;;;   S    the library read as data: one call-in-section per verb, every check
;;;        before it, every symbol inside it listed whole, the import clause
;;;        whole, and the set of every symbol the library references, so no
;;;        Scheme copy of a secret can be written
;;;
;;; The decoy's halves, which show what reaches C, are
;;; tests/test-library-loading-passwords.sps.
;;;
;;; Every computation that can raise runs under a guard with a sentinel of its
;;; own: SRFI-64 makes #f of a raise in an actual expression, and catches none
;;; in an expected expression or a top-level definition. A row whose verb
;;; answers #f asserts (answered #f), so a raise cannot pass for it. Nothing
;;; depends on an order of evaluation: effects run through for-each, let* and
;;; named lets. Every engine row follows a reference to each library at the
;;; top of the suite: a library first reached inside an engine that is then
;;; abandoned stays wedged.
(import (rnrs)
        (rnrs eval)
        (rnrs mutable-strings)
        (rnrs records inspection)
        (srfi :64)
        (only (chezscheme) library-exports make-engine)
        (chez-sodium-testing)
        (chez-sodium private counters)
        (only (chez-sodium private conditions)
              sodium-failed? sodium-failed-function sodium-failed-code))

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

(test-begin "password-verbs")

;; --- the libraries, reached through eval ---------------------------------------------------

;; library-value : (List Symbol ...) Symbol -> Any
;; NAME in the library LIB; when it cannot be reached, a procedure that raises
;; that, with NAME, every time it is called, so each test that calls it fails
;; by name.
(define (library-value lib name)
  (guard (e (#t (lambda args
                  (error name "library could not be reached" lib (describe e)))))
    (eval name (environment lib))))

(define verbs-lib '(chez-sodium private password-verbs))
(define native-lib '(chez-sodium private native))
(define cap-lib '(chez-sodium private cap))

(define password-hash (library-value verbs-lib 'password-hash))
(define password-verify (library-value verbs-lib 'password-verify))
(define password-needs-rehash? (library-value verbs-lib 'password-needs-rehash?))
(define make-password-limits (library-value verbs-lib 'make-password-limits))
(define input-cap (library-value cap-lib 'input-cap))

;; native-number : Symbol -> Natural
;; One of native's recorded constants; 0 when native cannot be reached, so a
;; top-level definition cannot raise, and every row that needs the library
;; fails by name through the verb it calls.
(define (native-number name)
  (let ((v (library-value native-lib name)))
    (if (number? v) v 0)))

(define ops-min (native-number 'pwhash-opslimit-min))
(define ops-max (native-number 'pwhash-opslimit-max))
(define memory-min (native-number 'pwhash-memlimit-min))
(define memory-max (native-number 'pwhash-memlimit-max))
(define passwd-min (native-number 'pwhash-passwd-min))
(define passwd-max (native-number 'pwhash-passwd-max))

;; The whole KiB inside libsodium's memory range: the least rounded up, the
;; greatest rounded down.
(define kib-min (div (+ memory-min 1023) 1024))
(define kib-max (div memory-max 1024))

;; --- helpers ---------------------------------------------------------------------------------

(define zero-counts '((block . 0)))

;; outcome : (-> Any) -> Any
;; What THUNK did: (answered VALUE); (refused WHO IRRITANTS) for an assertion
;; violation; (failed WHO FUNCTION CODE) for a &sodium-failed; or (raised TEXT)
;; for any other raise. Never a message.
(define (outcome thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'refused (condition-who e) (condition-irritants e)))
            ((sodium-failed? e)
             (list 'failed (and (who-condition? e) (condition-who e))
                   (sodium-failed-function e) (sodium-failed-code e)))
            (#t (list 'raised (describe e))))
    (list 'answered (thunk))))

;; answered : Any -> Expected
(define (answered value) (list 'answered value))

;; refused : Symbol Any ... -> Expected
;; The assertion violation of WHO whose irritants are IRRITANTS.
(define (refused who . irritants)
  (list 'refused who irritants))

;; check : String Expected (-> Any) -> Void
;; One test: what THUNK did, as outcome shows it, against EXPECTED.
(define (check name expected thunk)
  (test-equal name expected (outcome thunk)))

;; kind : Symbol -> (List 'kind Symbol)
(define (kind k) (list 'kind k))

;; append-map : (A -> (Listof B)) (Listof A) -> (Listof B)
(define (append-map f lst) (apply append (map f lst)))

;; split-on : Char String -> (Listof String)
(define (split-on ch s)
  (let loop ((i 0) (start 0) (found '()))
    (cond ((= i (string-length s))
           (reverse (cons (substring s start i) found)))
          ((char=? (string-ref s i) ch)
           (loop (+ i 1) (+ i 1) (cons (substring s start i) found)))
          (else (loop (+ i 1) start found)))))

;; hash-shape : String -> (List String String String Natural Natural)
;; A hash string's prefix, version, parameter field, and the lengths of its
;; salt and tag: argon2id's own text, which libsodium writes.
(define (hash-shape hash)
  (let ((fields (split-on #\$ hash)))
    (if (= (length fields) 6)
        (list (cadr fields) (caddr fields) (cadddr fields)
              (string-length (list-ref fields 4)) (string-length (list-ref fields 5)))
        (list 'not-a-hash-string))))

;; params-of : String -> String
(define (params-of hash)
  (let ((shape (hash-shape hash)))
    (if (= (length shape) 5) (caddr shape) 'no-params)))

;; replace-first : String String String -> String
;; S with the first OLD in it made NEW.
(define (replace-first s old new)
  (let ((n (string-length s)) (m (string-length old)))
    (let loop ((i 0))
      (cond ((> (+ i m) n) s)
            ((string=? (substring s i (+ i m)) old)
             (string-append (substring s 0 i) new (substring s (+ i m) n)))
            (else (loop (+ i 1)))))))

;; with-char-at : String Natural Char -> String
;; A fresh copy of S whose character at I is CH.
(define (with-char-at s i ch)
  (let ((copy (string-copy s)))
    (string-set! copy i ch)
    copy))

;; limits-of : Natural Natural -> (U Password-limits Symbol)
;; make-password-limits, guarded: the symbol limits-failed instead of a raise,
;; so a top-level definition cannot raise.
(define (limits-of ops kib)
  (guard (e (#t 'limits-failed))
    (make-password-limits ops kib)))

;; The minimum limits: the one every row hashes at but those that name other limits.
(define min-limits (limits-of ops-min kib-min))

;; hash-at : String Any -> (U String (List Symbol String))
;; password-hash, guarded: a fixture that could not be made is a list, which
;; no row's expected value equals.
(define (hash-at password limits)
  (guard (e (#t (list 'unhashed (describe e))))
    (password-hash password limits)))

(define password "pässwörd€")
(define password-changed "pässwörd¢")

(define hash-min (hash-at password min-limits))

;; --- limits: the constructor ---------------------------------------------------------------

(check "make-password-limits answers a value at libsodium's least ops and memory, at its greatest of each, and at each mixed pair"
  (answered '(made made made made))
  (lambda ()
    (list (begin (make-password-limits ops-min kib-min) 'made)
          (begin (make-password-limits ops-max kib-max) 'made)
          (begin (make-password-limits ops-min kib-max) 'made)
          (begin (make-password-limits ops-max kib-min) 'made))))

(test-equal "the minimum limits and the first hash were made"
  '(#t #t)
  (list (not (symbol? min-limits)) (string? hash-min)))

;; --- R3, R11, R12: what a password is -------------------------------------------------------------

(check "R3 password-hash of a non-ASCII password at the minimum limits is a hash string of argon2id v=19 at m=8,t=1,p=1, with a salt of 22 characters and a tag of 43"
  (answered '("argon2id" "v=19" "m=8,t=1,p=1" 22 43))
  (lambda () (hash-shape hash-min)))

(check "R3 password-verify of that hash against the same non-ASCII password answers #t"
  (answered #t)
  (lambda () (password-verify hash-min password)))

(check "R3 password-verify of that hash against the password with its last character changed answers #f, and raises nothing"
  (answered #f)
  (lambda () (password-verify hash-min password-changed)))

(check "R3 password-verify of that hash against the password's ASCII part alone answers #f: the bytes, not the characters, are hashed"
  (answered #f)
  (lambda () (password-verify hash-min "pässwörd")))

(check "R3 the same password hashed twice gives two different hash strings, each verifying"
  (answered '(#f #t #t))
  (lambda ()
    (let ((a (password-hash password min-limits)) (b (password-hash password min-limits)))
      (list (string=? a b) (password-verify a password) (password-verify b password)))))

(check "R11 the empty password hashes, and verifies #t against its own hash"
  (answered '(#t #t))
  (lambda ()
    (let ((h (password-hash "" min-limits)))
      (list (string? h) (password-verify h "")))))

(check "R11 the empty password's hash does not verify \"a\""
  (answered #f)
  (lambda () (password-verify (password-hash "" min-limits) "a")))

(check "R11 a hash of \"a\" does not verify the empty password"
  (answered #f)
  (lambda () (password-verify (password-hash "a" min-limits) "")))

(define nul-password (string #\a #\nul #\b))

(check "R12 a password holding a NUL is hashed whole: it verifies against itself, and not against the text before the NUL, nor the same text with another last character"
  (answered '(#t #f #f #f))
  (lambda ()
    (let ((h (password-hash nul-password min-limits)))
      (list (password-verify h nul-password)
            (password-verify h "a")
            (password-verify h (string #\a #\nul #\c))
            (password-verify h (string #\a #\nul))))))

;; --- R5, R6, R7: the limits ------------------------------------------------------------------------

(check "R5 (make-password-limits 2 16) gives a hash whose prefix, version and parameter field are argon2id, v=19 and m=16,t=2,p=1"
  (answered '("argon2id" "v=19" "m=16,t=2,p=1" 22 43))
  (lambda () (hash-shape (password-hash "pw" (make-password-limits 2 16)))))

(check "R5 (make-password-limits 1 8) gives m=8,t=1,p=1"
  (answered "m=8,t=1,p=1")
  (lambda () (params-of (password-hash "pw" (make-password-limits 1 8)))))

(check "R7 password-hash with no limits reads m=65536,t=2, the interactive preset"
  (answered "m=65536,t=2,p=1")
  (lambda () (params-of (password-hash "pw"))))

;; Hand-written strings of each preset, a 22-character salt and a 43-character
;; tag, which libsodium answers 0 for at their own limits and 1 at the others.
(define salt-and-tag "$QUJDREVGR0hJSktMTU5PUA$YWRnam1wc3Z5fH+ChYiLjpGUl5qdoKOmqayvsrW4u74")
(define interactive-string
  (string-append "$argon2id$v=19$m=65536,t=2,p=1" salt-and-tag))
(define moderate-string
  (string-append "$argon2id$v=19$m=262144,t=3,p=1" salt-and-tag))
(define sensitive-string
  (string-append "$argon2id$v=19$m=1048576,t=4,p=1" salt-and-tag))

(for-each
 (lambda (row)
   (let ((name (car row)) (string (cadr row)) (expected (caddr row)))
     (for-each
      (lambda (preset want)
        (check (string-append "R6 the " name " preset's hand-written string at '"
                              (symbol->string preset)
                              (if want
                                  " is stale: #t, and nothing is raised"
                                  " is current: #f, and nothing is raised"))
          (answered want)
          (lambda () (password-needs-rehash? string preset))))
      '(interactive moderate sensitive)
      expected)))
 (list (list "interactive" interactive-string '(#f #t #t))
       (list "moderate" moderate-string '(#t #f #t))
       (list "sensitive" sensitive-string '(#t #t #f))))

(check "R6 a hash string at the interactive preset's own numbers is current at the default"
  (answered #f)
  (lambda () (password-needs-rehash? interactive-string)))

;; --- R8: needs-rehash ----------------------------------------------------------------------------

(define limits-2-16 (limits-of 2 16))
(define hash-2-16 (hash-at "pw" limits-2-16))

;; The hash made at the minimum limits. When it cannot be made, a string of 93
;; characters that is no hash, so no top-level use of it raises, and every row
;; that needs the hash fails by name.
(define hash-pw-min
  (let ((h (hash-at "pw" min-limits)))
    (if (string? h) h (make-string 93 #\?))))

;; hand-written : Natural Natural -> String
;; A hash string, no hash of anything, with OPS passes and MEMORY-KIB KiB, p=1:
;; libsodium reads only its parameters and prefix.
(define (hand-written ops memory-kib)
  (string-append "$argon2id$v=19$m=" (number->string memory-kib)
                 ",t=" (number->string ops) ",p=1" salt-and-tag))

(check "R8 a hash is current at the limits it was made with: #f at the minimum, and at 2 passes and 16 KiB"
  (answered '(#f #f))
  (lambda ()
    (list (password-needs-rehash? hash-pw-min min-limits)
          (password-needs-rehash? hash-2-16 limits-2-16))))

(check "R8 a hash made at the minimum is stale at 2 passes and 16 KiB, and at the default"
  (answered '(#t #t))
  (lambda ()
    (list (password-needs-rehash? hash-pw-min limits-2-16)
          (password-needs-rehash? hash-pw-min))))

(check "R8 a hash made at 2 passes and 16 KiB is stale at the minimum"
  (answered #t)
  (lambda () (password-needs-rehash? hash-2-16 min-limits)))

;; Each axis alone, on hand-written strings, which differ from the limits in
;; one number.
(check "R8 a string of 1 more pass than the limits, at the minimum, is #t: the passes alone differ"
  (answered #t)
  (lambda () (password-needs-rehash? (hand-written (+ ops-min 1) kib-min) min-limits)))

(check "R8 a string of 8 KiB more memory than the limits, at the minimum, is #t: the memory alone differs"
  (answered #t)
  (lambda () (password-needs-rehash? (hand-written ops-min (+ kib-min 8)) min-limits)))

(check "R8 a string of 1 fewer pass than 2 passes and 16 KiB is #t: the passes alone differ"
  (answered #t)
  (lambda () (password-needs-rehash? (hand-written 1 16) limits-2-16)))

(check "R8 a string of 8 KiB less memory than 2 passes and 16 KiB is #t: the memory alone differs"
  (answered #t)
  (lambda () (password-needs-rehash? (hand-written 2 8) limits-2-16)))

(check "R8 the control for those four: a string of 2 passes and 16 KiB at 2 passes and 16 KiB is #f"
  (answered #f)
  (lambda () (password-needs-rehash? (hand-written 2 16) limits-2-16)))

;; a string of another prefix, at the same limits, which libsodium answers 0 for
(check "R8 a string of prefix $argon2i$, which libsodium reads as current, is #t: the prefix is the loaded library's"
  (answered #t)
  (lambda ()
    (password-needs-rehash? (replace-first hash-pw-min "$argon2id$" "$argon2i$") min-limits)))

(check "R8 a string of prefix $argon2d$ is #t"
  (answered #t)
  (lambda ()
    (password-needs-rehash? (replace-first hash-pw-min "$argon2id$" "$argon2d$") min-limits)))

;; A hand-written string of p=4 at the interactive preset: libsodium answers 0
;; for it at its own limits, and for the same string with p=1.
(define p4-string (replace-first interactive-string ",p=1$" ",p=4$"))
(define p1-string interactive-string)

(check "R8 the control for the p=4 string: the same string with p=1 at the interactive preset is current, #f"
  (answered #f)
  (lambda () (password-needs-rehash? p1-string 'interactive)))

(check "R8 a p=4 string at the interactive preset, its own numbers, which libsodium answers 0 for, is #t"
  (answered #t)
  (lambda () (password-needs-rehash? p4-string 'interactive)))

;; The raw call, to show libsodium itself answers 0 for the strings above:
;; only the binding's rules make them #t.
(define needs-rehash-call (library-value native-lib 'crypto-pwhash-str-needs-rehash))
(define call-with-c-string (library-value native-lib 'call-with-c-string))
(define call-in-section (library-value native-lib 'call-in-section))

;; libsodium-says : String Natural Natural -> Integer
;; crypto_pwhash_str_needs_rehash's own answer for STRING at OPS and MEMORY
;; bytes, through native's raw binding.
(define (libsodium-says string ops memory)
  (call-in-section
   (lambda ()
     (call-with-c-string 'password-needs-rehash? string
       (lambda (block) (needs-rehash-call block ops memory))
       (lambda () 'changed)))))

(check "R8 libsodium's own answers: 0 for the p=4 string and for its p=1 control, 0 for an argon2i-prefixed copy of a current hash"
  (answered '(0 0 0))
  (lambda ()
    (list (libsodium-says p4-string 2 (* 65536 1024))
          (libsodium-says p1-string 2 (* 65536 1024))
          (libsodium-says (replace-first hash-pw-min "$argon2id$" "$argon2i$")
                          ops-min (* kib-min 1024)))))

;; The 136-character hash, made by libsodium for the password "pw" at the
;; minimum limits with a 64-byte tag: it verifies, and is longer than strbytes.
(define long-hash
  "$argon2id$v=19$m=8,t=1,p=1$EyYDv0QsQbeigj9AAWd4og$2h21FCkx8IoVDEl4/mLnPx/13x3VOsaGEEcSznsHWANOIbT5yNoNpmiSmo3WFrwrB8CHtsaXS9cT0QGGUfFzow")

(check "R8 the 136-character hash is #t: libsodium answers -1 for any string of strbytes characters or more"
  (answered '(136 #t))
  (lambda () (list (string-length long-hash) (password-needs-rehash? long-hash min-limits))))

(for-each
 (lambda (row)
   (check (string-append "R8 " (car row) " is #t, and nothing is raised")
     (answered #t)
     (lambda () (password-needs-rehash? (cadr row) min-limits))))
 (list (list "a malformed string, \"garbage\"" "garbage")
       (list "a string of the prefix alone" "$argon2id$")
       (list "a hash with its version removed" (replace-first hash-pw-min "$v=19" ""))
       (list "a hash with p=0" (replace-first hash-pw-min ",p=1$" ",p=0$"))
       (list "a hash with p=2" (replace-first hash-pw-min ",p=1$" ",p=2$"))
       (list "a hash with p=10, which begins like p=1" (replace-first hash-pw-min ",p=1$" ",p=10$"))
       (list "the empty string, which fails the pre-check" "")
       (list "a hash with a space, which fails the pre-check" (string-append hash-pw-min " "))
       (list "a hash then a NUL then junk, which libsodium reads as current, and the pre-check refuses"
             (string-append hash-pw-min (string #\nul) "junk"))
       (list "a hash with a non-ASCII salt character, which fails the pre-check"
             (with-char-at hash-pw-min 27 #\x00E9))
       (list "a hash over the cap, which fails the pre-check"
             (string-append hash-pw-min (make-string 65536 #\a)))))

(check "R8 a hash that is current and ends at its tag is #f at the same limits: the control for the rows above"
  (answered #f)
  (lambda () (password-needs-rehash? hash-pw-min min-limits)))

;; --- R9: the pre-check, against libsodium's own answers --------------------------------------------

(check "R9 a hash then a NUL then junk, which libsodium verifies, is #f from password-verify: the pre-check answers, with nothing raised"
  (answered #f)
  (lambda () (password-verify (string-append hash-pw-min (string #\nul) "junk") "pw")))

(check "R9 the control: the hash alone verifies the same password, #t"
  (answered #t)
  (lambda () (password-verify hash-pw-min "pw")))

(for-each
 (lambda (row)
   (check (string-append "R9 password-verify of " (car row) " answers #f, and raises nothing")
     (answered #f)
     (lambda () (password-verify (cadr row) "pw"))))
 (list (list "the empty hash" "")
       (list "a hash with a trailing space" (string-append hash-pw-min " "))
       (list "a hash with a trailing newline" (string-append hash-pw-min "\n"))
       (list "a hash with a leading space" (string-append " " hash-pw-min))
       (list "a hash with a character of U+007F" (string-append hash-pw-min (string #\x7F)))
       (list "a hash with a non-ASCII character" (string-append hash-pw-min "\x00E9;"))
       (list "a hash with a non-ASCII salt character" (with-char-at hash-pw-min 27 #\x00E9))
       (list "a hash over the cap" (string-append hash-pw-min (make-string 65536 #\a)))
       (list "the text \"garbage\"" "garbage")))

(check "R9 password-verify of a wrong password against a good hash answers #f, and raises nothing"
  (answered #f)
  (lambda () (password-verify hash-pw-min "px")))

(check "R9 password-verify of the 136-character hash answers #t for its password and #f for another: libsodium's verify reads strings longer than strbytes"
  (answered '(#t #f))
  (lambda () (list (password-verify long-hash "pw") (password-verify long-hash "pX"))))

;; --- the cap: boundaries counted in UTF-8 bytes ----------------------------------------------------

;; repeated : Char Natural -> String
(define (repeated ch n) (make-string n ch))

;; euros-and-x : Natural -> String
;; A string of N UTF-8 bytes holding as many euro signs, three bytes each, as
;; fit, then plain characters: 65537 bytes is 21845 euros and two of them.
(define (euros-and-x n)
  (string-append (make-string (div n 3) #\x20AC) (make-string (mod n 3) #\x)))

(for-each
 (lambda (row)
   (check (string-append "R15 a password of " (car row)
                         " is accepted: it hashes, and verifies against itself")
     (answered '(#t #t))
     (lambda ()
       (let ((h (password-hash (cadr row) min-limits)))
         (list (string? h) (password-verify h (cadr row)))))))
 (list (list "65536 ASCII characters, 65536 bytes" (repeated #\a 65536))
       (list "21845 euro signs and one more character, 65536 bytes, 21846 characters"
             (euros-and-x 65536))))

(for-each
 (lambda (row)
   (for-each
    (lambda (who call)
      (check (string-append "R15 " (symbol->string who) " of " (car row) " is refused, over-the-cap, by kind alone")
        (refused who 'over-the-cap 'password (kind 'string))
        (lambda () (call (cadr row)))))
    '(password-hash password-verify)
    (list (lambda (s) (password-hash s min-limits))
          (lambda (s) (password-verify hash-pw-min s)))))
 (list (list "65537 ASCII characters, 65537 bytes" (repeated #\a 65537))
       (list "21845 euro signs and two more, 65537 bytes, 21847 characters" (euros-and-x 65537))
       (list "32769 two-byte characters, 65538 bytes, fewer characters than the cap"
             (repeated #\x00E9 32769))))

;; --- R15: every refusal ----------------------------------------------------------------------------

;; secrets : (Listof (Pair Any Symbol))
;; What a secret-looking value of each non-string kind is, and its kind.
(define secrets
  (list (cons 'hunter2 'symbol)
        (cons 4242424242 'number)
        (cons '(#\s #\e #\c #\r #\e #\t) 'list)
        (cons (string->utf8 "secret") 'bytevector)
        (cons #f 'boolean)))

;; --- make-password-limits

(for-each
 (lambda (row)
   (check (string-append "R15 make-password-limits ops " (car row)
                         " is refused, not-a-natural, its value shown as it is")
     (refused 'make-password-limits 'not-a-natural 'ops (cadr row))
     (lambda () (make-password-limits (caddr row) kib-min))))
 (list (list "-1" -1 -1)
       (list "1.5" 1.5 1.5)
       (list "2.0, which is no exact natural" 2.0 2.0)
       (list "1/2" 1/2 1/2)
       (list "a symbol" 'many 'many)
       (list "a string, shown by its kind" (kind 'string) "2")
       (list "#f" #f #f)))

(for-each
 (lambda (row)
   (check (string-append "R15 make-password-limits memory-kib " (car row)
                         " is refused, not-a-natural, its value shown as it is")
     (refused 'make-password-limits 'not-a-natural 'memory-kib (cadr row))
     (lambda () (make-password-limits ops-min (caddr row)))))
 (list (list "-1" -1 -1)
       (list "1.5" 1.5 1.5)
       (list "16.0, which is no exact natural" 16.0 16.0)
       (list "a symbol" 'much 'much)
       (list "a string, shown by its kind" (kind 'string) "16")
       (list "#f" #f #f)))

(check "R15 make-password-limits ops one below libsodium's least is refused, ops-out-of-range, its value shown"
  (refused 'make-password-limits 'ops-out-of-range 'ops (- ops-min 1))
  (lambda () (make-password-limits (- ops-min 1) kib-min)))

(check "R15 make-password-limits ops one above libsodium's greatest is refused, ops-out-of-range"
  (refused 'make-password-limits 'ops-out-of-range 'ops (+ ops-max 1))
  (lambda () (make-password-limits (+ ops-max 1) kib-min)))

(check "R15 make-password-limits memory-kib one below the least is refused, memory-out-of-range"
  (refused 'make-password-limits 'memory-out-of-range 'memory-kib (- kib-min 1))
  (lambda () (make-password-limits ops-min (- kib-min 1))))

(check "R15 make-password-limits memory-kib one above the greatest is refused, memory-out-of-range"
  (refused 'make-password-limits 'memory-out-of-range 'memory-kib (+ kib-max 1))
  (lambda () (make-password-limits ops-min (+ kib-max 1))))

(check "R15 make-password-limits memory-kib 0 is refused, memory-out-of-range"
  (refused 'make-password-limits 'memory-out-of-range 'memory-kib 0)
  (lambda () (make-password-limits ops-min 0)))

(check "R15 make-password-limits order: ops 0 and a bad memory-kib are refused at ops' range"
  (refused 'make-password-limits 'ops-out-of-range 'ops 0)
  (lambda () (make-password-limits 0 0)))

(check "R15 make-password-limits order: a bad ops type and a bad memory-kib are refused at ops' type"
  (refused 'make-password-limits 'not-a-natural 'ops 'x)
  (lambda () (make-password-limits 'x 'y)))

(check "R15 make-password-limits order: ops out of range and a memory-kib of no type are refused at ops' range, before memory's type"
  (refused 'make-password-limits 'ops-out-of-range 'ops 0)
  (lambda () (make-password-limits 0 'y)))

(check "R15 make-password-limits order: a good ops and a bad memory-kib type are refused at memory-kib's type"
  (refused 'make-password-limits 'not-a-natural 'memory-kib 'y)
  (lambda () (make-password-limits ops-min 'y)))

;; --- password-hash

(for-each
 (lambda (secret)
   (check (string-append "R15 password-hash of a " (symbol->string (cdr secret))
                         " is refused, not-a-string password, by kind alone")
     (refused 'password-hash 'not-a-string 'password (kind (cdr secret)))
     (lambda () (password-hash (car secret) min-limits))))
 secrets)

(for-each
 (lambda (row)
   (check (string-append "R15 password-hash limits " (car row)
                         " is refused, not-password-limits, shown by shown-value")
     (refused 'password-hash 'not-password-limits 'limits (cadr row))
     (lambda () (password-hash "pw" (caddr row)))))
 (list (list "a symbol that is no preset" 'fast 'fast)
       (list "a number" 42 42)
       (list "#f" #f #f)
       (list "a string, even a preset's name, shown by its kind" (kind 'string) "interactive")
       (list "a list of numbers, shown as it is" '(2 16) '(2 16))
       (list "a pair of limits' numbers as a list" '(1 8) (list 1 8))))

(check "R15 password-hash order: a bad password and bad limits are refused at the password"
  (refused 'password-hash 'not-a-string 'password (kind 'symbol))
  (lambda () (password-hash 'hunter2 'fast)))

(check "R15 password-hash order: an over-long password and bad limits are refused at the cap"
  (refused 'password-hash 'over-the-cap 'password (kind 'string))
  (lambda () (password-hash (repeated #\a 65537) 'fast)))

(check "R15 password-hash order: a good password and bad limits are refused at the limits"
  (refused 'password-hash 'not-password-limits 'limits 'fast)
  (lambda () (password-hash "pw" 'fast)))

;; --- password-verify

(for-each
 (lambda (secret)
   (check (string-append "R15 password-verify of a hash that is a " (symbol->string (cdr secret))
                         " is refused, not-a-string hash, by kind alone")
     (refused 'password-verify 'not-a-string 'hash (kind (cdr secret)))
     (lambda () (password-verify (car secret) "pw")))
   (check (string-append "R15 password-verify of a password that is a " (symbol->string (cdr secret))
                         " is refused, not-a-string password, by kind alone")
     (refused 'password-verify 'not-a-string 'password (kind (cdr secret)))
     (lambda () (password-verify hash-pw-min (car secret)))))
 secrets)

(check "R15 password-verify order: a hash and a password that are both no string are refused at the hash"
  (refused 'password-verify 'not-a-string 'hash (kind 'symbol))
  (lambda () (password-verify 'hunter2 'oops)))

(check "R15 password-verify order: a hash that fails the pre-check and a password that is no string are refused at the password, never #f"
  (refused 'password-verify 'not-a-string 'password (kind 'symbol))
  (lambda () (password-verify (string #\nul #\b #\a #\d) 'x)))

(check "R15 password-verify order: a hash that fails the pre-check and a password over the cap are refused at the cap"
  (refused 'password-verify 'over-the-cap 'password (kind 'string))
  (lambda () (password-verify "" (repeated #\a 65537))))

(check "R15 password-verify order: the empty hash and a good password answer #f"
  (answered #f)
  (lambda () (password-verify "" "pw")))

(check "R15 password-verify order: a hash over the cap is no refusal, and answers #f"
  (answered #f)
  (lambda () (password-verify (repeated #\a 65537) "pw")))

;; --- password-needs-rehash?

(for-each
 (lambda (secret)
   (check (string-append "R15 password-needs-rehash? of a hash that is a " (symbol->string (cdr secret))
                         " is refused, not-a-string hash, by kind alone")
     (refused 'password-needs-rehash? 'not-a-string 'hash (kind (cdr secret)))
     (lambda () (password-needs-rehash? (car secret) min-limits))))
 secrets)

(for-each
 (lambda (row)
   (check (string-append "R15 password-needs-rehash? limits " (car row)
                         " is refused, not-password-limits, though the hash fails the pre-check")
     (refused 'password-needs-rehash? 'not-password-limits 'limits (cadr row))
     (lambda () (password-needs-rehash? "garbage" (caddr row)))))
 (list (list "a symbol that is no preset" 'fast 'fast)
       (list "a number" 42 42)
       (list "a string, shown by its kind" (kind 'string) "moderate")))

(check "R15 password-needs-rehash? order: a hash that is no string and bad limits are refused at the hash"
  (refused 'password-needs-rehash? 'not-a-string 'hash (kind 'symbol))
  (lambda () (password-needs-rehash? 'x 'fast)))

(check "R15 password-needs-rehash? order: a bad hash string and good limits answer #t, with nothing raised"
  (answered #t)
  (lambda () (password-needs-rehash? "garbage" 'moderate)))

(check "R15 the presets and a Password-limits are all accepted by password-needs-rehash?"
  (answered '(#t #t #t #t))
  (lambda ()
    (list (password-needs-rehash? "x" 'interactive)
          (password-needs-rehash? "x" 'moderate)
          (password-needs-rehash? "x" 'sensitive)
          (password-needs-rehash? "x" min-limits))))

;; --- R16: no secret in a refusal -------------------------------------------------------------------

;; occurs-in? : String String -> Boolean
(define (occurs-in? needle text)
  (let ((n (string-length text)) (m (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring text i (+ i m)) needle) #t)
            (else (loop (+ i 1)))))))

(define secret-calls
  (list (cons "password-hash password" (lambda (s) (password-hash s min-limits)))
        (cons "password-verify hash" (lambda (s) (password-verify s "pw")))
        (cons "password-verify password" (lambda (s) (password-verify hash-pw-min s)))
        (cons "password-needs-rehash? hash" (lambda (s) (password-needs-rehash? s min-limits)))))

(for-each
 (lambda (call)
   (test-equal (string-append "R16 " (car call)
                              ": a symbol, a number and a list of characters are each refused, and the refusal's whole text names none of them")
     '((refused refused refused) (clean clean clean))
     (let* ((vals (list 'hunter2 4242424242 '(#\q #\z #\w)))
            (needles (list '("hunter2") '("4242424242") '("#\\q" "(q z w)")))
            (conditions (map (lambda (value)
                               (guard (e (#t e)) ((cdr call) value) 'no-raise))
                             vals)))
       (list (map (lambda (c) (if (assertion-violation? c) 'refused (list 'not-refused c)))
                  conditions)
             (map (lambda (c needle)
                    (if (and (condition? c)
                             (not (exists (lambda (n) (occurs-in? n (describe c))) needle)))
                        'clean
                        'leaks))
                  conditions needles)))))
 secret-calls)

;; hunter-string : Natural -> String
;; N characters, "hunter2" repeated: a string that passes the type check, whose
;; text and length a refusal must not print.
(define (hunter-string n)
  (let ((out (make-string n #\a)) (seed "hunter2"))
    (do ((i 0 (+ i 1))) ((= i n) out)
      (string-set! out i (string-ref seed (mod i 7))))))

;; printed-refusal : (-> Any) -> (U String (List 'not-refused Any))
;; THUNK's refusal as printed, message and irritants; else not-refused and
;; what it answered or raised.
(define (printed-refusal thunk)
  (let ((c (guard (e (#t e)) (thunk) 'no-raise)))
    (if (assertion-violation? c) (describe c) (list 'not-refused c))))

;; three strings of 65537 and 65538 bytes: ASCII of one length, a non-ASCII one
;; of the same UTF-8 length with other characters, and an ASCII one of another
;; length, so that a character count differs from a byte count.
(define over-calls
  (list (cons "password-hash" (lambda (s) (password-hash s min-limits)))
        (cons "password-verify" (lambda (s) (password-verify hash-pw-min s)))))

(for-each
 (lambda (call)
   (test-equal (string-append "R16 " (car call)
                              " of a password over the cap: refused, the printed refusal holds the condition's whole message, and names neither the secret's text nor its length in bytes nor in characters")
     '(refused states-message clean clean clean)
     (let* ((s (hunter-string 65537))
            (c (guard (e (#t e)) ((cdr call) s) 'no-raise)))
       (if (assertion-violation? c)
           (let ((text (describe c)))
             (list 'refused
                   (if (occurs-in? (condition-message c) text) 'states-message 'message-missing)
                   (if (occurs-in? "hunter2" text) 'leaks 'clean)
                   (if (occurs-in? "65537" text) 'leaks 'clean)
                   (if (occurs-in? "104 117 110 116 101 114 50" text) 'leaks 'clean)))
           (list 'not-refused c)))))
 over-calls)

(for-each
 (lambda (call)
   (test-equal (string-append "R16 " (car call)
                              " of a password over the cap: the printed refusal is the same for another string of the same UTF-8 length with non-ASCII characters, and for another length under the same rule")
     '(refused same same)
     (let* ((p (printed-refusal (lambda () ((cdr call) (hunter-string 65537)))))
            (q (printed-refusal (lambda () ((cdr call) (euros-and-x 65537)))))
            (r (printed-refusal (lambda () ((cdr call) (hunter-string 65538))))))
       (list (if (string? p) 'refused p)
             (if (equal? p q) 'same (list 'differs q))
             (if (equal? p r) 'same (list 'differs r))))))
 over-calls)

;; --- the exports ------------------------------------------------------------------------------------

(test-equal "input-cap is 65536"
  65536
  input-cap)

(define (sorted-exports lib)
  (guard (e (#t (list 'unreadable (describe e))))
    (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
               (library-exports lib))))

(test-equal "(chez-sodium private password-verbs) exports exactly the three verbs and make-password-limits"
  '(make-password-limits password-hash password-needs-rehash? password-verify)
  (sorted-exports verbs-lib))

(test-equal "a Password-limits is made, and is no pair, no vector and no list of its numbers"
  '(#t #f #f #f)
  (let ((limits (limits-of 2 16)))
    (list (not (symbol? limits)) (pair? limits) (vector? limits) (equal? limits '(2 16)))))

(check "a Password-limits is opaque: record? answers #f"
  (answered #f)
  (lambda () (record? (make-password-limits 2 16))))

(test-equal "a Password-limits is opaque: record-rtd of it is refused, as for anything that is no record"
  'refused
  (let ((limits (limits-of 2 16)))
    (if (symbol? limits)
        'limits-failed
        (guard (e ((assertion-violation? e) 'refused)
                  (#t (list 'raised (describe e))))
          (record-rtd limits)
          'answered))))

;; --- R18: under an engine --------------------------------------------------------------------------
;; An engine spends no ticks inside a critical section, so no expiry falls in
;; one, and an expiry before it is resumed harmlessly. Each row runs a job at
;; every fuel from 1 until the first fuel at which it completes without
;; expiring, and asserts the outcome at each, never the count of expiries.
;; Every library was reached at the top of this suite, before the first engine.

;; run-in-engine : Natural (-> Any) (-> Void) -> (List Any Natural)
;; THUNK run in an engine of FUEL ticks per run, resumed at each expiry until
;; it completes: (done VALUE) or (raised OBJECT), then how many times it
;; expired. MUTATE! runs at each expiry, before the resume.
(define (run-in-engine fuel thunk mutate!)
  (let ((expiries 0))
    (let ((result
           (guard (e (#t (list 'raised e)))
             (let loop ((eng (make-engine thunk)))
               (eng fuel
                    (lambda (ticks answer) (list 'done answer))
                    (lambda (next)
                      (set! expiries (+ expiries 1))
                      (mutate!)
                      (loop next)))))))
      (list result expiries))))

;; classify : Any -> Any
;; A run's result as outcome shows it: (answered V), (refused WHO IRRITANTS),
;; (failed ...) or (raised TEXT).
(define (classify result)
  (if (eq? (car result) 'done)
      (list 'answered (cadr result))
      (let ((e (cadr result)))
        (cond ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
               (list 'refused (condition-who e) (condition-irritants e)))
              ((sodium-failed? e)
               (list 'failed (and (who-condition? e) (condition-who e))
                     (sodium-failed-function e) (sodium-failed-code e)))
              (else (list 'raised (if (condition? e) (describe e) e)))))))

;; sweep : (-> (Pair (-> Any) (-> Void))) (Any -> Boolean) -> Any
;; A job made fresh at each fuel from 1: every outcome must satisfy RIGHT? and
;; leave every count zero. (every-fuel-right SEEN) when a fuel completes with no
;; expiry, SEEN the distinct outcome kinds met, (kinds) a sorted list of each
;; outcome's head; otherwise (wrong-at-fuel N OUTCOME COUNTS), or
;; never-completed past 5,000.
(define (sweep make-job right?)
  (let loop ((fuel 1) (seen '()))
    (if (> fuel 5000)
        'never-completed
        (let* ((job (make-job))
               (run (run-in-engine fuel (car job) (cdr job)))
               (shown (classify (car run)))
               (counts (native-counts))
               (seen (if (member (kind-of-outcome shown) seen)
                         seen
                         (cons (kind-of-outcome shown) seen))))
          (cond ((not (and (right? shown) (equal? counts zero-counts)))
                 (list 'wrong-at-fuel fuel shown counts))
                ((= (cadr run) 0) (list 'every-fuel-right (list-sort symbol<? seen)))
                (else (loop (+ fuel 1) seen)))))))

(define (symbol<? a b) (string<? (symbol->string a) (symbol->string b)))

;; kind-of-outcome : Any -> Symbol
;; What an outcome is, for the kinds a sweep met: answered-true, answered-false,
;; answered-string, refused-changed (a changed-during-call) or other.
(define (kind-of-outcome o)
  (cond ((equal? o '(answered #t)) 'answered-true)
        ((equal? o '(answered #f)) 'answered-false)
        ((and (eq? (car o) 'answered) (string? (cadr o))) 'answered-string)
        ((and (eq? (car o) 'refused) (pair? (caddr o)) (eq? (car (caddr o)) 'changed-during-call))
         'refused-changed)
        (else 'other)))

;; plain : (-> Any) -> (-> (Pair (-> Any) (-> Void)))
;; A job that changes nothing.
(define (plain thunk)
  (lambda () (cons thunk (lambda () #t))))

;; a-hash? : Any -> Boolean
;; Whether X is a hash string of argon2id at the minimum limits.
(define (a-hash? x)
  (and (string? x) (equal? (hash-shape x) '("argon2id" "v=19" "m=8,t=1,p=1" 22 43))))

(test-equal "R18 password-hash under an engine at every fuel from 1 until it completes: each run answers a hash string at the minimum limits, raises nothing, and leaves every count zero"
  '(every-fuel-right (answered-string))
  (sweep (plain (lambda () (password-hash password min-limits)))
         (lambda (shown) (and (eq? (car shown) 'answered) (a-hash? (cadr shown))))))

(test-equal "R18 password-hash of the empty password under an engine at every fuel: each run answers a hash string at the minimum limits"
  '(every-fuel-right (answered-string))
  (sweep (plain (lambda () (password-hash "" min-limits)))
         (lambda (shown) (and (eq? (car shown) 'answered) (a-hash? (cadr shown))))))

(test-equal "R18 password-verify under an engine at every fuel: each run answers #t for the right password"
  '(every-fuel-right (answered-true))
  (sweep (plain (lambda () (password-verify hash-min password)))
         (lambda (shown) (equal? shown '(answered #t)))))

(test-equal "R18 password-verify under an engine at every fuel: each run answers #f for a wrong password, and raises nothing"
  '(every-fuel-right (answered-false))
  (sweep (plain (lambda () (password-verify hash-min password-changed)))
         (lambda (shown) (equal? shown '(answered #f)))))

(test-equal "R18 password-verify of a hash that fails the pre-check under an engine at every fuel: each run answers #f"
  '(every-fuel-right (answered-false))
  (sweep (plain (lambda () (password-verify (string-append hash-min " ") password)))
         (lambda (shown) (equal? shown '(answered #f)))))

(test-equal "R18 password-needs-rehash? of a current hash under an engine at every fuel: each run answers #f"
  '(every-fuel-right (answered-false))
  (sweep (plain (lambda () (password-needs-rehash? hash-min min-limits)))
         (lambda (shown) (equal? shown '(answered #f)))))

(test-equal "R18 password-needs-rehash? of a stale hash under an engine at every fuel: each run answers #t"
  '(every-fuel-right (answered-true))
  (sweep (plain (lambda () (password-needs-rehash? hash-min 'interactive)))
         (lambda (shown) (equal? shown '(answered #t)))))

(test-equal "R18 password-needs-rehash? of a hash that fails the pre-check under an engine at every fuel: each run answers #t"
  '(every-fuel-right (answered-true))
  (sweep (plain (lambda () (password-needs-rehash? "garbage" min-limits)))
         (lambda (shown) (equal? shown '(answered #t)))))

(test-equal "R18 make-password-limits under an engine at every fuel: each run answers a value, raises nothing, and leaves every count zero"
  '(every-fuel-right (answered-string))
  (sweep (plain (lambda () (begin (make-password-limits 2 16) "made")))
         (lambda (shown) (equal? shown '(answered "made")))))

;; --- changed-during-call, made deterministic with an engine ------------------------------------------
;; At each expiry the job's string has one character changed, from ASCII to
;; U+20AC, which is three bytes: a password counted before the change and
;; written after it. A hash's character is changed to one outside U+0021 to
;; U+007E. An expiry cannot fall inside the section, so it falls before it,
;; where the change is counted in or is not yet made, or after it, where it
;; comes too late. So each run answers right for one of those, and some fuel
;; must have fallen between the count and the write.

;; changing-password : -> (Pair (-> Any) (-> Void)) -> ...
;; (make-case CALL) : a fresh password and the change to make to it, and the
;; job that calls CALL on it.
(define (changing-password call)
  (lambda ()
    (let ((pw (string-copy "abcdefgh")))
      (cons (lambda () (call pw))
            (lambda () (string-set! pw 3 #\x20AC))))))

(define (changing-hash call)
  (lambda ()
    (let ((h (string-copy hash-pw-min)))
      (cons (lambda () (call h))
            (lambda () (string-set! h (- (string-length h) 3) #\x7F))))))

(define changed-refusal-hash
  '(refused password-hash (changed-during-call password (kind string))))
(define changed-refusal-verify-password
  '(refused password-verify (changed-during-call password (kind string))))
(define changed-refusal-verify-hash
  '(refused password-verify (changed-during-call hash (kind string))))

(test-equal "R18 password-hash with a password that changes width at each expiry: each run answers a hash string or the refusal (changed-during-call password (kind string)), leaves every count zero, and some fuel gives the refusal"
  '(every-fuel-right (answered-string refused-changed))
  (sweep (changing-password (lambda (pw) (password-hash pw min-limits)))
         (lambda (shown)
           (or (equal? shown changed-refusal-hash)
               (and (eq? (car shown) 'answered) (a-hash? (cadr shown)))))))

(define verify-hash-of-abcdefgh (hash-at "abcdefgh" min-limits))

(test-equal "R18 password-verify with a password that changes width at each expiry: each run answers #t, or #f for the changed password, or the refusal (changed-during-call password (kind string)); some fuel gives the refusal"
  '(every-fuel-right (answered-false answered-true refused-changed))
  (sweep (changing-password (lambda (pw) (password-verify verify-hash-of-abcdefgh pw)))
         (lambda (shown)
           (or (equal? shown changed-refusal-verify-password)
               (equal? shown '(answered #t))
               (equal? shown '(answered #f))))))

(test-equal "R18 password-verify with a hash that gains a character out of U+0021 to U+007E at each expiry: each run answers #t, or #f from the pre-check, or the refusal (changed-during-call hash (kind string)); some fuel gives the refusal"
  '(every-fuel-right (answered-false answered-true refused-changed))
  (sweep (changing-hash (lambda (h) (password-verify h "pw")))
         (lambda (shown)
           (or (equal? shown changed-refusal-verify-hash)
               (equal? shown '(answered #t))
               (equal? shown '(answered #f))))))

(test-equal "R18 password-needs-rehash? with a hash that gains a character out of U+0021 to U+007E at each expiry: each run answers #f for the hash before the change, or #t, and raises nothing; some fuel gives #t"
  '(every-fuel-right (answered-false answered-true))
  (sweep (changing-hash (lambda (h) (password-needs-rehash? h min-limits)))
         (lambda (shown)
           (or (equal? shown '(answered #t)) (equal? shown '(answered #f))))))

;; --- S: the library, read as data ------------------------------------------------------------------
;; A verb that refused a mistake or raised inside its section behaves exactly
;; as one that does it outside: call-in-section raises again, after the
;; section, whatever its thunk raised. Only the text can tell. So
;; password-verbs.sls is read as data, forms and never comments.

(define verbs-source "src/chez-sodium/private/password-verbs.sls")

;; read-library : String -> (U (List Any ...) (List 'unreadable Any))
;; The library form at PATH, as a list.
(define (read-library path)
  (guard (e (#t (list 'unreadable (describe e))))
    (let ((form (call-with-port
                 (open-file-input-port path (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (if (and (list? form) (> (length form) 4) (eq? (car form) 'library))
          form
          (list 'unreadable 'not-a-library-form)))))

(define verbs-form (read-library verbs-source))

(define (library-read? form) (not (eq? (car form) 'unreadable)))

;; library-imports : Any -> (U (Listof Any) (List 'unreadable Any))
;; The import specs of a library form, each as written.
(define (library-imports form)
  (if (and (library-read? form) (list? (cadddr form)) (eq? (car (cadddr form)) 'import))
      (cdr (cadddr form))
      (list 'unreadable 'no-import-clause)))

;; library-body : Any -> (Listof Any)
(define (library-body form)
  (if (library-read? form) (cddddr form) '()))

;; definition-form : Symbol -> Any
;; The top-level (define NAME EXPR) or (define (NAME . ARGS) BODY ...) of NAME
;; in the library, or no-definition.
(define (definition-form name)
  (let loop ((forms (library-body verbs-form)))
    (cond ((null? forms) 'no-definition)
          ((let ((form (car forms)))
             (and (pair? form) (eq? (car form) 'define) (pair? (cdr form))
                  (or (eq? (cadr form) name)
                      (and (pair? (cadr form)) (eq? (car (cadr form)) name)))))
           (car forms))
          (else (loop (cdr forms))))))

;; tokens : Any -> (Listof Any)
;; The symbols of X, in reading order, a dotted tail and a vector included.
(define (tokens x)
  (cond ((symbol? x) (list x))
        ((pair? x) (append (tokens (car x)) (tokens (cdr x))))
        ((vector? x) (tokens (vector->list x)))
        (else '())))

;; headed : Symbol Any -> (Listof Any)
;; Every list headed by HEAD anywhere in X, in reading order, elements only.
(define (headed head x)
  (cond ((not (pair? x)) '())
        (else
         (let loop ((rest x) (found (if (eq? (car x) head) (list x) '())))
           (if (pair? rest)
               (loop (cdr rest) (append found (headed head (car rest))))
               found)))))

(define verb-names '(password-hash password-verify password-needs-rehash?))

(define (count-of symbol list)
  (let loop ((rest list) (n 0))
    (cond ((null? rest) n)
          ((eq? (car rest) symbol) (loop (cdr rest) (+ n 1)))
          (else (loop (cdr rest) n)))))

(test-equal "S1 each verb's definition holds exactly one call-in-section, as a symbol anywhere in it, and make-password-limits holds none"
  '((password-hash 1) (password-verify 1) (password-needs-rehash? 1) (make-password-limits 0))
  (map (lambda (name) (list name (count-of 'call-in-section (tokens (definition-form name)))))
       (append verb-names '(make-password-limits))))

(test-equal "S1 the library's whole body holds three call-in-section symbols, one in each verb: no helper holds a section of its own"
  3
  (count-of 'call-in-section (tokens (library-body verbs-form))))

;; around-section : Symbol Symbol -> (List Natural Natural)
;; How many times TOKEN occurs in NAME's definition before its first
;; call-in-section, in reading order, and how many after.
(define (around-section name token)
  (let loop ((rest (tokens (definition-form name))) (before 0) (after 0) (seen-section #f))
    (cond ((null? rest) (list before after))
          ((eq? (car rest) 'call-in-section) (loop (cdr rest) before after #t))
          ((eq? (car rest) token)
           (if seen-section
               (loop (cdr rest) before (+ after 1) seen-section)
               (loop (cdr rest) (+ before 1) after seen-section)))
          (else (loop (cdr rest) before after seen-section)))))

(test-equal "S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-limits, the pre-check and the shape check, the type tests) and the raises (refuse-secret, raise-sodium-failed), counted before and after its call-in-section"
  '((password-hash (check-password 1 0) (resolve-limits 1 0) (string? 0 0)
                   (refuse-secret 0 1) (raise-sodium-failed 0 1) (assertion-violation 0 0))
    (password-verify (check-password 1 0) (readable-hash-string? 1 0) (string? 1 0)
                     (refuse-secret 1 2) (raise-sodium-failed 0 0) (assertion-violation 0 0))
    (password-needs-rehash? (resolve-limits 1 0) (readable-hash-string? 1 0)
                            (current-hash-shape? 1 0) (string? 1 0)
                            (refuse-secret 1 0) (raise-sodium-failed 0 0)
                            (assertion-violation 0 0)))
  (map (lambda (name)
         (cons name
               (map (lambda (token) (cons token (around-section name token)))
                    (cdr (assq name
                               '((password-hash check-password resolve-limits string?
                                                refuse-secret raise-sodium-failed assertion-violation)
                                 (password-verify check-password readable-hash-string? string?
                                                  refuse-secret raise-sodium-failed assertion-violation)
                                 (password-needs-rehash? resolve-limits readable-hash-string?
                                                         current-hash-shape? string?
                                                         refuse-secret raise-sodium-failed
                                                         assertion-violation)))))))
       verb-names))

(test-equal "S2 the helpers hold the checks and no section: check-password and resolve-limits refuse, make-password-limits refuses, and none holds call-in-section"
  '((check-password (refuse-secret 3) (assertion-violation 0) (call-in-section 0))
    (resolve-limits (refuse-secret 0) (assertion-violation 1) (call-in-section 0))
    (make-password-limits (refuse-secret 0) (assertion-violation 4) (call-in-section 0)))
  (map (lambda (name)
         (cons name
               (map (lambda (token) (list token (count-of token (tokens (definition-form name)))))
                    '(refuse-secret assertion-violation call-in-section))))
       '(check-password resolve-limits make-password-limits)))

;; section-tokens : Symbol -> (Listof Symbol)
;; Every symbol inside call-in-section's argument in NAME's definition, in
;; reading order.
(define (section-tokens name)
  (append-map tokens (map cdr (headed 'call-in-section (definition-form name)))))

(test-equal "S2 no lambda in a verb's definition lies outside its call-in-section argument, but case-lambda's clauses: a check cannot be written there and called inside"
  '((password-hash 0) (password-verify 0) (password-needs-rehash? 0))
  (map (lambda (name)
         (list name (- (count-of 'lambda (tokens (definition-form name)))
                       (count-of 'lambda (section-tokens name)))))
       verb-names))

;; What runs inside a section is whatever it names. Each verb's whole list is
;; written here, so a helper called there, a let-bound lambda or a top-level
;; procedure, raiser or not, adds its name and fails the row.
(test-equal "S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called there, and no raise"
  '((password-hash lambda call-with-utf8 quote password-hash password n
                   lambda in call-with-block quote password-hash pwhash-strbytes leave-unwritten
                   lambda out
                   let code crypto-pwhash-str out in n car pair cdr pair
                   if eqv? code
                   let hash foreign-ascii-string out pwhash-strbytes
                   if and hash readable-hash-string? hash cons quote hash hash cons quote failed
                   cons quote failed code
                   lambda cons quote changed quote password)
    (password-verify lambda call-with-c-string quote password-verify hash
                     lambda str call-with-utf8 quote password-verify password n
                     lambda in cons quote code crypto-pwhash-str-verify str in n
                     lambda cons quote changed quote password
                     lambda cons quote changed quote hash)
    (password-needs-rehash? lambda call-with-c-string quote password-needs-rehash? hash
                            lambda str cons quote code crypto-pwhash-str-needs-rehash str
                            car pair cdr pair
                            lambda cons quote changed quote hash))
  (map (lambda (name) (cons name (section-tokens name))) verb-names))

(test-equal "S3 no raise inside a section: none of raise, assertion-violation, error, refuse-secret, raise-sodium-failed, check-password or resolve-limits is named there"
  '((password-hash ()) (password-verify ()) (password-needs-rehash? ()))
  (map (lambda (name)
         (list name
               (filter (lambda (t) (memq t '(raise raise-continuable assertion-violation error
                                              refuse-secret raise-sodium-failed check-password
                                              resolve-limits make-password-limits)))
                       (section-tokens name))))
       verb-names))

(test-equal "S4 password-verbs' import clauses, whole: require-threaded first, then (rnrs), native, conditions, cap and password-text, and nothing from (chezscheme)"
  '((chez-sodium private require-threaded)
    (rnrs)
    (chez-sodium private native)
    (chez-sodium private conditions)
    (chez-sodium private cap)
    (chez-sodium private password-text))
  (library-imports verbs-form))

(test-equal "S4 the library exports the three verbs and make-password-limits, as written"
  '(export password-hash password-verify password-needs-rehash? make-password-limits)
  (if (library-read? verbs-form) (caddr verbs-form) 'unreadable))

(test-equal "S5 input-cap is written in the library twice, both in check-password: once for the comparison and once as the bound"
  '((check-password 2) (password-hash 0) (password-verify 0) (password-needs-rehash? 0)
    (whole-body 2))
  (append
   (map (lambda (name) (list name (count-of 'input-cap (tokens (definition-form name)))))
        (cons 'check-password verb-names))
   (list (list 'whole-body (count-of 'input-cap (tokens (library-body verbs-form)))))))

;; The whole set of symbols the library references, sorted, written here: an
;; allow-list. A copy of a secret is made by a procedure this list would then
;; have to name, and none of string->utf8, utf8->string, string->list,
;; list->string, substring, string-copy, bytevector-copy, make-string or
;; string-set! is in it. string-append is, for the two messages, which S7 holds.
(define allowed-symbols
  '(* + <= >= and assertion-violation block call-in-section call-with-block
    call-with-c-string call-with-utf8 car case-lambda cdr changed changed-during-call
    check-password code cond cons crypto-pwhash-str crypto-pwhash-str-needs-rehash
    crypto-pwhash-str-verify current-hash-shape? define define-record-type div else eq?
    eqv? exact? failed fields foreign-ascii-string greatest-kib hash if immutable in
    input-cap integer? interactive kib lambda least-kib leave-unwritten
    length-out-of-range let let* limits limits-kib limits-ops limits-record limits?
    make-password-limits memory-kib memory-message memory-out-of-range moderate n
    natural? new-limits not not-a-natural not-a-string not-password-limits
    number->string opaque ops ops-message ops-out-of-range out outcome over-the-cap pair
    password password-hash password-needs-rehash? password-verify
    pwhash-memlimit-interactive pwhash-memlimit-max pwhash-memlimit-min
    pwhash-memlimit-moderate pwhash-memlimit-sensitive pwhash-opslimit-interactive
    pwhash-opslimit-max pwhash-opslimit-min pwhash-opslimit-moderate
    pwhash-opslimit-sensitive pwhash-passwd-max pwhash-passwd-min pwhash-strbytes
    pwhash-strprefix quote raise-sodium-failed readable-hash-string? refuse-secret
    resolve-limits sealed sensitive shown-value str string-append string? unless
    utf8-length who x))

;; unique-sorted : (Listof Symbol) -> (Listof Symbol)
(define (unique-sorted symbols)
  (let loop ((rest (list-sort symbol<? symbols)) (out '()))
    (cond ((null? rest) (reverse out))
          ((and (pair? out) (eq? (car out) (car rest))) (loop (cdr rest) out))
          (else (loop (cdr rest) (cons (car rest) out))))))

(test-equal "S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies a string or a bytevector is named, and string-append is named only where S7 lets it"
  allowed-symbols
  (unique-sorted (tokens (library-body verbs-form))))

(test-equal "S7 string-append appears only in the two top-level definitions of no parameters whose names end in -message, which cannot see a verb's arguments"
  '(memory-message ops-message)
  (let loop ((forms (library-body verbs-form)) (found '()))
    (cond ((null? forms) (list-sort symbol<? found))
          ((and (pair? (car forms)) (eq? (caar forms) 'define)
                (memq 'string-append (tokens (car forms))))
           (let ((head (cadar forms)))
             (loop (cdr forms)
                   (cons (if (and (pair? head) (null? (cdr head))) (car head) (list 'bad head))
                         found))))
          (else (loop (cdr forms) found)))))

;; --- the end -------------------------------------------------------------------------------------

(test-equal "every count is zero after every row"
  zero-counts
  (native-counts))

(test-end "password-verbs")

(exit (suite-exit-status runner))
