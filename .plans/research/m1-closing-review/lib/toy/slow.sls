(library (toy slow)
  (export answer)
  (import (chezscheme))
  (define answer
    (begin (sleep (make-time 'time-duration 0 1)) 'ready)))
