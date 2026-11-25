#!r6rs
;;; What verifying a stored hash costs is set by the limits written in the
;;; string, not by the caller's. A real 'interactive hash, its parameter field
;;; edited, verified with the right password: the answer is #f, and the time,
;;; in ms, is the edited limits'.
(import (rnrs) (chez-sodium) (only (chezscheme) current-time time-second time-nanosecond))

(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000.0 (time-second t)) (/ (time-nanosecond t) 1e6))))

(define (replace-params hash new)
  ;; "$argon2id$v=19$" PARAMS "$" SALT "$" TAG
  (let loop ((i 0) (seen 0) (start #f))
    (cond ((char=? (string-ref hash i) #\$)
           (cond ((= seen 2) (loop (+ i 1) 3 (+ i 1)))
                 ((= seen 3) (string-append (substring hash 0 start) new (substring hash i (string-length hash))))
                 (else (loop (+ i 1) (+ seen 1) start))))
          (else (loop (+ i 1) seen start)))))

(define pw "correct horse")
(define h (password-hash pw 'interactive))

(for-each
 (lambda (params)
   (let* ((tampered (replace-params h params))
          (t0 (now-ms))
          (answer (password-verify tampered pw))
          (t1 (now-ms)))
     (write (list params 'verify answer 'ms (/ (round (* 10 (- t1 t0))) 10)))
     (newline)))
 '("m=65536,t=2,p=1" "m=65536,t=20,p=1" "m=262144,t=3,p=1" "m=1048576,t=4,p=1"))
