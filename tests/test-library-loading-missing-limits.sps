#!r6rs
;;; One of the suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds each entry
;;; point of the password hash's five memlimits and two password-length
;;; functions left out, one at a time, and the load's order (a lacking build
;;; under a switch that an earlier step refuses). Each is bound after
;;; sodium_init, so a refusal's log is the version calls and sodium_init, and
;;; no size or constant call.
;;; tests/test-library-loading-missing.sps holds the load's five,
;;; -missing-verbs.sps the byte verbs' eight, and -missing-passwords.sps the
;;; rest.
;;;
;;; Under the memory gate each child runs under a Valgrind of its own, so
;;; the rows are split among the suites, each running at most 14 children,
;;; to keep each well under MEMORY_TIMEOUT (ADR-0011); (library-loading)
;;; holds what they all use.
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

(test-begin "library-loading-missing-limits")

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
(define builds (decoy-builds (map lacks-build limit-entries)))

(define (so-of build) (in-scratch (string-append build ".so")))

;; compiled : (Listof (Pairof String Any))
;; Every build, compiled once, in order.
(define compiled (compile-decoys so-of floor-values builds))

(define (compiled-status build) (decoy-status compiled build))

;; decoy-row : String (U String #f) (Listof String) String (String -> Expected) -> Void
;; (library-loading)'s decoy-row-in, on this suite's builds.
(define (decoy-row build switch args description expected)
  (decoy-row-in so-of compiled-status build switch args description expected))

;; --- the entries ----------------------------------------------------------------------

;; The seven are written out here, whole and in order, apart from the list
;; they are cut from: every-entry's last seven. test-library-loading-missing holds every-entry
;; whole to the convention table.
(test-equal "the entries this suite leaves out are the password hash's seven, in native's order"
  '("crypto_pwhash_memlimit_min" "crypto_pwhash_memlimit_max"
    "crypto_pwhash_memlimit_interactive" "crypto_pwhash_memlimit_moderate"
    "crypto_pwhash_memlimit_sensitive" "crypto_pwhash_passwd_min"
    "crypto_pwhash_passwd_max")
  limit-entries)

(test-equal "every build of the decoy compiled"
  (map (lambda (build) (cons (car build) 0)) builds)
  compiled)

;; --- each entry left out ---------------------------------------------------------------

(missing-api-rows decoy-row limit-entries)

;; The load's order, by behaviour: each library lacks an entry point that a
;; later step binds, and answers wrongly at an earlier step. The earlier
;; step's refusal must win, and the log must stop where it does.
(decoy-row "lacks-crypto_pwhash_passwd_max" "init-fails" '()
  "sodium_init comes before the password hash's limit functions: init-failed with its answer, not missing-api"
  (lambda (so) (refused 'init-failed so 'override -1 '() (init-calls "init-fails"))))

(decoy-row "lacks-crypto_pwhash_memlimit_min" "below-floor" '()
  "the floor comes before the password hash's limit functions: below-floor, not missing-api"
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

(test-end "library-loading-missing-limits")

(exit (suite-exit-status runner))
