#!r6rs
;; Keyed BLAKE2b with a key length other than the size, through libsodium's
;; crypto_generichash, against hashlib's answers (keyed-python.out).
;; Usage: scheme --program keyed.sps LIBRARY
(import (chezscheme))
(define path (cadr (command-line)))
(load-shared-object path)
(define init (foreign-procedure "sodium_init" () int))
(define generichash
  (foreign-procedure "crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int))
(init)
(define (block bytes)
  (let* ((n (max 1 (length bytes))) (b (foreign-alloc n)))
    (foreign-set! 'unsigned-8 b 0 0)
    (let loop ((i 0) (l bytes)) (unless (null? l) (foreign-set! 'unsigned-8 b i (car l)) (loop (+ i 1) (cdr l))))
    b))
(define (iota* a b) (if (>= a b) '() (cons a (iota* (+ a 1) b))))
(define (hex b n)
  (apply string-append
         (map (lambda (i) (let ((x (foreign-ref 'unsigned-8 b i)))
                            (string-append (if (< x 16) "0" "") (number->string x 16))))
              (iota* 0 n))))
(define (run name input size key)
  (let ((out (foreign-alloc size)) (in (block input)) (k (block key)))
    (let ((rc (generichash out size in (length input) k (length key))))
      (printf "~a ~a rc ~a\n" name (string-downcase (hex out size)) rc))))
(printf "library ~a\n" path)
(run "key16-size32-abc" '(97 98 99) 32 (iota* 1 17))
(run "key64-size20-abc" '(97 98 99) 20 (iota* 0 64))
(run "key17-size64-empty" '() 64 (iota* 0 17))
