#!r6rs
(library (chez-sodium private native)
  (export buf)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define buf (foreign-procedure "randombytes_buf" (uptr size_t) void)))
