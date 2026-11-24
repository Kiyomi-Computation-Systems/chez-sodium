#!r6rs
;; Item 4: which argument forms does __collect_safe accept?  Each form is eval'd in a guard.
(import (chezscheme))
(load-shared-object (car (cdr (command-line))))
(define (try label form)
  (printf "~a: ~a\n" label
          (guard (e (#t (list 'refused (call-with-string-output-port (lambda (p) (display-condition e p))))))
            (let ((p (eval form))) (list 'accepted (procedure? p))))))
(try "uptr uptr unsigned-64 unsigned-64 size_t -> int"
     '(foreign-procedure __collect_safe "crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int))
(try "uptr uptr unsigned-64 -> int"
     '(foreign-procedure __collect_safe "crypto_pwhash_str_verify" (uptr uptr unsigned-64) int))
(try "(uptr) -> int" '(foreign-procedure __collect_safe "sodium_init" () int))
(try "int argument" '(foreign-procedure __collect_safe "abs" (int) int))
(try "size_t argument" '(foreign-procedure __collect_safe "strlen" (size_t) size_t))
(try "u8* argument" '(foreign-procedure __collect_safe "strlen" (u8*) size_t))
(try "string argument" '(foreign-procedure __collect_safe "strlen" (string) size_t))
(try "utf-8 argument" '(foreign-procedure __collect_safe "strlen" (utf-8) size_t))
(try "u8* inside a record-less uptr list with uptr" '(foreign-procedure __collect_safe "strlen" (uptr u8*) size_t))
(try "plain u8* (control)" '(foreign-procedure "strlen" (u8*) size_t))
(try "plain string (control)" '(foreign-procedure "strlen" (string) size_t))
(try "plain utf-8 (control)" '(foreign-procedure "strlen" (utf-8) size_t))
(try "__collect_safe, u8* result" '(foreign-procedure __collect_safe "strlen" (uptr) u8*))
(try "__collect_safe, string result" '(foreign-procedure __collect_safe "strlen" (uptr) string))
(try "__collect_safe, utf-8 result" '(foreign-procedure __collect_safe "strlen" (uptr) utf-8))
