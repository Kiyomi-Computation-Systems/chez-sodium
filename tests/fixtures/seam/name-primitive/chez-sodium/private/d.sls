(library (chez-sodium private d) (export run) (import (rnrs) (only (chezscheme) $primitive))
  (define (run) (($primitive eval) (quote (let () (import (chez-sodium private target)) (hello))))))
