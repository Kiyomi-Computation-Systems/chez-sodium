#!r6rs
;;; The suite for tests/check-ci.sh, the check behind `make check-ci`: it holds
;;; .github/workflows/ci.yml to the one shape it reads, and fails closed on any
;;; spelling that a text reader cannot see. Without this suite, loosening a rule
;;; would leave `make test` green: nothing else plants a fault in the workflow.
;;;
;;; Every row copies the real workflow into a directory of its own, under one
;;; temporary directory of this process (never at a fixed path, so two runs at
;;; once share no file), applies its edits, and runs the script on it. An edit
;;; is old text and new text, and the old text must occur exactly once in the
;;; real file, or the row fails and says which. A row asserts the exit status,
;;; the whole of stdout and the whole of stderr. Each expected problem is
;;; written by hand here: the line it names is the one holding an anchor text
;;; in the edited file, never a number read back from the script.
;;;
;;; make test runs every suite from the repository root. Without CHEZ nothing
;;; below runs: that fails here, by name, and never skips.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (only (chezscheme) mkdir))

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

(define script "tests/check-ci.sh")
(define real-path ".github/workflows/ci.yml")

;; --- files and text ---------------------------------------------------------------

;; read-text : String -> String
(define (read-text path)
  (call-with-port
   (open-file-input-port path (file-options) (buffer-mode block)
                         (make-transcoder (utf-8-codec)))
   get-string-all))

;; write-text : String String -> Void
(define (write-text path text)
  (call-with-port
   (open-file-output-port path (file-options) (buffer-mode block)
                          (make-transcoder (utf-8-codec)))
   (lambda (p) (put-string p text))))

;; find-sub : String String Natural -> (U Natural #f)
(define (find-sub s sub start)
  (let ((n (string-length s)) (m (string-length sub)))
    (let loop ((i start))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring s i (+ i m)) sub) i)
            (else (loop (+ i 1)))))))

;; count-sub : String String -> Natural
(define (count-sub s sub)
  (let loop ((i 0) (n 0))
    (let ((at (find-sub s sub i)))
      (if at (loop (+ at (string-length sub)) (+ n 1)) n))))

;; replace-first : String String String -> String
(define (replace-first s old new)
  (let ((at (find-sub s old 0)))
    (string-append (substring s 0 at) new (substring s (+ at (string-length old)) (string-length s)))))

;; split-lines : String -> (Listof String)
;; The lines of TEXT, a final newline ending the last line, not starting another.
(define (split-lines text)
  (let loop ((chars (string->list text)) (cur '()) (acc '()))
    (cond ((null? chars) (reverse (if (null? cur) acc (cons (list->string (reverse cur)) acc))))
          ((char=? (car chars) #\newline)
           (loop (cdr chars) '() (cons (list->string (reverse cur)) acc)))
          (else (loop (cdr chars) (cons (car chars) cur) acc)))))

(define real (guard (e (#t "")) (read-text real-path)))

;; lines : String ... -> String
;; Each argument as a line, newline-ended.
(define (lines . ls)
  (apply string-append (map (lambda (l) (string-append l "\n")) ls)))

;; span : String String -> String
;; The real file from the first START to the end of the first END after it.
(define (span start end)
  (let* ((s (find-sub real start 0))
         (e (and s (find-sub real end s))))
    (unless e (error 'span "markers not found" start end))
    (substring real s (+ e (string-length end)))))

;; e : String String -> (Pair String String)
(define (e old new) (cons old new))

;; The jobs, in the file's order. A job's text runs from its header line to the
;; next job's, so a job's text can be told from the other jobs' copies of it.
(define job-order '("main" "memory" "nothreads" "floor" "current"))

;; job-bounds : String String -> (Pair Natural Natural)
(define (job-bounds text job)
  (let ((start (find-sub text (string-append "\n  " job ":\n") 0)))
    (unless start (error 'job-bounds "no such job" job))
    (let loop ((later (cdr (member job job-order))))
      (cond ((null? later) (cons start (string-length text)))
            ((find-sub text (string-append "\n  " (car later) ":\n") start)
             => (lambda (at) (cons start at)))
            (else (loop (cdr later)))))))

;; job-text : String String -> String
(define (job-text text job)
  (let ((b (job-bounds text job))) (substring text (car b) (cdr b))))

;; le : String String String -> Edit
;; An edit that must find OLD once in one job's text, not once in the file: the
;; jobs hold copies of each other's steps.
(define (le job old new) (list 'job job old new))

;; apply-edit : String Edit -> String
;; The old text must occur once in the real file, and once in the text so far;
;; for a job edit, once in that job's text of each.
(define (apply-edit text edit)
  (if (eq? (car edit) 'job)
      (let* ((job (cadr edit)) (old (caddr edit)) (new (cadddr edit))
             (tb (job-bounds text job))
             (tt (substring text (car tb) (cdr tb))))
        (unless (and (= (count-sub (job-text real job) old) 1) (= (count-sub tt old) 1))
          (error 'apply-edit "the old text does not occur exactly once in the job" job old))
        (string-append (substring text 0 (car tb))
                       (replace-first tt old new)
                       (substring text (cdr tb) (string-length text))))
      (let ((old (car edit)))
        (unless (and (= (count-sub real old) 1) (= (count-sub text old) 1))
          (error 'apply-edit "the old text does not occur exactly once" old))
        (replace-first text old (cdr edit)))))

(define (apply-edits edits)
  (fold-left apply-edit real edits))

;; --- the words the problems are made of, written by hand --------------------------

(define tab-msg "holds a tab, which YAML may read as white space beside a key")
(define odd-msg "holds a character beyond ASCII, which GitHub may fold into a key's letters")
(define explicit-msg "writes an explicit key, with ?, whose colon may be on another line")
(define alias-msg "puts an alias or an anchor where a key goes")
(define quoted-msg "writes a quoted key")
(define space-msg "has white space between a key and its colon")
(define flow-msg "holds a flow mapping, with {, outside a quoted scalar and a ${{ }} expression")
(define openq-msg "holds a quoted scalar that runs past the line's end")
(define bsq-msg "holds a backslash after a double quote, which YAML may read as an escape")
(define place-msg "is not a line check-ci reads at this place")
(define hasval-msg "this key must hold a block, not a value")
(define stray-msg "names scripts/ other than as a step's whole run line of scripts/ci/ or a cache key's hashed files")

(define (names-msg w) (string-append "names " w ", which could steer a check or a later step"))
(define (gate-msg w)
  (string-append "names " w " other than as the whole run line of the one step that runs it"))

(define tops "name, on, permissions, concurrency, jobs")
(define (top-unknown k) (string-append "top-level key \"" k "\" is not one of " tops))
(define (top-twice k) (string-append "top-level key \"" k "\" is written twice"))
(define (top-order k)
  (string-append "top-level key \"" k "\" comes out of order: the order is " tops))
(define (top-missing k) (string-append "top-level key \"" k "\" is missing"))
(define (block-differs k want got)
  (string-append "the \"" k "\" block differs from the one check-ci holds: expected \""
                 want "\", found \"" got "\""))
(define (block-extra k got)
  (string-append "the \"" k "\" block has a line it must not: \"" got "\""))

(define jobs "main, memory, nothreads, floor, current")
(define (job-unknown j) (string-append "job \"" j "\" is not one of " jobs))
(define (job-missing j) (string-append "job \"" j "\" is missing"))
(define (job-key j k)
  (string-append "job " j " has the key \"" k "\", which is not one of name, runs-on, timeout-minutes, steps"))
(define (job-key-twice j k) (string-append "job " j " has the key \"" k "\" twice"))
(define (job-no-key j k) (string-append "job " j " has no key \"" k "\""))
(define (job-runs-on j) (string-append "job " j " has runs-on other than ubuntu-24.04"))
(define (job-timeout j)
  (string-append "job " j " has a timeout-minutes that is not a whole number"))

(define (step-key k)
  (string-append "step key \"" k "\" is not one of name, id, uses, with, run, env, if"))
(define (with-key k)
  (string-append "with key \"" k "\" is not one of submodules, path, key"))
(define (env-key k) (string-append "env key \"" k "\" is not CHEZ"))
(define chez-t "${{ runner.temp }}/chez-threads/bin/scheme")
(define chez-n "${{ runner.temp }}/chez-nothreads/bin/scheme")
(define (env-chez j v) (string-append "env CHEZ in job " j " is not " v))
(define (env-missing j run) (string-append "job " j "'s step that runs \"" run "\" has no env CHEZ"))
(define hash-list
  "'packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-chez.sh', 'scripts/ci/check-chez.sh'")
(define (cache-key j prefix)
  (string-append "the cache key in job " j " does not begin with " prefix
                 "${{ hashFiles(" hash-list ") }}"))
(define primary "${{ steps.chez.outputs.cache-primary-key }}")
(define (save-key j) (string-append "the cache key of the save in job " j " is not exactly " primary))
;; A lane's cache steps may name two paths, the Chez cache's and its own
;; libsodium cache's; the other jobs, the Chez cache's alone.
(define (cache-path j p)
  (if (or (string=? j "floor") (string=? j "current"))
      (string-append "the cache path in job " j " is not one of " p " or ${{ runner.temp }}/sodium-" j)
      (string-append "the cache path in job " j " is not " p)))
(define (restore-id j) (string-append "the cache's restore in job " j " is not id: chez"))
(define (restores j n) (string-append "job " j " has " (number->string n) " restores of the Chez cache, not one"))
(define (saves j n) (string-append "job " j " has " (number->string n) " saves of the Chez cache, not one"))
(define (restore-late j)
  (string-append "job " j " restores the Chez cache after the Chez build, and must restore it before"))
(define (save-early j)
  (string-append "job " j " saves the Chez cache before the Chez build, and must save it after"))
(define (save-late j)
  (string-append "job " j " saves the Chez cache after the Chez check, and must save it before"))
(define (uses-msg j u)
  (string-append "job " j " has a step that uses \"" u "\", which is not actions/checkout@, actions/cache/restore@ or actions/cache/save@"))
(define if-line "if: steps.chez.outputs.cache-hit != 'true'")
(define if-bad (string-append "if is not exactly \"" if-line "\""))
(define if-sod-line "if: steps.sodium.outputs.cache-hit != 'true'")
(define lane-if-bad
  (string-append "if is not one of \"" if-line "\" or \"" if-sod-line "\""))
;; if-bad-for : String -> String
(define (if-bad-for j)
  (if (or (string=? j "floor") (string=? j "current")) lane-if-bad if-bad))
(define if-wrong
  "if is on a step that neither runs scripts/ci/build-chez.sh nor uses actions/cache/save")

(define (n-steps j run n)
  (string-append "job " j " has " (number->string n) " steps that run \"" run "\", not one"))
(define (out-of-order j run before)
  (string-append "job " j " runs \"" run "\" before \"" before "\", and must run it after"))
(define (step-has-if j run) (string-append "job " j "'s step that runs \"" run "\" has an if"))
(define (step-no-if j run) (string-append "job " j "'s step that runs \"" run "\" has no if"))
(define (first-step-msg j)
  (string-append "job " j "'s first step is not uses: actions/checkout@ with submodules: recursive"))
(define second-step-msg
  "job main's second step is not run: scripts/ci/check-action-pins.sh .github/workflows")

;; the two report steps of main
(define vers-name "Report the versions this run uses")
(define sod-name "Report the runner's libsodium")
(define sod-run "scripts/ci/report-sodium.sh")
(define (named-n name n)
  (string-append "job main has " (number->string n) " steps named \"" name "\", not one"))
(define (runs-before name before)
  (string-append "job main runs step \"" name "\" before \"" before "\", and must run it after"))
(define (runs-after name after)
  (string-append "job main runs step \"" name "\" after \"" after "\", and must run it before"))
(define swapped-msg
  (string-append "job main's step \"" sod-name "\" comes before step \"" vers-name "\", and must come after"))
(define not-block-msg
  (string-append "job main's step \"" vers-name "\" does not run a block: it must be run: |"))
(define (vers-differs want got)
  (string-append "job main's step \"" vers-name "\" has a run line that differs from the one check-ci holds: expected \""
                 want "\", found \"" got "\""))
(define (vers-extra got)
  (string-append "job main's step \"" vers-name "\" has a run line it must not: \"" got "\""))
(define (vers-early want)
  (string-append "job main's step \"" vers-name "\" has a run block that ends early: expected \"" want "\""))
(define sod-run-msg (string-append "job main's step \"" sod-name "\" is not run: " sod-run))
(define vers-l1 "          \"$RUNNER_TEMP/chez-threads/bin/scheme\" --version")
(define vers-l2 "          cc --version | head -n 1")
(define vers-l3 "          valgrind --version")
(define vers-l4 "          echo \"image: ${ImageOS:-unknown} ${ImageVersion:-unknown}\"")
(define vers-l5 "          echo \"kernel: $(uname -r)\"")
(define vers-hdr "      - name: Report the versions this run uses")
(define sod-hdr "      - name: Report the runner's libsodium")
(define (vers-step) (span (string-append vers-hdr "\n") (string-append vers-l5 "\n")))
(define (sod-step) (span "      # The runner's own libsodium" (string-append "run: " sod-run "\n")))
(define (make-run) (string-append "        run: " make-line "\n"))

(define pin-run "scripts/ci/check-action-pins.sh .github/workflows")
(define bld-t "scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-threads\"")
(define chk-t "scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-threads\"")
(define chk-n "scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-nothreads\" --nothreads")
(define bld-n "scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-nothreads\" --nothreads")
(define make-line
  "make check-help check-suites check-pins check-floors check-ci test check-test-fails check-dev check-clean")
(define build-run "make build")
(define disc-run "scripts/ci/check-sodium.sh --discovery")
(define disc-hdr "      - name: The runner's libsodium is the floor")
(define disc-line (string-append "        run: " disc-run))
(define install-hdr "      - name: The install check, by discovery")
(define build-line "        run: make build")
(define (install-step)
  (span "      # ADR-0002's install check." "        run: make build\n"))
(define chk-step-hdr "      - name: Check the Chez this job runs\n")
(define (main-chk-step) (string-append chk-step-hdr "        run: " chk-t "\n"))
(define launcher "sh tests/guix-env-launcher.sh")
(define gate-run "make check-memory-gate")
(define mem-run "make test-memory")
(define nt-run "make check-nothreads")

(define checkout-line
  "      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1")

;; --- rows ---------------------------------------------------------------------------

;; A row is (name edits-thunk problems-thunk setup-thunk): the edits to the
;; real ci.yml, the problems expected, in order, each (anchor message), and
;; what to do to the directory before the run (or #f). The thunks keep a fault
;; in a row's own construction from killing the suite: it fails that row, by
;; name.
(define-syntax row
  (syntax-rules ()
    ((_ name edits problems)
     (list name (lambda () edits) (lambda () problems) #f))))

(define-syntax row/setup
  (syntax-rules ()
    ((_ name setup edits problems)
     (list name (lambda () edits) (lambda () problems) setup))))

;; An anchor: a string, the one line of the edited file that is exactly it; a
;; list (string n), the nth such line; (after HEADER string), the first line
;; that is exactly string below the one line that is exactly HEADER, so that a
;; line repeated across steps is named by its step; (in JOB HEADER string), the
;; same inside one job: the first line that is exactly HEADER below the job's
;; own header line "  JOB:" (or the job's header itself, with #f), then the
;; first line that is exactly string below that; 'eof, the file's last line;
;; 'dir, no line, the directory; 'file, no line, the file.

;; line-number : (Listof String) Anchor -> Natural
(define (line-number ls anchor)
  (cond ((and (pair? anchor) (eq? (car anchor) 'after))
         (line-number-after ls (cadr anchor) (caddr anchor)))
        ((and (pair? anchor) (eq? (car anchor) 'in))
         (line-number-in ls (cadr anchor) (caddr anchor) (cadddr anchor)))
        (else (line-number-plain ls anchor))))

;; line-number-in : (Listof String) String (U String #f) String -> Natural
(define (line-number-in ls job header text)
  (let* ((j (line-number-plain ls (string-append "  " job ":")))
         (h (if header (line-number-below ls j header) j)))
    (line-number-below ls h text)))

;; line-number-below : (Listof String) Natural String -> Natural
;; The first line after line START (1-based) that is exactly TEXT.
(define (line-number-below ls start text)
  (let loop ((rest (list-tail ls start)) (i (+ start 1)))
    (cond ((null? rest) (error 'anchor "no such line below its header" text))
          ((string=? (car rest) text) i)
          (else (loop (cdr rest) (+ i 1))))))

;; line-number-after : (Listof String) String String -> Natural
(define (line-number-after ls header text)
  (let ((start (line-number-plain ls header)))
    (let loop ((rest (list-tail ls start)) (i (+ start 1)))
      (cond ((null? rest) (error 'anchor "no such line below its header" header text))
            ((string=? (car rest) text) i)
            (else (loop (cdr rest) (+ i 1)))))))

(define (line-number-plain ls anchor)
  (let* ((text (if (pair? anchor) (car anchor) anchor))
         (nth (if (pair? anchor) (cadr anchor) #f))
         (hits (let loop ((ls ls) (i 1) (acc '()))
                 (cond ((null? ls) (reverse acc))
                       ((string=? (car ls) text) (loop (cdr ls) (+ i 1) (cons i acc)))
                       (else (loop (cdr ls) (+ i 1) acc))))))
    (cond (nth (if (<= nth (length hits))
                   (list-ref hits (- nth 1))
                   (error 'anchor "no such line" anchor)))
          ((= (length hits) 1) (car hits))
          (else (error 'anchor "the line is not there exactly once" anchor)))))

;; problem-line : String String (Listof String) (List Anchor String) -> String
(define (problem-line dir file ls problem)
  (let* ((a (car problem)) (msg (cadr problem)))
    (string-append
     "check-ci: "
     (cond ((eq? a 'dir) (string-append dir ": "))
           ((eq? a 'file) (string-append file ": "))
           ((eq? a 'eof) (string-append file ":" (number->string (length ls)) ": "))
           (else (string-append file ":" (number->string (line-number ls a)) ": ")))
     msg "\n")))

(define pass-line (lambda (dir) (string-append "check-ci: " dir "/ci.yml has the one shape check-ci reads\n")))

;; expected : String String (Listof (List Anchor String)) -> (List Integer String String)
(define (expected dir text problems)
  (let ((file (string-append dir "/ci.yml")) (ls (split-lines text)))
    (if (null? problems)
        (list 0 (pass-line dir) "")
        (list 1 ""
              (string-append
               (apply string-append (map (lambda (p) (problem-line dir file ls p)) problems))
               "check-ci: FAILED (problems: " (number->string (length problems)) ")\n")))))

;; Without a temporary directory no row can run, so the suite says why and exits
;; 1 here, before any row: a raise at the top level names no test.
(define base
  (guard (e (#t (display "test-check-ci: no temporary directory for the rows' copies: ")
                (display (describe e))
                (newline)
                (exit 1)))
    (make-process-temp-directory)))

(define counter 0)

;; run-row : (List String Thunk Thunk (U Procedure #f))
;;         -> (List (List Integer String String) (List Integer String String))
;; The expected answer, then the script's.
(define (run-row r)
  (set! counter (+ counter 1))
  (let ((dir (string-append base "/r" (number->string counter))))
    (guard (c (#t (list (list 'raised (string-append (car r) ": " (describe c))) '(not run))))
      (mkdir dir)
      (let* ((text (apply-edits ((cadr r))))
             (want (expected dir text ((caddr r)))))
        (write-text (string-append dir "/ci.yml") text)
        (when (cadddr r) ((cadddr r) dir))
        (list want (capture-command (list "sh" script dir)))))))

;; The rows.

;; setup procedures
(define (add-file name)
  (lambda (dir) (write-text (string-append dir "/" name) "on: push\n")))

;; in-dir : String -> (String -> Void)
;; A setup that runs the shell command CMD in the row's directory.
(define (in-dir cmd)
  (lambda (dir)
    (let ((r (capture-command (list "sh" "-c" (string-append "cd \"$1\" && " cmd) "sh" dir))))
      (unless (= (car r) 0) (error 'setup "the setup command failed" cmd r)))))

(define not-regular "is not a regular file: a link, a directory or nothing there")
(define (stray-entry name)
  (string-append name " is not ci.yml: the directory must hold ci.yml alone"))

(define (insert-after old new-lines) (e old (string-append old new-lines)))

;; The block scalar the rows plant their lines in: main's "Identify the runner
;; image" run block, which check-ci holds to no line. (The versions step's own
;; block is held line for line, so a planted line there is a problem of its own.)
(define id-line "          echo \"id=${ID}-${VERSION_ID}-${RUNNER_ARCH}\" >> \"$GITHUB_OUTPUT\"\n")
;; The text from main's first comment to the end of that block: it holds the
;; real file's one such text, which the other two jobs' copies of the block do not.
(define (id-span)
  (span "      # Every line with a uses key in this directory" id-line))
(define (in-id-block f)
  (let ((old (id-span))) (e old (f old))))
(define (after-id . ls)
  (in-id-block (lambda (old)
                 (string-append old (apply lines (map (lambda (l) (string-append "          " l)) ls))))))

(define inj-body "# ${{ fromJSON('\"\\necho MAKEFLAGS=-n >> \\\"$GITHUB_ENV\\\"\"') }}")
(define inj-line (string-append "          " inj-body))

(define step-keys-refused '("shell" "working-directory" "continue-on-error" "timeout-minutes"))
(define job-keys
  '("if" "needs" "continue-on-error" "strategy" "container" "services" "defaults"
    "env" "permissions" "outputs" "environment"))

(define banned-words
  '("MAKEFLAGS" "MFLAGS" "GNUMAKEFLAGS" "VALGRIND" "VALGRIND_OPTS" "VALGRIND_LIB"
    "MEMORY_SUITES" "MEMORY_TIMEOUT" "TEST_TIMEOUT" "LIBDIRS" "TIMEOUT" "SUITES"
    "CHEZ_SODIUM_LIBRARY" "CHEZ_SODIUM_GATE_CHILD"
    "CC" "C_INCLUDE_PATH" "CPATH" "LIBRARY_PATH" "LD_LIBRARY_PATH" "LD_PRELOAD" "CHECK_CI_ROOT"
    ;; the shard and its lists, and the pattern that holds them, MEMORY_*
    "MEMORY_SHARD" "MEMORY_SUITES_1" "MEMORY_LOGS"))

(define make-words
  '("check-help" "check-suites" "check-pins" "check-floors" "check-ci" "test"
    "check-test-fails" "check-dev" "check-clean"))

(define (without-word line word)
  (let* ((at (find-sub line (string-append " " word) 0)))
    (string-append (substring line 0 at)
                   (substring line (+ at 1 (string-length word)) (string-length line)))))

(define nt-restore-key
  "          key: chez-nothreads-${{ hashFiles('packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-chez.sh', 'scripts/ci/check-chez.sh') }}-${{ steps.image.outputs.id }}")
(define t-restore-key
  "          key: chez-threads-${{ hashFiles('packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-chez.sh', 'scripts/ci/check-chez.sh') }}-${{ steps.image.outputs.id }}")

(define hash-parts
  '("'packaging/floors.sexp', " ", 'scripts/ci/floor.sh'" ", 'scripts/ci/build-chez.sh'"
    ", 'scripts/ci/check-chez.sh'"))

;; The cache and build steps of a job, as the real file writes them: the
;; Chez cache's restore, build, save and check, as text.
(define (restore-hdr j) (if (string=? j "nothreads") "      - name: Restore Chez without threads" "      - name: Restore Chez"))
(define (build-hdr j) (if (string=? j "nothreads") "      - name: Build Chez without threads" "      - name: Build Chez"))
(define (save-hdr j) (if (string=? j "nothreads") "      - name: Save Chez without threads" "      - name: Save Chez"))
(define chk-hdr "      - name: Check the Chez this job runs")
(define (cache-dir j) (if (string=? j "nothreads") "chez-nothreads" "chez-threads"))
(define (cache-path-line j) (string-append "          path: ${{ runner.temp }}/" (cache-dir j)))
(define (bld-run j) (if (string=? j "nothreads") bld-n bld-t))
(define (chk-run j) (if (string=? j "nothreads") chk-n chk-t))
(define (restore-key-line j) (if (string=? j "nothreads") nt-restore-key t-restore-key))
(define restore-uses "        uses: actions/cache/restore@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0")
(define save-uses "        uses: actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0")
(define (restore-text j)
  (string-append (restore-hdr j) "\n        id: chez\n" restore-uses "\n        with:\n"
                 (cache-path-line j) "\n" (restore-key-line j) "\n"))
(define (build-text j)
  (string-append (build-hdr j) "\n        " if-line "\n        run: " (bld-run j) "\n"))
(define (save-text j)
  (string-append (save-hdr j) "\n        " if-line "\n" save-uses "\n        with:\n"
                 (cache-path-line j) "\n          key: " primary "\n"))
(define (chk-text j)
  (string-append chk-hdr "\n        run: " (chk-run j) "\n"))

;; --- a script named other than as the rule that holds its execute bit reads it -------------
;; Each row adds one step after the runner's libsodium report, whose run line
;; names a script of scripts/ci/ in one spelling the execute-bit rule does not
;; read. The step's other keys are free, so the planted line is its one problem.
;; (The spellings the rule does read, run: scripts/ci/NAME and run:
;; scripts/ci/NAME ARGS, are the rows of the execute bits, below.)

(define report-run "        run: scripts/ci/report-sodium.sh\n")

;; stray-row : String (Listof String) -> Row
;; An extra step of LINES, the first the row's anchor, and the problem on it.
(define (stray-row name . step-lines)
  (row name
       (list (insert-after report-run
                           (string-append "\n      - name: Extra\n" (apply lines step-lines))))
       (list (list (car step-lines) stray-msg))))

(define stray-rows
  (list
   (stray-row "a stray scripts/ci/ line: a double-quoted path"
              "        run: \"scripts/ci/extra.sh\"")
   (stray-row "a stray scripts/ci/ line: a single-quoted path"
              "        run: 'scripts/ci/extra.sh'")
   (stray-row "a stray scripts/ci/ line: two spaces after run:"
              "        run:  scripts/ci/extra.sh")
   (row "a stray scripts/ci/ line: a block scalar, run: |"
        (list (insert-after report-run "\n      - name: Extra\n        run: |\n          scripts/ci/extra.sh\n"))
        (list (list "          scripts/ci/extra.sh" stray-msg)))
   (row "a stray scripts/ci/ line: a block scalar, run: >-"
        (list (insert-after report-run "\n      - name: Extra\n        run: >-\n          scripts/ci/extra.sh\n"))
        (list (list "          scripts/ci/extra.sh" stray-msg)))
   (stray-row "a stray scripts/ci/ line: ./scripts/ci/NAME"
              "        run: ./scripts/ci/extra.sh")
   (stray-row "a stray scripts/ci/ line: scripts/ci//NAME"
              "        run: scripts/ci//extra.sh")
   (stray-row "a stray scripts/ci/ line: scripts/ci/sub/NAME"
              "        run: scripts/ci/sub/extra.sh")
   (stray-row "a stray scripts/ci/ line: NAME;true"
              "        run: scripts/ci/extra.sh;true")
   (stray-row "a stray scripts/ci/ line: NAME&&true"
              "        run: scripts/ci/extra.sh&&true")
   (stray-row "a stray scripts/ci/ line: after another command, true && scripts/ci/NAME"
              "        run: true && scripts/ci/extra.sh")
   (stray-row "a stray scripts/ line: scripts/./ci/NAME, which holds no scripts/ci/"
              "        run: scripts/./ci/extra.sh")
   (stray-row "a stray scripts/ line: scripts//ci/NAME, which holds no scripts/ci/"
              "        run: scripts//ci/extra.sh")))

;; --- the Chez cache and its build, in every job -------------------------------------------

(define (hdr-in j h text) (list 'in j h text))

(define (cache-rows j)
  (let ((restore (restore-text j)) (build (build-text j)) (save (save-text j)) (chk (chk-text j))
        (pfx (lambda (s) (string-append j ": " s))))
    (list
     (row (pfx "the Chez build deleted")
          (list (le j build ""))
          (list (list (string-append "  " j ":") (n-steps j (bld-run j) 0))))
     (row (pfx "the Chez build written twice")
          (list (le j build (string-append build "\n" build)))
          (list (list (string-append "  " j ":") (n-steps j (bld-run j) 2))))
     (row (pfx "the check-chez step deleted")
          (list (le j chk ""))
          (list (list (string-append "  " j ":") (n-steps j (chk-run j) 0))))
     (row (pfx "the Chez build without its if")
          (list (le j build (string-append (build-hdr j) "\n        run: " (bld-run j) "\n")))
          (list (list (hdr-in j #f (build-hdr j)) (step-no-if j (bld-run j)))))
     (row (pfx "the Chez build with another if")
          (list (le j build (string-append (build-hdr j) "\n        if: false\n        run: " (bld-run j) "\n")))
          (list (list "        if: false" (if-bad-for j))))
     (row (pfx "the Chez restore deleted")
          (list (le j restore ""))
          (list (list (string-append "  " j ":") (restores j 0))))
     (row (pfx "the Chez restore written twice")
          (list (le j restore (string-append restore "\n" restore)))
          (list (list (string-append "  " j ":") (restores j 2))))
     (row (pfx "the Chez save deleted")
          (list (le j save ""))
          (list (list (string-append "  " j ":") (saves j 0))))
     (row (pfx "the Chez save written twice")
          (list (le j save (string-append save "\n" save)))
          (list (list (string-append "  " j ":") (saves j 2))))
     (row (pfx "the restore's path is another")
          (list (le j restore (replace-first restore (cache-path-line j) "          path: /x")))
          (list (list (hdr-in j (restore-hdr j) "          path: /x")
                      (cache-path j (string-append "${{ runner.temp }}/" (cache-dir j))))))
     (row (pfx "the save's path is another")
          (list (le j save (replace-first save (cache-path-line j) "          path: /x")))
          (list (list (hdr-in j (save-hdr j) "          path: /x")
                      (cache-path j (string-append "${{ runner.temp }}/" (cache-dir j))))))
     (row (pfx "the restore's id is another")
          (list (le j restore (replace-first restore "        id: chez\n" "        id: other\n")))
          (list (list (hdr-in j (restore-hdr j) "        id: other") (restore-id j))))
     (row (pfx "the restore has no id")
          (list (le j restore (replace-first restore "        id: chez\n" "")))
          (list (list (hdr-in j #f (restore-hdr j)) (restore-id j))))
     (row (pfx "the save is keyed as a restore is")
          (list (le j save (replace-first save (string-append "          key: " primary)
                                          (restore-key-line j))))
          (list (list (hdr-in j (save-hdr j) (restore-key-line j)) (save-key j))))
     (row (pfx "the save has no key")
          (list (le j save (replace-first save (string-append "          key: " primary "\n") "")))
          (list (list (hdr-in j #f (save-hdr j)) (save-key j))))
     (row (pfx "the restore's key drops the prefix")
          (list (le j restore (replace-first restore (string-append "key: " (cache-dir j) "-") "key: ")))
          (list (list (hdr-in j (restore-hdr j) (replace-first (restore-key-line j) (string-append (cache-dir j) "-") ""))
                      (cache-key j (string-append (cache-dir j) "-")))))
     (row (pfx "the restore's key has a tail that is no suffix")
          (list (le j restore (replace-first restore "}}-${{" "}}x${{")))
          (list (list (hdr-in j (restore-hdr j) (replace-first (restore-key-line j) "}}-${{" "}}x${{"))
                      (cache-key j (string-append (cache-dir j) "-")))))
     (row (pfx "the restore's key is no expression at all")
          (list (le j restore (replace-first restore (restore-key-line j) "          key: static")))
          (list (list (hdr-in j (restore-hdr j) "          key: static")
                      (cache-key j (string-append (cache-dir j) "-")))))
     (row (pfx "the restore's key hashes one file more")
          (list (le j restore (replace-first restore "check-chez.sh')" "check-chez.sh', 'README.org')")))
          (list (list (hdr-in j (restore-hdr j) (replace-first (restore-key-line j) "check-chez.sh')" "check-chez.sh', 'README.org')"))
                      (cache-key j (string-append (cache-dir j) "-")))))
     (row (pfx "the restore's key takes the other Chez's prefix")
          (list (le j restore (replace-first restore (string-append "key: " (cache-dir j))
                                             (string-append "key: " (if (string=? j "nothreads") "chez-threads" "chez-nothreads")))))
          (list (list (hdr-in j (restore-hdr j)
                              (replace-first (restore-key-line j) (cache-dir j)
                                             (if (string=? j "nothreads") "chez-threads" "chez-nothreads")))
                      (cache-key j (string-append (cache-dir j) "-")))))
     (row (pfx "the restore moved below the build")
          (list (le j restore "")
                (le j build (string-append build "\n" restore)))
          (list (list (hdr-in j #f (restore-hdr j)) (restore-late j))))
     (row (pfx "the save moved above the build")
          (list (le j save "")
                (le j build (string-append save "\n" build)))
          (list (list (hdr-in j #f (save-hdr j)) (save-early j))))
     (row (pfx "the save moved below the check")
          (list (le j save "")
                (le j chk (string-append chk "\n" save)))
          (list (list (hdr-in j #f (save-hdr j)) (save-late j))))
     (row (pfx "the restore uses actions/cache, not actions/cache/restore")
          (list (le j restore (replace-first restore "actions/cache/restore@" "actions/cache@")))
          (list (list (hdr-in j #f (restore-hdr j))
                      (uses-msg j "actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9"))
                (list (string-append "  " j ":") (restores j 0))))
     (row (pfx "a step that uses another action")
          (list (le j chk (string-append chk "\n      - uses: actions/upload-artifact@3d3c42e5aac5ba805825da76410c181273ba90b1 # v4.0.0\n")))
          (list (list "      - uses: actions/upload-artifact@3d3c42e5aac5ba805825da76410c181273ba90b1 # v4.0.0"
                      (uses-msg j "actions/upload-artifact@3d3c42e5aac5ba805825da76410c181273ba90b1")))))))

(define (job-key-rows j)
  (let ((jl (string-append "  " j ":")))
    (append
     (list
      (row (string-append j ": the job's runs-on changes")
           (list (le j "    runs-on: ubuntu-24.04\n" "    runs-on: ubuntu-latest\n"))
           (list (list (hdr-in j #f "    runs-on: ubuntu-latest") (job-runs-on j))))
      (row (string-append j ": the job's timeout-minutes is no number")
           (list (le j (string-append "    timeout-minutes: " (if (string=? j "memory") "120" "60") "\n")
                     "    timeout-minutes: sixty\n"))
           (list (list (hdr-in j #f "    timeout-minutes: sixty") (job-timeout j))))
      (row (string-append j ": the job has no timeout-minutes")
           (list (le j (string-append "    timeout-minutes: " (if (string=? j "memory") "120" "60") "\n") ""))
           (list (list jl (job-no-key j "timeout-minutes"))))
      (row (string-append j ": the job has no name")
           (list (le j (string-append "    name: " (cond ((string=? j "main") "main (checks and suites, Chez built from source)")
                                                         ((string=? j "memory") "memory (the Valgrind gate)")
                                                         ((string=? j "floor") "floor (the suites against libsodium at its floor, built from source)")
                                                         ((string=? j "current") "current (the suites against libsodium at the current release, built from source)")
                                                         (else "nothreads (every library is refused on a Chez without threads)"))
                                      "\n") ""))
           (list (list jl (job-no-key j "name"))))
      (row (string-append j ": a job key twice")
           (list (le j "    runs-on: ubuntu-24.04\n" "    runs-on: ubuntu-24.04\n    runs-on: x\n"))
           (list (list (hdr-in j #f "    runs-on: x") (job-key-twice j "runs-on"))))
      (row (string-append j ": steps with a value where a block goes")
           (list (le j "    steps:\n" "    steps: x\n"))
           (list (list (hdr-in j #f "    steps: x") hasval-msg))))
     (map (lambda (k)
            (row (string-append j ": a job key " k)
                 (list (le j "    steps:\n" (string-append "    " k ": x\n    steps:\n")))
                 (list (list (hdr-in j #f (string-append "    " k ": x")) (job-key j k)))))
          job-keys))))

;; --- the steps that run make, and what each is held to ------------------------------------

;; (job header run chez-value): the five steps that run make or sh with Chez.
(define make-steps
  (list (list "main" install-hdr build-run chez-t)
        (list "main" disc-hdr disc-run chez-t)
        (list "main" "      - name: Checks and suites" make-line chez-t)
        (list "main" "      - name: The launcher's host-side tests" launcher chez-t)
        (list "memory" "      - name: The gate must fail on planted defects" gate-run chez-t)
        (list "memory" "      - name: Every suite under Valgrind" mem-run chez-t)
        (list "nothreads" "      - name: Every library must be refused, by name" nt-run chez-n)))

(define (env-text v) (string-append "        env:\n          CHEZ: " v "\n"))

(define (make-step-rows s)
  (let* ((j (car s)) (hdr (cadr s)) (run (caddr s)) (v (cadddr s))
         (other (if (string=? v chez-t) chez-n chez-t))
         (pfx (lambda (x) (string-append j ": the step that runs " run ": " x)))
         (old (string-append hdr "\n" (env-text v)))
         (stepline (lambda (l) (hdr-in j hdr l))))
    (list
     (row (pfx "its env dropped")
          (list (le j old (string-append hdr "\n")))
          (list (list (hdr-in j #f hdr) (env-missing j run))))
     (row (pfx "its CHEZ is the other Chez's")
          (list (le j old (string-append hdr "\n" (env-text other))))
          (list (list (stepline (string-append "          CHEZ: " other)) (env-chez j v))))
     (row (pfx "its env gains another key")
          (list (le j old (string-append old "          FOO: x\n")))
          (list (list (stepline "          FOO: x") (env-key "FOO"))))
     (row (pfx "its env names CHEZ twice")
          (list (le j old (string-append old "          CHEZ: x\n")))
          (list (list (stepline "          CHEZ: x") "env key \"CHEZ\" is written twice in one step")))
     (row (pfx "an if: always() on it")
          (list (le j old (string-append hdr "\n        if: always()\n" (env-text v))))
          (list (list (stepline "        if: always()") if-bad)
                (list (stepline "        if: always()") if-wrong)
                (list (stepline "        if: always()") (step-has-if j run))))
     (row (pfx "continue-on-error on it")
          (list (le j old (string-append hdr "\n        continue-on-error: true\n" (env-text v))))
          (list (list (stepline "        continue-on-error: true") (step-key "continue-on-error"))))
     (row (pfx "the cache's if on it")
          (list (le j old (string-append hdr "\n        " if-line "\n" (env-text v))))
          (list (list (stepline (string-append "        " if-line)) if-wrong)
                (list (stepline (string-append "        " if-line)) (step-has-if j run))))
     (row (pfx "its env names CC")
          (list (le j old (string-append old "          CC: gcc\n")))
          (list (list (stepline "          CC: gcc") (names-msg "CC"))
                (list (stepline "          CC: gcc") (env-key "CC")))))))

;; --- the whole list ---------------------------------------------------------------

(define mem-line "        run: make test-memory\n")
(define mem-name-line "    name: memory (the Valgrind gate)\n")

(define text-rows
  (list
   (row "the unedited file passes" '() '())

   ;; --- the spellings a text reader cannot see ---
   (row "a quoted key, \"if\": false"
        (list (e mem-line (string-append "        \"if\": false\n" mem-line)))
        (list (list "        \"if\": false" quoted-msg)))
   (row "a single-quoted key, 'if': false"
        (list (e mem-line (string-append "        'if': false\n" mem-line)))
        (list (list "        'if': false" quoted-msg)))
   (row "white space between a key and its colon, if : false"
        (list (e mem-line (string-append "        if : false\n" mem-line)))
        (list (list "        if : false" space-msg)))
   (row "an explicit key, ? if"
        (list (e mem-line (string-append "        ? if\n        : false\n" mem-line)))
        (list (list "        ? if" explicit-msg)
              (list "        : false" (step-key ""))))
   (row "an anchor where a key goes"
        (list (e mem-line (string-append "        &a if: false\n" mem-line)))
        (list (list "        &a if: false" alias-msg)))
   (row "an alias where a key goes"
        (list (e mem-line (string-append "        *a if: false\n" mem-line)))
        (list (list "        *a if: false" alias-msg)))
   (row "an anchor on a step's key, - &a uses: x"
        (list (insert-after "        run: scripts/ci/check-action-pins.sh .github/workflows\n"
                            "\n      - &a uses: owner/action@main\n"))
        (list (list "      - &a uses: owner/action@main" alias-msg)))
   (row "an unpinned action hidden by - ? uses / : owner/action@main"
        (list (insert-after "        run: scripts/ci/check-action-pins.sh .github/workflows\n"
                            "\n      - ? uses\n        : owner/action@main\n"))
        (list (list "      - ? uses" explicit-msg)
              (list "        : owner/action@main" (step-key ""))))
   (row "a flow mapping in a name"
        (list (e mem-name-line "    name: memory {the Valgrind gate}\n"))
        (list (list "    name: memory {the Valgrind gate}" flow-msg)))
   (row "a { inside a quoted scalar passes"
        (list (e mem-name-line "    name: \"memory {the Valgrind gate}\"\n"))
        '())
   (row "a backslash after a double quote"
        (list (e mem-name-line "    name: \"memory\\x2D\"\n"))
        (list (list "    name: \"memory\\x2D\"" bsq-msg)))
   (row "a quoted scalar left open"
        (list (e mem-name-line "    name: \"memory\n"))
        (list (list "    name: \"memory" openq-msg)))
   (row "a tab in a structural line"
        (list (e "main (checks and suites" "main\t(checks and suites"))
        (list (list "    name: main\t(checks and suites, Chez built from source)" tab-msg)))
   (row "a tab in a block scalar's content"
        (list (in-id-block (lambda (old) (replace-first old "id=$" "id=\t$"))))
        (list (list "          echo \"id=\t${ID}-${VERSION_ID}-${RUNNER_ARCH}\" >> \"$GITHUB_OUTPUT\"" tab-msg)))
   (row "a character beyond ASCII in a structural line"
        (list (e "main (checks and suites" "ma\x131;n (checks and suites"))
        (list (list "    name: ma\x131;n (checks and suites, Chez built from source)" odd-msg)))
   (row "a key spelled with a dotless i"
        (list (e mem-line (string-append "        \x131;f: false\n" mem-line)))
        (list (list "        \x131;f: false" odd-msg)))
   (row "a character beyond ASCII in a block scalar's content"
        (list (in-id-block (lambda (old) (replace-first old "id=$" "id=\xe9;$"))))
        (list (list "          echo \"id=\xe9;${ID}-${VERSION_ID}-${RUNNER_ARCH}\" >> \"$GITHUB_OUTPUT\"" odd-msg)))
   (row "a tab in a comment"
        (list (e "# One workflow, Linux only" "#\tOne workflow, Linux only"))
        (list (list "#\tOne workflow, Linux only, on a pinned runner image (ADR-0010, ADR-0011)." tab-msg)))
   (row "a tab in an indented comment"
        (list (e "      # The one package list." "      #\tThe one package list."))
        (list (list "      #\tThe one package list. A failed grep must not become an empty install." tab-msg)))
   (row "a line separator, U+2028, in a comment"
        (list (e "# What is deliberately not here:" "# What is deliberately not here:\x2028;"))
        (list (list "# What is deliberately not here:\x2028;" odd-msg)))
   ;; A line of a block scalar that begins with # is the script's text, not a
   ;; comment: GitHub expands its expressions, and the shell may run it.
   (row "a character beyond ASCII, U+0085, in a comment line of a run block"
        (list (after-id "# note\x85;"))
        (list (list "          # note\x85;" odd-msg)))
   (row "a line separator, U+2028, in a comment line of a run block"
        (list (after-id "# note\x2028;        if: false"))
        (list (list "          # note\x2028;        if: false" odd-msg)))
   (row "an expression in a comment line of a run block names GITHUB_ENV and MAKEFLAGS"
        (list (after-id inj-body))
        (list (list inj-line (names-msg "GITHUB_ENV"))
              (list inj-line (names-msg "MAKEFLAGS"))))
   (row "a comment line of a run block names a gate"
        (list (after-id "# make check-memory-gate"))
        (list (list "          # make check-memory-gate" (gate-msg "check-memory-gate"))))
   (row "a comment line of a run block names scripts/"
        (list (after-id "# scripts/ci/extra.sh"))
        (list (list "          # scripts/ci/extra.sh" stray-msg)))
   (row "a comment line of a run block that names nothing passes"
        (list (after-id "# a note"))
        '())
   (row "a comment that names GITHUB_ENV and MAKEFLAGS passes"
        (list (e "# One workflow, Linux only" "# One workflow, GITHUB_ENV and MAKEFLAGS, Linux only"))
        '())
   (row "key-looking lines inside a block scalar are content, and pass"
        (list (after-id "if: false" "? x" "\"q\": 1" "*a" "foo: {x}" "&b c: d"))
        '())
   (row "a line dedented out of a block scalar is read again"
        (list (in-id-block (lambda (old) (string-append old "        shell: bash\n"))))
        (list (list "        shell: bash" (step-key "shell"))))

   ;; --- the names no line may hold ---
   (row "GITHUB_ENV written as MAKE\"\"FLAGS"
        (list (after-id "echo \"MAKE\"\"FLAGS=-i\" >> \"$GITHUB_ENV\""))
        (list (list "          echo \"MAKE\"\"FLAGS=-i\" >> \"$GITHUB_ENV\"" (names-msg "GITHUB_ENV"))))
   (row "GITHUB_PATH in a block scalar"
        (list (after-id "echo /x >> \"$GITHUB_PATH\""))
        (list (list "          echo /x >> \"$GITHUB_PATH\"" (names-msg "GITHUB_PATH"))))
   (row "a word of the allowed set, SUITES_X, is no name held"
        (list (after-id "echo SUITES_X MAKEFLAGSX timeout"))
        '())
   (row "CHEZ_SODIUM_LIBRARY at the workflow's top level"
        (list (e "permissions:\n  contents: read\n"
                 "env:\n  CHEZ_SODIUM_LIBRARY: /x\npermissions:\n  contents: read\n"))
        (list (list "env:" (top-unknown "env"))
              (list "  CHEZ_SODIUM_LIBRARY: /x" (names-msg "CHEZ_SODIUM_LIBRARY"))))
   (row "CHEZ_SODIUM_LIBRARY in a step's env"
        (list (insert-after (string-append "      - name: Every suite under Valgrind\n" (env-text chez-t))
                            "          CHEZ_SODIUM_LIBRARY: /x\n"))
        (list (list "          CHEZ_SODIUM_LIBRARY: /x" (names-msg "CHEZ_SODIUM_LIBRARY"))
              (list "          CHEZ_SODIUM_LIBRARY: /x" (env-key "CHEZ_SODIUM_LIBRARY"))))))

(define word-rows
  (append
   (map (lambda (w)
          (row (string-append "a block scalar names " w)
               (list (after-id (string-append "echo " w)))
               (list (list (string-append "          echo " w) (names-msg w)))))
        banned-words)
   (map (lambda (w)
          (row (string-append "a block scalar names " w ", a gate")
               (list (after-id (string-append "echo " w)))
               (list (list (string-append "          echo " w) (gate-msg w)))))
        '("check-memory-gate" "test-memory" "check-nothreads"))))

(define top-rows
  (list
   (row "the on block gets a path filter"
        (list (e "  pull_request:\n" "  pull_request:\n    paths: [src/**]\n"))
        (list (list "    paths: [src/**]"
                    (block-differs "on" "  workflow_dispatch:" "    paths: [src/**]"))))
   (row "the on block gets another trigger"
        (list (insert-after "  workflow_dispatch:\n" "  workflow_run:\n"))
        (list (list "  workflow_run:" (block-extra "on" "  workflow_run:"))))
   (row "the on block loses a trigger"
        (list (e "  workflow_dispatch:\n" ""))
        (list (list "  pull_request:" "the \"on\" block ends early: expected \"  workflow_dispatch:\"")))
   (row "the permissions widen"
        (list (e "  contents: read\n" "  contents: write\n"))
        (list (list "  contents: write" (block-differs "permissions" "  contents: read" "  contents: write"))))
   (row "the concurrency group changes"
        (list (e "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}\n"
                 "  cancel-in-progress: false\n"))
        (list (list "  cancel-in-progress: false"
                    (block-differs "concurrency"
                                   "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}"
                                   "  cancel-in-progress: false"))))
   (row "a top-level defaults"
        (list (e "permissions:\n" "defaults:\n  run:\n    shell: bash\npermissions:\n"))
        (list (list "defaults:" (top-unknown "defaults"))))
   (row "a top-level key twice"
        (list (e "name: CI\n" "name: CI\nname: CI\n"))
        (list (list '("name: CI" 2) (top-twice "name"))))
   (row "permissions after concurrency"
        (list (e "permissions:\n  contents: read\n" "")
              (insert-after "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}\n"
                            "permissions:\n  contents: read\n"))
        (list (list "permissions:" (top-order "permissions"))))
   (row "no jobs key"
        (list (e "jobs:\n" "jobz:\n"))
        (append
         (list (list "jobz:" (top-unknown "jobz"))
               (list "        run: make check-memory-gate" (gate-msg "check-memory-gate"))
               (list "        run: make test-memory" (gate-msg "test-memory"))
               (list "        run: make check-nothreads" (gate-msg "check-nothreads")))
         (lane-name-problems "floor")
         (lane-name-problems "current")
         (list (list 'eof (top-missing "jobs")))))

   ;; --- jobs ---
   (row "the nothreads job deleted"
        (list (e (span "  nothreads:\n    name:" "run: make check-nothreads\n") ""))
        (list (list "jobs:" (job-missing "nothreads"))))
   (row "the memory job deleted"
        (list (e (span "  memory:\n    name:" "run: make test-memory\n\n") ""))
        (list (list "jobs:" (job-missing "memory"))))
   (row "the main job deleted"
        (list (e (span "  main:\n    name:" "run: sh tests/guix-env-launcher.sh\n\n") ""))
        (list (list "jobs:" (job-missing "main"))))
   (row "a job added"
        (list (insert-after "        run: make check-nothreads\n"
                            (string-append "\n" (lines "  extra:" "    name: x" "    runs-on: ubuntu-24.04"
                                                       "    timeout-minutes: 5" "    steps:" "      - run: echo hi"))))
        (list (list "  extra:" (job-unknown "extra"))))
   (row "a job twice"
        (list (e "  nothreads:\n" "  main:\n    name: x\n  nothreads:\n"))
        (list (list '("  main:" 2) "job \"main\" is written twice")))))

;; main's own steps, in the order of the file.
(define main-rows
  (list
   (row "main's pin step deleted"
        (list (e (span "      # Every line with a uses key in this directory"
                       "run: scripts/ci/check-action-pins.sh .github/workflows\n\n")
                 ""))
        (list (list (list 'after "  main:" "      - name: Install the packages in packaging/debian-prereqs.txt")
                    second-step-msg)))
   (row "main's pin step moved after the install step"
        (list (e (span "      # Every line with a uses key in this directory"
                       "run: scripts/ci/check-action-pins.sh .github/workflows\n\n")
                 "")
              (le "main" (restore-text "main") (string-append (restore-text "main") "\n      - name: Every action is pinned to a commit\n        run: " pin-run "\n")))
        (list (list (list 'after "  main:" "      - name: Install the packages in packaging/debian-prereqs.txt")
                    second-step-msg)))
   (row "main's checkout without submodules"
        (list (le "main" "        with:\n          submodules: recursive\n\n      # Every line" "\n      # Every line"))
        (list (list (hdr-in "main" #f checkout-line) (first-step-msg "main"))))
   (row "main's checkout with submodules: false"
        (list (le "main" "          submodules: recursive\n\n      # Every line" "          submodules: false\n\n      # Every line"))
        (list (list (hdr-in "main" #f checkout-line) (first-step-msg "main"))))
   (row "main's launcher step deleted"
        (list (e (span "      # The launcher's own tests run no Guix" "run: sh tests/guix-env-launcher.sh\n") ""))
        (list (list "  main:" (n-steps "main" launcher 0))))
   (row "main's launcher step before the checks"
        (list (e (span "      # The launcher's own tests run no Guix" "run: sh tests/guix-env-launcher.sh\n") "")
              (e "      # CHEZ is the real binary" (string-append "      - name: The launcher's host-side tests\n" (env-text chez-t) "        run: sh tests/guix-env-launcher.sh\n\n      # CHEZ is the real binary")))
        (list (list "        run: sh tests/guix-env-launcher.sh" (out-of-order "main" launcher make-line))))
   (row "main's install check deleted"
        (list (e (string-append (install-step) "\n") ""))
        (list (list "  main:" (n-steps "main" build-run 0))))
   (row "main's install check written twice"
        (list (e (string-append (install-step) "\n")
                 (string-append (install-step) "\n" (install-step) "\n")))
        (list (list "  main:" (n-steps "main" build-run 2))))
   (row "main's install check moved after Checks and suites"
        (list (e (string-append (install-step) "\n") "")
              (e (make-run) (string-append (make-run) "\n" (install-step))))
        ;; the discovery step, which must follow the install check, is out of order too
        (list (list "        run: scripts/ci/check-sodium.sh --discovery" (out-of-order "main" disc-run build-run))
              (list (string-append "        run: " make-line) (out-of-order "main" make-line build-run))))
   (row "main's install check moved before Check the Chez"
        (list (e (string-append (install-step) "\n") "")
              (le "main" (main-chk-step) (string-append (install-step) "\n" (main-chk-step))))
        (list (list (hdr-in "main" #f build-line) (out-of-order "main" build-run chk-t))))
   (row "main's install check with an argument, make build X"
        (list (le "main" "        run: make build\n" "        run: make build X\n"))
        (list (list "  main:" (n-steps "main" build-run 0))))
   (row "main's install check as a block scalar"
        (list (le "main" "        run: make build\n" "        run: |\n          make build\n"))
        (list (list "  main:" (n-steps "main" build-run 0))))
   (row "main's make line with an argument"
        (list (e (make-run) (string-append "        run: " make-line " build\n")))
        (list (list "  main:" (n-steps "main" make-line 0))))
   (row "main's make line as a block scalar"
        (list (e (make-run) (string-append "        run: |\n          " make-line "\n")))
        (list (list "  main:" (n-steps "main" make-line 0))))
   (row "main's make line replaced by make build: the install check is then written twice, and no step runs the make line"
        (list (e (make-run) (string-append "        run: make build\n")))
        (list (list "  main:" (n-steps "main" build-run 2))
              (list "  main:" (n-steps "main" make-line 0))))))

(define make-word-rows
  (map (lambda (w)
         (row (string-append "main's make line without " w)
              (list (e (make-run) (string-append "        run: " (without-word make-line w) "\n")))
              (list (list "  main:" (n-steps "main" make-line 0)))))
       make-words))

;; main's report steps.
(define report-rows
  (list
   (row "the versions step deleted"
        (list (e (string-append (vers-step) "\n") ""))
        (list (list "  main:" (named-n vers-name 0))))
   (row "the libsodium step deleted"
        (list (e (string-append (sod-step) "\n") ""))
        (list (list "  main:" (named-n sod-name 0))))
   (row "both report steps deleted"
        (list (e (string-append (vers-step) "\n") "")
              (e (string-append (sod-step) "\n") ""))
        (list (list "  main:" (named-n vers-name 0))
              (list "  main:" (named-n sod-name 0))))
   (row "the versions step renamed"
        (list (e vers-hdr "      - name: Report the version this run uses"))
        (list (list "  main:" (named-n vers-name 0))))
   (row "the libsodium step renamed"
        (list (e sod-hdr "      - name: Report the libsodium"))
        (list (list "  main:" (named-n sod-name 0))))
   (row "the versions step written twice"
        (list (e (string-append (vers-step) "\n") (string-append (vers-step) "\n" (vers-step) "\n")))
        (list (list "  main:" (named-n vers-name 2))))
   (row "the two report steps swapped"
        (list (e (string-append (vers-step) "\n" (sod-step))
                 (string-append (sod-step) "\n" (vers-step))))
        (list (list sod-hdr swapped-msg)))
   (row "the versions step moved after Checks and suites"
        (list (e (string-append (vers-step) "\n") "")
              (e (make-run) (string-append (make-run) "\n" (vers-step))))
        (list (list vers-hdr (runs-after vers-name make-line))
              (list sod-hdr swapped-msg)))
   (row "the libsodium step moved after Checks and suites"
        (list (e (string-append (sod-step) "\n") "")
              (e (make-run) (string-append (make-run) "\n" (sod-step))))
        (list (list sod-hdr (runs-after sod-name make-line))))
   (row "the versions step moved before Check the Chez"
        (list (e (string-append (chk-text "main") "\n" (vers-step))
                 (string-append (vers-step) "\n" (chk-text "main"))))
        (list (list vers-hdr (runs-before vers-name chk-t))))
   (row "the libsodium step moved before Check the Chez"
        (list (e (string-append (sod-step) "\n") "")
              (e (string-append (chk-text "main") "\n" (vers-step))
                 (string-append (sod-step) "\n" (chk-text "main") "\n" (vers-step))))
        (list (list sod-hdr (runs-before sod-name chk-t))
              (list sod-hdr swapped-msg)))
   (row "a line at the start of the versions block"
        (list (e (string-append vers-l1 "\n") (string-append "          echo x\n" vers-l1 "\n")))
        (list (list "          echo x" (vers-differs vers-l1 "          echo x"))))
   (row "a line in the middle of the versions block"
        (list (e (string-append vers-l2 "\n") (string-append vers-l2 "\n          echo x\n")))
        (list (list "          echo x" (vers-differs vers-l3 "          echo x"))))
   (row "a line at the end of the versions block"
        (list (e (string-append vers-l5 "\n") (string-append vers-l5 "\n          echo x\n")))
        (list (list "          echo x" (vers-extra "          echo x"))))
   (row "a comment at the end of the versions block"
        (list (e (string-append vers-l5 "\n") (string-append vers-l5 "\n          # x\n")))
        (list (list "          # x" (vers-extra "          # x"))))
   (row "a line removed from the middle of the versions block"
        (list (e (string-append vers-l3 "\n") ""))
        (list (list vers-l4 (vers-differs vers-l3 vers-l4))))
   (row "the last line removed from the versions block"
        (list (e (string-append vers-l5 "\n") ""))
        (list (list vers-l4 (vers-early vers-l5))))
   (row "a line of the versions block changed"
        (list (e vers-l2 "          cc --version | head -n 2"))
        (list (list "          cc --version | head -n 2"
                    (vers-differs vers-l2 "          cc --version | head -n 2"))))
   (row "a line of the versions block re-indented"
        (list (e vers-l3 "            valgrind --version"))
        (list (list "            valgrind --version" (vers-differs vers-l3 "            valgrind --version"))))
   (row "the versions block clipped, run: |-"
        (list (e (span (string-append vers-hdr "\n") "run: |\n")
                 (string-append vers-hdr "\n        run: |-\n")))
        (list (list "        run: |-" not-block-msg)))
   (row "the libsodium step's run line changed"
        (list (e (string-append "run: " sod-run "\n") (string-append "run: " sod-run " --x\n")))
        (list (list (string-append "        run: " sod-run " --x") sod-run-msg)))
   (row "the libsodium step gains an if"
        (list (e sod-hdr (string-append sod-hdr "\n        if: always()")))
        (list (list "        if: always()" if-bad)
              (list "        if: always()" if-wrong)))))

;; the memory job's two commands, bare and in order.
(define memory-rows
  (list
   (row "memory's gate step deleted"
        (list (e (span "      # The gate proves nothing unless it can fail" "run: make check-memory-gate\n\n") ""))
        (list (list "  memory:" (n-steps "memory" gate-run 0))))
   (row "memory's test-memory step deleted"
        (list (e (span "      - name: Every suite under Valgrind" "run: make test-memory\n") ""))
        (list (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "memory's two steps swapped: test-memory first"
        (list (e (span "      # The gate proves nothing unless it can fail" "run: make check-memory-gate\n\n") "")
              (e mem-line
                 (string-append mem-line "\n      - name: The gate must fail on planted defects\n" (env-text chez-t)
                                "        run: make check-memory-gate\n")))
        (list (list "        run: make test-memory" (out-of-order "memory" mem-run gate-run))))
   (row "memory's gate step with an argument"
        (list (e "        run: make check-memory-gate\n" "        run: make check-memory-gate X\n"))
        (list (list "        run: make check-memory-gate X" (gate-msg "check-memory-gate"))
              (list "  memory:" (n-steps "memory" gate-run 0))))
   (row "memory's test-memory step with a suite list"
        (list (e mem-line "        run: make test-memory MEMORY_SUITES=tests/test-a.sps\n"))
        (list (list "        run: make test-memory MEMORY_SUITES=tests/test-a.sps" (names-msg "MEMORY_SUITES"))
              (list "        run: make test-memory MEMORY_SUITES=tests/test-a.sps" (gate-msg "test-memory"))
              (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "memory's test-memory step with a shard"
        (list (e mem-line "        run: make test-memory MEMORY_SHARD=1\n"))
        (list (list "        run: make test-memory MEMORY_SHARD=1" (names-msg "MEMORY_SHARD"))
              (list "        run: make test-memory MEMORY_SHARD=1" (gate-msg "test-memory"))
              (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "memory's test-memory step with a Valgrind option"
        (list (e mem-line "        run: make test-memory VALGRIND=true\n"))
        (list (list "        run: make test-memory VALGRIND=true" (names-msg "VALGRIND"))
              (list "        run: make test-memory VALGRIND=true" (gate-msg "test-memory"))
              (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "memory's test-memory step with a timeout"
        (list (e mem-line "        run: make test-memory MEMORY_TIMEOUT=9999\n"))
        (list (list "        run: make test-memory MEMORY_TIMEOUT=9999" (names-msg "MEMORY_TIMEOUT"))
              (list "        run: make test-memory MEMORY_TIMEOUT=9999" (gate-msg "test-memory"))
              (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "a trailing comment on memory's test-memory line"
        (list (e mem-line "        run: make test-memory # x\n"))
        (list (list "        run: make test-memory # x" (gate-msg "test-memory"))
              (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "memory's test-memory line as a block scalar"
        (list (e mem-line "        run: |\n          make test-memory\n"))
        (list (list "          make test-memory" (gate-msg "test-memory"))
              (list "  memory:" (n-steps "memory" mem-run 0))))
   (row "memory's gate line in the wrong job"
        (list (e "        run: make check-nothreads\n" "        run: make check-memory-gate\n"))
        (list (list '("        run: make check-memory-gate" 2) (gate-msg "check-memory-gate"))
              (list "  nothreads:" (n-steps "nothreads" nt-run 0))))
   (row "a run block in memory that names the gate"
        (list (le "memory" "      # The gate proves nothing unless it can fail"
                  "      - name: sneak\n        run: |\n          make check-memory-gate\n\n      # The gate proves nothing unless it can fail"))
        (list (list "          make check-memory-gate" (gate-msg "check-memory-gate"))))
   (row "VALGRIND_OPTS written through GITHUB_ENV"
        (list (after-id "echo VALGRIND_OPTS=--x >> \"$GITHUB_ENV\""))
        (list (list "          echo VALGRIND_OPTS=--x >> \"$GITHUB_ENV\"" (names-msg "GITHUB_ENV"))
              (list "          echo VALGRIND_OPTS=--x >> \"$GITHUB_ENV\"" (names-msg "VALGRIND_OPTS"))))
   (row "MAKEFLAGS in memory's gate step's env"
        (list (insert-after (string-append "      - name: The gate must fail on planted defects\n" (env-text chez-t))
                            "          MAKEFLAGS: -i\n"))
        (list (list "          MAKEFLAGS: -i" (names-msg "MAKEFLAGS"))
              (list "          MAKEFLAGS: -i" (env-key "MAKEFLAGS"))))
   (row "memory's checkout without submodules"
        (list (le "memory" "        with:\n          submodules: recursive\n\n" "\n"))
        (list (list (hdr-in "memory" #f checkout-line) (first-step-msg "memory"))))
   (row "memory's checkout with submodules: false"
        (list (le "memory" "          submodules: recursive\n" "          submodules: false\n"))
        (list (list (hdr-in "memory" #f checkout-line) (first-step-msg "memory"))))))

(define nothreads-rows
  (list
   (row "nothreads's check-chez without --nothreads"
        (list (e (string-append "run: " chk-n "\n")
                 (string-append "run: scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-nothreads\"\n")))
        (list (list "  nothreads:" (n-steps "nothreads" chk-n 0))))
   (row "nothreads's build without --nothreads"
        (list (e (string-append "run: " bld-n "\n")
                 (string-append "run: scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-nothreads\"\n")))
        (list (list "  nothreads:" (n-steps "nothreads" bld-n 0))))
   (row "nothreads's check-nothreads step deleted"
        (list (e (span "      # No submodules, no deps" "run: make check-nothreads\n") ""))
        (list (list "  nothreads:" (n-steps "nothreads" nt-run 0))))
   (row "nothreads's check-nothreads before its check-chez"
        (list (e (span "      # No submodules, no deps" "run: make check-nothreads\n") "")
              (e (chk-text "nothreads")
                 (string-append "      - name: Every library must be refused, by name\n" (env-text chez-n)
                                "        run: make check-nothreads\n\n" (chk-text "nothreads"))))
        (list (list "        run: make check-nothreads" (out-of-order "nothreads" nt-run chk-n))))
   (row "nothreads's CHEZ is main's"
        (list (e (string-append "      - name: Every library must be refused, by name\n" (env-text chez-n))
                 (string-append "      - name: Every library must be refused, by name\n" (env-text chez-t))))
        (list (list (list 'after "      - name: Every library must be refused, by name"
                          (string-append "          CHEZ: " chez-t))
                    (env-chez "nothreads" chez-n))))))

(define step-key-rows
  (append
   (map (lambda (k)
          (row (string-append "a step key " k)
               (list (e "        run: make check-nothreads\n"
                        (string-append "        " k ": x\n        run: make check-nothreads\n")))
               (list (list (string-append "        " k ": x") (step-key k)))))
        step-keys-refused)
   (list
    (row "a with key outside the three"
         (list (le "nothreads" (string-append checkout-line "\n")
                   (string-append checkout-line "\n        with:\n          ref: x\n")))
         (list (list "          ref: x" (with-key "ref"))))
    (row "a flow mapping under with"
         (list (le "nothreads" (string-append checkout-line "\n")
                   (string-append checkout-line "\n        with: {ref: x}\n")))
         (list (list "        with: {ref: x}" flow-msg)))
    (row "an env key besides CHEZ, in nothreads"
         (list (le "nothreads" (env-text chez-n) (string-append (env-text chez-n) "          FOO: x\n")))
         (list (list "          FOO: x" (env-key "FOO"))))
    (row "a with key twice"
         (list (le "nothreads" (string-append checkout-line "\n")
                   (string-append checkout-line "\n        with:\n          ref: x\n          ref: y\n")))
         (list (list "          ref: x" (with-key "ref"))
               (list "          ref: y" (with-key "ref")))))))

;; --- spellings of the structure check-ci reads, one fault each -----------------------------

(define nt-run-line "        run: make check-nothreads\n")

(define structure-rows
  (list
   (row "a step key written twice"
        (list (le "nothreads" nt-run-line (string-append nt-run-line nt-run-line)))
        (list (list '("        run: make check-nothreads" 2) "step key \"run\" is written twice in one step")))
   (row "a with key written twice"
        (list (le "main" "          submodules: recursive\n\n      # Every line"
                  "          submodules: recursive\n          submodules: false\n\n      # Every line"))
        (list (list "          submodules: false" "with key \"submodules\" is written twice in one step")))
   (row "a with holding a value"
        (list (le "nothreads" (string-append checkout-line "\n") (string-append checkout-line "\n        with: x\n")))
        (list (list "        with: x" hasval-msg)))
   (row "an env holding a value"
        (list (le "nothreads" (env-text chez-n) "        env: x\n"))
        (list (list "        env: x" hasval-msg)
              (list (hdr-in "nothreads" #f "      - name: Every library must be refused, by name")
                    (env-missing "nothreads" nt-run))))
   (row "a step line with no colon"
        (list (le "nothreads" nt-run-line (string-append nt-run-line "        junk\n")))
        (list (list "        junk" (string-append "is not a key line check-ci reads"))))
   (row "a job line with no colon"
        (list (le "nothreads" "    steps:\n" "    junk\n    steps:\n"))
        (list (list "    junk" "is not a key line check-ci reads")))
   (row "a job header line with no colon"
        (list (e "  nothreads:\n" "  junk\n  nothreads:\n"))
        (list (list "  junk" "is not a key line check-ci reads")))
   (row "a top-level line with no colon"
        (list (e "permissions:\n" "junk\npermissions:\n"))
        (list (list "junk" "is not a key line check-ci reads")))
   (row "a line indented where no key is read"
        (list (le "nothreads" nt-run-line (string-append nt-run-line "          x: y\n")))
        (list (list "          x: y" place-msg)))
   (row "an escaped quote does not end a quoted scalar: the { after it is quoted, and only the backslash is named"
        (list (e mem-name-line "    name: \"a\\\"{b\"\n"))
        (list (list "    name: \"a\\\"{b\"" bsq-msg)))
   (row "a key line that names scripts/ outside a hashFiles list"
        (list (le "nothreads" (string-append checkout-line "\n") (string-append checkout-line "\n        with:\n          key: scripts/ci/x\n")))
        (list (list "          key: scripts/ci/x" stray-msg)))
   (row "a with line with no colon"
        (list (le "nothreads" (string-append checkout-line "\n") (string-append checkout-line "\n        with:\n          junk\n")))
        (list (list "          junk" "is not a key line check-ci reads")))
   (row "a step key outside any step"
        (list (le "nothreads" "    steps:\n" "    steps:\n        run: x\n"))
        (list (list "        run: x" place-msg)))
   (row "main's checkout with an if"
        (list (le "main" (string-append checkout-line "\n        with:\n          submodules: recursive\n")
                  (string-append checkout-line "\n        if: always()\n        with:\n          submodules: recursive\n")))
        (list (list "        if: always()" if-bad)
              (list "        if: always()" if-wrong)
              (list (hdr-in "main" #f checkout-line) (first-step-msg "main"))))
   (row "main's checkout with a run"
        (list (le "main" (string-append checkout-line "\n        with:\n          submodules: recursive\n")
                  (string-append checkout-line "\n        run: echo hi\n        with:\n          submodules: recursive\n")))
        (list (list (hdr-in "main" #f checkout-line) (first-step-msg "main"))))
   (row "main's second step with an if"
        (list (e "      - name: Every action is pinned to a commit\n        run: scripts/ci/check-action-pins.sh .github/workflows\n"
                 "      - name: Every action is pinned to a commit\n        run: scripts/ci/check-action-pins.sh .github/workflows\n        if: false\n"))
        (list (list "        if: false" if-bad)
              (list "        if: false" if-wrong)))))

;; --- the directory and the arguments ---------------------------------------------------

(define directory-rows
  (list
   (row/setup "a second workflow in the directory" (add-file "pages.yml") '()
              (list (list 'dir (stray-entry "pages.yml"))))
   (row/setup "a hidden file in the directory" (add-file ".hidden") '()
              (list (list 'dir (stray-entry ".hidden"))))
   (row/setup "a subdirectory in the directory"
              (lambda (dir) (mkdir (string-append dir "/sub"))) '()
              (list (list 'dir (stray-entry "sub"))))
   (row/setup "ci.yml is a link"
              (in-dir "mv ci.yml real.yml.tmp && ln -s real.yml.tmp ci.yml")
              '()
              (list (list 'file not-regular)
                    (list 'dir (stray-entry "real.yml.tmp"))))
   (row/setup "a file named ..odd" (add-file "..odd") '()
              (list (list 'dir (stray-entry "..odd"))))
   (row/setup "a second file named ci.yml, a newline, other.yml" (add-file "ci.yml\nother.yml") '()
              (list (list 'dir (stray-entry "ci.yml?other.yml"))))
   (row/setup "ci.yml is named ci.yaml" (in-dir "mv ci.yml ci.yaml") '()
              (list (list 'file not-regular)
                    (list 'dir (stray-entry "ci.yaml"))))))

;; --- the lanes: floor and current ----------------------------------------------------
;; Each lane builds one libsodium (scripts/ci/build-sodium.sh), checks it, and
;; runs make build and make test against it. The steps that run the check,
;; make build and make test carry that build's library and header directory,
;; exactly, beside CHEZ; no other step of any job carries either name.

(define (lane-floor? j) (string=? j "floor"))
(define (lane-where j) (if (lane-floor? j) "at its floor" "at the current release"))
(define (lane-flag j) (if (lane-floor? j) "" " --current"))
(define (sod-sq j) (string-append "${{ runner.temp }}/sodium-" j))
(define (sod-so j) (if (lane-floor? j) "23" "26"))
(define (sod-lib* j so) (string-append (sod-sq j) "/lib/libsodium.so." so))
(define (sod-lib j) (sod-lib* j (sod-so j)))
(define (sod-inc j) (string-append (sod-sq j) "/include"))
(define (other-lane j) (if (lane-floor? j) "current" "floor"))
(define (bld* j flag)
  (string-append "scripts/ci/build-sodium.sh \"$RUNNER_TEMP/sodium-" j "\"" flag))
(define (chk* j flag)
  (string-append "scripts/ci/check-sodium.sh \"$RUNNER_TEMP/sodium-" j "\"" flag))
(define (lane-bld j) (bld* j (lane-flag j)))
(define (lane-chk j) (chk* j (lane-flag j)))
(define cc-line
  "echo \"id=$(cc --version | head -n 1 | tr -c '[:alnum:].' '-')\" >> \"$GITHUB_OUTPUT\"")
(define (lane-hash j)
  (if (lane-floor? j)
      "'packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-sodium.sh', 'scripts/ci/check-sodium.sh'"
      "'scripts/ci/build-sodium.sh', 'scripts/ci/check-sodium.sh'"))
(define (lane-key j)
  (string-append "sodium-" j "-${{ hashFiles(" (lane-hash j) ") }}-${{ steps.image.outputs.id }}-${{ steps.cc.outputs.id }}"))
(define (key-line k) (string-append "          key: " k))
(define (path-line p) (string-append "          path: " p))
(define (env-line k v) (string-append "          " k ": " v))

(define h-install-pk "Install the packages in packaging/debian-prereqs.txt")
(define h-image "Identify the runner image")
(define h-restore-chez "Restore Chez")
(define h-build-chez "Build Chez")
(define h-save-chez "Save Chez")
(define h-chk-chez "Check the Chez this job runs")
(define h-cc "Name the C compiler for the cache key")
(define (h-restore j) (string-append "Restore libsodium " (lane-where j)))
(define (h-build j) (string-append "Build libsodium " (lane-where j)))
(define (h-save j) (string-append "Save libsodium " (lane-where j)))
(define h-chk "Check the libsodium this job runs")
(define (h-load j) (string-append "Load libsodium " (lane-where j)))
(define (h-suites j) (string-append "The suites against libsodium " (lane-where j)))
(define (hdr-line h) (string-append "      - name: " h))

;; to-end : String -> String
;; The real file from the one START to its end.
(define (to-end start)
  (unless (= (count-sub real start) 1) (error 'to-end "the start must occur once" start))
  (substring real (find-sub real start 0) (string-length real)))

;; between : String String -> String
;; The real file from the one START up to, not including, the one END after it.
(define (between start end)
  (let* ((s (find-sub real start 0)) (t (and s (find-sub real end s))))
    (unless (and s t (= (count-sub real start) 1)) (error 'between "markers" start end))
    (substring real s t)))

;; lane-step : String String -> String
;; The text of one step of a job, its header line to its last line.
(define (lane-step j h)
  (let* ((rt (job-text real j))
         (hl (string-append (hdr-line h) "\n"))
         (s (find-sub rt hl 0)))
    (unless (and s (= (count-sub rt hl) 1)) (error 'lane-step "no such step, or twice" j h))
    (let ((end (find-sub rt "\n\n" s)))
      (substring rt s (if end (+ end 1) (string-length rt))))))

;; se : String String String String -> Edit
;; In one step of one job, OLD becomes NEW.
(define (se j h old new)
  (let ((st (lane-step j h)))
    (unless (= (count-sub st old) 1) (error 'se "the old text is not once in the step" j h old))
    (le j st (replace-first st old new))))

;; del-step : String String -> Edit
;; The step and the blank line after it, or before it for the job's last.
(define (del-step j h)
  (let ((st (lane-step j h)))
    (if (find-sub (job-text real j) (string-append st "\n") 0)
        (le j (string-append st "\n") "")
        (le j (string-append "\n" st) ""))))

;; A : String (U String #f) String -> Anchor
(define (A j h text) (list 'in j h text))

(define if-chez if-line)
(define if-sod if-sod-line)
(define chez-if-wrong
  "the Chez cache's if is on a step that is neither the Chez build nor the Chez cache's save")
(define sod-if-wrong
  "the libsodium cache's if is on a step that is neither the libsodium build nor the libsodium cache's save")
(define (path-msg j) (cache-path j "${{ runner.temp }}/chez-threads"))
(define (restores-msg j n)
  (string-append "job " j " has " (number->string n) " restores of the libsodium cache, not one"))
(define (saves-msg j n)
  (string-append "job " j " has " (number->string n) " saves of the libsodium cache, not one"))
(define (sod-restore-id-msg j)
  (string-append "the libsodium cache's restore in job " j " is not id: sodium"))
(define (sod-key-msg j) (string-append "the cache key in job " j " is not exactly " (lane-key j)))
(define (sod-save-key-msg j id)
  (string-append "the cache key of the save in job " j " is not exactly ${{ steps." id ".outputs.cache-primary-key }}"))
(define (lane-env-key k)
  (string-append "env key \"" k "\" is not one of CHEZ, CHEZ_SODIUM_LIBRARY, C_INCLUDE_PATH"))
(define (env-value j k v) (string-append "env " k " in job " j " is not " v))
(define (env-wrong-step k)
  (string-append "env key \"" k "\" is only for the steps that run the libsodium check, make build and make test"))
(define (env-missing3 j run k)
  (string-append "job " j "'s step that runs \"" run "\" has no env " k))
(define (cc-id-msg j) (string-append "job " j "'s step that runs \"" cc-line "\" has no id: cc"))
(define (sod-restore-late j)
  (string-append "job " j " restores the libsodium cache after the libsodium build, and must restore it before"))
(define (sod-save-early j)
  (string-append "job " j " saves the libsodium cache before the libsodium build, and must save it after"))
(define (sod-save-late j)
  (string-append "job " j " saves the libsodium cache after the libsodium check, and must save it before"))
(define (restore-cc j)
  (string-append "job " j " restores the libsodium cache before the step that names the C compiler, and must restore it after"))

;; wrong-step-pair : String String -> (Listof Problem)
;; The problems of a step whose run line is none of the three, but whose env
;; names the two keys.
(define (wrong-step-pair j h)
  (list (list (A j (hdr-line h) (env-line "CHEZ_SODIUM_LIBRARY" (sod-lib j)))
              (env-wrong-step "CHEZ_SODIUM_LIBRARY"))
        (list (A j (hdr-line h) (env-line "C_INCLUDE_PATH" (sod-inc j)))
              (env-wrong-step "C_INCLUDE_PATH"))))

;; lane-name-problems : String -> (Listof Problem)
;; With no jobs key no job is known, so no lane's env may name the two names:
;; every line that names one of them is refused.
(define (lane-name-problems j)
  (apply append
         (map (lambda (h)
                (list (list (A j (hdr-line h) (env-line "CHEZ_SODIUM_LIBRARY" (sod-lib j)))
                            (names-msg "CHEZ_SODIUM_LIBRARY"))
                      (list (A j (hdr-line h) (env-line "C_INCLUDE_PATH" (sod-inc j)))
                            (names-msg "C_INCLUDE_PATH"))))
              (list h-chk (h-load j) (h-suites j)))))

(define chez-key-line t-restore-key)

(define (lane-rows j)
  (define (HA h) (A j #f (hdr-line h)))
  (define (here) (string-append "  " j ":"))
  (define (step h) (lane-step j h))
  ;; each required line: the step's name, its run line
  (define req
    (list (list h-chk-chez chk-t)
          (list h-cc cc-line)
          (list (h-build j) (lane-bld j))
          (list h-chk (lane-chk j))
          (list (h-load j) build-run)
          (list (h-suites j) "make test")))
  (define (insert-line h line)
    (le j (string-append (hdr-line h) "\n") (string-append (hdr-line h) "\n" line "\n")))
  (define (drop-part part) (replace-first (lane-key j) part ""))
  (define key-parts
    (if (lane-floor? j)
        (list "'packaging/floors.sexp', " ", 'scripts/ci/floor.sh'" ", 'scripts/ci/build-sodium.sh'"
              ", 'scripts/ci/check-sodium.sh'")
        (list "'scripts/ci/build-sodium.sh', " ", 'scripts/ci/check-sodium.sh'")))
  (define (pfx s) (string-append j ": " s))
  (define (restore-key-row name new-key)
    (row (pfx name)
         (list (se j (h-restore j) (key-line (lane-key j)) (key-line new-key)))
         (list (list (A j (hdr-line (h-restore j)) (key-line new-key)) (sod-key-msg j)))))
  (define (chk-env k v) (env-line k v))
  (append
   ;; the first step
   (list
    (row (pfx "the checkout without submodules")
         (list (le j "        with:\n          submodules: recursive\n" ""))
         (list (list (A j #f checkout-line) (first-step-msg j))))
    (row (pfx "the checkout with submodules: false")
         (list (le j "          submodules: recursive\n" "          submodules: false\n"))
         (list (list (A j #f checkout-line) (first-step-msg j)))))

   ;; each required run line deleted, and written twice
   (apply append
          (map (lambda (r)
                 (let ((h (car r)) (run (cadr r)))
                   (list
                    (row (pfx (string-append "the step that runs " run " deleted"))
                         (list (del-step j h))
                         (list (list (here) (n-steps j run 0))))
                    (row (pfx (string-append "the step that runs " run " written twice"))
                         (list (le j (step h) (string-append (step h) "\n" (step h))))
                         (list (list (here) (n-steps j run 2)))))))
               req))

   ;; order, exactness, ifs on the steps
   (list
    (row (pfx "the check after make build")
         (list (le j (string-append (step h-chk) "\n" (step (h-load j)))
                   (string-append (step (h-load j)) "\n" (step h-chk))))
         (list (list (A j (hdr-line (h-load j)) "        run: make build")
                     (out-of-order j build-run (lane-chk j)))))
    (row (pfx "make test before make build")
         (list (le j (string-append (step (h-load j)) "\n" (step (h-suites j)))
                   (string-append (step (h-suites j)) "\n" (step (h-load j)))))
         (list (list (A j (hdr-line (h-suites j)) "        run: make test")
                     (out-of-order j "make test" build-run))))
    (row (pfx "the libsodium build before check-chez")
         (list (del-step j (h-build j))
               (le j (step h-chk-chez) (string-append (step (h-build j)) "\n" (step h-chk-chez))))
         ;; the build now comes before the libsodium restore too
         (list (list (A j (hdr-line (h-build j)) (string-append "        run: " (lane-bld j)))
                     (out-of-order j (lane-bld j) cc-line))
               (list (HA (h-restore j)) (sod-restore-late j))))
    (row (pfx "the libsodium build without its if")
         (list (se j (h-build j) (string-append "        " if-sod "\n") ""))
         (list (list (HA (h-build j)) (step-no-if j (lane-bld j)))))
    (row (pfx "an if with another value on the libsodium build")
         (list (se j (h-build j) if-sod "if: false"))
         (list (list (A j (hdr-line (h-build j)) "        if: false") lane-if-bad)))
    (row (pfx "an if: always() on the libsodium check")
         (list (insert-line h-chk "        if: always()"))
         (list (list (A j (hdr-line h-chk) "        if: always()") lane-if-bad)
               (list (A j (hdr-line h-chk) "        if: always()") (step-has-if j (lane-chk j)))))
    (row (pfx "an if: always() on make build")
         (list (insert-line (h-load j) "        if: always()"))
         (list (list (A j (hdr-line (h-load j)) "        if: always()") lane-if-bad)
               (list (A j (hdr-line (h-load j)) "        if: always()") (step-has-if j build-run))))
    (row (pfx "an if: always() on make test")
         (list (insert-line (h-suites j) "        if: always()"))
         (list (list (A j (hdr-line (h-suites j)) "        if: always()") lane-if-bad)
               (list (A j (hdr-line (h-suites j)) "        if: always()") (step-has-if j "make test"))))
    (row (pfx "continue-on-error on make test")
         (list (insert-line (h-suites j) "        continue-on-error: true"))
         (list (list (A j (hdr-line (h-suites j)) "        continue-on-error: true")
                     (step-key "continue-on-error"))))
    (row (pfx "make test X")
         (list (se j (h-suites j) "        run: make test\n" "        run: make test X\n"))
         (cons (list (here) (n-steps j "make test" 0)) (wrong-step-pair j (h-suites j))))
    (row (pfx "make test as a block scalar")
         (list (se j (h-suites j) "        run: make test\n" "        run: |\n          make test\n"))
         (cons (list (here) (n-steps j "make test" 0)) (wrong-step-pair j (h-suites j))))
    (row (pfx "make build with an argument")
         (list (se j (h-load j) "        run: make build\n" "        run: make build X\n"))
         (cons (list (here) (n-steps j build-run 0)) (wrong-step-pair j (h-load j))))
    (row (pfx (if (lane-floor? j) "the check with --current" "the check without --current"))
         (list (se j h-chk (lane-chk j) (chk* j (if (lane-floor? j) " --current" ""))))
         (cons (list (here) (n-steps j (lane-chk j) 0)) (wrong-step-pair j h-chk)))
    (row (pfx "the build with the other lane's flag")
         (list (se j (h-build j) (lane-bld j) (bld* j (if (lane-floor? j) " --current" ""))))
         (list (list (here) (n-steps j (lane-bld j) 0))))
    ;; Its if then guards a build of no cache: a cache's build is the step that
    ;; names its directory.
    (row (pfx "the build into another directory")
         (list (se j (h-build j) (lane-bld j) (string-append "scripts/ci/build-sodium.sh \"$RUNNER_TEMP/sodium-x\"" (lane-flag j))))
         (list (list (A j (hdr-line (h-build j)) (string-append "        " if-sod)) sod-if-wrong)
               (list (here) (n-steps j (lane-bld j) 0))))
    (row (pfx "the compiler step's line changed")
         (list (se j h-cc "head -n 1" "head -n 2"))
         (list (list (here) (n-steps j cc-line 0))))
    (row (pfx "the compiler step without its id")
         (list (se j h-cc "        id: cc\n" ""))
         (list (list (HA h-cc) (cc-id-msg j))))
    (row (pfx "check-chez with --nothreads")
         (list (se j h-chk-chez chk-t (string-append chk-t " --nothreads")))
         (list (list (here) (n-steps j chk-t 0)))))

   ;; the ifs, each on the other cache's steps
   (list
    (row (pfx "the libsodium if on the Chez build")
         (list (se j h-build-chez "steps.chez." "steps.sodium."))
         (list (list (A j (hdr-line h-build-chez) (string-append "        " if-sod)) sod-if-wrong)))
    (row (pfx "the Chez if on the libsodium build")
         (list (se j (h-build j) "steps.sodium." "steps.chez."))
         (list (list (A j (hdr-line (h-build j)) (string-append "        " if-chez)) chez-if-wrong)))
    (row (pfx "the libsodium if on the Chez save")
         (list (se j h-save-chez "steps.chez.outputs.cache-hit" "steps.sodium.outputs.cache-hit"))
         (list (list (A j (hdr-line h-save-chez) (string-append "        " if-sod)) sod-if-wrong)))
    (row (pfx "the Chez if on the libsodium save")
         (list (se j (h-save j) "steps.sodium.outputs.cache-hit" "steps.chez.outputs.cache-hit"))
         (list (list (A j (hdr-line (h-save j)) (string-append "        " if-chez)) chez-if-wrong)))
    (row (pfx "the libsodium if on make test")
         (list (insert-line (h-suites j) (string-append "        " if-sod)))
         (list (list (A j (hdr-line (h-suites j)) (string-append "        " if-sod)) sod-if-wrong)
               (list (A j (hdr-line (h-suites j)) (string-append "        " if-sod)) (step-has-if j "make test"))))
    (row (pfx "the Chez if on make test")
         (list (insert-line (h-suites j) (string-append "        " if-chez)))
         (list (list (A j (hdr-line (h-suites j)) (string-append "        " if-chez)) chez-if-wrong)
               (list (A j (hdr-line (h-suites j)) (string-append "        " if-chez)) (step-has-if j "make test")))))

   ;; the cache keys
   (map (lambda (part)
          (restore-key-row (string-append "the libsodium key drops " part) (drop-part part)))
        key-parts)
   (list
    (restore-key-row "the libsodium key hashes one file more"
                     (replace-first (lane-key j) "check-sodium.sh')" "check-sodium.sh', 'README.org')"))
    (restore-key-row "the libsodium key drops the compiler"
                     (replace-first (lane-key j) "-${{ steps.cc.outputs.id }}" ""))
    (restore-key-row "the libsodium key drops the image"
                     (replace-first (lane-key j) "-${{ steps.image.outputs.id }}" ""))
    (restore-key-row "the libsodium key takes the other lane's prefix"
                     (replace-first (lane-key j) (string-append "sodium-" j "-") (string-append "sodium-" (other-lane j) "-")))
    (restore-key-row "the libsodium key takes the other lane's whole key"
                     (lane-key (other-lane j)))
    (restore-key-row "the libsodium key has a tail"
                     (string-append (lane-key j) "-x"))
    (row (pfx "the libsodium restore's path is the other lane's")
         (list (se j (h-restore j) (path-line (sod-sq j)) (path-line (sod-sq (other-lane j)))))
         (list (list (A j (hdr-line (h-restore j)) (path-line (sod-sq (other-lane j)))) (path-msg j))
               (list (here) (restores-msg j 0))))
    (row (pfx "the libsodium save's path is the other lane's")
         (list (se j (h-save j) (path-line (sod-sq j)) (path-line (sod-sq (other-lane j)))))
         ;; a save at the other lane's path is no save of this lane's cache, so
         ;; its if is held as well
         (list (list (A j (hdr-line (h-save j)) (string-append "        " if-sod)) sod-if-wrong)
               (list (A j (hdr-line (h-save j)) (path-line (sod-sq (other-lane j)))) (path-msg j))
               (list (here) (saves-msg j 0))))
    (row (pfx "the libsodium save is keyed by the Chez cache")
         (list (se j (h-save j) "steps.sodium.outputs.cache-primary-key" "steps.chez.outputs.cache-primary-key"))
         (list (list (A j (hdr-line (h-save j)) (key-line "${{ steps.chez.outputs.cache-primary-key }}"))
                     (sod-save-key-msg j "sodium"))))
    (row (pfx "the Chez save is keyed by the libsodium cache")
         (list (se j h-save-chez "steps.chez.outputs.cache-primary-key" "steps.sodium.outputs.cache-primary-key"))
         (list (list (A j (hdr-line h-save-chez) (key-line "${{ steps.sodium.outputs.cache-primary-key }}"))
                     (save-key j))))
    (row (pfx "the libsodium save is keyed as a restore is")
         (list (se j (h-save j) "${{ steps.sodium.outputs.cache-primary-key }}" (lane-key j)))
         (list (list (A j (hdr-line (h-save j)) (key-line (lane-key j))) (sod-save-key-msg j "sodium"))))
    (row (pfx "the libsodium restore deleted")
         (list (del-step j (h-restore j)))
         (list (list (here) (restores-msg j 0))))
    (row (pfx "the libsodium restore written twice")
         (list (le j (step (h-restore j)) (string-append (step (h-restore j)) "\n" (step (h-restore j)))))
         (list (list (here) (restores-msg j 2))))
    (row (pfx "the libsodium save deleted")
         (list (del-step j (h-save j)))
         (list (list (here) (saves-msg j 0))))
    (row (pfx "the libsodium restore without its id")
         (list (se j (h-restore j) "        id: sodium\n" ""))
         (list (list (HA (h-restore j)) (sod-restore-id-msg j))))
    (row (pfx "the libsodium restore's id is another")
         (list (se j (h-restore j) "        id: sodium\n" "        id: sodium-x\n"))
         (list (list (A j (hdr-line (h-restore j)) "        id: sodium-x") (sod-restore-id-msg j))))
    (row (pfx "the Chez key drops a file")
         (list (se j h-restore-chez ", 'scripts/ci/check-chez.sh'" ""))
         (list (list (A j (hdr-line h-restore-chez)
                        "          key: chez-threads-${{ hashFiles('packaging/floors.sexp', 'scripts/ci/floor.sh', 'scripts/ci/build-chez.sh') }}-${{ steps.image.outputs.id }}")
                     (cache-key j "chez-threads-"))))
    (row (pfx "the Chez cache's path is the libsodium cache's")
         (list (se j h-restore-chez "/chez-threads\n" (string-append "/sodium-" j "\n")))
         ;; a second restore of the libsodium path, before the compiler step,
         ;; with the Chez restore's id and key; and none of the Chez cache's
         (list (list (A j (hdr-line h-restore-chez) "        id: chez") (sod-restore-id-msg j))
               (list (A j (hdr-line h-restore-chez) chez-key-line) (sod-key-msg j))
               (list (HA h-restore-chez) (restore-cc j))
               (list (here) (restores j 0))
               (list (here) (restores-msg j 2)))))

   ;; the env keys
   (list
    (row (pfx "the check's library is the other lane's")
         (list (se j h-chk (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)) (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib (other-lane j)))))
         (list (list (A j (hdr-line h-chk) (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib (other-lane j))))
                     (env-value j "CHEZ_SODIUM_LIBRARY" (sod-lib j)))))
    ;; The lanes differ in the soname as well as the directory.
    (row (pfx "the check's library is this lane's directory with the other release's soname")
         (list (se j h-chk (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j))
                   (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib* j (sod-so (other-lane j))))))
         (list (list (A j (hdr-line h-chk) (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib* j (sod-so (other-lane j)))))
                     (env-value j "CHEZ_SODIUM_LIBRARY" (sod-lib j)))))
    (row (pfx "the suites' header directory has a second directory")
         (list (se j (h-suites j) (chk-env "C_INCLUDE_PATH" (sod-inc j)) (chk-env "C_INCLUDE_PATH" (string-append (sod-inc j) ":/usr/include"))))
         (list (list (A j (hdr-line (h-suites j)) (chk-env "C_INCLUDE_PATH" (string-append (sod-inc j) ":/usr/include")))
                     (env-value j "C_INCLUDE_PATH" (sod-inc j)))))
    (row (pfx "the library's value is relative")
         (list (se j (h-load j) (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)) (chk-env "CHEZ_SODIUM_LIBRARY" "lib/libsodium.so.23")))
         (list (list (A j (hdr-line (h-load j)) (chk-env "CHEZ_SODIUM_LIBRARY" "lib/libsodium.so.23"))
                     (env-value j "CHEZ_SODIUM_LIBRARY" (sod-lib j)))))
    (row (pfx "the check's CHEZ is the nothreads Chez")
         (list (se j h-chk (chk-env "CHEZ" chez-t) (chk-env "CHEZ" chez-n)))
         (list (list (A j (hdr-line h-chk) (chk-env "CHEZ" chez-n)) (env-chez j chez-t))))
    (row (pfx "make test without C_INCLUDE_PATH")
         (list (se j (h-suites j) (string-append (chk-env "C_INCLUDE_PATH" (sod-inc j)) "\n") ""))
         (list (list (HA (h-suites j)) (env-missing3 j "make test" "C_INCLUDE_PATH"))))
    (row (pfx "make build without CHEZ_SODIUM_LIBRARY")
         (list (se j (h-load j) (string-append (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)) "\n") ""))
         (list (list (HA (h-load j)) (env-missing3 j build-run "CHEZ_SODIUM_LIBRARY"))))
    (row (pfx "the check without CHEZ")
         (list (se j h-chk (string-append (chk-env "CHEZ" chez-t) "\n") ""))
         (list (list (HA h-chk) (env-missing3 j (lane-chk j) "CHEZ"))))
    (row (pfx "the check without any env")
         (list (se j h-chk (string-append "        env:\n" (chk-env "CHEZ" chez-t) "\n" (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)) "\n" (chk-env "C_INCLUDE_PATH" (sod-inc j)) "\n") ""))
         (list (list (HA h-chk) (env-missing3 j (lane-chk j) "CHEZ"))
               (list (HA h-chk) (env-missing3 j (lane-chk j) "CHEZ_SODIUM_LIBRARY"))
               (list (HA h-chk) (env-missing3 j (lane-chk j) "C_INCLUDE_PATH"))))
    (row (pfx "the libsodium build without CHEZ")
         (list (se j (h-build j) (string-append "        env:\n" (chk-env "CHEZ" chez-t) "\n") ""))
         (list (list (HA (h-build j)) (env-missing3 j (lane-bld j) "CHEZ"))))
    (row (pfx "the libsodium build with the override")
         (list (se j (h-build j) (string-append (chk-env "CHEZ" chez-t) "\n")
                   (string-append (chk-env "CHEZ" chez-t) "\n" (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)) "\n")))
         (list (list (A j (hdr-line (h-build j)) (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)))
                     (env-wrong-step "CHEZ_SODIUM_LIBRARY"))))
    (row (pfx "the libsodium restore with the header directory")
         (list (se j (h-restore j) "        with:\n"
                   (string-append "        env:\n" (chk-env "C_INCLUDE_PATH" (sod-inc j)) "\n        with:\n")))
         (list (list (A j (hdr-line (h-restore j)) (chk-env "C_INCLUDE_PATH" (sod-inc j)))
                     (env-wrong-step "C_INCLUDE_PATH"))))
    (row (pfx "the Chez build with the override")
         (list (se j h-build-chez "        run:" (string-append "        env:\n" (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)) "\n        run:")))
         (list (list (A j (hdr-line h-build-chez) (chk-env "CHEZ_SODIUM_LIBRARY" (sod-lib j)))
                     (env-wrong-step "CHEZ_SODIUM_LIBRARY"))))
    ;; The exemption is for the key alone: a banned word in the value is named.
    (row (pfx "the header directory's value names CPATH")
         (list (se j (h-suites j) (chk-env "C_INCLUDE_PATH" (sod-inc j)) (chk-env "C_INCLUDE_PATH" (string-append (sod-inc j) "/CPATH"))))
         (list (list (A j (hdr-line (h-suites j)) (chk-env "C_INCLUDE_PATH" (string-append (sod-inc j) "/CPATH")))
                     (names-msg "CPATH"))
               (list (A j (hdr-line (h-suites j)) (chk-env "C_INCLUDE_PATH" (string-append (sod-inc j) "/CPATH")))
                     (env-value j "C_INCLUDE_PATH" (sod-inc j)))))
    ;; The exemption is for an env key: a with key of the name is named, and
    ;; refused as a with key.
    (row (pfx "a with key of the restore is C_INCLUDE_PATH")
         (list (se j (h-restore j) "        with:\n" (string-append "        with:\n" (env-line "C_INCLUDE_PATH" "x") "\n")))
         (list (list (A j (hdr-line (h-restore j)) (env-line "C_INCLUDE_PATH" "x")) (names-msg "C_INCLUDE_PATH"))
               (list (A j (hdr-line (h-restore j)) (env-line "C_INCLUDE_PATH" "x")) (with-key "C_INCLUDE_PATH"))))
    ;; The exemption is for the name as it stands: a quoted key, and an
    ;; explicit one, are refused by their spelling and name the word.
    (row (pfx "a quoted key, \"C_INCLUDE_PATH\", in the suites' env")
         (list (se j (h-suites j) (chk-env "C_INCLUDE_PATH" (sod-inc j))
                   (string-append (chk-env "C_INCLUDE_PATH" (sod-inc j)) "\n          \"C_INCLUDE_PATH\": " (sod-inc j))))
         (list (list (A j (hdr-line (h-suites j)) (string-append "          \"C_INCLUDE_PATH\": " (sod-inc j)))
                     (names-msg "C_INCLUDE_PATH"))
               (list (A j (hdr-line (h-suites j)) (string-append "          \"C_INCLUDE_PATH\": " (sod-inc j)))
                     quoted-msg)))
    (row (pfx "an explicit key, ? C_INCLUDE_PATH: x, in the suites' env")
         (list (se j (h-suites j) (chk-env "C_INCLUDE_PATH" (sod-inc j))
                   (string-append (chk-env "C_INCLUDE_PATH" (sod-inc j)) "\n          ? C_INCLUDE_PATH: x")))
         (list (list (A j (hdr-line (h-suites j)) "          ? C_INCLUDE_PATH: x") (names-msg "C_INCLUDE_PATH"))
               (list (A j (hdr-line (h-suites j)) "          ? C_INCLUDE_PATH: x") explicit-msg))))
   ;; the names that stay refused
   (map (lambda (k)
          (row (pfx (string-append "the suites' env gains " k))
               (list (se j (h-suites j) (string-append "          CHEZ: " chez-t "\n")
                         (string-append "          CHEZ: " chez-t "\n          " k ": x\n")))
               (list (list (A j (hdr-line (h-suites j)) (string-append "          " k ": x")) (names-msg k))
                     (list (A j (hdr-line (h-suites j)) (string-append "          " k ": x")) (lane-env-key k)))))
        '("CPATH" "LD_LIBRARY_PATH" "CC" "MAKEFLAGS" "CHEZ_SODIUM_GATE_CHILD"))

   ;; the names on every other line
   (list
    (row (pfx "a run block exports CHEZ_SODIUM_LIBRARY")
         (list (se j h-image id-line (string-append id-line "          export CHEZ_SODIUM_LIBRARY=x\n")))
         (list (list (A j (hdr-line h-image) "          export CHEZ_SODIUM_LIBRARY=x") (names-msg "CHEZ_SODIUM_LIBRARY"))))
    (row (pfx "C_INCLUDE_PATH is written to GITHUB_ENV")
         (list (se j h-image id-line (string-append id-line "          echo C_INCLUDE_PATH=/x >> \"$GITHUB_ENV\"\n")))
         (list (list (A j (hdr-line h-image) "          echo C_INCLUDE_PATH=/x >> \"$GITHUB_ENV\"") (names-msg "GITHUB_ENV"))
               (list (A j (hdr-line h-image) "          echo C_INCLUDE_PATH=/x >> \"$GITHUB_ENV\"") (names-msg "C_INCLUDE_PATH"))))
    (row (pfx "a step's name names C_INCLUDE_PATH")
         (list (le j (hdr-line (h-load j)) "      - name: Load C_INCLUDE_PATH"))
         (list (list (A j #f "      - name: Load C_INCLUDE_PATH") (names-msg "C_INCLUDE_PATH"))))
    (row (pfx "a with value names CHEZ_SODIUM_LIBRARY")
         (list (se j (h-restore j) (path-line (sod-sq j)) (path-line "CHEZ_SODIUM_LIBRARY")))
         (list (list (A j (hdr-line (h-restore j)) (path-line "CHEZ_SODIUM_LIBRARY")) (names-msg "CHEZ_SODIUM_LIBRARY"))
               (list (A j (hdr-line (h-restore j)) (path-line "CHEZ_SODIUM_LIBRARY")) (path-msg j))
               ;; at no libsodium path, it is a Chez restore, after the Chez build
               (list (HA (h-restore j)) (restore-late j))
               (list (here) (restores j 2))
               (list (here) (restores-msg j 0))))
    (row (pfx "a run line names C_INCLUDE_PATH")
         (list (se j (h-load j) "        run: make build\n" "        run: make build C_INCLUDE_PATH=x\n"))
         (list (list (A j (hdr-line (h-load j)) "        run: make build C_INCLUDE_PATH=x") (names-msg "C_INCLUDE_PATH"))
               (list (here) (n-steps j build-run 0))
               (car (wrong-step-pair j (h-load j)))
               (cadr (wrong-step-pair j (h-load j))))))

   ;; the spellings, over a lane's steps: the exemption for the two names is
   ;; for a plain key, so each of these is refused by its spelling
   (list
    (row (pfx "a quoted key, \"if\": false")
         (list (insert-line (h-load j) "        \"if\": false"))
         (list (list (A j (hdr-line (h-load j)) "        \"if\": false") quoted-msg)))
    (row (pfx "an explicit key, ? if")
         (list (insert-line (h-load j) "        ? if\n        : false"))
         (list (list (A j (hdr-line (h-load j)) "        ? if") explicit-msg)
               (list (A j (hdr-line (h-load j)) "        : false") (step-key "")))))

   ;; the actions a job uses, and the order of each cache's steps
   (list
    (row (pfx "the libsodium restore uses actions/cache, not actions/cache/restore")
         (list (le j (step (h-restore j))
                   (replace-first
                    (replace-first (step (h-restore j))
                                   "uses: actions/cache/restore@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0"
                                   "uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0")
                    (key-line (lane-key j)) (key-line (string-append "sodium-" j "-anything")))))
         (list (list (HA (h-restore j))
                     (uses-msg j "actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9"))
               (list (here) (restores-msg j 0))))
    (row (pfx "the libsodium restore moved below the check")
         (list (le j (string-append (step (h-restore j)) "\n" (step (h-build j)) "\n" (step (h-save j)) "\n" (step h-chk))
                   (string-append (step (h-build j)) "\n" (step (h-save j)) "\n" (step h-chk) "\n" (step (h-restore j)))))
         (list (list (HA (h-restore j)) (sod-restore-late j))))
    (row (pfx "the compiler step moved below the libsodium restore")
         (list (le j (string-append (step h-cc) "\n" (step (h-restore j)))
                   (string-append (step (h-restore j)) "\n" (step h-cc))))
         (list (list (HA (h-restore j)) (restore-cc j))))
    (row (pfx "the libsodium save moved below the check")
         (list (le j (string-append (step (h-save j)) "\n" (step h-chk))
                   (string-append (step h-chk) "\n" (step (h-save j)))))
         (list (list (HA (h-save j)) (sod-save-late j))))
    (row (pfx "the libsodium save moved above the build")
         (list (le j (string-append (step (h-build j)) "\n" (step (h-save j)))
                   (string-append (step (h-save j)) "\n" (step (h-build j)))))
         (list (list (HA (h-save j)) (sod-save-early j)))))))

;; The rows that are not a lane's: the job list, and the two names in the jobs
;; that must stay refused them.
(define (env-ln k v) (string-append "          " k ": " v))

(define (disc-step)
  (span "      # The library the install check found" (string-append disc-line "\n")))
(define gate-hdr "      - name: The gate must fail on planted defects")
(define mem-hdr "      - name: Every suite under Valgrind")
(define nt-hdr "      - name: Every library must be refused, by name")

(define lane-global-rows
  (append
   (list
    (row "the floor job deleted"
         (list (e (between "\n  # libsodium at its floor," "\n  # libsodium at the current release,") ""))
         (list (list "jobs:" (job-missing "floor"))))
    (row "the current job deleted"
         (list (e (to-end "\n  # libsodium at the current release,") ""))
         (list (list "jobs:" (job-missing "current"))))
    (row "a job beside the five"
         (list (le "current" (lane-step "current" (h-suites "current"))
                   (string-append (lane-step "current" (h-suites "current")) "\n"
                                  (lines "  extra:" "    name: x" "    runs-on: ubuntu-24.04"
                                         "    timeout-minutes: 5" "    steps:" "      - run: echo hi"))))
         (list (list "  extra:" (job-unknown "extra")))))
   ;; The two names, with floor's exact values, in every job that must refuse
   ;; them, the discovery step among them.
   (map (lambda (spec)
          (let ((name (car spec)) (hdr (cadr spec)) (job (caddr spec)) (chez (cadddr spec)) (k (car (cddddr spec))))
            (row (string-append name " gains " k ", with floor's exact value")
                 (list (le job (string-append hdr "\n        env:\n          CHEZ: " chez "\n")
                           (string-append hdr "\n        env:\n          CHEZ: " chez "\n"
                                          (env-ln k (if (string=? k "C_INCLUDE_PATH") (sod-inc "floor") (sod-lib "floor"))) "\n")))
                 (let ((at (A job hdr (env-ln k (if (string=? k "C_INCLUDE_PATH") (sod-inc "floor") (sod-lib "floor"))))))
                   (list (list at (names-msg k)) (list at (env-key k)))))))
        (apply append
               (map (lambda (k)
                      (list (list "main's install check" install-hdr "main" chez-t k)
                            (list "main's discovery step" disc-hdr "main" chez-t k)
                            (list "memory's gate step" gate-hdr "memory" chez-t k)
                            (list "memory's test-memory step" mem-hdr "memory" chez-t k)
                            (list "nothreads's step" nt-hdr "nothreads" chez-n k)))
                    '("CHEZ_SODIUM_LIBRARY" "C_INCLUDE_PATH"))))))

;; --- main's discovery step: the runner's libsodium is the floor -----------------------------

(define discovery-rows
  (list
   (row "main's discovery step deleted"
        (list (e (string-append (disc-step) "\n") ""))
        (list (list "  main:" (n-steps "main" disc-run 0))))
   (row "main's discovery step written twice"
        (list (e (string-append (disc-step) "\n") (string-append (disc-step) "\n" (disc-step) "\n")))
        (list (list "  main:" (n-steps "main" disc-run 2))))
   (row "main's discovery step moved before the install check"
        (list (e (string-append (disc-step) "\n") "")
              (e (string-append (install-step) "\n") (string-append (disc-step) "\n" (install-step) "\n")))
        (list (list disc-line (out-of-order "main" disc-run build-run))))
   (row "main's discovery step moved after Checks and suites"
        (list (e (string-append (disc-step) "\n") "")
              (e (make-run) (string-append (make-run) "\n" (disc-step))))
        (list (list (string-append "        run: " make-line) (out-of-order "main" make-line disc-run))))
   (row "main's discovery step with an argument, --discovery X"
        (list (e disc-line (string-append disc-line " X")))
        (list (list "  main:" (n-steps "main" disc-run 0))))
   (row "main's discovery step with a prefix, as a lane's check has it"
        (list (e disc-line (string-append "        run: " (chk* "floor" ""))))
        (list (list "  main:" (n-steps "main" disc-run 0))))
   (row "main's discovery step as a block scalar"
        (list (e disc-line (string-append "        run: |\n          " disc-run)))
        (list (list "  main:" (n-steps "main" disc-run 0))
              (list (string-append "          " disc-run) stray-msg)))))

(define rows
  (append
   stray-rows
   text-rows
   word-rows
   top-rows
   (apply append (map job-key-rows job-order))
   (apply append (map cache-rows job-order))
   (apply append (map (lambda (s) (make-step-rows s)) make-steps))
   step-key-rows
   structure-rows
   main-rows
   make-word-rows
   report-rows
   memory-rows
   nothreads-rows
   discovery-rows
   lane-global-rows
   (lane-rows "floor")
   (lane-rows "current")
   directory-rows))

;; --- the run ------------------------------------------------------------------------

(test-begin "check-ci")

(test-assert "the real workflow is there to be copied" (> (string-length real) 1000))

(let loop ((rs rows))
  (unless (null? rs)
    (let ((result (run-row (car rs))))
      (test-equal (caar rs) (car result) (cadr result)))
    (loop (cdr rs))))

;; Rows that need no copy of the workflow.

;; run-bare : (Listof String) -> (U (List Integer String String) (List 'raised String))
(define (run-bare args)
  (guard (c (#t (list 'raised (describe c))))
    (capture-command (append (list "sh" script) args))))

(define usage-line "check-ci: usage: sh tests/check-ci.sh DIR\n")

(test-equal "no argument is a usage error" (list 2 "" usage-line) (run-bare '()))
(test-equal "two arguments are a usage error" (list 2 "" usage-line) (run-bare '("a" "b")))

(let ((missing (string-append base "/nowhere")))
  (test-equal "a directory that is not there"
              (list 1 "" (string-append "check-ci: " missing ": is not a directory\n"
                                        "check-ci: FAILED (problems: 1)\n"))
              (run-bare (list missing))))

(let ((empty (string-append base "/empty")))
  (guard (c (#t #f)) (mkdir empty))
  (test-equal "a directory with no workflow"
              (list 1 ""
                    (string-append "check-ci: " empty "/ci.yml: " not-regular "\n"
                                   "check-ci: FAILED (problems: 1)\n"))
              (run-bare (list empty))))

;; --- the execute bits ------------------------------------------------------------------
;;
;; CI runs a script by its path, so a lost execute bit, or a script that is not
;; there, fails the step on a runner and nowhere else. Each row copies the real
;; scripts/ci into a root of its own, outside the copy of ci.yml (which must be
;; alone in its directory), changes one script there, and points check-ci at
;; the root with CHECK_CI_ROOT. The real tree is never touched.

;; The steps that run a script by its path, in the file's order: each (script
;; job step-header run-line). Written by hand, one for each such step.
(define script-steps
  (list
   (list "check-action-pins.sh" "main" "      - name: Every action is pinned to a commit"
         "        run: scripts/ci/check-action-pins.sh .github/workflows")
   (list "build-chez.sh" "main" "      - name: Build Chez"
         "        run: scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "check-chez.sh" "main" "      - name: Check the Chez this job runs"
         "        run: scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "report-sodium.sh" "main" "      - name: Report the runner's libsodium"
         "        run: scripts/ci/report-sodium.sh")
   (list "check-sodium.sh" "main" "      - name: The runner's libsodium is the floor"
         "        run: scripts/ci/check-sodium.sh --discovery")
   (list "build-chez.sh" "memory" "      - name: Build Chez"
         "        run: scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "check-chez.sh" "memory" "      - name: Check the Chez this job runs"
         "        run: scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "build-chez.sh" "nothreads" "      - name: Build Chez without threads"
         "        run: scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-nothreads\" --nothreads")
   (list "check-chez.sh" "nothreads" "      - name: Check the Chez this job runs"
         "        run: scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-nothreads\" --nothreads")
   (list "build-chez.sh" "floor" "      - name: Build Chez"
         "        run: scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "check-chez.sh" "floor" "      - name: Check the Chez this job runs"
         "        run: scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "build-sodium.sh" "floor" "      - name: Build libsodium at its floor"
         "        run: scripts/ci/build-sodium.sh \"$RUNNER_TEMP/sodium-floor\"")
   (list "check-sodium.sh" "floor" "      - name: Check the libsodium this job runs"
         "        run: scripts/ci/check-sodium.sh \"$RUNNER_TEMP/sodium-floor\"")
   (list "build-chez.sh" "current" "      - name: Build Chez"
         "        run: scripts/ci/build-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "check-chez.sh" "current" "      - name: Check the Chez this job runs"
         "        run: scripts/ci/check-chez.sh \"$RUNNER_TEMP/chez-threads\"")
   (list "build-sodium.sh" "current" "      - name: Build libsodium at the current release"
         "        run: scripts/ci/build-sodium.sh \"$RUNNER_TEMP/sodium-current\" --current")
   (list "check-sodium.sh" "current" "      - name: Check the libsodium this job runs"
         "        run: scripts/ci/check-sodium.sh \"$RUNNER_TEMP/sodium-current\" --current")))

(define (noexec-msg name)
  (string-append "runs scripts/ci/" name ", which is missing or not executable: "
                 "a step runs it by its path, so it must be there and carry the execute bit"))

;; script-problems : String -> (Listof (List Anchor String))
(define (script-problems name)
  (let loop ((ss script-steps) (acc '()))
    (cond ((null? ss) (reverse acc))
          ((string=? (car (car ss)) name)
           (let ((s (car ss)))
             (loop (cdr ss)
                   (cons (list (list 'in (cadr s) (caddr s) (cadddr s)) (noexec-msg name)) acc))))
          (else (loop (cdr ss) acc)))))

(define script-names
  '("check-action-pins.sh" "build-chez.sh" "check-chez.sh" "report-sodium.sh"
    "build-sodium.sh" "check-sodium.sh"))

(define (must-run argv)
  (let ((r (capture-command argv)))
    (unless (and (eqv? (car r) 0))
      (error 'must-run "a setup command failed" argv r))))

;; script-row : String (Procedure String -> Void) (Listof Problem) -> Void
;; Copies the scripts, runs ACTION on the copy's root, and checks the script's
;; answer on the real workflow.
(define (script-row name action problems)
  (set! counter (+ counter 1))
  (let* ((dir (string-append base "/r" (number->string counter)))
         (root (string-append base "/root" (number->string counter)))
         (result
          (guard (c (#t (list (list 'raised (string-append name ": " (describe c))) '(not run))))
            (mkdir dir)
            (mkdir root)
            (mkdir (string-append root "/scripts"))
            (must-run (list "cp" "-R" "scripts/ci" (string-append root "/scripts/ci")))
            (action (string-append root "/scripts/ci"))
            (write-text (string-append dir "/ci.yml") real)
            (list (expected dir real problems)
                  (capture-command (list "env" (string-append "CHECK_CI_ROOT=" root)
                                         "sh" script dir))))))
    (test-equal name (car result) (cadr result))))

(script-row "the real scripts, each executable: the workflow passes" (lambda (d) #f) '())

(for-each
 (lambda (name)
   (script-row (string-append name " without its execute bit: every step that runs it is named")
               (lambda (d) (must-run (list "chmod" "a-x" (string-append d "/" name))))
               (script-problems name)))
 script-names)

(for-each
 (lambda (name)
   (script-row (string-append name " missing: every step that runs it is named")
               (lambda (d) (must-run (list "rm" (string-append d "/" name))))
               (script-problems name)))
 '("build-chez.sh" "report-sodium.sh" "check-sodium.sh"))

;; floor.sh is run with sh by the other scripts, never by its path.
(script-row "floor.sh without its execute bit: the workflow passes"
            (lambda (d) (must-run (list "chmod" "a-x" (string-append d "/floor.sh"))))
            '())

(test-end "check-ci")

(exit (suite-exit-status runner))
