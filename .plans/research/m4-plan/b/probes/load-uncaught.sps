#!r6rs
;;; A program that names a verb directly, inside a guard for the refusal. The
;;; load runs before the program's first line, so the guard is not yet in
;;; place: a refusal reaches Chez's default handler.
(import (rnrs) (chez-sodium))

(display "first line ran\n")
(display
 (guard (e ((sodium-library-unavailable? e) "caught by the guard"))
   (sodium-version)))
(newline)
