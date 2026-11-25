#!r6rs
;;; Which libsodium (chez-sodium) loads, or why it refuses one, as a user's
;;; program reads it: the load is reached through eval, inside a guard, so
;;; the program itself names only the conditions' predicates and accessors,
;;; which load nothing. It reaches the load twice, to show that a refusal is
;;; remembered: the second raise is the same condition.
(import (rnrs) (rnrs eval) (chez-sodium))

(define (attempt)
  (guard (e ((sodium-library-unavailable? e) e)
            (#t (list 'other-raise (if (message-condition? e) (condition-message e) e))))
    (eval '(list 'loaded (sodium-version)) (environment '(rnrs) '(chez-sodium)))))

(define first (attempt))
(define second (attempt))

(define (show x) (write x) (newline))

(if (sodium-library-unavailable? first)
    (begin
      (show (list 'refused
                  'reason (sodium-library-unavailable-reason first)
                  'path (sodium-library-unavailable-path first)
                  'source (sodium-library-unavailable-source first)
                  'detail (sodium-library-unavailable-detail first)
                  'candidates (sodium-library-unavailable-candidates first)))
      (show (list 'who (condition-who first)
                  'chez-sodium-error? (chez-sodium-error? first)
                  'serious? (serious-condition? first)))
      (show (list 'message (condition-message first)))
      (show (list 'irritants (condition-irritants first)))
      (show (list 'second-raise-is-the-same-condition (eq? first second))))
    (show (list first 'again second)))
