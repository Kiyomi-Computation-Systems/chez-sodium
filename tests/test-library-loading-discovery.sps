#!r6rs
;;; One of the eight suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds discovery, with the
;;; override unset: what it chooses in each world, and not-found. In a Guix world
;;; the profiles can be made to hold what a row needs. In an FHS world the
;;; standard directories cannot be emptied, so those rows assert discovery's
;;; success there instead, and their names say which world ran.
;;;
;;; The rows assume the host's system profile, /run/current-system/profile,
;;; holds no libsodium: they run in the development container and on CI.
;;;
;;; Under the memory gate each child runs under a Valgrind of its own, so
;;; the rows are split among eight suites, each running at most 14 children,
;;; to keep each well under MEMORY_TIMEOUT (ADR-0011); (library-loading)
;;; holds what all eight use.
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
        (only (chezscheme) getenv format format-condition? load-shared-object file-directory?
              foreign-entry? machine-type)
        (chez-sodium private discovery))

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

(test-begin "library-loading-discovery")

;; The Makefile exports CHEZ, so this suite spawns the Chez that runs it.
;; Without it nothing below can run: fail, never skip.
(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the floors ----------------------------------------------

;; scratch : (U String #f)
;; A fresh directory for the empty profiles, the copies and the text files.
;; This suite is flat top-level forms, so (chez-sodium-testing) removes the
;; directory when the process ends; the last forms remove it earlier, and
;; the tests below require that.
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

;; copy-file : String String -> (U 'copied (List 'not-copied Any))
;; The file at FROM, copied to TO; never a raise.
(define (copy-file from to)
  (guard (e (#t (list 'not-copied (describe e))))
    (let ((answer (capture-command (list "cp" from to))))
      (if (eqv? (car answer) 0) 'copied (list 'not-copied answer)))))

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

;; oracle-field : Any Symbol -> Pair
(define (oracle-field oracle key)
  (or (and (list? oracle) (for-all pair? oracle) (assq key oracle))
      (list key 'no-oracle)))

;; oracle-report : Any -> Report
;; The oracle's version, major and minor, and a load's first answer, 0, as a
;; fresh process sees it.
(define (oracle-report oracle)
  (report (cdr (oracle-field oracle 'version)) (cdr (oracle-field oracle 'major))
          (cdr (oracle-field oracle 'minor)) 0))

;; loader-text : String -> (U String (List Symbol Any))
;; What Chez's loader says when it refuses PATH, formatted as native formats
;; it. Nothing loads.
(define (loader-text path)
  (guard (e ((and (format-condition? e) (message-condition? e) (irritants-condition? e))
             (apply format (condition-message e) (condition-irritants e)))
            (#t (list 'unexpected-raise (describe e))))
    (load-shared-object path)
    (list 'loaded path)))

;; --- the world ----------------------------------------------------------------------------
;; Discovery runs with the override unset, so which libsodium it chooses
;; depends on the world this Chez lives in. These rows assume the host's
;; system profile, /run/current-system/profile, holds no libsodium: they run
;; in the development container and on CI.

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

;; No profile to search, every source listed: what not-found needs in a Guix
;; world.
(define no-profiles (no-profiles-env empty-environment empty-profile empty-home))

(define guix-not-found-candidates
  (guix-candidates-in empty-environment empty-profile empty-home))

;; fhs-triple : Symbol -> (U String #f)
;; The Debian multiarch directory under /usr/lib for MACHINE-TYPE, written out
;; here, not asked of discovery, which maps the machine type itself.
(define (fhs-triple type)
  (case type
    ((ta6le a6le) "x86_64-linux-gnu")
    ((tarm64le arm64le) "aarch64-linux-gnu")
    (else #f)))

;; append-map : (A -> (Listof B)) (Listof A) -> (Listof B)
(define (append-map f lst) (apply append (map f lst)))

;; fhs-candidate-paths : (Listof String)
;; Every FHS candidate, as ADR-0002 orders them, written out: each standard
;; directory in turn, .so.26 before .so.23 in each.
(define fhs-candidate-paths
  (let ((triple (fhs-triple (machine-type))))
    (append-map
     (lambda (directory)
       (list (string-append directory "/libsodium.so.26")
             (string-append directory "/libsodium.so.23")))
     (append '("/usr/local/lib")
             (if triple (list (string-append "/usr/lib/" triple)) '())
             '("/usr/lib64" "/usr/lib")))))

;; Runs in every world. The FHS rows below run only where the standard
;; directories are the world's, and take their expected path from the list
;; above, so this row holds that list to discovery's.
(test-equal "the hand-written FHS candidate list is the one discovery gives for this machine type"
  fhs-candidate-paths
  (guard (e (#t (list 'raised (describe e))))
    (map car (libsodium-candidates 'fhs (machine-type) getenv))))

;; first-standard : (U String (List 'no-fhs-candidate-exists) (List 'raised String))
;; The first FHS candidate that exists here, from the hand-written list.
(define first-standard
  (guard (e (#t (list 'raised (describe e))))
    (or (find file-exists? fhs-candidate-paths)
        (list 'no-fhs-candidate-exists))))

;; loaded-fhs : -> Expected
;; The probe's whole answer when discovery chooses the first FHS candidate.
(define (loaded-fhs)
  (loaded first-standard 'system (oracle-report (oracle-of (and (string? first-standard) first-standard))) #f))

(case world
  ((guix)
   (let* ((environment-libsodium
           (string-append (or (getenv "GUIX_ENVIRONMENT") "<GUIX_ENVIRONMENT unset>")
                          "/lib/libsodium.so.26"))
          (oracle (oracle-of environment-libsodium)))
     (test-equal "discovery (guix world): with the override unset, $GUIX_ENVIRONMENT/lib/libsodium.so.26 loads"
       (loaded environment-libsodium 'guix-environment (oracle-report oracle) #f)
       (probe unset-override))

     (test-equal "not-found (guix world): with no profile to search, not-found lists every candidate checked, ten, .so.26 before .so.23 in each of the five"
       (refused 'not-found #f #f #f guix-not-found-candidates #f (list guix-not-found-candidates))
       (probe no-profiles))

     ;; A directory that holds libsodium.so alone: the development link, which
     ;; names no ABI, is never a candidate.
     (let* ((directory (in-scratch "only-link"))
            (candidates (guix-candidates-in directory empty-profile empty-home)))
       (test-equal "the only-link directory was made, and the library copied to libsodium.so alone"
         '(made copied)
         (let* ((made (make-directory (string-append directory "/lib")))
                (copied (copy-file environment-libsodium
                                   (string-append directory "/lib/libsodium.so"))))
           (list made copied)))
       (test-equal "not-found (guix world): a directory holding only libsodium.so is not a candidate"
         (refused 'not-found #f #f #f candidates #f (list candidates))
         (probe (no-profiles-env directory empty-profile empty-home))))

     ;; Both sonames: the newer is tried first. The .so.23 is a text file, so
     ;; trying it first would be load-failed.
     (let* ((directory (in-scratch "both"))
            (newer (string-append directory "/lib/libsodium.so.26")))
       (test-equal "the both-sonames directory was made, and the library copied to libsodium.so.26"
         '(made copied)
         (let* ((made (make-directory (string-append directory "/lib")))
                (copied (copy-file environment-libsodium newer)))
           (list made copied)))
       (test-equal "the older soname's text file was written"
         'written
         (write-text-file (string-append directory "/lib/libsodium.so.23") "not a shared object\n"))
       (test-equal "discovery (guix world): a directory holding both sonames loads libsodium.so.26"
         (loaded newer 'guix-environment (oracle-report (oracle-of newer)) #f)
         (probe (no-profiles-env directory empty-profile empty-home))))

     ;; The older soname alone is a candidate, and loads.
     (let* ((directory (in-scratch "older"))
            (older (string-append directory "/lib/libsodium.so.23")))
       (test-equal "the older-soname directory was made, and the library copied to libsodium.so.23 alone"
         '(made copied)
         (let* ((made (make-directory (string-append directory "/lib")))
                (copied (copy-file environment-libsodium older)))
           (list made copied)))
       (test-equal "discovery (guix world): a directory holding libsodium.so.23 alone loads it"
         (loaded older 'guix-environment (oracle-report (oracle-of older)) #f)
         (probe (no-profiles-env directory empty-profile empty-home))))

     ;; GUIX_ENVIRONMENT's candidate exists, so it is chosen, but it is a text
     ;; file. GUIX_PROFILE's, next in line, is a real libsodium, and must
     ;; never be tried (ADR-0002).
     (let* ((broken-profile (in-scratch "broken-profile"))
            (broken (string-append broken-profile "/lib/libsodium.so.26")))
       (test-equal "the broken profile's lib directory was made"
         'made
         (make-directory (string-append broken-profile "/lib")))
       (test-equal "the broken profile's text file was written"
         'written
         (write-text-file broken "not a shared object\n"))
       (let ((refusal (loader-text broken)))
         (test-equal "discovery (guix world): a candidate that fails to load is load-failed, and the next is never tried"
           (refused 'load-failed broken 'guix-environment refusal '() #f)
           (probe (append unset-override
                          (list (string-append "GUIX_ENVIRONMENT=" broken-profile)
                                (string-append "GUIX_PROFILE=" (or (getenv "GUIX_ENVIRONMENT") "/nonexistent"))
                                (string-append "HOME=" empty-home)))))))))
  (else
   (test-equal "discovery (fhs world): with the override unset, the first standard candidate that exists loads, source system"
     (loaded-fhs)
     (probe unset-override))

   ;; No Guix profile is a candidate here, and the standard directories
   ;; cannot be emptied, so not-found cannot be built: with no profile to
   ;; search, discovery must still load the first standard candidate.
   (test-equal "not-found (fhs world): not buildable, so with no profile to search, discovery's success instead: the first standard candidate, source system"
     (loaded-fhs)
     (probe no-profiles))))

;; --- every C oracle run said whether it ran under Valgrind --------------------------

(test-equal "every C oracle run ran under Valgrind exactly when the gate asked, and there were at least two"
  (cons #t (map (lambda (run) valgrind-line) oracle-runs))
  (cons (>= (length oracle-runs) 2) oracle-runs))

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

(test-end "library-loading-discovery")

(exit (suite-exit-status runner))
