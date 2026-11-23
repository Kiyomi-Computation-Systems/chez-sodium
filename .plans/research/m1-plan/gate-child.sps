#!r6rs
;; Under Valgrind, does a child started through /bin/sh with LD_PRELOAD set
;; to the free() interposer run outside Valgrind, with only that preload?
;; Usage: valgrind scheme --script gate-child.sps INTERPOSER
(import (chezscheme))
(define interposer (cadr (command-line)))
(define parent-maps
  (call-with-port (open-input-file "/proc/self/maps") get-string-all))
(define (holds? text word)
  (let ((n (string-length text)) (m (string-length word)))
    (let loop ((i 0)) (and (<= (+ i m) n) (or (string=? (substring text i (+ i m)) word) (loop (+ i 1)))))))
(printf "parent under memcheck: ~s\n" (holds? parent-maps "vgpreload_memcheck"))
(printf "parent LD_PRELOAD: ~s\n" (getenv "LD_PRELOAD"))
(system (string-append "env LD_PRELOAD=" interposer " sh -c 'echo child LD_PRELOAD=$LD_PRELOAD; grep -c vgpreload_memcheck /proc/self/maps; grep -c libfreewatch /proc/self/maps'"))
(system (string-append "LD_PRELOAD=" interposer " " (getenv "CHEZ") " --script p05-freewatch.sps " interposer))
