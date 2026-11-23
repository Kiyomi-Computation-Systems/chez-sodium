#!r6rs
;;; Read as data by tests/test-conventions.sps, never loaded. A keyword alias
;;; hides a binding: no form is headed by foreign-procedure, but the symbol
;;; is used.
(library (chez-sodium private native)
  (export sneaky-init)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define-syntax fp (identifier-syntax foreign-procedure))
  (define sneaky-init (fp "sodium_init" () int)))
