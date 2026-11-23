(library (chez-sodium private a) (export run) (import (rnrs) (only (chezscheme) import-only))
  (define (run) (let () (import-only (chez-sodium private target)) (hello))))
