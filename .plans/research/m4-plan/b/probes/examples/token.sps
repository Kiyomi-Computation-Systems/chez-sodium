(import (rnrs) (chez-sodium))

;; A token is an id and a secret. The user keeps the secret; the server
;; keeps only its BLAKE2b hash, under the id.
(define tokens (make-eqv-hashtable))

(define (issue-token! id)
  (let ((secret (random-bytes 32)))
    (hashtable-set! tokens id (blake2b secret))
    secret))                       ; show it to the user once

(define (token-valid? id secret)
  (let ((stored (hashtable-ref tokens id #f)))
    (and stored
         (bytevector? secret)
         (<= (bytevector-length secret) 64)
         (constant-time-bytevector=? (blake2b secret) stored))))

(define secret (issue-token! 7))
(define wrong (bytevector-copy secret))
(bytevector-u8-set! wrong 0 (bitwise-xor 1 (bytevector-u8-ref wrong 0)))

(write
 (list (bytevector-length secret)
       (bytevector-length (hashtable-ref tokens 7 #f))
       (token-valid? 7 secret)
       (token-valid? 7 wrong)
       (token-valid? 8 secret)))
(newline)
