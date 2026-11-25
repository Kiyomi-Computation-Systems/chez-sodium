#!r6rs
;;; What the caller holds after a verb: its own password string, untouched,
;;; and fresh values the verbs return. And whether string-fill! can wipe a
;;; string literal or only a string the program made.
(import (rnrs) (rnrs mutable-strings) (chez-sodium))

(define (show x) (write x) (newline))

(define typed (string-copy "correct horse"))   ; as a parser would make it
(define h (password-hash typed (make-password-limits 1 8)))
(show (list 'password-after-hash typed))
(string-fill! typed #\x0)
(show (list 'after-string-fill! (string->list typed)))
(show (list 'still-verifies-the-original (password-verify h "correct horse")))
(show (list 'string-fill!-on-a-literal
            (guard (e ((assertion-violation? e) (list 'raised (condition-message e))))
              (string-fill! "correct horse" #\x0)
              'wiped)))
(let* ((key (random-bytes 32)) (copy (bytevector-copy key)))
  (bytevector-fill! key 0)
  (show (list 'random-bytes-is-the-callers-to-wipe (bytevector=? key (make-bytevector 32 0))
              'copy-untouched (not (bytevector=? copy key)))))
