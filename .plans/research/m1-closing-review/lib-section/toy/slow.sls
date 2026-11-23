(library (toy slow)
  (export answer)
  (import (chezscheme))
  (define answer
    (critical-section
      (let loop ((i 0)) (if (< i 400000000) (loop (+ i 1)) 'ready)))))
