#!r6rs
(library (chez-sodium private native)
  (export c)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define c (foreign-procedure "sodium_init" () int)))
