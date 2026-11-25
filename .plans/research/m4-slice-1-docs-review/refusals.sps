#!r6rs
;; Every refusal, default and answer docs/reference.md and the pages state,
;; as the library gives it: each line is (WHAT RESULT), RESULT being
;; (raised WHO IRRITANTS) or (value V). Run through
;; .plans/research/m4-plan/b/probes/both.sh.
(import (rnrs) (chez-sodium))

(define (try thunk)
  (guard (e ((assertion-violation? e)
             (list 'raised (and (who-condition? e) (condition-who e))
                   (if (irritants-condition? e) (condition-irritants e) '())))
            ((sodium-failed? e) (list 'sodium-failed (sodium-failed-function e) (sodium-failed-code e)))
            ((sodium-library-unavailable? e) (list 'unavailable (sodium-library-unavailable-reason e)))
            (#t (list 'other-raise (if (message-condition? e) (condition-message e) e))))
    (list 'value (thunk))))

(define-syntax probe
  (syntax-rules ()
    ((_ what expr) (begin (write (list what (try (lambda () expr)))) (newline)))))

(define bv (u8-list->bytevector '(1 2 3)))
(define big (make-bytevector 65537 0))
(define cap (make-bytevector 65536 0))
(define key16 (make-bytevector 16 7))
(define cheap (make-password-limits 1 8))
(define h (password-hash "pw" cheap))

;; random-bytes
(probe 'rb-0 (random-bytes 0))
(probe 'rb-string (random-bytes "32"))
(probe 'rb-neg (random-bytes -1))
(probe 'rb-inexact (random-bytes 1.0))
(probe 'rb-cap (bytevector-length (random-bytes 65536)))
(probe 'rb-over (random-bytes 65537))

;; blake2b
(probe 'b-default (bytevector-length (blake2b bv)))
(probe 'b-input-type (blake2b "abc"))
(probe 'b-input-cap-ok (bytevector-length (blake2b cap)))
(probe 'b-input-over (blake2b big))
(probe 'b-size-false (blake2b bv #f))
(probe 'b-size-15 (blake2b bv 15))
(probe 'b-size-65 (blake2b bv 65))
(probe 'b-size-16 (bytevector-length (blake2b bv 16)))
(probe 'b-key-false (blake2b bv 32 #f))
(probe 'b-key-empty (blake2b bv 32 (make-bytevector 0)))
(probe 'b-key-15 (blake2b bv 32 (make-bytevector 15 1)))
(probe 'b-key-65 (blake2b bv 32 (make-bytevector 65 1)))
(probe 'b-key-16 (bytevector-length (blake2b bv 32 key16)))
(probe 'b-order-input-then-size (blake2b "x" 3))
(probe 'b-same (equal? (blake2b bv 32 key16) (blake2b bv 32 key16)))

;; constant-time-bytevector=?
(probe 'ct-empty (constant-time-bytevector=? (make-bytevector 0) (make-bytevector 0)))
(probe 'ct-diff-len (constant-time-bytevector=? bv (make-bytevector 2 1)))
(probe 'ct-a-type (constant-time-bytevector=? 1 2))
(probe 'ct-a-over-b-type (constant-time-bytevector=? big 2))
(probe 'ct-b-type (constant-time-bytevector=? bv "x"))
(probe 'ct-b-over (constant-time-bytevector=? bv big))

;; password-hash
(probe 'ph-bytevector (password-hash bv))
(probe 'ph-order (password-hash 1 'bogus))
(probe 'ph-limits (password-hash "pw" 'fast))
(probe 'ph-over (password-hash (make-string 65537 #\a) cheap))
(probe 'ph-over-utf8 (password-hash (make-string 16385 #\x10000) cheap))
(probe 'ph-cap-utf8 (string? (password-hash (make-string 16384 #\x10000) cheap)))
(probe 'ph-empty (string? (password-hash "" cheap)))

;; password-verify
(probe 'pv-right (password-verify h "pw"))
(probe 'pv-hash-type (password-verify 1 2))
(probe 'pv-pw-false (password-verify h #f))
(probe 'pv-pw-number (password-verify h 42))
(probe 'pv-pw-over (password-verify h (make-string 65537 #\a)))
(probe 'pv-bad-hash-bad-pw (password-verify "garbage" (make-string 65537 #\a)))
(probe 'pv-garbage (password-verify "garbage" "pw"))
(probe 'pv-empty-hash (password-verify "" "pw"))
(probe 'pv-hash-over (password-verify (make-string 65537 #\a) "pw"))
(probe 'pv-hash-tab (password-verify (string-append h "\t") "pw"))
(probe 'pv-hash-del (password-verify (string-append h (string (integer->char 127))) "pw"))
(probe 'pv-hash-space (password-verify (string-append h " ") "pw"))
(probe 'pv-hash-newline (password-verify (string-append h "\n") "pw"))

;; password-needs-rehash?
(probe 'nr-garbage (password-needs-rehash? "garbage"))
(probe 'nr-empty (password-needs-rehash? ""))
(probe 'nr-same (password-needs-rehash? h cheap))
(probe 'nr-other (password-needs-rehash? h))
(probe 'nr-order (password-needs-rehash? 1 'bogus))
(probe 'nr-limits (password-needs-rehash? h 'bogus))

;; make-password-limits
(probe 'ml-equal (equal? (make-password-limits 2 19456) (make-password-limits 2 19456)))
(probe 'ml-ops-0 (make-password-limits 0 8))
(probe 'ml-ops-max (begin (make-password-limits 4294967295 8) 'made))
(probe 'ml-ops-over (make-password-limits 4294967296 8))
(probe 'ml-ops-type (make-password-limits 1.0 8))
(probe 'ml-mem-7 (make-password-limits 1 7))
(probe 'ml-mem-max (begin (make-password-limits 1 4294967295) 'made))
(probe 'ml-mem-over (make-password-limits 1 4294967296))
(probe 'ml-mem-inexact (make-password-limits 1 64.0))
(probe 'ml-alike (let* ((a (make-password-limits 1 8)) (b (make-password-limits 1 8))
                        (x (password-hash "pw" a)))
                   (list (password-needs-rehash? x a) (password-needs-rehash? x b))))

;; the accessors and predicates
(probe 'acc-failed (sodium-failed-code 1))
(probe 'acc-unavailable (sodium-library-unavailable-reason "x"))
(probe 'pred-mistake (guard (e (#t (list (chez-sodium-error? e) (assertion-violation? e))))
                       (random-bytes -1)))
(probe 'version-fresh (let ((a (sodium-version)) (b (sodium-version))) (eq? a b)))
