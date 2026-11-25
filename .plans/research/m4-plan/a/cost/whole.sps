#!r6rs
;; Probe: a whole program of the docs, as a gated child would run it.
(import (rnrs) (chez-sodium))
(define hash (password-hash "s3cret"))
(display (password-verify hash "s3cret"))
(newline)
