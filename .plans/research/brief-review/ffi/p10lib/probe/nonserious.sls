#!r6rs
;; A library whose body raises a non-serious object (a symbol).
(library (probe nonserious) (export x) (import (rnrs))
  (define x (begin (raise 'not-serious) 1)))
