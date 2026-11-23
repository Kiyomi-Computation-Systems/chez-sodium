#!r6rs
(library (chez-sodium private native)
  (export a)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define a (foreign-procedure "sodium_init" () int))
