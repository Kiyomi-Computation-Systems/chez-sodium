#!r6rs
;;; One of the six suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds each entry
;;; point left out, one at a time, a build with no sodium_* function, and the
;;; load's order (a lacking build under a switch that an earlier step
;;; refuses).
;;;
;;; Under the memory gate each child runs under a Valgrind of its own, so
;;; the rows are split among six suites, each running at most 14 children,
;;; to keep each well under MEMORY_TIMEOUT (ADR-0011); (library-loading)
;;; holds what all six use.
;;;
;;; Native loads libsodium in its library body, once per process, and Chez
;;; runs that body before a program's own, so a refusal cannot be caught in
;;; this process, nor a second library tried in it. Every case therefore runs
;;; a probe in a fresh Chez, through `env`, and reads back what it printed,
;;; as data, whole: exit status, every line, and stderr.
;;;
;;; Each child that reaches native code prints its counts, and every row
;;; requires them zero (ADR-0011). Each runs through gated-command, so under
;;; make test-memory the gate's own Valgrind runs it, with a log of its own
;;; that the gate reads. Every child here says whether it ran under Valgrind
;;; (memcheck's preload in /proc/self/maps), and a row requires yes exactly
;;; when the gate asked. A child that escaped the gate fails its row
;;; (ADR-0011).
;;;
;;; This process itself never loads libsodium, and requires as much at its
;;; end. Each expected value is one the code under test cannot produce by
;;; failing, and none is #f: SRFI-64 makes #f of a raise in the actual
;;; expression. Anything that can raise is computed under a guard with a
;;; sentinel. Effects run in order, through let*, named lets and for-each,
;;; never map.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (library-loading)
        (foreign-conventions)
        (only (chezscheme) file-directory? foreign-entry?))

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

(test-begin "library-loading-missing")

;; The Makefile exports CHEZ, so this suite spawns the Chez that runs it.
;; Without it nothing below can run: fail, never skip.
(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the floors ----------------------------------------------

;; scratch : (U String #f)
;; A fresh directory for the decoys. This suite is flat top-level forms, so
;; (chez-sodium-testing) removes the directory when the process ends; the
;; last forms remove it earlier, and the tests below require that.
(define scratch
  (guard (e (#t #f))
    (make-process-temp-directory)))

(test-equal "mktemp -d made a scratch directory"
  'made
  (if (and (absolute? scratch) (file-directory? scratch)) 'made 'not-made))

(unless (and (absolute? scratch) (file-directory? scratch))
  (exit 1))

(define (in-scratch name) (string-append scratch "/" name))

(define floor-values (read-floor-values))

(test-equal "packaging/floors.sexp gives the decoys their versions: the floor, and the version one patch below it"
  'read
  (if (and (= (length floor-values) 2) (string? (car floor-values))) 'read floor-values))

(unless (string? (car floor-values))
  (exit 1))

(define floor-version (car floor-values))
(define below-version (cadr floor-values))

;; builds : (Listof (Pairof String (Listof String)))
;; The builds this suite's rows use.
(define builds (decoy-builds (append (quote ("control" "not-sodium")) (map lacks-build every-entry))))

(define (so-of build) (in-scratch (string-append build ".so")))

;; compiled : (Listof (Pairof String Any))
;; Every build, compiled once, in order.
(define compiled (compile-decoys so-of floor-values builds))

(define (compiled-status build) (decoy-status compiled build))

;; decoy-row : String (U String #f) (Listof String) String (String -> Expected) -> Void
;; (library-loading)'s decoy-row-in, on this suite's builds.
(define (decoy-row build switch args description expected)
  (decoy-row-in so-of compiled-status build switch args description expected))

(define control-report (report floor-version 10 3 0))
(define (control-calls) (loaded-calls "control"))

;; --- the entries ----------------------------------------------------------------------

;; The list is written out, and an entry dropped from it takes its build and
;; its missing-api row with it. The convention table holds the bindings to
;; native, in ADR-0002's order (test-conventions), so the list is held to the
;; table's names, whole and in order, as test-conventions holds it too.
(test-equal "the decoy's entry list, every-entry, is the convention table's names, whole and in order"
  (map row-name conventions-table)
  every-entry)

(test-equal "every build of the decoy compiled"
  (map (lambda (build) (cons (car build) 0)) builds)
  compiled)

;; --- each entry left out ---------------------------------------------------------------

(missing-api-rows decoy-row every-entry)

(decoy-row "not-sodium" #f '()
  "a library with no sodium_* function is missing-api, naming sodium_version_string, the first asked"
  (lambda (so) (refused 'missing-api so 'override "sodium_version_string" '() (log-of "control"))))

;; The load's order, by behaviour. Each row's library lacks an entry point that
;; a later step binds, and answers wrongly at an earlier step: the earlier
;; step's refusal must win, and the log must stop where it does.
(decoy-row "lacks-sodium_memzero" "below-floor" '()
  "the floor comes before the rest: below-floor, not missing-api"
  (lambda (so) (refused 'below-floor so 'override below-version '()
                        (apply log-of "below-floor" version-calls))))

(decoy-row "lacks-sodium_memzero" "init-fails" '()
  "sodium_init comes before the rest: init-failed with its answer, not missing-api"
  (lambda (so) (refused 'init-failed so 'override -1 '() (loaded-calls "init-fails"))))

(decoy-row "lacks-sodium_init" "below-floor" '()
  "the floor comes before sodium_init's binding: below-floor, not missing-api"
  (lambda (so) (refused 'below-floor so 'override below-version '()
                        (apply log-of "below-floor" version-calls))))

;; --- this process ----------------------------------------------------------------------------

(test-equal "this suite's own process never loaded a libsodium, nor a decoy"
  '(not-loaded not-loaded)
  (list (if (foreign-entry? "sodium_version_string") 'loaded 'not-loaded)
        (if (foreign-entry? "decoy_calls") 'loaded 'not-loaded)))

(test-equal "the scratch directory is removed"
  '(done removed)
  (let* ((removal (guard (e (#t (list 'raised (describe e))))
                    (remove-temp-directory scratch)
                    'done))
         (left (if (file-directory? scratch) 'left 'removed)))
    (list removal left)))

(test-end "library-loading-missing")

(exit (suite-exit-status runner))
