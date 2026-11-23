#!r6rs
;;; One of the six suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds the real
;;; libsodium, the refusals no decoy reaches, sodium_init called before and after
;;; the load, and make build's preflight on the real libsodium.
;;; tests/test-library-loading-discovery.sps holds discovery,
;;; tests/test-library-loading-preflight.sps preflight's other rows.
;;;
;;;   - the real libsodium: the one the probe loads in this environment,
;;;     then through the override, and preflight's report of it. What each
;;;     reports must equal what tests/libsodium-oracle.c reads from the same
;;;     file;
;;;   - the refusals no decoy reaches: invalid-override and load-failed;
;;;   - sodium_init (ADR-0002): a direct call before the load, which then sees
;;;     1, and a direct call after it, which answers 1.
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
        (only (chezscheme) getenv putenv format format-condition? load-shared-object
              file-directory? foreign-entry? directory-list))

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

(test-begin "library-loading-real")

;; The Makefile exports CHEZ, so this suite spawns the Chez that runs it.
;; Without it nothing below can run: fail, never skip.
(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the floors ----------------------------------------------

;; scratch : (U String #f)
;; A fresh directory for the text file. This suite is flat top-level forms, so
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

;; write-text-file : String String -> (U 'written (List 'not-written String))
;; TEXT in the file at PATH, or what went wrong; never a raise.
(define (write-text-file path text)
  (guard (e (#t (list 'not-written (describe e))))
    (call-with-port (open-file-output-port path (file-options no-fail)
                                           (buffer-mode block)
                                           (make-transcoder (utf-8-codec)))
      (lambda (p) (put-string p text)))
    'written))

;; --- the real libsodium ---------------------------------------------------------------

;; The probe, in this process's own environment: the libsodium a program here
;; would load, through the override when it is set, by discovery when not.
(define ambient (probe (switch-args #f)))

(define real-libsodium
  (let ((path (cdr (field ambient 'loaded))))
    (and (absolute? path) path)))

(test-equal "the real libsodium: the probe, in this environment, loads one by absolute path"
  'loaded
  (if (and (pair? ambient) (eqv? (car ambient) 0) real-libsodium) 'loaded ambient))

(test-equal "the real libsodium: that probe ran under Valgrind exactly when the gate asked"
  valgrind-line
  (field ambient 'valgrind))

;; oracle-runs : (Listof Pair)
;; The (valgrind . yes) or (valgrind . no) line of every oracle run so far, or
;; (valgrind no-oracle) of one that failed: the last row requires each.
(define oracle-runs '())

;; oracle-of : (U String #f) -> (U (Listof (Pairof Symbol Any)) (List 'no-oracle Symbol Any))
;; What tests/libsodium-oracle.c reads from the library at PATH.
(define (oracle-of path)
  (let ((oracle (if (string? path)
                    (libsodium-oracle getenv path)
                    (list 'no-oracle 'no-path path))))
    (set! oracle-runs
          (cons (or (and (list? oracle) (for-all pair? oracle) (assq 'valgrind oracle))
                    (list 'valgrind 'no-oracle))
                oracle-runs))
    oracle))

(define real-oracle (oracle-of real-libsodium))

;; oracle-field : Any Symbol -> Pair
;; The oracle's (KEY . VALUE), or (KEY no-oracle) when it failed.
(define (oracle-field oracle key)
  (or (and (list? oracle) (for-all pair? oracle) (assq key oracle))
      (list key 'no-oracle)))

;; oracle-init : Any -> (U Integer (List 'no-oracle))
;; The oracle's first sodium_init answer: what a fresh process's load sees.
(define (oracle-init oracle)
  (let ((init (oracle-field oracle 'init)))
    (if (and (pair? (cdr init)) (integer? (cadr init))) (cadr init) (list 'no-oracle))))

;; oracle-report : Any Integer -> Report
;; The oracle's version, major and minor, with INIT as sodium_init's answer.
(define (oracle-report oracle init)
  (report (cdr (oracle-field oracle 'version)) (cdr (oracle-field oracle 'major))
          (cdr (oracle-field oracle 'minor)) init))

(test-equal "the C oracle read the real libsodium"
  'read
  (if (and (pair? real-oracle) (eq? (car real-oracle) 'no-oracle)) real-oracle 'read))

;; Field by field, so a failure names the field. The first sodium_init answer
;; is a fresh process's: 0.
(for-each
 (lambda (key)
   (test-equal (string-append "the real libsodium: the probe's " (symbol->string key)
                              " is the C oracle's")
     (oracle-field real-oracle key)
     (field ambient key)))
 '(version major minor))

(test-equal "the real libsodium: the probe's init is the oracle's first sodium_init answer, 0"
  (cons 'init (oracle-init real-oracle))
  (field ambient 'init))

(test-equal "the real libsodium through the override: loaded, with the C oracle's report, whole"
  (loaded (or real-libsodium "?") 'override (oracle-report real-oracle (oracle-init real-oracle)) #f)
  (probe (cons (override (or real-libsodium "/the-probe-loaded-nothing")) (switch-args #f))))

;; make build's preflight on the same file, through the override: what it
;; tells a person installing chez-sodium, all of it, the C oracle's report
;; (tests/test-library-loading-preflight.sps holds preflight's other rows).
(test-equal "preflight, the real libsodium: exit 0, with the C oracle's report, then its counts"
  (list 0 (accepted-text (or real-libsodium "?") 'override
                         (oracle-report real-oracle (oracle-init real-oracle)))
        "" valgrind-line)
  (preflight (cons (override (or real-libsodium "/the-probe-loaded-nothing")) (switch-args #f))))

;; call-with-tmpdir : String (-> Any) -> Any
;; THUNK with TMPDIR set to DIR. Afterwards TMPDIR is put back to its old
;; value, or to /tmp when it was unset: putenv cannot unset, and /tmp is
;; where mktemp and capture-command go for an unset TMPDIR.
(define (call-with-tmpdir dir thunk)
  (let ((old (getenv "TMPDIR")))
    (dynamic-wind
      (lambda () (putenv "TMPDIR" dir))
      thunk
      (lambda () (putenv "TMPDIR" (or old "/tmp"))))))

;; The oracle never raises, and removes its directory when something inside it
;; raises. Here the getenv it is handed does, once the directory exists.
(test-equal "the oracle, when a raise comes inside its directory: it answers no-oracle, and has removed the directory"
  '(no-oracle raised 1 ())
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (base)
       (let* ((seen '())
              (answer (call-with-tmpdir base
                        (lambda ()
                          (libsodium-oracle (lambda (name)
                                              (set! seen (directory-list base))
                                              (raise 'getenv-raised))
                                            "/unused")))))
         (list (car answer) (cadr answer) (length seen) (directory-list base)))))))

;; --- refusals no decoy reaches ----------------------------------------------------------

(test-equal "a bare name in the override is invalid-override, carrying it"
  (refused 'invalid-override #f 'override "libsodium.so.26" '() #f (list "libsodium.so.26"))
  (probe (cons (override "libsodium.so.26") (switch-args #f))))

(test-equal "an empty override is invalid-override too, carrying it"
  (refused 'invalid-override #f 'override "" '() #f (list ""))
  (probe (cons (override "") (switch-args #f))))

;; loader-text : String -> (U String (List Symbol Any))
;; What Chez's loader says when it refuses PATH, formatted as native formats
;; it: the oracle for load-failed's detail. Nothing loads.
(define (loader-text path)
  (guard (e ((and (format-condition? e) (message-condition? e) (irritants-condition? e))
             (apply format (condition-message e) (condition-irritants e)))
            (#t (list 'unexpected-raise (describe e))))
    (load-shared-object path)
    (list 'loaded path)))

(define text-file (in-scratch "not-a-library.so"))
(test-equal "the text file was written"
  'written
  (write-text-file text-file "not a shared object\n"))
(define text-file-refusal (loader-text text-file))

(test-equal "a text file is load-failed, with the loader's message"
  (refused 'load-failed text-file 'override text-file-refusal '() #f)
  (probe (cons (override text-file) (switch-args #f))))

(define no-such-file (in-scratch "no-such-dir/libsodium.so.26"))
(define no-such-file-refusal (loader-text no-such-file))

(test-equal "a path that does not exist is load-failed, with the loader's message"
  (refused 'load-failed no-such-file 'override no-such-file-refusal '() #f)
  (probe (cons (override no-such-file) (switch-args #f))))

;; --- sodium_init called by someone else (ADR-0002) -----------------------------------
;; The probe calls the real sodium_init through a binding of its own before
;; the load: the load sees 1, and loads. A direct call after the load answers
;; 1 either way. Both rows name the real library by the override: the probe
;; loads that path itself.

(let ((path (or real-libsodium "/the-probe-loaded-nothing")))
  (test-equal "sodium_init called first: the probe's call answers 0, the load sees 1 and loads, a direct call after answers 1"
    (list 0
          (append (list (cons 'init-before 0))
                  (loaded-lines path 'override (oracle-report real-oracle 1))
                  (list once (cons 'init-after 1) no-native-objects valgrind-line))
          "")
    (probe-with (cons (override path) (switch-args #f))
                '("--init-before" "yes" "--init-after" "yes")))

  (test-equal "the load first: it sees 0, and a direct call after answers 1"
    (list 0
          (append (loaded-lines path 'override (oracle-report real-oracle 0))
                  (list once (cons 'init-after 1) no-native-objects valgrind-line))
          "")
    (probe-with (cons (override path) (switch-args #f)) '("--init-after" "yes"))))

;; --- every C oracle run said whether it ran under Valgrind --------------------------
;; The C oracle's answers carry the line among other things.

(test-equal "every C oracle run ran under Valgrind exactly when the gate asked, and there was at least one"
  (cons #t (map (lambda (run) valgrind-line) oracle-runs))
  (cons (>= (length oracle-runs) 1) oracle-runs))

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

(test-end "library-loading-real")

(exit (suite-exit-status runner))
