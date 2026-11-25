#!r6rs
;; Probe: the same whole program at libsodium's minimum limits.
(import (rnrs) (chez-sodium))
(define limits (make-password-limits 1 8))
(define hash (password-hash "s3cret" limits))
(display (password-verify hash "s3cret"))
(newline)
