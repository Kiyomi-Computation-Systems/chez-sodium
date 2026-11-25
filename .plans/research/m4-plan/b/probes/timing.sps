#!r6rs
;;; Wall-clock times, in ms, of each verb, as the median of several runs, and
;;; the runs themselves. Plain runs, not under Valgrind.
;;;
;;;   preset P     password-hash at P, then password-verify of that hash with
;;;                the right password and with a wrong one
;;;   unknown      the dummy check of an unknown account: password-verify
;;;                against a real 'interactive hash, against strings the
;;;                pre-check refuses, and against strings that reach C and
;;;                that libsodium cannot read
;;;   cap          each byte verb at the input cap, 64 KiB, and a 64 KiB
;;;                password hashed at the least limits
(import (rnrs) (chez-sodium) (only (chezscheme) current-time time-second time-nanosecond))

(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000.0 (time-second t)) (/ (time-nanosecond t) 1e6))))

(define (ms thunk)
  (let* ((t0 (now-ms)) (v (thunk)) (t1 (now-ms)))
    (cons (- t1 t0) v)))

(define (median xs)
  (let* ((s (list-sort < xs)) (n (length s)))
    (if (odd? n)
        (list-ref s (div n 2))
        (/ (+ (list-ref s (- (div n 2) 1)) (list-ref s (div n 2))) 2))))

(define (round1 x) (/ (round (* 10 x)) 10))
(define (round3 x) (/ (round (* 1000 x)) 1000))

(define (runs n thunk)
  (let loop ((i 0) (acc '()))
    (if (= i n) (reverse acc) (loop (+ i 1) (cons (car (ms thunk)) acc)))))

(define (report label n thunk)
  (let ((xs (runs n thunk)))
    (write (list label 'median-ms (round3 (median xs)) 'runs (map round3 xs)))
    (newline)))

(define pw "correct horse")

(define (preset p n)
  (let ((h (password-hash pw p)))
    (report (list p 'hash) n (lambda () (password-hash pw p)))
    (report (list p 'verify-right) n (lambda () (password-verify h pw)))
    (report (list p 'verify-wrong) n (lambda () (password-verify h "battery staple")))))

(define mode (if (null? (cdr (command-line))) "all" (cadr (command-line))))

(when (member mode '("all" "presets"))
  (report '(least hash) 9 (lambda () (password-hash pw (make-password-limits 1 8))))
  (preset 'interactive 9)
  (preset 'moderate 7)
  (preset 'sensitive 5))

(when (member mode '("all" "unknown"))
  (let ((real (password-hash "not anyone's password" 'interactive)))
    (report '(unknown real-interactive-hash) 9 (lambda () (password-verify real pw)))
    (report '(unknown empty-string) 9 (lambda () (password-verify "" pw)))
    (report '(unknown with-a-space) 9 (lambda () (password-verify "no such user" pw)))
    (report '(unknown star) 9 (lambda () (password-verify "*" pw)))
    (report '(unknown params-no-tag) 9
            (lambda () (password-verify "$argon2id$v=19$m=65536,t=2,p=1$c29tZXNhbHQ" pw)))))

(when (member mode '("all" "cap"))
  (let ((big (make-bytevector 65536 7)) (big2 (make-bytevector 65536 7)))
    (report '(cap random-bytes-65536) 15 (lambda () (random-bytes 65536)))
    (report '(cap random-bytes-32) 15 (lambda () (random-bytes 32)))
    (report '(cap blake2b-65536) 15 (lambda () (blake2b big)))
    (report '(cap blake2b-32) 15 (lambda () (blake2b (make-bytevector 32 7))))
    (report '(cap compare-65536-equal) 15 (lambda () (constant-time-bytevector=? big big2)))
    (report '(cap password-65536-least) 9
            (lambda () (password-hash (make-string 65536 #\a) (make-password-limits 1 8))))
    (report '(cap password-13-least) 9
            (lambda () (password-hash pw (make-password-limits 1 8))))))
