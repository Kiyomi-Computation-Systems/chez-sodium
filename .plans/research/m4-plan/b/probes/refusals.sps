#!r6rs
;;; Every refusal of every verb of (chez-sodium), as a caller meets it: who,
;;; the condition's kinds, its irritants and its message. One line a case:
;;;
;;;   (CASE answered VALUE)   or
;;;   (CASE raised WHO (KINDS ...) IRRITANTS MESSAGE)
;;;
;;; KINDS names what holds of the condition: assertion, chez-sodium-error,
;;; sodium-failed, syntax, error, violation. A value too big to print is shown
;;; as (bytes N) or (string N).
(import (rnrs) (rnrs eval) (chez-sodium))

(define (kinds e)
  (filter (lambda (x) x)
          (list (and (assertion-violation? e) 'assertion)
                (and (chez-sodium-error? e) 'chez-sodium-error)
                (and (sodium-failed? e) 'sodium-failed)
                (and (syntax-violation? e) 'syntax)
                (and (error? e) 'error)
                (and (violation? e) 'violation))))

(define (shown v)
  (cond ((and (bytevector? v) (> (bytevector-length v) 8)) (list 'bytes (bytevector-length v)))
        ((and (string? v) (> (string-length v) 40)) (list 'string (string-length v)))
        (else v)))

(define (try name thunk)
  (write
   (guard (e ((condition? e)
              (list name 'raised
                    (and (who-condition? e) (condition-who e))
                    (kinds e)
                    (and (irritants-condition? e) (condition-irritants e))
                    (and (message-condition? e) (condition-message e))))
             (#t (list name 'raised-non-condition e)))
     (list name 'answered (shown (thunk)))))
  (newline))

(define cap 65536)
(define (bytes n) (make-bytevector n 7))
(define good-hash
  (password-hash "correct horse" (make-password-limits 1 8)))

;; random-bytes
(try 'rb-symbol (lambda () (random-bytes 'x)))
(try 'rb-negative (lambda () (random-bytes -1)))
(try 'rb-inexact (lambda () (random-bytes 2.0)))
(try 'rb-over-cap (lambda () (random-bytes (+ cap 1))))
(try 'rb-at-cap (lambda () (bytevector-length (random-bytes cap))))
(try 'rb-zero (lambda () (random-bytes 0)))
(try 'rb-string (lambda () (random-bytes "32")))

;; blake2b
(try 'b2-input-symbol (lambda () (blake2b 'x)))
(try 'b2-input-string (lambda () (blake2b "abc")))
(try 'b2-input-over-cap (lambda () (blake2b (bytes (+ cap 1)))))
(try 'b2-input-at-cap (lambda () (bytevector-length (blake2b (bytes cap)))))
(try 'b2-size-symbol (lambda () (blake2b (bytes 3) 'x)))
(try 'b2-size-false (lambda () (blake2b (bytes 3) #f)))
(try 'b2-size-15 (lambda () (blake2b (bytes 3) 15)))
(try 'b2-size-65 (lambda () (blake2b (bytes 3) 65)))
(try 'b2-size-16 (lambda () (bytevector-length (blake2b (bytes 3) 16))))
(try 'b2-size-64 (lambda () (bytevector-length (blake2b (bytes 3) 64))))
(try 'b2-key-string (lambda () (blake2b (bytes 3) 32 "key")))
(try 'b2-key-false (lambda () (blake2b (bytes 3) 32 #f)))
(try 'b2-key-empty (lambda () (blake2b (bytes 3) 32 (bytes 0))))
(try 'b2-key-15 (lambda () (blake2b (bytes 3) 32 (bytes 15))))
(try 'b2-key-65 (lambda () (blake2b (bytes 3) 32 (bytes 65))))
(try 'b2-key-16 (lambda () (bytevector-length (blake2b (bytes 3) 32 (bytes 16)))))
(try 'b2-key-64 (lambda () (bytevector-length (blake2b (bytes 3) 32 (bytes 64)))))
(try 'b2-input-and-size-bad (lambda () (blake2b 'x 99)))

;; constant-time-bytevector=?
(try 'ct-a-symbol (lambda () (constant-time-bytevector=? 'x (bytes 3))))
(try 'ct-b-string (lambda () (constant-time-bytevector=? (bytes 3) "abc")))
(try 'ct-a-over-cap (lambda () (constant-time-bytevector=? (bytes (+ cap 1)) (bytes 3))))
(try 'ct-b-over-cap-short-a (lambda () (constant-time-bytevector=? (bytes 3) (bytes (+ cap 1)))))
(try 'ct-at-cap (lambda () (constant-time-bytevector=? (bytes cap) (bytes cap))))
(try 'ct-lengths-differ (lambda () (constant-time-bytevector=? (bytes 3) (bytes 4))))
(try 'ct-both-empty (lambda () (constant-time-bytevector=? (bytes 0) (bytes 0))))

;; password-hash
(try 'ph-password-symbol (lambda () (password-hash 'x)))
(try 'ph-password-bytevector (lambda () (password-hash (bytes 3))))
(try 'ph-password-over-cap (lambda () (password-hash (make-string (+ cap 1) #\a))))
(try 'ph-password-over-cap-bytes (lambda () (password-hash (make-string (+ (div cap 2) 1) #\xE9))))
(try 'ph-limits-symbol (lambda () (password-hash "correct horse" 'fast)))
(try 'ph-limits-pair (lambda () (password-hash "correct horse" '(2 . 65536))))
(try 'ph-limits-string (lambda () (password-hash "correct horse" "interactive")))
(try 'ph-both-bad (lambda () (password-hash 'x 'fast)))

;; password-verify
(try 'pv-hash-symbol (lambda () (password-verify 'x "correct horse")))
(try 'pv-password-symbol (lambda () (password-verify good-hash 'x)))
(try 'pv-password-over-cap (lambda () (password-verify good-hash (make-string (+ cap 1) #\a))))
(try 'pv-password-over-cap-bad-hash (lambda () (password-verify "" (make-string (+ cap 1) #\a))))
(try 'pv-both-bad (lambda () (password-verify 'x 'y)))
(try 'pv-hash-over-cap (lambda () (password-verify (make-string (+ cap 1) #\a) "correct horse")))

;; password-needs-rehash?
(try 'pn-hash-symbol (lambda () (password-needs-rehash? 'x)))
(try 'pn-limits-symbol (lambda () (password-needs-rehash? good-hash 'fast)))
(try 'pn-bad-hash-bad-limits (lambda () (password-needs-rehash? "" 'fast)))
(try 'pn-hash-over-cap (lambda () (password-needs-rehash? (make-string (+ cap 1) #\a))))

;; make-password-limits
(try 'ml-ops-symbol (lambda () (make-password-limits 'x 64)))
(try 'ml-ops-zero (lambda () (make-password-limits 0 64)))
(try 'ml-ops-2^32 (lambda () (make-password-limits (expt 2 32) 64)))
(try 'ml-ops-max (lambda () (record? (make-password-limits (- (expt 2 32) 1) 64))))
(try 'ml-memory-string (lambda () (make-password-limits 2 "64")))
(try 'ml-memory-7 (lambda () (make-password-limits 2 7)))
(try 'ml-memory-8 (lambda () (record? (make-password-limits 2 8))))
(try 'ml-memory-2^32 (lambda () (make-password-limits 2 (expt 2 32))))
(try 'ml-memory-max (lambda () (record? (make-password-limits 2 (- (expt 2 32) 1)))))
(try 'ml-memory-inexact (lambda () (make-password-limits 2 64.0)))
(try 'ml-both-bad (lambda () (make-password-limits 0 0)))

;; the accessors
(try 'acc-failed-code (lambda () (sodium-failed-code 'x)))
(try 'acc-failed-function (lambda () (sodium-failed-function "x")))
(try 'acc-unavailable-reason (lambda () (sodium-library-unavailable-reason 'x)))
(try 'acc-unavailable-candidates (lambda () (sodium-library-unavailable-candidates 42)))
(try 'pred-on-symbol (lambda () (list (chez-sodium-error? 'x) (sodium-failed? 'x) (sodium-library-unavailable? 'x))))

;; arity, as Chez itself refuses it
(try 'arity-password-hash (lambda () (eval '(password-hash) (environment '(chez-sodium)))))
(try 'arity-blake2b (lambda () (eval '(blake2b (make-bytevector 1) 32 (make-bytevector 16) 1) (environment '(rnrs) '(chez-sodium)))))
(try 'arity-make-password-limits (lambda () (eval '(make-password-limits 2) (environment '(chez-sodium)))))
