#!r6rs
;;; A program that calls libsodium's sodium_init itself, before chez-sodium
;;; loads, as another library in the same process might. chez-sodium is
;;; reached only through eval, so its load runs after the first call.
(import (chezscheme))

(define path (getenv "CHEZ_SODIUM_LIBRARY"))
(load-shared-object path)
(define sodium-init (foreign-procedure "sodium_init" () int))

(define (show x) (write x) (newline))

(show (list 'first-sodium-init (sodium-init)))
(show (list 'chez-sodium-loads
            (guard (e (#t (list 'raised (condition-message e))))
              (eval '(list (sodium-version) (bytevector-length (random-bytes 4)))
                    (environment '(rnrs) '(chez-sodium))))))
(show (list 'init-recorded-by-the-load
            (cdr (assq 'init (eval '(loaded-libsodium)
                                   (environment '(chez-sodium private native)))))))
(show (list 'later-sodium-init (sodium-init)))
