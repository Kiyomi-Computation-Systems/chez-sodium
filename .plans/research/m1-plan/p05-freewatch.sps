#!r6rs
;; Probe: can a C oracle preloaded into the test process see whether a block
;; Chez's foreign-free frees was zeroed first, with no hook in the library?
;; Usage: LD_PRELOAD=$PWD/libfreewatch.so scheme --script p05-freewatch.sps $PWD/libfreewatch.so
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define watch-set (foreign-procedure "watch_set" (uptr size_t) void))
(define watch-verdict (foreign-procedure "watch_verdict" () int))
(define (trial zero?)
  (let ((b (foreign-alloc 32)))
    (do ((i 0 (+ i 1))) ((= i 32)) (foreign-set! 'unsigned-8 b i (if zero? 0 #x41)))
    (watch-set b 32)
    (foreign-free b)
    (watch-verdict)))
(printf "verdict, block of 'A's freed: ~s (2 = non-zero seen)\n" (trial #f))
(printf "verdict, zeroed block freed:  ~s (1 = all zero seen)\n" (trial #t))
