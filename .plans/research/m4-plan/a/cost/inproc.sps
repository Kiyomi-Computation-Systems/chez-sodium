#!r6rs
;; Probe: what a docs suite's in-process run blocks cost, as test-docs
;; evaluates a block: the body of (let () ...) in an environment of (rnrs)
;; and (chez-sodium). Each line: a label and the milliseconds it took.
(import (chezscheme))
(define env (environment '(rnrs) '(chez-sodium)))
(define (timed label form)
  (let* ((t0 (real-time))
         (v (eval form env))
         (t1 (real-time)))
    (printf "~a ~a ms ~s\n" label (- t1 t0)
            (if (string? v) (string-length v) v))
    v))
(timed "first-reference" '(sodium-version))
(timed "min-hash-verify"
       '(let () (define h (password-hash "pw" (make-password-limits 1 8)))
          (password-verify h "pw")))
(define h (timed "default-hash" '(password-hash "p\xe4;ssw\xf6;rd\x20ac;")))
(timed "default-verify" `(password-verify ,h "p\xe4;ssw\xf6;rd\x20ac;"))
(timed "default-verify-wrong" `(password-verify ,h "password"))
(timed "needs-rehash" `(password-needs-rehash? ,h))
(timed "login-block"
       '(let () (define h (password-hash "s3cret"))
          (and (password-verify h "s3cret")
               (not (password-needs-rehash? h)))))
(timed "random-and-blake2b"
       '(let () (define k (random-bytes 32))
          (bytevector-length (blake2b k))))
(timed "compare" '(constant-time-bytevector=? (u8-list->bytevector '(1 2)) (u8-list->bytevector '(1 2))))
