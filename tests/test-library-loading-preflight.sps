#!r6rs
;;; One of the suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds make build's
;;; preflight on a decoy and on refusals, its remedy line, a raise that is not
;;; a refusal, and the probe on the raising fixture.
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

(test-begin "library-loading-preflight")

;; The Makefile exports CHEZ, so this suite spawns the Chez that runs it.
;; Without it nothing below can run: fail, never skip.
(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the floors ----------------------------------------------

;; scratch : (U String #f)
;; A fresh directory for the decoy and the empty profiles. This suite is flat top-level forms, so
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

;; --- the world -------------------------------------------------------------------------
;; Preflight's not-found row needs a Guix world and no profile to search, as
;; tests/test-library-loading-discovery.sps's not-found row does. It assumes
;; the host's system profile, /run/current-system/profile, holds no
;; libsodium: it runs in the development container and on CI.

;; world : (U 'guix 'fhs (List 'raised String))
(define world (process-world))

(test-equal "the world, guix or fhs, was determined"
  'determined
  (if (memq world '(guix fhs)) 'determined world))

(define empty-environment (in-scratch "empty-environment"))
(define empty-profile (in-scratch "empty-profile"))
(define empty-home (in-scratch "home"))
(test-equal "the three empty directories were made"
  '(made made made)
  (list (make-directory empty-environment) (make-directory empty-profile)
        (make-directory empty-home)))

(define no-profiles (no-profiles-env empty-environment empty-profile empty-home))

(define guix-not-found-candidates
  (guix-candidates-in empty-environment empty-profile empty-home))

;; guix-not-found-lines : (U String Symbol)
;; The candidates' lines preflight prints for not-found, each "    PATH\n",
;; built under a guard, so a list of another shape makes the row fail by
;; name instead of killing the suite: SRFI-64 doesn't catch a raise in an
;; expected expression.
(define guix-not-found-lines
  (guard (e (#t 'candidates-unreadable))
    (if (and (list? guix-not-found-candidates) (for-all string? guix-not-found-candidates))
        (apply string-append
               (map (lambda (c) (string-append "    " c "\n")) guix-not-found-candidates))
        'candidates-not-strings)))

(define (decoy-env build switch)
  (cons (override (so-of build)) (switch-args switch)))

;; --- a raise that is not a refusal --------------------------------------------------------
;; tests/fixtures/raising/chez-sodium/private/native.sls shadows src/'s
;; native: its loaded-libsodium raises a plain error. That is a bug, not a
;; refusal, and the probe must report it as a raise.

(define raising-libdirs "tests/fixtures/raising:src")

;; What the fixture raises, as the probe prints it: its &who, and the
;; condition types it is, by name (rnrs's error: serious, error, who, message
;; and irritants); never its text (ADR-0006).
(define fixture-raised '(loaded-libsodium (serious error who message irritants)))

(test-equal "a raise that is not a refusal: the probe prints its who and its types, each reference again, and exits 2"
  (list 2 (list (cons 'raised fixture-raised)
                (cons 'again (list (cons 'raised fixture-raised) (cons 'raised fixture-raised)))
                no-native-objects valgrind-line)
        "")
  (as-data (spawn-in raising-libdirs (switch-args #f) "tests/refusal-probe.sps" '())))

;; --- make build's preflight ----------------------------------------------------------------
;; Its output is what make build tells a person installing chez-sodium, so
;; these rows assert all of it. Its remedy line is the refusal's message,
;; which no test writes as text (ADR-0006): it must equal what the probe read
;; for the same refusal, in a process of its own. Preflight itself, its text
;; and its gate check are (library-loading)'s.

;; message-runs : (Listof Pair)
;; The valgrind line of every probe message-of ran: the last row requires each.
(define message-runs '())

;; message-of : (Listof String) -> (U String (List 'no-message Any))
;; The message of the refusal the probe meets under ENV-ARGS.
(define (message-of env-args)
  (let* ((answer (probe-with env-args '("--message" "yes")))
         (entry (field answer 'message)))
    (set! message-runs (cons (field answer 'valgrind) message-runs))
    (if (string? (cdr entry)) (cdr entry) (list 'no-message answer))))

(let ((so (so-of "control")))
  (test-equal "preflight, the control decoy: exit 0, naming its path, version and libtool numbers, then its counts"
    (list 0 (accepted-text so 'override control-report) "" valgrind-line)
    (preflight (decoy-env "control" #f))))

;; refusal-text : String Any Any String String -> String
;; What preflight prints on stderr for a refusal: REASON, the path and source
;; lines, DETAIL, the candidates lines, and REMEDY.
(define (refusal-text reason path source detail candidates remedy)
  (text "chez-sodium: libsodium refused\n"
        "(reason . " reason ")\n"
        "  path:       " path "\n"
        "  source:     " source "\n"
        "  detail:     " detail "\n"
        candidates
        "  remedy:     " remedy "\n"
        counts-line))

(let* ((so (so-of "control"))
       (env-args (decoy-env "control" "below-floor")))
  (test-equal "preflight, the control decoy below the floor: exit 1, the reason and the fields, the refusal's own message as the remedy, then its counts"
    (list 1 "" (refusal-text "below-floor" so "override" below-version "  candidates: none\n"
                             (message-of env-args))
          valgrind-line)
    (preflight env-args)))

(let ((env-args (cons (override "libsodium.so.26") (switch-args #f))))
  (test-equal "preflight, a bare name: exit 1, invalid-override, the refusal's own message as the remedy, then its counts"
    (list 1 "" (refusal-text "invalid-override" "none" "override" "libsodium.so.26"
                             "  candidates: none\n" (message-of env-args))
          valgrind-line)
    (preflight env-args)))

(let* ((so (so-of "control"))
       (env-args (decoy-env "control" "init-fails")))
  (test-equal "preflight, sodium_init answering -1: exit 1, init-failed, detail -1, the refusal's own message as the remedy, then its counts"
    (list 1 "" (refusal-text "init-failed" so "override" -1 "  candidates: none\n"
                             (message-of env-args))
          valgrind-line)
    (preflight env-args)))

;; reason-line? : String -> Boolean
;; Whether some line of TEXT begins "(reason ", as a refusal's first datum does.
(define (reason-line? text)
  (exists (lambda (line) (string-prefix? "(reason " line)) (lines-of text)))

;; A raise that is no refusal is Chez's default handler's to print, and what
;; it prints is its own text, never written here (ADR-0006): the row asserts
;; the exit status, that nothing reached stdout, that no refusal's reason
;; line appeared, and that stderr is what the default handler prints for the
;; same raise with no guard at all (tests/fixtures/raising/unguarded.sps). A
;; guard wider than a refusal still exits 255, but its handler's first
;; accessor raises in place of the bug, and stderr names the accessor.
(test-equal "preflight, a raise that is not a refusal: Chez's default handler, exit 255, nothing on stdout, no reason line, and stderr exactly what the same raise with no guard prints"
  (list 255 "" 'no-reason-line 'unguarded-stderr valgrind-line)
  (let* ((answer (preflight-in raising-libdirs (switch-args #f)))
         (bare (spawn-in raising-libdirs (switch-args #f)
                         "tests/fixtures/raising/unguarded.sps" '())))
    (cond ((eq? (car answer) 'raised) answer)
          ((eq? (car bare) 'raised) (list 'unguarded bare))
          (else
           (list (car answer) (cadr answer)
                 (if (reason-line? (caddr answer)) 'reason-line 'no-reason-line)
                 (if (and (eqv? (car bare) 255) (equal? (cadr bare) "")
                          (not (equal? (caddr bare) ""))
                          (equal? (caddr answer) (caddr bare)))
                     'unguarded-stderr
                     (list 'stderr (caddr answer) 'unguarded bare))
                 (cadddr answer))))))

(when (eq? world 'guix)
  (test-equal "preflight, not-found (guix world), no profile to search: exit 1, every candidate on its own line, then its counts"
    (list 1 "" (refusal-text "not-found" "none" "none" "none"
                             (text "  candidates:\n" guix-not-found-lines)
                             (message-of no-profiles))
          valgrind-line)
    (preflight no-profiles)))

;; --- every probe that read a message said whether it ran under Valgrind --------------

(test-equal "every probe that read a refusal's message ran under Valgrind exactly when the gate asked, and there were at least two"
  (cons #t (map (lambda (run) valgrind-line) message-runs))
  (cons (>= (length message-runs) 2) message-runs))

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

(test-end "library-loading-preflight")

(exit (suite-exit-status runner))
