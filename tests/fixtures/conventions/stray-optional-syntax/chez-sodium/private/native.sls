#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. A macro named
;;; bind-optional has two (syntax foreign-procedure) in its fender, and no
;;; bind-required is there to have an allowance: neither is allowed.
(library (chez-sodium private native)
  (export version)
  (import (rnrs) (only (chezscheme) foreign-entry? foreign-procedure))
  (define-syntax bind-optional
    (lambda (x)
      (syntax-case x ()
        ((_ (fp convention ... entry (arg ...) result))
         (and (identifier? #'fp)
              (free-identifier=? #'fp #'foreign-procedure)
              (free-identifier=? #'fp #'foreign-procedure))
         #'(and (foreign-entry? entry)
                (fp convention ... entry (arg ...) result))))))
  (define version
    (load-step
     (bind-optional
       (foreign-procedure "sodium_version_string" () uptr)))))
