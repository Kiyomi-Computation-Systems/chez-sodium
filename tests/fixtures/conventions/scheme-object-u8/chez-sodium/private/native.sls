#!r6rs
(library (chez-sodium private native)
  (export zero)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define zero (foreign-procedure "sodium_memzero" (u8* size_t) void)))
