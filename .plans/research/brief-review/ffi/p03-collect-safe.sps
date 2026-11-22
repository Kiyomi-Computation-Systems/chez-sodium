#!r6rs
;; Probe: does another thread's (collect) wait for a plain blocking call, and
;; not for a __collect_safe one, and does a critical section around the
;; collect-safe call change that? Also: the race in "the collection ends
;; before the hash returns" when the hash's end is read in Scheme.
;; Usage: scheme --script p03-collect-safe.sps ./libblock.so
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define plain (foreign-procedure "block_ms" (int) void))
(define safe (foreign-procedure __collect_safe "block_ms" (int) void))
(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000 (time-second t)) (quotient (time-nanosecond t) 1000000))))
(define (trial name call wrap)
  (let* ((m (make-mutex)) (c (make-condition))
         (started #f) (t-start #f) (t-end #f) (done #f))
    (fork-thread
     (lambda ()
       (with-mutex m (set! started #t) (condition-signal c))
       (set! t-start (now-ms))
       (wrap (lambda () (call 1000)))
       (set! t-end (now-ms))
       (with-mutex m (set! done #t) (condition-signal c))))
    (with-mutex m (let loop () (unless started (condition-wait c m) (loop))))
    (plain 0)
    ;; give the thread time to enter C
    ((foreign-procedure "block_ms" (int) void) 0)
    (let wait () (when (< (- (now-ms) (or t-start (now-ms))) 100) (safe 10) (wait)))
    (let* ((c0 (now-ms)) (_ (collect-rendezvous)) (c1 (now-ms)))
      (with-mutex m (let loop () (unless done (condition-wait c m) (loop))))
      (printf "~a: collect took ~s ms; collect ended ~s ms after call start; call (Scheme-read end) ended ~s ms after start; collect-end before call-end? ~s\n"
              name (- c1 c0) (- c1 t-start) (- t-end t-start) (< c1 t-end)))))
(define (bare thunk) (thunk))
(define (in-section thunk) (critical-section (thunk)))
(trial "plain" plain bare)
(trial "plain" plain bare)
(trial "plain" plain bare)
(trial "collect-safe" safe bare)
(trial "collect-safe in critical-section" safe in-section)
(trial "plain in critical-section" plain in-section)
;; And (collect) itself, with a second thread alive:
(printf "(collect) with another thread active: ~s\n"
        (let ((m (make-mutex)) (c (make-condition)) (go #f))
          (fork-thread (lambda () (with-mutex m (let loop () (unless go (condition-wait c m) (loop))))))
          (let ((r (guard (e (#t (list 'raised (condition-message e)))) (collect) 'collected)))
            (with-mutex m (set! go #t) (condition-broadcast c))
            r)))
