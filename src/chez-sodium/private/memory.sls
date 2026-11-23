#!r6rs
;;; (chez-sodium private memory): counted foreign blocks (ADR-0011), and the
;;; wipe fused with the free (ADR-0008). The only library check-seam lets
;;; import foreign-alloc and foreign-free.
;;;
;;; A block is malloc'd memory, where Valgrind sees an overrun or a leak.
;;; Each one is counted as a block in (chez-sodium private counters) while it
;;; lives, and kept in a table of live blocks, behind a mutex, so that freeing
;;; an address that is not a live block, twice or never allocated here,
;;; raises before anything reaches free, and before anything is wiped.
;;;
;;; free-foreign-block! takes the wipe: the check that the block is live, the
;;; wipe, the free and the count-down are one step, in one critical section,
;;; with the table's lock held through the wipe and the free. A block that is
;;; not live is never wiped, since it may be freed already, and a write to
;;; freed memory corrupts the allocator. Memory holds no foreign-procedure: the
;;; wipe is a procedure it is given, and never loads libsodium.
;;;
;;; Each block's malloc, its entry in the table and its count happen in one
;;; critical section, and so do its wipe, removal, free and count down: an
;;; interrupt that escapes, a keyboard or timer handler that invokes a
;;; continuation, cannot fall between them and leave a block no table and no
;;; count sees, nor leave the table's mutex held.
;;;
;;; Nothing raises inside those sections. Each answers data, and the refusal
;;; it decided is raised after it: a raise inside one would reach a
;;; with-exception-handler handler with interrupts still disabled, where an
;;; engine never expires and another thread's collection waits for the
;;; handler. A raise from a call made in a section, foreign-alloc's, the
;;; wipe's or count-down!'s, is caught there and raised again, the same
;;; object, after it.
;;;
;;; A refusal names the value it refused by shown-value: a size or an address,
;;; neither a secret (ADR-0006).
(library (chez-sodium private memory)
  (export foreign-block free-foreign-block!)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (only (chezscheme) critical-section foreign-alloc foreign-free make-mutex with-mutex)
          (chez-sodium private counters)
          (chez-sodium private conditions))

  ;; The live blocks, by address, each with its size, and the mutex every
  ;; read and write holds.
  (define live (make-eqv-hashtable))
  (define lock (make-mutex))

  ;; locked : Mutex (-> Any) -> Any
  ;; THUNK's value, run holding LOCK, in a critical section. Chez's
  ;; with-mutex is a dynamic-wind whose before thunk takes the mutex, so an
  ;; interrupt that escapes between the take and the wind would leave it
  ;; held, with no after thunk to release it, and block every other thread.
  ;; Every mutex here is held through locked.
  (define (locked lock thunk)
    (critical-section (with-mutex lock (thunk))))

  ;; foreign-block : Positive-Integer -> Positive-Integer
  ;; A fresh block of SIZE bytes, uninitialised, counted: its address. An
  ;; assertion violation for a SIZE that is not a positive exact integer.
  ;; foreign-alloc never answers 0: a malloc that fails is its own
  ;; assertion violation, raised again after the section, and nothing is
  ;; counted.
  (define (foreign-block size)
    (unless (and (integer? size) (exact? size) (positive? size))
      (assertion-violation 'foreign-block "a block's size is a positive exact integer"
                           (shown-value size)))
    (let ((outcome
           (critical-section
            (let ((allocated (guard (c (#t (list 'failed c)))
                               (list 'allocated (foreign-alloc size)))))
              (when (eq? (car allocated) 'allocated)
                (locked lock (lambda () (hashtable-set! live (cadr allocated) size)))
                (count-up! 'block))
              allocated))))
      (if (eq? (car outcome) 'allocated)
          (cadr outcome)
          (raise (cadr outcome)))))

  ;; free-foreign-block! : Positive-Integer (Positive-Integer Positive-Integer -> Any) -> Void
  ;; Frees the live block at ADDRESS, after WIPE has been called with ADDRESS
  ;; and the size foreign-block recorded for it, and counts it down: one step,
  ;; in one critical section, the table's lock held throughout. An address
  ;; that is not a live block raises an assertion violation, and WIPE is never
  ;; called, nor anything freed. A WIPE that is no procedure is refused first,
  ;; before the section, and the block stays live. A WIPE that raises is
  ;; caught inside the section: the block is still freed and counted down, and
  ;; that raise, the same object, follows once the section has ended, in
  ;; preference to a count-down that finds the count at zero, which is
  ;; count-down!'s double free, raised after the free in its stead. WIPE should
  ;; not call back into this library. If it does, the table entry is gone
  ;; already, so a free of its own block is refused as not live, and that refusal is the
  ;; wipe's failure: nothing is freed twice.
  (define (free-foreign-block! address wipe)
    (unless (procedure? wipe)
      (assertion-violation 'free-foreign-block! "a wipe is a procedure" (shown-value wipe)))
    (let ((outcome
           (critical-section
            (let ((step (locked lock
                          (lambda ()
                            (let ((size (hashtable-ref live address #f)))
                              (if (not size)
                                  '(not-live)
                                  (let ((wiped (begin
                                                 (hashtable-delete! live address)
                                                 (guard (c (#t (list 'wipe-failed c)))
                                                   (wipe address size)
                                                   #f))))
                                    (foreign-free address)
                                    (or wiped '(freed)))))))))
              (if (eq? (car step) 'not-live)
                  step
                  (let ((counted (guard (c (#t (list 'double-free c)))
                                   (count-down! 'block)
                                   #f)))
                    (cond ((eq? (car step) 'wipe-failed) step)
                          (counted counted)
                          (else step))))))))
      (case (car outcome)
        ((not-live)
         (assertion-violation 'free-foreign-block! "not a live block" (shown-value address)))
        ((double-free wipe-failed) (raise (cadr outcome)))
        (else (if #f #f))))))
