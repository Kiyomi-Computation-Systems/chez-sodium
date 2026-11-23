#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. bind-required
;;; and a macro named bind-optional each have one (syntax foreign-procedure)
;;; in their fender. Only bind-required's is allowed.
(library (chez-sodium private native)
  (export init version)
  (import (rnrs) (only (chezscheme) foreign-entry? foreign-procedure))
  (define-syntax bind-required
    (lambda (x)
      (syntax-case x ()
        ((_ chosen (fp convention ... entry (arg ...) result))
         (and (identifier? #'fp)
              (free-identifier=? #'fp #'foreign-procedure))
         #'(begin
             (required-entry entry chosen)
             (fp convention ... entry (arg ...) result))))))
  (define-syntax bind-optional
    (lambda (x)
      (syntax-case x ()
        ((_ (fp convention ... entry (arg ...) result))
         (and (identifier? #'fp)
              (free-identifier=? #'fp #'foreign-procedure))
         #'(and (foreign-entry? entry)
                (fp convention ... entry (arg ...) result))))))
  (define init
    (load-step
     (bind-required chosen
       (foreign-procedure "sodium_init" () int))))
  (define version
    (load-step
     (bind-optional
       (foreign-procedure "sodium_version_string" () uptr)))))
