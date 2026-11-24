#!r6rs
;;; The suite for (chez-sodium), the public library, as a whole (ADR-0012).
;;;
;;;   the exports    (chez-sodium)'s, written out whole, so nothing private,
;;;                  no raw binding of native's among it, can pass through
;;;                  unseen
;;;   re-exports     src/chez-sodium.sls, read as data, is one library form
;;;                  with no body; every public name is the very procedure its
;;;                  private library defines, eq?, so referencing a condition
;;;                  predicate runs conditions' body alone and loads nothing
;;;   the version    sodium-version, whole, against (chez-sodium private
;;;                  native)'s loaded-libsodium; a fresh string at every call;
;;;                  and under an engine, at every fuel from 1 until it
;;;                  completes, where it answers right and raises nothing
;;;
;;; Reached through eval under a guard, as tests/test-native.sps reaches
;;; native, so a refused library fails rows by name. A library first reached
;;; inside an engine that is then abandoned stays wedged (ADR-0007), so the
;;; library is referenced once, before the first engine. No expected value is
;;; #f: a verdict is a symbol.
(import (rnrs)
        (rnrs eval)
        (rnrs mutable-strings)
        (srfi :64)
        (only (chezscheme) library-exports make-engine)
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
      (when (memq (test-result-kind r) '(fail xpass))
        (display "  expected: ")
        (write (test-result-ref r 'expected-value))
        (newline)
        (display "  actual:   ")
        (write (test-result-ref r 'actual-value))
        (newline)))))

;; public-load : (U 'loaded (List 'raised String))
;; The first reference to the library, before any engine. Its environment
;; call also loads the library, which library-exports needs.
(define public-load
  (guard (e (#t (list 'raised (describe e))))
    (eval '(sodium-version) (environment '(chez-sodium)))
    'loaded))

;; reach : (Listof Symbol) Symbol -> Any
;; NAME's value in LIBRARY, or a procedure that raises that it could not be
;; reached, every time it is called.
(define (reach library name)
  (guard (e (#t (lambda args (error name "could not be reached" library (describe e)))))
    (eval name (environment library))))

(define (public name) (reach '(chez-sodium) name))

(define sodium-version (public 'sodium-version))
(define loaded-libsodium (reach '(chez-sodium private native) 'loaded-libsodium))

(define zero-counts '((block . 0)))

(define (sorted-names names)
  (guard (e (#t (list 'unsortable names)))
    (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) names)))

;; attempt : (-> Any) -> Any
;; THUNK's answer; an assertion violation as (assertion-violation WHO
;; IRRITANTS), anything else raised as (raised TEXT).
(define (attempt thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'raised (describe e))))
    (thunk)))

;; --- what each name is, written out ----------------------------------------------------------

;; public-names : (Listof (Pairof Symbol (Listof Symbol)))
;; Each public name with the private library that defines it.
(define public-names
  '((sodium-version chez-sodium private native)
    (random-bytes chez-sodium private byte-verbs)
    (blake2b chez-sodium private byte-verbs)
    (constant-time-bytevector=? chez-sodium private byte-verbs)
    (password-hash chez-sodium private password-verbs)
    (password-verify chez-sodium private password-verbs)
    (password-needs-rehash? chez-sodium private password-verbs)
    (make-password-limits chez-sodium private password-verbs)
    (sodium-failed? chez-sodium private conditions)
    (sodium-failed-function chez-sodium private conditions)
    (sodium-failed-code chez-sodium private conditions)
    (chez-sodium-error? chez-sodium private conditions)
    (sodium-library-unavailable? chez-sodium private conditions)
    (sodium-library-unavailable-reason chez-sodium private conditions)
    (sodium-library-unavailable-path chez-sodium private conditions)
    (sodium-library-unavailable-source chez-sodium private conditions)
    (sodium-library-unavailable-detail chez-sodium private conditions)
    (sodium-library-unavailable-candidates chez-sodium private conditions)))

(test-begin "public")

(test-equal "(chez-sodium) loads, reached through eval"
  'loaded
  public-load)

(test-equal "(chez-sodium) exports exactly the version, the three byte verbs, the four password verbs and the condition predicates and accessors, and nothing private"
  (sorted-names (map car public-names))
  (guard (e (#t (list 'raised (describe e))))
    (sorted-names (library-exports '(chez-sodium)))))

;; --- re-exports ------------------------------------------------------------------------------

(define public-source "src/chez-sodium.sls")

;; public-data : (U (Listof Any) (List 'unreadable String))
(define public-data
  (guard (e (#t (list 'unreadable (describe e))))
    (call-with-port
     (open-file-input-port public-source (file-options) (buffer-mode block)
                           (make-transcoder (utf-8-codec)))
     (lambda (port)
       (let loop ((found '()))
         (let ((datum (read port)))
           (if (eof-object? datum) (reverse found) (loop (cons datum found)))))))))

(test-equal "src/chez-sodium.sls is one library form, (chez-sodium), with an export clause, an import clause, and no body: every name is a re-export"
  '(one-form (chez-sodium) export import no-body)
  (if (and (list? public-data) (= (length public-data) 1) (list? (car public-data))
           (>= (length (car public-data)) 4) (eq? (car (car public-data)) 'library))
      (let ((form (car public-data)))
        (list 'one-form (cadr form) (car (caddr form)) (car (cadddr form))
              (if (null? (cddddr form)) 'no-body (list 'body (cddddr form)))))
      public-data))

(test-equal "each public name is the procedure its private library defines, eq?: nothing is wrapped"
  (map (lambda (entry) (list (car entry) 'same)) public-names)
  (map (lambda (entry)
         (list (car entry)
               (guard (e (#t (list 'raised (describe e))))
                 (if (eq? (eval (car entry) (environment '(chez-sodium)))
                          (eval (car entry) (environment (cdr entry))))
                     'same
                     'different))))
       public-names))

;; --- the version -------------------------------------------------------------------------------

;; native-version : (U String (List 'no-report String))
(define native-version
  (guard (e (#t (list 'no-report (describe e))))
    (cdr (assq 'version (loaded-libsodium)))))

(test-equal "sodium-version is the version string native recorded at the load, whole"
  native-version
  (attempt sodium-version))

;; scribbled : (-> String) -> Any
;; THUNK's answer after its last answer had every character overwritten:
;; the same as before when each answer is a fresh copy.
(define (scribbled thunk)
  (attempt (lambda ()
             (let* ((first (thunk))
                    (kept (string-copy first)))
               (string-fill! first #\X)
               (let ((second (thunk)))
                 (if (equal? second kept) 'unchanged (list 'changed kept second)))))))

(test-equal "two answers of sodium-version are two strings, never the same object"
  'fresh
  (attempt (lambda ()
             (let* ((a (sodium-version)) (b (sodium-version)))
               (if (eq? a b) 'same 'fresh)))))

(test-equal "the string sodium-version answers is a fresh copy: one overwritten leaves the next answer as it was"
  'unchanged
  (scribbled sodium-version))

;; --- under an engine ---------------------------------------------------------------------------

;; run-engine : (-> Any) Positive-Integer Positive-Integer -> (U (List Any Natural) (List 'unfinished Natural))
;; THUNK run in an engine of FUEL ticks a slice, resumed each time it expires
;; until it completes: its answer and how many times it expired; or
;; (unfinished CAP) once it has expired CAP times.
(define (run-engine thunk fuel cap)
  (let loop ((engine (make-engine thunk)) (expired 0))
    (if (>= expired cap)
        (list 'unfinished cap)
        (engine fuel
                (lambda (left . answers) (list (car answers) expired))
                (lambda (next) (loop next (+ expired 1)))))))

;; version-sweep : -> (List Symbol Symbol Symbol)
;; sodium-version in an engine at each fuel from 1 until a run completes
;; without expiring, capped at 1000 fuels: whether every run answered
;; native's version and raised nothing, whether some run completed
;; unexpired, and whether some run expired. sodium-version holds no section,
;; so an expiry can fall inside it; the row asserts only that some run
;; expired. The library was referenced before the first engine.
(define (version-sweep)
  (let loop ((fuel 1) (right 'all-right) (expired-any 'never-expired))
    (if (> fuel 1000)
        (list right 'never-completed expired-any)
        (let* ((run (run-engine (lambda () (attempt sodium-version)) fuel 100000))
               (ok (and (not (eq? (car run) 'unfinished))
                        (equal? (car run) native-version)))
               (right* (if ok right (list 'wrong-at fuel run)))
               (exp* (if (and (not (eq? (car run) 'unfinished)) (> (cadr run) 0))
                         'expired expired-any)))
          (if (and (not (eq? (car run) 'unfinished)) (= (cadr run) 0))
              (list right* 'completed exp*)
              (loop (+ fuel 1) right* exp*))))))

(test-equal "sodium-version under an engine at every fuel from 1 until it completes: right every time, raising nothing, some run expired, one completed, and no block is left"
  (list '(all-right completed expired) zero-counts)
  (let* ((sweep (guard (e (#t (list 'raised (describe e)))) (version-sweep)))
         (counts (native-counts)))
    (list sweep counts)))

(test-end "public")

(exit (suite-exit-status runner))
