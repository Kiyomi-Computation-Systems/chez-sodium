#!r6rs
;;; When a keyboard interrupt (SIGINT, as Ctrl-C sends) reaches a thread
;;; that is hashing. interrupts.sh sends it about 300 ms after this program
;;; writes its marker file. MODE is one of:
;;;
;;;   hash-P     password-hash at the preset P
;;;   verify-P   password-verify of a hash made at P, made before the marker
;;;   spin       a plain Scheme loop of about 2 s, the control
;;;
;;; It prints when the work began and ended, and when the handler ran, each
;;; in ms after the marker.
(import (rnrs) (chez-sodium)
        (only (chezscheme) current-time time-second time-nanosecond
              keyboard-interrupt-handler))

(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000.0 (time-second t)) (/ (time-nanosecond t) 1e6))))
(define (round1 x) (/ (round (* 10 x)) 10))

(define args (cdr (command-line)))
(define mode (car args))
(define marker (cadr args))

(define handled-at #f)
(define verify-hash
  (cond ((string=? mode "verify-interactive") (password-hash "correct horse" 'interactive))
        ((string=? mode "verify-sensitive") (password-hash "correct horse" 'sensitive))
        (else #f)))

(keyboard-interrupt-handler (lambda () (set! handled-at (now-ms))))

(define t0 (now-ms))
(call-with-output-file marker (lambda (p) (put-string p "ready\n")))

(define (spin ms)
  (let ((end (+ (now-ms) ms)))
    (let loop () (when (< (now-ms) end) (loop)))))

(define began (now-ms))
(cond ((string=? mode "hash-interactive") (password-hash "correct horse" 'interactive))
      ((string=? mode "hash-sensitive") (password-hash "correct horse" 'sensitive))
      ((string=? mode "verify-interactive") (password-verify verify-hash "correct horse"))
      ((string=? mode "verify-sensitive") (password-verify verify-hash "correct horse"))
      ((string=? mode "spin") (spin 2000)))
(define ended (now-ms))
;; Give a pending interrupt the chance to run, then report.
(spin 50)
(write (list mode
             'work-began (round1 (- began t0))
             'work-ended (round1 (- ended t0))
             'handler-ran (and handled-at (round1 (- handled-at t0)))))
(newline)
