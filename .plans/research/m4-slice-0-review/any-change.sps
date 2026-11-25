#!r6rs
;;; Plan section 3: "Any change ... makes it verify #f for ever." Every
;;; single-character substitution of one real hash at (make-password-limits 1 8),
;;; at every position, by every printable ASCII character but a space: how
;;; many verify #t with the right password, and where.
(import (rnrs) (rnrs mutable-strings) (chez-sodium))

(define limits (make-password-limits 1 8))
(define password "correct horse")
(define hash (password-hash password limits))
(define n (string-length hash))
(define tried 0)
(define verified '())
(let loop ((i 0))
  (when (< i n)
    (let next ((c 33))
      (when (<= c 126)
        (let ((ch (integer->char c)))
          (unless (char=? ch (string-ref hash i))
            (let ((h (string-copy hash)))
              (string-set! h i ch)
              (set! tried (+ tried 1))
              (when (password-verify h password)
                (set! verified (cons (list i ch) verified))))))
        (next (+ c 1))))
    (loop (+ i 1))))
(write (list 'length n 'substitutions tried 'verified-true (length verified) (reverse verified)))
(newline)
