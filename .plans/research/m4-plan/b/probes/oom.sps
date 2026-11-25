#!r6rs
;;; Short memory, as a login meets it. Run by oom.sh, some modes under
;;; ulimit -v. The password is "correct horse".
;;;
;;;   make PRESET FILE           write a hash at PRESET to FILE
;;;   login FILE TARGET          the login pattern on FILE's hash, rehashing
;;;                              to the preset TARGET: each step's answer
;;;   fallback FILE PW CURRENT   Techo's fallback after a #f: hash a
;;;                              throwaway string at the preset CURRENT, and
;;;                              read a &sodium-failed there as short memory
(import (rnrs) (chez-sodium))

(define (params hash)
  (let loop ((i 0) (seen 0))
    (cond ((= i (string-length hash)) hash)
          ((and (char=? (string-ref hash i) #\$) (= seen 3)) (substring hash 0 (+ i 1)))
          ((char=? (string-ref hash i) #\$) (loop (+ i 1) (+ seen 1)))
          (else (loop (+ i 1) seen)))))

(define (read-hash file)
  (call-with-input-file file get-line))

(define (hashed password limits)
  (guard (e ((sodium-failed? e)
             (list 'raised 'sodium-failed (condition-who e)
                   (sodium-failed-function e) (sodium-failed-code e)))
            (#t (list 'raised 'other)))
    (list 'hashed (params (password-hash password limits)))))

(define args (cdr (command-line)))
(define mode (car args))

(define (show x) (write x) (newline))

(cond
 ((string=? mode "make")
  (let ((h (password-hash "correct horse" (string->symbol (cadr args)))))
    (call-with-output-file (caddr args) (lambda (p) (put-string p h) (newline p)))
    (show (list 'made (params h)))))
 ((string=? mode "login")
  (let* ((h (read-hash (cadr args)))
         (target (string->symbol (caddr args)))
         (ok (password-verify h "correct horse")))
    (show (list 'verify ok))
    (when ok
      (let ((stale (password-needs-rehash? h target)))
        (show (list 'needs-rehash? target stale))
        (when stale
          (show (list 'rehash (hashed "correct horse" target))))))))
 ((string=? mode "fallback")
  (let* ((h (read-hash (cadr args)))
         (pw (caddr args))
         (current (string->symbol (cadddr args)))
         (ok (password-verify h pw)))
    (show (list 'verify ok))
    (unless ok
      (let ((probe (hashed "throwaway" current)))
        (show (list 'throwaway-hash current probe))
        (show (list 'reads-as (if (eq? (car probe) 'raised) 'short-memory 'wrong-password)))))))
 (else (show '(unknown-mode))))
