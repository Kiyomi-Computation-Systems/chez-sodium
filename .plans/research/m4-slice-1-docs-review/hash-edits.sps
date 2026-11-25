#!r6rs
;; docs/passwords.md and docs/reference.md say any change to a stored hash
;; makes it verify #f for ever. Each line: (EDIT VERIFY NEEDS-REHASH), the
;; edit made to a hash of "pw" at (make-password-limits 1 8), verify run with
;; "pw", needs-rehash at those limits. Run through
;; .plans/research/m4-plan/b/probes/both.sh.
(import (rnrs) (chez-sodium))

(define cheap (make-password-limits 1 8))
(define h (password-hash "pw" cheap))

;; replace-once : String String String -> (U String #f)
(define (replace-once s from to)
  (let ((n (string-length s)) (k (string-length from)))
    (let loop ((i 0))
      (cond ((> (+ i k) n) #f)
            ((string=? (substring s i (+ i k)) from)
             (string-append (substring s 0 i) to (substring s (+ i k) n)))
            (else (loop (+ i 1)))))))

(define (show edit s)
  (write (list edit
               (and s (password-verify s "pw"))
               (and s (password-needs-rehash? s cheap))))
  (newline))

(show 'as-made h)
(show 'version-field-dropped (replace-once h "$v=19" ""))
(show 'version-leading-zero (replace-once h "v=19" "v=019"))
(show 'memory-leading-zero (replace-once h "m=8," "m=08,"))
(show 'ops-leading-zero (replace-once h "t=1," "t=01,"))
(show 'lanes-leading-zero (replace-once h "p=1$" "p=01$"))
(show 'prefix-argon2i (replace-once h "$argon2id$" "$argon2i$"))
