#!r6rs
;; Item 2c: cost of writing 64 KiB of UTF-8 into a block, per character, in microseconds.
;; Usage: scheme --program cost2.sps REPS     (encoder copied from enc.sps)
(import (chezscheme))
;; utf8-length : String -> Natural
(define (utf8-length s)
  (let loop ((i 0) (n 0))
    (if (= i (string-length s)) n
        (let ((c (char->integer (string-ref s i))))
          (loop (+ i 1) (+ n (cond ((< c #x80) 1) ((< c #x800) 2) ((< c #x10000) 3) (else 4))))))))

;; write-utf8! : String Uptr Natural -> (U Natural 'overrun 'short)
;; Bound checked before each character's bytes. Answers the byte count written.
(define (write-utf8! s block size)
  (let ((len (string-length s)))
    (let loop ((i 0) (p 0))
      (if (= i len)
          (if (= p size) p 'short)
          (let* ((c (char->integer (string-ref s i)))
                 (w (cond ((< c #x80) 1) ((< c #x800) 2) ((< c #x10000) 3) (else 4))))
            (if (> (+ p w) size) 'overrun
                (begin
                  (case w
                    ((1) (foreign-set! 'unsigned-8 block p c))
                    ((2) (foreign-set! 'unsigned-8 block p (+ #xC0 (bitwise-arithmetic-shift-right c 6)))
                         (foreign-set! 'unsigned-8 block (+ p 1) (+ #x80 (bitwise-and c #x3F))))
                    ((3) (foreign-set! 'unsigned-8 block p (+ #xE0 (bitwise-arithmetic-shift-right c 12)))
                         (foreign-set! 'unsigned-8 block (+ p 1) (+ #x80 (bitwise-and (bitwise-arithmetic-shift-right c 6) #x3F)))
                         (foreign-set! 'unsigned-8 block (+ p 2) (+ #x80 (bitwise-and c #x3F))))
                    (else (foreign-set! 'unsigned-8 block p (+ #xF0 (bitwise-arithmetic-shift-right c 18)))
                          (foreign-set! 'unsigned-8 block (+ p 1) (+ #x80 (bitwise-and (bitwise-arithmetic-shift-right c 12) #x3F)))
                          (foreign-set! 'unsigned-8 block (+ p 2) (+ #x80 (bitwise-and (bitwise-arithmetic-shift-right c 6) #x3F)))
                          (foreign-set! 'unsigned-8 block (+ p 3) (+ #x80 (bitwise-and c #x3F)))))
                  (loop (+ i 1) (+ p w)))))))))

(define reps (string->number (cadr (command-line))))
(define (now-ns) (let ((t (current-time 'time-monotonic))) (+ (* 1000000000 (time-second t)) (time-nanosecond t))))
(define (measure label thunk)
  (thunk)
  (let ((t0 (now-ns)))
    (do ((i 0 (+ i 1))) ((= i reps)) (thunk))
    (printf "~a ~a\n" label (/ (round (* 1000 (/ (- (now-ns) t0) reps 1000.0))) 1000.0))))
(define ascii (make-string 65536 #\a))
(define euro (make-string 21845 (integer->char #x20AC)))
(define buf (foreign-alloc 65536))
(define (run s) (let ((n (utf8-length s))) (critical-section (let ((r (write-utf8! s buf n))) (if (not (eqv? r n)) (error 'cost2 r))))))
(measure "utf8-ascii-65536-chars" (lambda () (run ascii)))
(measure "utf8-euro-21845-chars" (lambda () (run euro)))
(foreign-free buf)
