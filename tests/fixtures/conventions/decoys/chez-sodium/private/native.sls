#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. It names the
;;; word foreign-procedure everywhere it is not a form, and three times where
;;; it is: (foreign-procedure "sodium_memzero" (uptr size_t) void) in this
;;; comment is no form.
(library (chez-sodium private native)
  (export init version used)
  (import (rnrs)
          (only (chezscheme) foreign-entry? foreign-procedure foreign-ref))

  (define text "(foreign-procedure \"sodium_memzero\" (uptr size_t) void)")
  (define quoted-name 'foreign-procedure)
  (define the-syntax (lambda (x) #'foreign-procedure))
  (define a-tail '(this list ends in the tail foreign-procedure))

  (define init
    (load-step
     (bind-required chosen
       (foreign-procedure "sodium_init" () int))))

  (define version
    (let ((unused 1))
      (lambda ()
        (let loop ()
          (foreign-procedure "sodium_version_string" () uptr)))))

  (define used
    '#((foreign-procedure "sodium_memzero" (uptr size_t) void))))
