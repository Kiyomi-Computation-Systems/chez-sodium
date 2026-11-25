#!r6rs
;; docs/passwords.md says a password another thread changes while a verb
;; reads it is refused, as changed-during-call, "and never answered
;; wrongly". The writer checks only each character's width against the count
;; taken before the section. Here a second thread rewrites an ASCII password
;; with other ASCII characters, one width for another of the same width,
;; while password-hash reads it. Each trial prints (OUTCOME VERIFIES-ALL-A
;; VERIFIES-ALL-B): a hash that verifies against neither string was made from
;; a password nobody chose, and nothing was refused. Given the argument
;; wide, the thread writes U+00E9, two bytes, instead of b: the control,
;; which the writer sees.
(import (rnrs) (rnrs mutable-strings) (chez-sodium)
        (only (chezscheme) fork-thread make-mutex with-mutex box unbox set-box!))

(define n 60000)
(define cheap (make-password-limits 1 8))
(define all-a (make-string n #\a))
(define other (if (member "wide" (command-line)) (integer->char #xE9) #\b))
(define all-b (make-string n other))

(define (trial)
  (let ((p (make-string n #\a))
        (stop (box #f))
        (done (box #f))
        (m (make-mutex)))
    (fork-thread
     (lambda ()
       (guard (e (#t #f))
         (let loop ((c other))
           (unless (unbox stop)
             (let fill ((i 0))
               (when (< i n) (string-set! p i c) (fill (+ i 1))))
             (loop (if (char=? c #\a) other #\a)))))
       (with-mutex m (set-box! done #t))))
    (let ((outcome (guard (e ((assertion-violation? e)
                              (list 'refused (car (condition-irritants e)))))
                     (list 'hash (password-hash p cheap)))))
      (set-box! stop #t)
      (let wait ((k 0))
        (unless (or (with-mutex m (unbox done)) (> k 100000000)) (wait (+ k 1))))
      (if (eq? (car outcome) 'hash)
          (list 'answered
                (password-verify (cadr outcome) all-a)
                (password-verify (cadr outcome) all-b))
          outcome))))

(let loop ((k 0))
  (when (< k 10)
    (write (trial))
    (newline)
    (loop (+ k 1))))
