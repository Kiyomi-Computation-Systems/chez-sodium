#!r6rs
;; Probe: Chez 10.4.0's size_t and unsigned-64, as arguments and results,
;; against a C echo library (echo.c) and the real libsodium 1.0.18.
;; Usage: scheme --script p02-ints.sps ./libecho.so /path/libsodium.so.23
(import (chezscheme))
(define args (cdr (command-line)))
(load-shared-object (car args))
(load-shared-object (cadr args))
(define echo-size (foreign-procedure "echo_size" (size_t) size_t))
(define echo-ull (foreign-procedure "echo_ull" (unsigned-64) unsigned-64))
(define echo-size-as-u64 (foreign-procedure "echo_size" (unsigned-64) unsigned-64))
(define size-max (foreign-procedure "size_max" () size_t))
(define size-max-int (foreign-procedure "size_max" () int))
(define sizeof-ull (foreign-procedure "sizeof_ull" () int))
(define sizeof-size (foreign-procedure "sizeof_size" () int))
(define (try f x)
  (guard (e (#t (list 'raised (if (message-condition? e) (condition-message e) e)
                      (if (irritants-condition? e) (condition-irritants e) '()))))
    (f x)))
(printf "C sizeof(unsigned long long) ~s sizeof(size_t) ~s; Chez unsigned-64 ~s size_t ~s\n"
        (sizeof-ull) (sizeof-size) (foreign-sizeof 'unsigned-64) (foreign-sizeof 'size_t))
(for-each
 (lambda (x)
   (let* ((a (try echo-size x)) (b (try echo-ull x)))
     (printf "~s: size_t -> ~s ; unsigned-64 -> ~s\n" x a b)))
 (list 0 1 -1 -2 (- (expt 2 63)) (- (- (expt 2 63)) 1) (- (expt 2 63) 1) (expt 2 63)
       (- (expt 2 64) 1) (expt 2 64) 1.0 1/2 'a))
(printf "size_max as size_t ~s, as int ~s\n" (size-max) (size-max-int))
;; Real libsodium: size_t results, and a size_t / unsigned long long argument.
(define memlimit-max (foreign-procedure "crypto_pwhash_memlimit_max" () size_t))
(define opslimit-max (foreign-procedure "crypto_pwhash_opslimit_max" () size_t))
(define opslimit-min (foreign-procedure "crypto_pwhash_opslimit_min" () size_t))
(define memlimit-min (foreign-procedure "crypto_pwhash_memlimit_min" () size_t))
(define passwd-max (foreign-procedure "crypto_pwhash_passwd_max" () size_t))
(define strbytes (foreign-procedure "crypto_pwhash_strbytes" () size_t))
(define gh-max (foreign-procedure "crypto_generichash_bytes_max" () size_t))
(define init (foreign-procedure "sodium_init" () int))
(init)
(printf "memlimit_max ~s opslimit_max ~s opslimit_min ~s memlimit_min ~s passwd_max ~s strbytes ~s generichash_bytes_max ~s\n"
        (memlimit-max) (opslimit-max) (opslimit-min) (memlimit-min) (passwd-max) (strbytes) (gh-max))
