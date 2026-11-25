(import (rnrs) (chez-sodium))

(define hash (password-hash "correct horse"))

(write (list (password-verify hash "correct horse")
             (password-verify hash "battery staple")
             (bytevector-length (random-bytes 32))))
(newline)
