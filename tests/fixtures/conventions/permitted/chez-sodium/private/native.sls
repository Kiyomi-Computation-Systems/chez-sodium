#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. The three
;;; places foreign-procedure may appear besides a form's head: the import
;;; clause, bind-required's fender, and nowhere else. No violation.
(library (chez-sodium private native)
  (export init)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define-syntax bind-required
    (lambda (x)
      (syntax-case x ()
        ((_ chosen (fp convention ... entry (arg ...) result))
         (and (identifier? #'fp)
              (free-identifier=? #'fp #'foreign-procedure))
         #'(begin
             (required-entry entry chosen)
             (fp convention ... entry (arg ...) result))))))
  (define init
    (load-step
     (bind-required chosen
       (foreign-procedure "sodium_init" () int)))))
