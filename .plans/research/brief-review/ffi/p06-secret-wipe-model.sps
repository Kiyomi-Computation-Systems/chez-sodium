#!r6rs
;; Probe: where can call-with-secret-bytes wipe its block so that the wipe
;; comes before the free on every path, an engine's expiry included?
;; call-with-block below is chez-sqlite3's (native.sls:321-364) with the
;; block's making and freeing replaced by a record of events, so the order of
;; wipe and free can be read. Three designs:
;;   outer : a dynamic-wind around call-with-block whose after thunk wipes
;;           (what "wraps call-with-bytes ... on the way out" reads as)
;;   inner : PROC wraps its use of the block in a dynamic-wind whose plain
;;           after thunk wipes
;;   fused : the wipe inside call-with-block's own critical after thunk,
;;           just before the free
;; Each is run under an engine at every fuel from 1 until it completes, each
;; remainder resumed once, and every run's events are judged: a free with no
;; wipe before it, or a wipe after the free, is a fault.
;; Usage: scheme --script p06-secret-wipe-model.sps
(import (chezscheme))

(define events '())
(define (note! e) (set! events (cons e events)))

;; A stand-in for the work an after thunk does before its wipe call: the
;; wrapper reading its block's size, a check, a call.
(define (some-work) (let loop ((i 0)) (when (< i 20) (loop (+ i 1)))))

(define (call-with-block who size fill! proc wipe-in-section?)
  (let ((block #f) (freed #f) (make-failure #f) (free-failure #f))
    (dynamic-wind
      (lambda () (when freed (assertion-violation who "re-entered after its block was freed")))
      (lambda ()
        (dynamic-wind #t
          (lambda () (set! block 'B) (note! 'made))
          (lambda () (fill! block) (proc block))
          (lambda ()
            (set! freed #t)
            (when block
              (when wipe-in-section? (note! 'wiped))
              (note! 'freed)
              (set! block #f)))))
      (lambda () #f))))

(define (use-block b) (some-work) (note! 'used) 'answer)

(define designs
  (list
   (cons 'outer
         (lambda ()
           (dynamic-wind (lambda () #f)
             (lambda () (call-with-block 'v 16 (lambda (b) #f) use-block #f))
             (lambda () (some-work) (note! 'wiped)))))
   (cons 'inner
         (lambda ()
           (call-with-block 'v 16 (lambda (b) #f)
             (lambda (b)
               (dynamic-wind (lambda () #f)
                 (lambda () (use-block b))
                 (lambda () (some-work) (note! 'wiped))))
             #f)))
   (cons 'fused
         (lambda () (call-with-block 'v 16 (lambda (b) #f) use-block #t)))))

;; judge : (Listof Symbol) -> Symbol, events oldest first
(define (judge evs)
  (let ((made (memq 'made evs)))
    (cond ((not made) 'nothing-made)
          (else
           (let* ((after-made (cdr made))
                  (f (memq 'freed after-made))
                  (w (memq 'wiped after-made)))
             (cond ((not f) 'never-freed)
                   ((not w) 'freed-never-wiped)
                   ((> (length w) (length f)) 'wiped-before-free)
                   (else 'wiped-after-free)))))))

(define (run-under-engine thunk fuel)
  ;; one run to its expiry, then the remainder resumed once to its end
  (set! events '())
  (let* ((first ((make-engine thunk) fuel
                 (lambda (left . vals) (list 'completed))
                 (lambda (rest) rest)))
         (second (if (procedure? first)
                     (guard (e (#t (list 'resume-raised (condition-message e))))
                       (first 1000000 (lambda (left . vals) 'resumed-completed)
                              (lambda (rest) 'expired-again)))
                     'no-remainder)))
    (list (judge (reverse events)) first second)))

(for-each
 (lambda (d)
   (let loop ((fuel 1) (tally '()))
     (let* ((r (run-under-engine (cdr d) fuel))
            (verdict (car r))
            (tally (let ((p (assq verdict tally)))
                     (if p (begin (set-cdr! p (+ (cdr p) 1)) tally) (cons (cons verdict 1) tally)))))
       (if (and (pair? (cadr r)) (eq? (car (cadr r)) 'completed))
           (printf "~a: fuels 1..~a, verdicts ~s\n" (car d) fuel tally)
           (loop (+ fuel 1) tally)))))
 designs)
