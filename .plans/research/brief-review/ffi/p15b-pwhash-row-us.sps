#!r6rs
;; Probe: the brief's section-8 collect-safe row run against the real
;; crypto_pwhash_str, bound PLAIN (the mutant) and __collect_safe. A worker
;; hashes at a limit that takes about a second; once it is about to call, and
;; 200 ms later, this thread runs collect-rendezvous. Two judges:
;;   order : the collection ended before the verb returned (the brief's
;;           wording), the verb's end read after it copies the 128-byte
;;           string out, as a verb does
;;   bound : the collection took under a quarter of the hash's time
;; Variant of p15 with a microsecond clock and a live heap of about 40 MB,
;; so the collection takes longer than the verb's copy-out.
;; Usage: scheme --program p15b-pwhash-row-us.sps /path/libsodium.so.23
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define init (foreign-procedure "sodium_init" () int))
(define pw-plain (foreign-procedure "crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int))
(define pw-safe (foreign-procedure __collect_safe "crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int))
(init)
(define live (let loop ((i 0) (acc (quote ()))) (if (= i 400000) acc (loop (+ i 1) (cons (make-bytevector 100 (mod i 256)) acc)))))
(define (now-ms)
  (let ((t (current-time 'time-monotonic)))
    (+ (* 1000000 (time-second t)) (quotient (time-nanosecond t) 1000))))
(define (verb pw)
  ;; a password-hash's shape: copy in, call, copy the answer out, free
  (let ((out (foreign-alloc 128)) (in (foreign-alloc 8)))
    (do ((i 0 (+ i 1))) ((= i 8)) (foreign-set! 'unsigned-8 in i 65))
    (let ((rc (pw out in 8 3 (* 256 1024 1024))))
      (let ((bytes (let loop ((i 0) (acc '()))
                     (let ((b (foreign-ref 'unsigned-8 out i)))
                       (if (= b 0) (u8-list->bytevector (reverse acc)) (loop (+ i 1) (cons b acc)))))))
        (foreign-free out) (foreign-free in)
        (list rc (bytevector-length bytes))))))
(define (trial name pw)
  (let* ((m (make-mutex)) (c (make-condition)) (calling #f) (t0 #f) (t-end #f) (done #f))
    (fork-thread
     (lambda ()
       (with-mutex m (set! calling #t) (set! t0 (now-ms)) (condition-signal c))
       (verb pw)
       (set! t-end (now-ms))
       (with-mutex m (set! done #t) (condition-signal c))))
    (with-mutex m (let loop () (unless calling (condition-wait c m) (loop))))
    (sleep (make-time 'time-duration 200000000 0))
    (let* ((c0 (now-ms)) (_ (collect-rendezvous)) (c1 (now-ms)))
      (with-mutex m (let loop () (unless done (condition-wait c m) (loop))))
      (let ((hash-ms (- t-end t0)))
        (printf "~a: hash ~s us, collect ~s us; order judge: ~a; bound judge: ~a\n"
                name hash-ms (- c1 c0)
                (if (< c1 t-end) 'pass 'fail)
                (if (< (- c1 c0) (quotient hash-ms 4)) 'pass 'fail))))))
(trial "plain (mutant)" pw-plain)
(trial "plain (mutant)" pw-plain)
(trial "collect-safe" pw-safe)
(trial "plain (mutant)" pw-plain)
(trial "plain (mutant)" pw-plain)
(trial "plain (mutant)" pw-plain)
(display (length live)) (newline)
