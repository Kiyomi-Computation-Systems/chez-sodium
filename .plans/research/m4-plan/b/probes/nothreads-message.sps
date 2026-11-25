#!r6rs
;;; What a user sees on a Chez built --nothreads, short of building one: the
;;; refusal's source, read as data, renamed, with each (threaded?) answering
;;; #f, as tests/test-require-threaded.sps does, evaluated, and its condition
;;; printed as Chez's default handler prints one.
(import (rnrs) (only (chezscheme) eval interaction-environment display-condition))

(define source
  (call-with-input-file "src/chez-sodium/private/require-threaded.sls"
    (lambda (p) (read p))))   ; read skips the #!r6rs

(define (as-nonthreaded x)
  (cond ((equal? x '(threaded?)) #f)
        ((pair? x) (cons (as-nonthreaded (car x)) (as-nonthreaded (cdr x))))
        (else x)))

(define renamed
  (let ((l (as-nonthreaded source)))
    (cons 'library (cons '(m4-probe nothreads) (cddr l)))))

(guard (e (#t
              (display-condition e)   ; prints "Exception in WHO: ..." itself
              (newline)
              (write (list 'syntax-violation? (syntax-violation? e)
                           'who (and (who-condition? e) (condition-who e))))
              (newline)))
  (eval renamed (interaction-environment))
  (display "no refusal\n"))
