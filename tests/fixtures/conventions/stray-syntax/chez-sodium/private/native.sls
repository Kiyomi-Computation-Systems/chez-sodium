#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. bind-required
;;; has the one (syntax foreign-procedure) in its fender, which is allowed,
;;; and a second, in the same fender, which is not.
(library (chez-sodium private native)
  (export init)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define-syntax bind-required
    (lambda (x)
      (syntax-case x ()
        ((_ chosen (fp convention ... entry (arg ...) result))
         (and (identifier? #'fp)
              (free-identifier=? #'fp #'foreign-procedure)
              (free-identifier=? #'fp #'foreign-procedure))
         #'(begin
             (required-entry entry chosen)
             (fp convention ... entry (arg ...) result))))))
  (define init
    (load-step
     (bind-required chosen
       (foreign-procedure "sodium_init" () int)))))
