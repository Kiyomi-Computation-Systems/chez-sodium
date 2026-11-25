#!r6rs
;;; The load runs once per process. A refusal is kept: setting
;;; CHEZ_SODIUM_LIBRARY to a good library afterwards changes nothing. GOOD is
;;; the path to set, the first argument.
(import (rnrs) (rnrs eval) (chez-sodium) (only (chezscheme) putenv))

(define (attempt)
  (guard (e ((sodium-library-unavailable? e) e))
    (eval '(sodium-version) (environment '(chez-sodium)))))

(define first (attempt))
(putenv "CHEZ_SODIUM_LIBRARY" (cadr (command-line)))
(define second (attempt))
(write (list 'first (if (condition? first) (sodium-library-unavailable-reason first) first)
             'after-putenv (if (condition? second) (sodium-library-unavailable-reason second) second)
             'same-condition (eq? first second)))
(newline)
