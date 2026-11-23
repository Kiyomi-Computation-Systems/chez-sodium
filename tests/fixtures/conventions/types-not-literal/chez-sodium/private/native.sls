#!r6rs
(library (chez-sodium private native)
  (export a b c d e)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define a (foreign-procedure "sodium_init" argument-types int))
  (define b (foreign-procedure "sodium_library_version_major" (uptr . uptr) int))
  (define c (foreign-procedure "sodium_library_version_minor" (uptr) "uptr"))
  (define d (foreign-procedure "sodium_memzero" (7) uptr))
  (define e (foreign-procedure "sodium_version_string" #(uptr uptr) uptr)))
