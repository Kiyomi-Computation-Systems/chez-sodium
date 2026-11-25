#!r6rs
;;; Set B's section 1.2: "At the presets it is 97", computed, not printed.
;;; Each preset's hash string length, and its parameter field's.
(import (rnrs) (chez-sodium))
(for-each
 (lambda (preset)
   (let ((h (password-hash "correct horse" preset)))
     (write (list preset 'length (string-length h)))
     (newline)))
 '(interactive moderate sensitive))
