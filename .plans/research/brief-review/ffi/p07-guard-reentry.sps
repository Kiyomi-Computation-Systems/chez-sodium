#!r6rs
;; Probe (reproduces chez-sqlite3 traps.md:68): a raise inside call-with-block's
;; PROC, under a caller's guard whose clauses do not match, re-enters the
;; extent, and call-with-block's re-entry refusal replaces the condition.
;; So a verb that raises &sodium-failed from inside PROC hands a caller who
;; guards for some other condition an assertion violation instead.
;; Usage: scheme --script p07-guard-reentry.sps
(import (chezscheme))
(define (call-with-block who proc)
  (let ((freed #f))
    (dynamic-wind
      (lambda () (when freed (assertion-violation who "re-entered after its block was freed")))
      (lambda () (dynamic-wind #t (lambda () #f) proc (lambda () (set! freed #t))))
      (lambda () #f))))
(define-condition-type &sodium-failed &error make-sodium-failed sodium-failed?)
(define caught
  (guard (e (#t (if (sodium-failed? e) 'sodium-failed (list 'other (condition-message e)))))
    (guard (e ((string? e) 'a-string))
      (call-with-block 'password-hash
        (lambda () (raise (condition (make-sodium-failed) (make-message-condition "pwhash -1"))))))))
(printf "the outer guard caught: ~s\n" caught)
