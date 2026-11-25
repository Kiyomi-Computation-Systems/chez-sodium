#!r6rs
;;; The suite for the password verbs against libsodium's own C, both ways
;;; (ADR-0011): tests/libsodium-oracle.c's hex mode hashes and verifies at
;;; libsodium's minimum limits, in gated children, and this process's verbs
;;; are held to what it says.
;;;
;;;   C hashes, Scheme verifies   password-verify answers #t, and #f for the
;;;                               password with its last byte changed
;;;   Scheme hashes, C verifies   password-hash at (make-password-limits
;;;                               ops-min memory-min-kib), both read from
;;;                               native, verifies with code 0, and with -1 for
;;;                               the changed password
;;;
;;; for three passwords: a non-ASCII one, one with a U+0000 in it, and the empty
;;; one, whose changed twin is "a" (an empty password has no last byte). A
;;; password-verify that answers #t for anything, or a password-hash that drops
;;; the bytes past ASCII or at a U+0000, fails a row. An oracle child reports
;;; (valgrind . yes) or (valgrind . no), and each row requires yes exactly when
;;; the memory gate asked.
;;;
;;; Every verb call is computed under a guard, and a row that expects #f from
;;; password-verify also holds what a guard answered: (answered #f), never a
;;; raise. The verbs are reached through eval, under a guard, so a refused
;;; load fails the rows by name. The oracle is a child process: C reading
;;; libsodium, not chez-sodium.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (only (chezscheme) getenv)
        (chez-sodium-testing)
        (libsodium-oracle))

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

(test-begin "password-oracle")

;; --- the verbs, and the library under them --------------------------------------------------

(define verbs (environment '(rnrs) '(chez-sodium private native) '(chez-sodium private password-verbs)))

;; library-path : -> (U String (List 'raised String))
;; The path of the libsodium native loaded: what the oracle must read.
(define library-path
  (guard (e (#t (list 'raised (describe e))))
    (cdr (assq 'path (eval '(loaded-libsodium) verbs)))))

(test-equal "native loads, and says which libsodium it loaded"
  'a-path
  (if (and (string? library-path) (> (string-length library-path) 0)) 'a-path library-path))

;; minimum-limits : -> (U Password-limits (List 'raised String))
;; (make-password-limits ops-min memory-min-kib), both read from native.
(define minimum-limits
  (guard (e (#t (list 'raised (describe e))))
    (eval '(make-password-limits pwhash-opslimit-min (div pwhash-memlimit-min 1024)) verbs)))

;; scheme-hash : String -> (List 'answered String) or (List 'raised String)
(define (scheme-hash password)
  (guard (e (#t (list 'raised (describe e))))
    (list 'answered ((eval 'password-hash verbs) password minimum-limits))))

;; scheme-verify : String String -> (List 'answered Any) or (List 'raised String)
(define (scheme-verify hash password)
  (guard (e (#t (list 'raised (describe e))))
    (list 'answered ((eval 'password-verify verbs) hash password))))

;; --- the oracle, and its verdicts ------------------------------------------------------------

;; The (valgrind . ...) line of each hex-mode run since the last take-verdicts!,
;; or the (no-oracle ...) answer of one that gave none.
(define hex-verdicts '())

;; take-verdicts! : -> (Listof Any)
;; The runs' verdicts, each distinct one once, in the order first seen; the
;; record is emptied.
(define (take-verdicts!)
  (let ((seen (let loop ((rest (reverse hex-verdicts)) (kept '()))
                (cond ((null? rest) (reverse kept))
                      ((member (car rest) kept) (loop (cdr rest) kept))
                      (else (loop (cdr rest) (cons (car rest) kept)))))))
    (set! hex-verdicts '())
    seen))

;; hex-answer : Symbol Any -> Any
;; ANSWER's value when it is (KEY VALUE VERDICT), the verdict recorded; ANSWER
;; itself otherwise, recorded as the verdict too, so a run that gave none fails
;; the row that asserts the verdicts.
(define (hex-answer key answer)
  (if (and (list? answer) (= (length answer) 3) (eq? (car answer) key))
      (begin (set! hex-verdicts (cons (caddr answer) hex-verdicts))
             (cadr answer))
      (begin (set! hex-verdicts (cons answer hex-verdicts))
             answer)))

;; bytes->hex : Bytevector -> String
(define (bytes->hex bytes)
  (let loop ((i (- (bytevector-length bytes) 1)) (digits '()))
    (if (< i 0)
        (apply string-append digits)
        (loop (- i 1)
              (cons (let ((h (number->string (bytevector-u8-ref bytes i) 16)))
                      (if (< (string-length h) 2) (string-append "0" h) h))
                    digits)))))

;; hex-of : String -> String
;; The hex of PASSWORD's UTF-8 bytes.
(define (hex-of password) (bytes->hex (string->utf8 password)))

;; oracle-hash : String -> (U String Any)
;; The hash string the oracle's hex mode made for PASSWORD, or what it answered.
(define (oracle-hash password)
  (guard (e (#t (list 'raised (describe e))))
    (hex-answer 'hash (libsodium-oracle-hash getenv library-path (hex-of password)))))

;; oracle-verify : String String -> Any
;; The oracle's verify code for HASH and PASSWORD, or what it answered.
(define (oracle-verify hash password)
  (guard (e (#t (list 'raised (describe e))))
    (hex-answer 'verify (libsodium-oracle-verify getenv library-path hash (hex-of password)))))

;; expected-verdicts : (Listof Pair)
;; What every hex-mode run must report: under Valgrind exactly when the gate asked.
(define expected-verdicts
  (list (if (getenv "CHEZ_SODIUM_GATE_CHILD") '(valgrind . yes) '(valgrind . no))))

;; shape : Any -> Any
;; A hash string as its prefix and length, so a row holds that the limits were
;; the minimum, without holding the salt; anything else as it is.
(define (shape hash)
  (if (string? hash)
      (list (substring hash 0 (min 27 (string-length hash))) (string-length hash))
      hash))

;; --- the three passwords --------------------------------------------------------------------

;; non-ASCII, with a last byte that differs in its twin: U+20AC and U+20AD end
;; in 0xAC and 0xAD.
(define passwords
  (list (cons "p\x00E4;ssw\x00F6;rd\x20AC;" "p\x00E4;ssw\x00F6;rd\x20AD;")
        (cons "a\x0;b" "a\x0;c")
        (cons "" "a")))

(define names '("a non-ASCII password" "a password with a U+0000 in it" "the empty password"))

(define minimum-shape '("$argon2id$v=19$m=8,t=1,p=1$" 93))

;; each-row : (String String String -> Void) -> Void
(define (each-row make-row)
  (let loop ((rest passwords) (names names))
    (unless (null? rest)
      (make-row (caar rest) (cdar rest) (car names))
      (loop (cdr rest) (cdr names)))))

(each-row
 (lambda (password changed name)
   (test-equal (string-append "C hashes at the minimum limits and the verb verifies, for " name
                              ": #t, and the password with its last byte changed answers (answered #f), raising nothing; the oracle ran under Valgrind exactly when the gate asked")
     (list minimum-shape (list 'answered #t) (list 'answered #f) expected-verdicts)
     (let* ((hash (oracle-hash password))
            (right (if (string? hash) (scheme-verify hash password) (list 'no-hash hash)))
            (wrong (if (string? hash) (scheme-verify hash changed) (list 'no-hash hash))))
       (list (shape hash) right wrong (take-verdicts!))))))

(each-row
 (lambda (password changed name)
   (test-equal (string-append "the verb hashes at (make-password-limits ops-min memory-min-kib) and C verifies, for " name
                              ": code 0, and the password with its last byte changed answers -1; the oracle ran under Valgrind exactly when the gate asked")
     (list minimum-shape 0 -1 expected-verdicts)
     (let* ((answer (scheme-hash password))
            (hash (if (eq? (car answer) 'answered) (cadr answer) answer))
            (right (if (string? hash) (oracle-verify hash password) (list 'no-hash hash)))
            (wrong (if (string? hash) (oracle-verify hash changed) (list 'no-hash hash))))
       (list (shape hash) right wrong (take-verdicts!))))))

(test-equal "two hashes of one password differ, the hash of \"a\" does not verify the empty password and the hash of the empty password does not verify \"a\", each (answered #f)"
  (list 'differ (list 'answered #f) (list 'answered #f))
  (guard (e (#t (list 'raised (describe e))))
    (let* ((ha (cadr (scheme-hash "a")))
           (ha2 (cadr (scheme-hash "a")))
           (he (cadr (scheme-hash ""))))
      (list (if (equal? ha ha2) 'same 'differ) (scheme-verify ha "") (scheme-verify he "a")))))

(test-end "password-oracle")

(exit (suite-exit-status runner))
