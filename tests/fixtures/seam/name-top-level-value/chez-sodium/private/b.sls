(library (chez-sodium private b) (export run) (import (rnrs) (only (chezscheme) top-level-value))
  (define (run) ((top-level-value (quote eval)) (quote (let () (import (chez-sodium private target)) (hello))))))
