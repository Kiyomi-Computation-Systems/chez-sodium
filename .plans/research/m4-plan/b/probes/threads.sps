#!r6rs
;;; While a worker thread hashes at 'sensitive, the main thread keeps
;;; allocating and calls (collect) every 10 ms: how long its longest gap and
;;; its longest collection take. The library is referenced on the main thread
;;; first (the program names it, so the load runs before the first line).
;;; Every wait is bounded: the main loop stops after 10 s.
(import (rnrs)
        (chez-sodium)
        (only (chezscheme) fork-thread make-mutex with-mutex collect
              current-time time-second time-nanosecond))

(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000.0 (time-second t)) (/ (time-nanosecond t) 1e6))))
(define (round1 x) (/ (round (* 10 x)) 10))

(define lock (make-mutex))
(define result #f)

(sodium-version)

(define t0 (now-ms))
(fork-thread
 (lambda ()
   (let ((answer (guard (e (#t (list 'raised)))
                   (let* ((a (now-ms)) (h (password-hash "correct horse" 'sensitive)) (b (now-ms)))
                     (list 'hashed (round1 (- b a)))))))
     (with-mutex lock (set! result answer)))))

(define (done) (with-mutex lock result))

(let loop ((last (now-ms)) (max-gap 0) (max-collect 0) (collects 0) (next-collect (+ (now-ms) 10)) (junk '()))
  (let ((now (now-ms)))
    (cond
     ((or (done) (> (- now t0) 10000))
      (write (list 'worker (done)
                   'main-max-gap-ms (round1 max-gap)
                   'main-max-collect-ms (round1 max-collect)
                   'collects collects))
      (newline))
     ((>= now next-collect)
      (let* ((a (now-ms)) (ignore (collect)) (b (now-ms)))
        (loop b (max max-gap (- now last)) (max max-collect (- b a)) (+ collects 1) (+ b 10) '())))
     (else
      (loop now (max max-gap (- now last)) max-collect collects next-collect
            (cons (make-vector 100 0) (if (> (length junk) 1000) '() junk)))))))
