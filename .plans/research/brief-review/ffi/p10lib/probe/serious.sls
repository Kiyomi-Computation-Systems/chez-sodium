#!r6rs
;; A library whose body raises a serious condition.
(library (probe serious) (export y) (import (rnrs))
  (define y (begin (error 'serious "a serious refusal") 1)))
