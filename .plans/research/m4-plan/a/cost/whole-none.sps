#!r6rs
;; Probe: a whole program that loads libsodium and hashes nothing.
(import (rnrs) (chez-sodium))
(display (bytevector-length (random-bytes 32)))
(newline)
