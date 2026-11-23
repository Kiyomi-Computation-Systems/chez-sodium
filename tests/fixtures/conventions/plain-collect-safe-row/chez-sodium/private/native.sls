#!r6rs
(library (chez-sodium private native)
  (export init)
  (import (rnrs) (only (chezscheme) foreign-procedure))
  (define init
    (load-step
     (bind-required chosen
       (foreign-procedure "sodium_init" () int)))))
