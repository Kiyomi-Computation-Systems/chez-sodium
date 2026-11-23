#!r6rs
;;; One of the six suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds the decoy's
;;; behaviours, one switch a row, on the control build.
;;; tests/test-library-loading-missing.sps holds a lacking build under a
;;; switch, and tests/test-library-loading-combined.sps the kept refusal.
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
        (libsodium-oracle)
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

(test-begin "library-loading-decoys")

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
(define builds (decoy-builds (quote ("control"))))

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

;; Every compile here, the decoys', runs $CC's words.
(test-equal "CC is cut at whitespace, so CC='ccache gcc' runs ccache, with gcc as its argument"
  '(("ccache" "gcc") ("gcc" "-m64") ("cc") ("cc"))
  (let* ((a (c-compiler (lambda (name) (and (string=? name "CC") " ccache\tgcc "))))
         (b (c-compiler (lambda (name) (and (string=? name "CC") "gcc -m64"))))
         (c (c-compiler (lambda (name) (and (string=? name "CC") "  "))))
         (d (c-compiler (lambda (name) #f))))
    (list a b c d)))

;; --- decoys --------------------------------------------------------------------------
;; The call log holds the load's order by behaviour: the three version
;; entries, the floor, sodium_init, each refused before the next runs.

;; below : String -> Expected
;; A refusal below the floor: detail DETAIL, and no call after the three.
(define (below detail switch)
  (lambda (so)
    (refused 'below-floor so 'override detail '() (apply log-of switch version-calls))))

(decoy-row "control" #f '()
  "the floor itself is accepted: the report's four fields, and the load's calls in order"
  (lambda (so) (loaded so 'override control-report (control-calls))))

(decoy-row "control" "below-floor" '()
  "one patch below the floor is below-floor, detail its version, and sodium_init never runs"
  (below below-version "below-floor"))

(decoy-row "control" "version-null" '()
  "a NULL version string is below-floor, detail #f, and sodium_init never runs"
  (below #f "version-null"))

(decoy-row "control" "version-malformed" '()
  "a version string that is the floor and more is below-floor, detail that string"
  (below (string-append floor-version "-stable") "version-malformed"))

;; Chez's utf8->string drops one leading U+FEFF: the string the library hands
;; back begins with it, and is no version.
(decoy-row "control" "version-bom" '()
  "a version string after a byte order mark is below-floor, detail that string with its U+FEFF"
  (below (string-append (string #\xFEFF) floor-version) "version-bom"))

(decoy-row "control" "libtool-high" '()
  "a version below the floor with libtool numbers 99.99 is below-floor: the string decides"
  (below below-version "libtool-high"))

(decoy-row "control" "libtool-low" '()
  "the floor with libtool numbers 0.0 loads, and reports them: the string decides"
  (lambda (so) (loaded so 'override (report floor-version 0 0 0) (loaded-calls "libtool-low"))))

(decoy-row "control" "init-fails" '()
  "sodium_init answering -1 is init-failed, detail -1, after the version entries"
  (lambda (so) (refused 'init-failed so 'override -1 '() (loaded-calls "init-fails"))))

;; A second code, so that no one value passes for "refused".
(decoy-row "control" "init-other" '()
  "sodium_init answering 2 is init-failed too, detail 2, not -1's"
  (lambda (so) (refused 'init-failed so 'override 2 '() (loaded-calls "init-other"))))

(decoy-row "control" "init-already" '()
  "sodium_init answering 1 is no failure: it loads, and the load records 1"
  (lambda (so) (loaded so 'override (report floor-version 10 3 1) (loaded-calls "init-already"))))

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

(test-end "library-loading-decoys")

(exit (suite-exit-status runner))
