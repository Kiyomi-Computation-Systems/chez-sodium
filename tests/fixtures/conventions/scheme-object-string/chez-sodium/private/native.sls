#!r6rs
(library (chez-sodium private native)
  (export version)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define version (foreign-procedure "sodium_version_string" () string)))
