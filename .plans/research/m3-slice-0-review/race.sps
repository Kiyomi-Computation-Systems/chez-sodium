#!r6rs
;; Row 19 as the plan describes it: reference the library, fork a thread that
;; calls the "verb" (a little Scheme, then one critical section around the
;; blocking call), then the main thread runs collect-rendezvous at once, with
;; no wait for the call to be in C, and releases the FIFO. BINDING is plain
;; or collect-safe. Prints who released the call.
(import (chezscheme))
(define args (cdr (command-line)))
(define lib (car args)) (define kind (cadr args)) (define fifo (caddr args)) (define marker (cadddr args))
(load-shared-object lib)
(define plain (foreign-procedure "block_on" (uptr) int))
(define safe (foreign-procedure __collect_safe "block_on" (uptr) int))
(define binding (if (string=? kind "safe") safe plain))
(define (path-block p)
  (let* ((bv (string->utf8 p)) (n (bytevector-length bv)) (b (foreign-alloc (+ n 1))))
    (do ((i 0 (+ i 1))) ((= i n)) (foreign-set! 'unsigned-8 b i (bytevector-u8-ref bv i)))
    (foreign-set! 'unsigned-8 b n 0) b))
(define (release!) (system (string-append "exec 3<>'" fifo "'")))
;; reference once
(let ((b (path-block "/nonexistent/none"))) (plain b) (safe b) (foreign-free b))
(define b (path-block fifo))
;; the "verb": argument checks in Scheme, then one section around the call
(define (verb)
  (let loop ((i 0)) (when (< i 200) (loop (+ i 1))))
  (critical-section (binding b)))
(define done #f)
(fork-thread (lambda () (verb) (set! done #t)))
(collect-rendezvous)
(release!)
(let wait ((i 0)) (unless (or done (= i 2000)) (sleep (make-time 'time-duration 10000000 0)) (wait (+ i 1))))
(printf "~a released-by=~a\n" kind (if (file-exists? marker) 'watchdog 'collector))
