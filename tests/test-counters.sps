#!r6rs
;;; The suite for (chez-sodium private counters): a count per kind of native
;;; object, behind one mutex, with no reset (ADR-0011). A count-down below
;;; zero is a double free, and raises.
;;;
;;; A test that raises a count on purpose lowers it again under
;;; dynamic-wind, and this suite exits through suite-exit-status, which
;;; fails it if any count is left. Each expected value is one the code under
;;; test cannot produce by failing: SRFI-64 makes #f of a raise in the
;;; actual expression, so none is #f, and each refusal is compared, who and
;;; irritants, against a no-raise sentinel.
(import (rnrs)
        (srfi :64)
        (only (chezscheme) fork-thread make-mutex with-mutex sleep make-time
              make-engine library-exports)
        (chez-sodium-testing)
        (chez-sodium private counters))

;; SRFI-64 sets no exit status. This suite's last line turns the runner's
;; counts into one.
(define runner (test-runner-simple))
(test-runner-current runner)

;; The simple runner names a failing test but not its values. Print both.
(let ((simple-end (test-runner-on-test-end runner)))
  (test-runner-on-test-end! runner
    (lambda (r)
      (simple-end r)
      (when (memq (test-result-kind r) (quote (fail xpass)))
        (display "  expected: ")
        (write (test-result-ref r (quote expected-value)))
        (newline)
        (display "  actual:   ")
        (write (test-result-ref r (quote actual-value)))
        (newline)))))

;; refused : (-> Any) -> (U (List 'assertion-violation Symbol (Listof Any)) (List 'other String) (List 'no-raise Any))
;; THUNK's assertion violation as its who and irritants alone, never its message.
(define (refused thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (list 'no-raise (thunk))))

(define zero-counts '((block . 0)))

;; counts-with : (Listof (Pairof Symbol Integer)) -> (Listof (Pairof Symbol Integer))
;; zero-counts, with each kind in CHANGES at its count.
(define (counts-with changes)
  (map (lambda (entry) (cond ((assq (car entry) changes) => (lambda (c) c)) (else entry)))
       zero-counts))

;; with-counts : (Listof Symbol) (-> Any) -> Any
;; THUNK's answer, with one more of each kind in KINDS counted while it runs.
(define (with-counts kinds thunk)
  (dynamic-wind
    (lambda () (for-each count-up! kinds))
    thunk
    (lambda () (for-each count-down! kinds))))

;; repeat : Natural Any -> (Listof Any)
(define (repeat n x) (if (= n 0) '() (cons x (repeat (- n 1) x))))

(define (sorted-names names)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) names))

(test-begin "counters")

(test-equal "(chez-sodium private counters) exports exactly native-kinds, count-up!, count-down! and native-counts: no reset"
  (sorted-names '(native-kinds count-up! count-down! native-counts))
  (sorted-names (library-exports '(chez-sodium private counters))))

(test-equal "native-kinds: block alone"
  '(block)
  native-kinds)

(test-equal "native-counts: every kind, in native-kinds' order, each zero at the start"
  zero-counts
  (native-counts))

(test-equal "count-up! raises the block count by one, and count-down! lowers it"
  (list (counts-with '((block . 1))) (counts-with '((block . 2))) zero-counts)
  (let* ((one (with-counts '(block) native-counts))
         (two (with-counts '(block block) native-counts)))
    (list one two (native-counts))))

(test-equal "count-up! and count-down! refuse a symbol that is no kind, as an assertion violation, and count nothing"
  (list (list 'assertion-violation 'count-up! '(not-a-kind blocks))
        (list 'assertion-violation 'count-down! '(not-a-kind blocks))
        (list 'assertion-violation 'count-up! '(not-a-kind "block"))
        (list 'assertion-violation 'count-down! '(not-a-kind blocking))
        zero-counts)
  (let* ((a (refused (lambda () (count-up! 'blocks))))
         (b (refused (lambda () (count-down! 'blocks))))
         (c (refused (lambda () (count-up! "block"))))
         (d (refused (lambda () (count-down! 'blocking)))))
    (list a b c d (native-counts))))

(test-equal "a count-down below zero, a double free, raises an assertion violation and leaves the count at zero"
  (list (list 'assertion-violation 'count-down! '(double-free block)) zero-counts
        (counts-with '((block . 1))) zero-counts)
  (let* ((result (refused (lambda () (count-down! 'block))))
         (after (native-counts))
         (up (with-counts '(block) native-counts)))
    (list result after up (native-counts))))

;; An unknown kind with a count standing at one: a count-down! that fell back
;; to some kind's slot would take that count to zero, and still raise at the
;; double free; the count held at one gives it away.
(test-equal "count-down! and count-up! of a symbol that is no kind leave every count where it stood"
  (list (list 'assertion-violation 'count-down! '(not-a-kind blocks))
        (list 'assertion-violation 'count-up! '(not-a-kind blocks))
        (counts-with '((block . 1))))
  (with-counts '(block)
    (lambda ()
      (let* ((down (refused (lambda () (count-down! 'blocks))))
             (up (refused (lambda () (count-up! 'blocks)))))
        (list down up (native-counts))))))

;; Every kind, each alone, written out here, not read from native-kinds: a
;; counter that lost a kind's index, or raised below zero for some kinds
;; only, passes a test of one or two.
(for-each
 (lambda (kind)
   (test-equal (string-append "count-up! of " (symbol->string kind)
                              " counts that kind alone, and count-down! takes it back")
     (list (counts-with (list (cons kind 1))) zero-counts)
     (let ((during (with-counts (list kind) native-counts)))
       (list during (native-counts))))
   (test-equal (string-append "count-down! of " (symbol->string kind)
                              " at zero raises, a double free, and leaves every count at zero")
     (list (list 'assertion-violation 'count-down! (list 'double-free kind)) zero-counts)
     (let ((r (refused (lambda () (count-down! kind)))))
       (list r (native-counts)))))
 '(block))

;; Several threads count one kind up, all of them, and then down, many times
;; each. Without the mutex, two threads read the same count and each writes
;; it plus one, losing one: the ups fall short, the downs reach zero early
;; and raise, or the count ends above zero.
(define thread-count 8)
(define steps 20000)

;; run-threads : (Symbol -> Void) -> (Listof Any)
;; THREAD-COUNT threads each call STEP on block STEPS times. Each thread's
;; answer is no-raise or what it raised; the wait is bounded, at 120000 steps of
;; 1 ms or more (run-until), and a thread that never answered is never-ran.
(define (run-threads step)
  (let ((mx (make-mutex)) (results (make-vector thread-count 'never-ran)))
    (do ((i 0 (+ i 1))) ((= i thread-count))
      (let ((i i))
        (fork-thread
         (lambda ()
           (let ((r (guard (e (#t (list 'raised (describe e))))
                      (do ((n 0 (+ n 1))) ((= n steps)) (step 'block))
                      'no-raise)))
             (with-mutex mx (vector-set! results i r)))))))
    ;; At most 120000 steps of 1 ms or more each. Whether it ended in time or
    ;; not, a thread that never answered stays never-ran in the answer.
    (run-until (lambda () (sleep (make-time 'time-duration 1000000 0)))
               (lambda () (with-mutex mx (not (memq 'never-ran (vector->list results)))))
               120000)
    (with-mutex mx (vector->list results))))

(test-equal "the mutex: 8 threads count block up 20000 times each, then down as often, with no raise, and the count is 160000 between and zero after"
  (list (repeat thread-count 'no-raise) (* thread-count steps)
        (repeat thread-count 'no-raise) zero-counts)
  ;; Nothing here lowers a count the ups raised and the downs did not: if a
  ;; thread raises, the count stays above zero, this row fails, and so does
  ;; the suite, which exits through suite-exit-status.
  (let* ((ups (run-threads count-up!))
         (between (cdr (assq 'block (native-counts))))
         (downs (run-threads count-down!)))
    (list ups between downs (native-counts))))

;; --- the critical section -------------------------------------------------
;; Chez's with-mutex takes the mutex in a dynamic-wind's before thunk. An
;; engine's expiry runs the after thunks of the winds it escapes, but one
;; between the take and the wind escapes none, and leaves the mutex held by
;; an engine no one resumes: every other thread's count then waits for good.
;; locked's critical section holds the expiry until the mutex is released.

;; another-thread-counts : -> (U 'counted 'never-answered (List 'raised String))
;; Whether a new thread counts block up, then down, within 5000 steps of 1 ms
;; or more (run-until).
(define (another-thread-counts)
  (let ((mx (make-mutex)) (result 'never-answered))
    (fork-thread
     (lambda ()
       (let ((r (guard (e (#t (list 'raised (describe e))))
                  (count-up! 'block)
                  (count-down! 'block)
                  'counted)))
         (with-mutex mx (set! result r)))))
    (run-until (lambda () (sleep (make-time 'time-duration 1000000 0)))
               (lambda () (with-mutex mx (not (eq? result 'never-answered))))
               5000)
    (with-mutex mx result)))

;; engine-at : Positive-Integer -> (U 'done 'expired)
;; count-up! then count-down! of block, in an engine given FUEL, and never
;; resumed once it expires.
(define (engine-at fuel)
  ((make-engine (lambda () (count-up! 'block) (count-down! 'block) 'done))
   fuel
   (lambda (left value) value)
   (lambda (resume) 'expired)))

(test-equal "the critical section: count-up! then count-down! in an engine abandoned at its expiry, at each fuel from 1 until it completes, never leave the mutex held, so another thread counts after each; and the engine expired at least once"
  (list 'never-held #t zero-counts)
  (let loop ((fuel 1) (expiries 0))
    (let ((outcome (engine-at fuel)))
      ;; An engine that expired between its two counts left a block counted.
      (when (= (cdr (assq 'block (native-counts))) 1)
        (count-down! 'block))
      (if (eq? outcome 'done)
          (list 'never-held (> expiries 0) (native-counts))
          (let ((other (another-thread-counts)))
            (if (eq? other 'counted)
                (loop (+ fuel 1) (+ expiries 1))
                (list (list 'after-fuel fuel other) (> expiries 0) (native-counts))))))))

(test-end "counters")

(exit (suite-exit-status runner))
