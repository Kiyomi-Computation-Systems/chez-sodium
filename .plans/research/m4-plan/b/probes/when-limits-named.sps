(import (rnrs) (only (chez-sodium) make-password-limits))
(display "first line ran\n")
(define (later) (make-password-limits 2 16))
(display "never called it\n")
