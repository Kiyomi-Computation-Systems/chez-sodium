#!r6rs
(library (chez-sodium private native)
  (export zero)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define zero (foreign-procedure (__varargs_after 2) "sodium_memzero" (uptr size_t) void)))
