#!r6rs
;;; (chez-sodium private byte-verbs): the three verbs that take and answer
;;; bytes, random-bytes, blake2b and constant-time-bytevector=? (ADR-0007,
;;; ADR-0012). It holds no foreign-procedure, no foreign memory of its own and
;;; no block of its own: native binds libsodium and makes every block, and this
;;; library reads foreign memory only through native's foreign-bytes.
;;;
;;; Each verb has the same shape (ADR-0007):
;;;
;;;   1. its arguments are checked, left to right, each one's type before its
;;;      range, and the first mistake is refused, before any block exists. A
;;;      secret is refused by its kind alone, through refuse-secret; a count
;;;      or a size, which no one holds secret, is shown by shown-value
;;;   2. its whole extent, the blocks, the copy in, the C call, the copy out
;;;      and the wipe and free, is one call-in-section, which answers data:
;;;      the bytes, or the code libsodium gave
;;;   3. what the data says is raised after the section, never inside it
;;;
;;; So a refusal is written in the verb's own definition, before its section,
;;; and the one raise a verb makes after it is blake2b's &sodium-failed. A
;;; test reads this file as data to hold each of these (tests/test-byte-verbs.sps).
;;;
;;; The blocks C writes, an output's, are made by call-with-block with a FILL!
;;; that writes nothing: C writes every byte of a success, and a failure's
;;; block is never read. The block is wiped when it is freed like any other.
;;;
;;; The sizes a verb checks against are native's, read from libsodium once at
;;; the load. None is written here.
(library (chez-sodium private byte-verbs)
  (export random-bytes blake2b constant-time-bytevector=?)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (chez-sodium private native)
          (chez-sodium private conditions)
          (chez-sodium private cap))

  ;; natural? : Any -> Boolean
  ;; Whether X is an exact integer, 0 or more.
  (define (natural? x)
    (and (integer? x) (exact? x) (>= x 0)))

  ;; leave-unwritten : Natural -> Boolean
  ;; The FILL! of an output block: C writes every byte of it.
  (define (leave-unwritten block) #f)

  ;; no-key : Any
  ;; What blake2b is given for a key when the caller gave none. No caller's
  ;; value is eq? to it, so a key of #f is still a refusal.
  (define no-key (list 'no-key))

  ;; cap-message : String
  (define cap-message
    (string-append "n is over the cap, " (number->string input-cap)))

  ;; size-message : -> String
  ;; blake2b's size refusal, with libsodium's range as native read it.
  (define (size-message)
    (string-append "size is from " (number->string generichash-bytes-min)
                   " to " (number->string generichash-bytes-max)))

  ;; random-bytes : Natural -> Bytevector
  ;; N bytes from libsodium's generator, N from 0 to the input cap. At 0 it is
  ;; the empty bytevector, and calls no C. Refused before any block: an N that
  ;; is no exact natural, from random-bytes, irritants (not-a-natural n V), and
  ;; an N over the cap, (over-the-cap n V), V by shown-value. With no source of
  ;; entropy at all the process aborts at the load, when sodium_init stirs the
  ;; generator; randombytes_buf aborts only if the source fails later.
  (define (random-bytes n)
    (unless (natural? n)
      (assertion-violation 'random-bytes "n is not an exact natural"
                           'not-a-natural 'n (shown-value n)))
    (unless (<= n input-cap)
      (assertion-violation 'random-bytes cap-message
                           'over-the-cap 'n (shown-value n)))
    (if (= n 0)
        (make-bytevector 0)
        (call-in-section
         (lambda ()
           (call-with-block 'random-bytes n leave-unwritten
             (lambda (out)
               (randombytes-buf out n)
               (foreign-bytes out n)))))))

  ;; blake2b : Bytevector [Natural] [Bytevector] -> Bytevector
  ;;   input, size, key
  ;; The BLAKE2b hash of INPUT, SIZE bytes long, keyed by KEY when given: a
  ;; fresh bytevector. SIZE runs from libsodium's least to its greatest and
  ;; defaults to its recommended size; a key runs from its shortest to its
  ;; longest, an empty one is refused, and a key needs a size. INPUT and the
  ;; key are secrets, shown by their kind alone. Refused before any block, from
  ;; blake2b, with irritants (RULE PARAMETER ...): not-a-bytevector for INPUT
  ;; and for KEY, over-the-cap for INPUT, not-a-natural and size-out-of-range
  ;; for SIZE, empty-key and key-length-out-of-range for KEY. Libsodium
  ;; answering anything but 0, which its sizes make impossible, raises a
  ;; &sodium-failed after the section, its function "crypto_generichash" and
  ;; its code the answer.
  (define blake2b
    (case-lambda
      ((input) (blake2b input generichash-bytes no-key))
      ((input size) (blake2b input size no-key))
      ((input size key)
       (unless (bytevector? input)
         (refuse-secret 'blake2b 'not-a-bytevector 'input input))
       (unless (<= (bytevector-length input) input-cap)
         (refuse-secret 'blake2b 'over-the-cap 'input input 0 input-cap))
       (unless (natural? size)
         (assertion-violation 'blake2b "size is not an exact natural"
                              'not-a-natural 'size (shown-value size)))
       (unless (and (>= size generichash-bytes-min) (<= size generichash-bytes-max))
         (assertion-violation 'blake2b (size-message)
                              'size-out-of-range 'size (shown-value size)))
       (unless (or (eq? key no-key) (bytevector? key))
         (refuse-secret 'blake2b 'not-a-bytevector 'key key))
       (unless (or (eq? key no-key) (> (bytevector-length key) 0))
         (refuse-secret 'blake2b 'empty-key 'key key
                        generichash-keybytes-min generichash-keybytes-max))
       (unless (or (eq? key no-key)
                   (and (>= (bytevector-length key) generichash-keybytes-min)
                        (<= (bytevector-length key) generichash-keybytes-max)))
         (refuse-secret 'blake2b 'key-length-out-of-range 'key key
                        generichash-keybytes-min generichash-keybytes-max))
       (let* ((key-bytes (if (eq? key no-key) (make-bytevector 0) key))
              (outcome
               (call-in-section
                (lambda ()
                  (call-with-bytes 'blake2b input
                    (lambda (in)
                      (call-with-bytes 'blake2b key-bytes
                        (lambda (key-block)
                          (call-with-block 'blake2b size leave-unwritten
                            (lambda (out)
                              (let ((code (crypto-generichash out size
                                                              in (bytevector-length input)
                                                              key-block
                                                              (bytevector-length key-bytes))))
                                (if (eqv? code 0)
                                    (cons 'hash (foreign-bytes out size))
                                    (cons 'failed code)))))))))))))
         (if (eq? (car outcome) 'hash)
             (cdr outcome)
             (raise-sodium-failed 'blake2b "crypto_generichash" (cdr outcome)))))))

  ;; constant-time-bytevector=? : Bytevector Bytevector -> Boolean
  ;; Whether A and B hold the same bytes, compared by sodium_memcmp in time
  ;; that depends on their length alone. Each is a secret, shown by its kind
  ;; alone. Refused before any block, from constant-time-bytevector=?, A's
  ;; type, A's cap, B's type, then B's cap, irritants (not-a-bytevector a (kind
  ;; K)) or (over-the-cap a (kind bytevector)), and b's likewise. Operands of
  ;; different lengths answer #f and call no C. Only 0 is #t.
  (define (constant-time-bytevector=? a b)
    (unless (bytevector? a)
      (refuse-secret 'constant-time-bytevector=? 'not-a-bytevector 'a a))
    (unless (<= (bytevector-length a) input-cap)
      (refuse-secret 'constant-time-bytevector=? 'over-the-cap 'a a 0 input-cap))
    (unless (bytevector? b)
      (refuse-secret 'constant-time-bytevector=? 'not-a-bytevector 'b b))
    (unless (<= (bytevector-length b) input-cap)
      (refuse-secret 'constant-time-bytevector=? 'over-the-cap 'b b 0 input-cap))
    (if (not (= (bytevector-length a) (bytevector-length b)))
        #f
        (let ((code (call-in-section
                     (lambda ()
                       (call-with-bytes 'constant-time-bytevector=? a
                         (lambda (a-block)
                           (call-with-bytes 'constant-time-bytevector=? b
                             (lambda (b-block)
                               (sodium-memcmp a-block b-block (bytevector-length a))))))))))
          (eqv? code 0)))))
