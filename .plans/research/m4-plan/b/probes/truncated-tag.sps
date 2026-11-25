#!r6rs
;;; How often a hash with its last character dropped reads as current: 400
;;; random hashes at (make-password-limits 1 8). Run through both.sh.
(import (chezscheme) (chez-sodium))
(define L (make-password-limits 1 8))
(define counts (make-eq-hashtable))
(do ((i 0 (+ i 1))) ((= i 400))
  (let* ((h (password-hash "correct horse" L))
         (d (substring h 0 (- (string-length h) 1)))
         (k (list (password-verify d "correct horse") (password-needs-rehash? d L))))
    (hashtable-update! counts (if (cadr k) 'rehash-t 'rehash-f) (lambda (n) (+ n 1)) 0)))
(write (list (hashtable-ref counts 'rehash-t 0) (hashtable-ref counts 'rehash-f 0))) (newline)
