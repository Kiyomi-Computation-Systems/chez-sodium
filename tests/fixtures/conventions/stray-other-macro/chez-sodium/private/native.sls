#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. A (syntax
;;; foreign-procedure) in the fender of a macro that is not bind-required.
(library (chez-sodium private native)
  (export init)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define-syntax other-required
    (lambda (x)
      (syntax-case x ()
        ((_ fp)
         (free-identifier=? #'fp #'foreign-procedure)
         #'(begin)))))
  (define init
    (load-step
     (other-required chosen
       (foreign-procedure "sodium_init" () int)))))
