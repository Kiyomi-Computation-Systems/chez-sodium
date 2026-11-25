#!r6rs
;;; A first program, as a quick start would show it, run against a fresh
;;; clone's src alone.
(import (rnrs) (chez-sodium))

(define hash (password-hash "correct horse"))
(write (list (sodium-version)
             (password-verify hash "correct horse")
             (password-verify hash "battery staple")
             (bytevector-length (random-bytes 32))))
(newline)
