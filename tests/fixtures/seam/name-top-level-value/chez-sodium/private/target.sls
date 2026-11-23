(library (chez-sodium private target) (export hello) (import (rnrs))
  (define (hello) (quote reached-target)))
