#!r6rs
(library (chez-sodium private other)
  (export init)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define init (foreign-procedure "sodium_init" () int)))
