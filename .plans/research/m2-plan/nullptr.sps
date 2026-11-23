#!r6rs
;; What crypto_generichash and sodium_memcmp do with a NULL pointer, per case.
;; Usage: scheme --program nullptr.sps LIBRARY CASE   (each case in its own process)
;; cases: key0 (key NULL, keylen 0), in0 (in NULL, inlen 0), key16 (key NULL, keylen 16),
;;        in3 (in NULL, inlen 3), cmp0 (both NULL, len 0), cmp4 (both NULL, len 4)
(import (chezscheme))
(define a (cdr (command-line)))
(load-shared-object (car a))
((foreign-procedure "sodium_init" () int))
(define gh (foreign-procedure "crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int))
(define mc (foreign-procedure "sodium_memcmp" (uptr uptr size_t) int))
(define out (foreign-alloc 32)) (define blk (foreign-alloc 4))
(do ((i 0 (+ i 1))) ((= i 4)) (foreign-set! 'unsigned-8 blk i 97))
(define r
  (case (string->symbol (cadr a))
    ((key0) (gh out 32 blk 3 0 0)) ((in0) (gh out 32 0 0 blk 0))
    ((key16) (gh out 32 blk 3 0 16)) ((in3) (gh out 32 0 3 blk 0))
    ((cmp0) (mc 0 0 0)) ((cmp4) (mc 0 0 4))))
(printf "answered ~s\n" r)
