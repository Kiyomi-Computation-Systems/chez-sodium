#!r6rs
;; Probe (re-checks chez-sqlite3's load-state rule on Chez 10.4.0): a library
;; body that raised a non-serious object wedges at the next reference; one
;; that raised a serious condition runs again at each reference.
;; Usage: scheme --libdirs p10lib --script p10-load-state.sps
(import (chezscheme))
(define (ref expr)
  (guard (e (#t (if (condition? e) (list 'condition (condition-message e)) (list 'raised e))))
    (eval expr (environment '(rnrs) '(only (probe nonserious) x) '(only (probe serious) y)))))
(define (ref1 sym lib)
  (guard (e (#t (if (condition? e) (list 'condition (condition-message e)) (list 'raised e))))
    (eval sym (environment '(rnrs) lib))))
(printf "non-serious, 1st: ~s\n" (ref1 'x '(probe nonserious)))
(printf "non-serious, 2nd: ~s\n" (ref1 'x '(probe nonserious)))
(printf "serious, 1st: ~s\n" (ref1 'y '(probe serious)))
(printf "serious, 2nd: ~s\n" (ref1 'y '(probe serious)))
