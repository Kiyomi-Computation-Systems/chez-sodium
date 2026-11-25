#!r6rs
;;; &sodium-failed as a caller meets it. Run with CHEZ_SODIUM_LIBRARY naming
;;; a decoy built by load.sh and CHEZ_SODIUM_DECOY naming its switch, or the
;;; real library under ulimit -v. MODE is hash or blake2b; with a third
;;; argument, uncaught, the raise reaches Chez's default handler.
(import (rnrs) (chez-sodium))

(define args (cdr (command-line)))
(define mode (car args))
(define (call)
  (cond ((string=? mode "hash") (password-hash "correct horse" (if (null? (cdr args)) 'interactive 'sensitive)))
        ((string=? mode "hash-sensitive") (password-hash "correct horse" 'sensitive))
        ((string=? mode "blake2b") (blake2b (make-bytevector 3 7)))))

(if (and (pair? (cdr args)) (string=? (cadr args) "uncaught"))
    (begin (call) (display "no raise\n"))
    (begin
      (write
       (guard (e ((sodium-failed? e)
                  (list 'sodium-failed
                        'function (sodium-failed-function e)
                        'code (sodium-failed-code e)
                        'who (condition-who e)
                        'message (condition-message e)
                        'irritants? (irritants-condition? e)
                        'chez-sodium-error? (chez-sodium-error? e)
                        'error? (error? e)
                        'assertion? (assertion-violation? e))))
         (list 'answered (call))))
      (newline)))
