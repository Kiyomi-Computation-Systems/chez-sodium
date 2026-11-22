#!r6rs
;; Probe: the brief's collect-safe row, "the collection ends before the hash
;; returns", judged by comparing two clock readings. With a PLAIN binding,
;; does the verdict depend on what the hashing thread does between C's return
;; and its own clock read? Here the thread runs a short loop first (as a
;; wrapper's after thunk, a copy-out of the result, or a guard would).
;; Usage: scheme --script p04-order-race.sps ./libblock.so
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define plain (foreign-procedure "block_ms" (int) void))
(define safe (foreign-procedure __collect_safe "block_ms" (int) void))
(define (now-us)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000000 (time-second t)) (quotient (time-nanosecond t) 1000))))
(define (busy n) (let loop ((i 0) (acc '())) (if (= i n) (length acc) (loop (+ i 1) (cons i acc)))))
(define (trial name call work)
  (let* ((m (make-mutex)) (c (make-condition))
         (started #f) (t-start #f) (t-end #f) (done #f))
    (fork-thread
     (lambda ()
       (with-mutex m (set! started #t) (condition-signal c))
       (set! t-start (now-us))
       (call 500)
       (work)
       (set! t-end (now-us))
       (with-mutex m (set! done #t) (condition-signal c))))
    (with-mutex m (let loop () (unless started (condition-wait c m) (loop))))
    (safe 100)
    (let* ((c0 (now-us)) (_ (collect-rendezvous)) (c1 (now-us)))
      (with-mutex m (let loop () (unless done (condition-wait c m) (loop))))
      (printf "~a: collection ended before the call's end, by the clock? ~s (collect ~s us; collect end - call end ~s us)\n"
              name (< c1 t-end) (- c1 c0) (- c1 t-end)))))
(trial "plain, clock read at once" plain (lambda () #t))
(trial "plain, 200k-cell loop before the clock read" plain (lambda () (busy 200000)))
(trial "plain, 2M-cell loop before the clock read" plain (lambda () (busy 2000000)))
(trial "collect-safe, 2M-cell loop" safe (lambda () (busy 2000000)))
