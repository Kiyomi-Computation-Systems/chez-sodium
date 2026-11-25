#!r6rs
;;; (library-loading): what the suites that load libsodium end to end
;;; share, tests/test-library-loading-*.sps (ADR-0002, ADR-0003, ADR-0006,
;;; ADR-0011). Their cost is their children, each under a Valgrind of its
;;; own under the memory gate, so the rows are split among thirteen suites, each
;;; running at most 14 children, to keep each well under MEMORY_TIMEOUT
;;; (ADR-0011):
;;;
;;;   -decoys      the control build under each switch, one a row
;;;   -missing     each of the first five entry points left out, a build
;;;                with no sodium_* function, and the load's order
;;;   -missing-verbs  each of the byte verbs' eight entry points left out
;;;   -missing-passwords  the password calls, strbytes, strprefix and the five
;;;                opslimits left out
;;;   -missing-limits  the five memlimits and the two password-length
;;;                functions left out
;;;   -combined    the kept refusal and the kept load, the marker, values
;;;                that are no switch, the wipe, seen in the decoy's log, what
;;;                each switch answers through eight bindings of the probe's
;;;                own, and the log's overflow
;;;   -password-entries  the password hash's three raw bindings called through the
;;;                probe, under each switch that changes what they answer, and
;;;                the constants with a NULL prefix
;;;   -real        the real libsodium, the refusals no decoy reaches, and
;;;                sodium_init called before and after the load
;;;   -discovery   the override unset: what discovery chooses, and not-found
;;;   -preflight   make build's preflight, and a raise that is not a refusal
;;;   -verbs       the byte verbs' calls on the control build, one child a switch:
;;;                what reaches C, and what each verb answers or raises
;;;   -passwords   the password verbs' calls the same way: what reaches C, each
;;;                refusal's empty growth, the other answers of the password
;;;                calls, and the constants as the decoy gives them
;;;   -password-limits  the memory range make-password-limits answers, rounded
;;;                inward, under a decoy whose memlimits are no whole KiB
;;;
;;;   the probe         spawn a child through env and gated-command, and
;;;                     read what tests/refusal-probe.sps printed, as data
;;;   the verb probe    the same for tests/verb-probe.sps, given verb calls:
;;;                     verb-probe-with, verb-answer and verb-row-in
;;;   the answers       a probe's whole expected answer: loaded, refused,
;;;                     with its counts, its Valgrind line and its call log
;;;   the floors        the decoy's versions, from packaging/floors.sexp
;;;   the entries       every entry point (chez-sodium private native)
;;;                     requires, in native's order: held to the convention
;;;                     table by tests/test-conventions.sps and by
;;;                     test-library-loading-missing; first-entries,
;;;                     verb-entries, password-entries and limit-entries are
;;;                     its four parts
;;;   the decoys        each build of tests/decoy-libsodium.c, compiled in
;;;                     a suite's scratch directory, and a row on one
;;;   the world         the world and the empty profiles that discovery's
;;;                     rows and preflight's not-found row share
;;;   preflight         tests/preflight.sps run as make build runs it, with
;;;                     whether the gate's Valgrind ran it, and the text it
;;;                     prints when it accepts a library
;;;
;;; Each suite keeps its own runner, scratch directory and floors, and names
;;; the helpers here that take them by the names its rows use. Nothing here
;;; runs at import but reading two environment variables: every child, every
;;; compile and every row runs when a suite calls for it.
;;;
;;; Test-only: it lives in tests/, which make test puts on Chez's library
;;; path. It loads no libsodium, and each suite requires as much at its end.
(library (library-loading)
  (export chez set? string-prefix? string-suffix? absolute? join
          spawn-in probe-with probe override switch-args as-data
          verb-probe-with verb-answer verb-row-in
          once no-native-objects gated? valgrind-line
          outcome report with-sizes control-sizes other-sizes
          loaded-lines refused-lines loaded refused
          with-constants control-constants other-constants constants-keys
          read-floor-values
          every-entry first-entries verb-entries password-entries limit-entries
          size-calls constant-calls
          lacks-build decoy-builds compile-decoys decoy-status decoy-row-in
          read-switch version-calls init-call log-of init-calls loaded-calls
          missing-api-rows
          field make-directory process-world unset-override
          no-profiles-env guix-candidates-in
          lines-of text counts-line accepted-text preflight-in preflight)
  (import (rnrs)
          (srfi :64)
          (chez-sodium-testing)
          (libsodium-oracle)
          (floors)
          (only (chezscheme) getenv directory-list file-directory? list-head)
          (chez-sodium private discovery))

  ;; --- strings ---------------------------------------------------------------

  ;; string-prefix? : String String -> Boolean
  (define (string-prefix? prefix s)
    (let ((n (string-length s)) (m (string-length prefix)))
      (and (>= n m) (string=? (substring s 0 m) prefix))))

  ;; string-suffix? : String String -> Boolean
  (define (string-suffix? suffix s)
    (let ((n (string-length s)) (m (string-length suffix)))
      (and (>= n m) (string=? (substring s (- n m) n) suffix))))

  ;; absolute? : Any -> Boolean
  (define (absolute? s)
    (and (string? s) (string-prefix? "/" s)))

  ;; join : (Listof String) -> String
  ;; ENTRIES with one space between: a decoy's call log.
  (define (join entries)
    (if (null? entries)
        ""
        (fold-left (lambda (all entry) (string-append all " " entry))
                   (car entries) (cdr entries))))

  ;; set? : Any -> Boolean
  (define (set? value) (and (string? value) (not (string=? value ""))))

  ;; --- the processes a suite spawns ----------------------------------------------

  ;; chez : (U String #f)
  ;; The Chez to spawn: the Makefile exports CHEZ, so a suite spawns the Chez
  ;; that runs it. Each suite's first row requires it set.
  (define chez (getenv "CHEZ"))

  ;; read-data : String -> (U (Listof Any) (List 'unreadable String))
  ;; TEXT read as a sequence of data.
  (define (read-data text)
    (guard (e (#t (list 'unreadable text)))
      (let ((port (open-string-input-port text)))
        (let loop ((data '()))
          (let ((datum (read port)))
            (if (eof-object? datum)
                (reverse data)
                (loop (cons datum data))))))))

  ;; env-order : (Listof String) -> (Listof String)
  ;; ENV-ARGS with every -u NAME pair first, then each NAME=VALUE, each group in
  ;; its own order: env reads -u only before the first assignment.
  (define (env-order env-args)
    (let loop ((rest env-args) (unsets '()) (sets '()))
      (cond ((null? rest) (append (reverse unsets) (reverse sets)))
            ((and (string=? (car rest) "-u") (pair? (cdr rest)))
             (loop (cddr rest) (cons (cadr rest) (cons "-u" unsets)) sets))
            (else (loop (cdr rest) unsets (cons (car rest) sets))))))

  ;; spawn-in : String (Listof String) String (Listof String)
  ;;            -> (U (List Integer String String) (List 'raised String))
  ;; Runs PROGRAM with ARGS in a fresh Chez with LIBDIRS as its library path,
  ;; under the memory gate's Valgrind when the gate asks (gated-command),
  ;; through env with ENV-ARGS (NAME=VALUE to set, -u NAME to unset): its exit
  ;; status, stdout and stderr. Never env -i: CHEZ and PATH survive.
  (define (spawn-in libdirs env-args program args)
    (guard (e (#t (list 'raised (describe e))))
      (capture-command
       (append '("env") (env-order env-args)
               (gated-command getenv (append (list chez "--libdirs" libdirs "--program" program)
                                             args))))))

  (define (spawn env-args program args) (spawn-in "src" env-args program args))

  ;; as-data : (U (List Integer String String) (List 'raised String))
  ;;           -> (U (List Integer (Listof Any) String) (List 'raised String))
  ;; A probe's answer, with what it printed read as data.
  (define (as-data answer)
    (if (eq? (car answer) 'raised)
        answer
        (list (car answer) (read-data (cadr answer)) (caddr answer))))

  ;; probe-with : (Listof String) (Listof String)
  ;;              -> (U (List Integer (Listof Any) String) (List 'raised String))
  ;; tests/refusal-probe.sps under ENV-ARGS, with ARGS.
  (define (probe-with env-args args)
    (as-data (spawn env-args "tests/refusal-probe.sps" args)))

  ;; probe : (Listof String) -> (U (List Integer (Listof Any) String) (List 'raised String))
  (define (probe env-args) (probe-with env-args '()))

  ;; verb-probe-with : (Listof String) (Listof String)
  ;;                   -> (U (List Integer (Listof Any) String) (List 'raised String))
  ;; tests/verb-probe.sps under ENV-ARGS, given CALLS, each the text of one
  ;; expression: its exit status, what it printed read as data, and stderr.
  (define (verb-probe-with env-args calls)
    (as-data (spawn env-args "tests/verb-probe.sps" calls)))

  ;; verb-answer : (Listof Any) -> Expected
  ;; The verb probe's whole answer: status 0, its LINES, one (OUTCOME GROWTH)
  ;; for each call, then every count zero and whether it ran under Valgrind,
  ;; and an empty stderr.
  (define (verb-answer lines)
    (list 0 (append lines (list no-native-objects valgrind-line)) ""))

  ;; verb-row-in : (String -> String) (String -> Any) String (U String #f)
  ;;               (Listof String) String (Listof Any) -> Void
  ;; The test DESCRIPTION: the verb probe, given CALLS, on BUILD, at (SO-OF
  ;; BUILD), under SWITCH; the build's compile, (COMPILED-STATUS BUILD), must
  ;; have answered 0, then (verb-answer LINES), whole. A suite names it
  ;; verb-row, with its own two.
  (define (verb-row-in so-of compiled-status build switch calls description lines)
    (test-equal (string-append "verbs on " build
                               (if switch (string-append " under \"" switch "\"") "")
                               ": " description)
      (verb-answer lines)
      (if (eqv? (compiled-status build) 0)
          (verb-probe-with (cons (override (so-of build)) (switch-args switch)) calls)
          (list 'not-compiled (compiled-status build)))))

  ;; override : String -> String
  (define (override path) (string-append "CHEZ_SODIUM_LIBRARY=" path))

  ;; switch-args : (U String #f) -> (Listof String)
  ;; CHEZ_SODIUM_DECOY set to SWITCH, or unset for #f: every child gets one or
  ;; the other, so a value left in this process's environment never reaches a
  ;; row.
  (define (switch-args switch)
    (if switch
        (list (string-append "CHEZ_SODIUM_DECOY=" switch))
        '("-u" "CHEZ_SODIUM_DECOY")))

  ;; --- what a probe answers ---------------------------------------------------------

  ;; The probe references loaded-libsodium three times. A load runs once per
  ;; process, whatever it decided, so the two later references answer what
  ;; the first did: the same record, or the refusal raised again.
  (define once '(again . (same same)))

  ;; Every count zero, whatever the load decided (ADR-0011).
  (define no-native-objects '(counts . ((block . 0))))

  ;; Under make test-memory, every child runs under the gate's own Valgrind,
  ;; and says so; anywhere else, none does.
  (define gated? (and (getenv "CHEZ_SODIUM_GATE_CHILD") #t))
  (define valgrind-line (cons 'valgrind (if gated? 'yes 'no)))

  ;; outcome : Integer (Listof Pair) (Listof Pair) (Listof Pair) (U (Listof String) #f)
  ;;           -> Expected
  ;; The probe's whole answer: STATUS; the lines of its first reference, HEAD;
  ;; BEFORE (then-override) and the references' again; the counts; AFTER
  ;; (marker); whether it ran under Valgrind; and the decoy's call log, CALLS,
  ;; as entries, or no calls line for a library without one. Its stderr is
  ;; empty.
  (define (outcome status head before after calls)
    (list status
          (append head before (list once no-native-objects) after (list valgrind-line)
                  (if calls (list (cons 'calls (join calls))) '()))
          ""))

  ;; report : String Integer Integer Integer -> Report
  ;; A report is what a loaded library says about itself, as the probe prints
  ;; it after the path and source: (version . V) (major . N) (minor . N)
  ;; (init . N).
  (define (report version major minor init)
    (list (cons 'version version) (cons 'major major) (cons 'minor minor)
          (cons 'init init)))

  ;; with-sizes : Report (Listof Natural) -> Report
  ;; REPORT with the probe's --sizes field after it: (sizes B BMIN BMAX KMIN
  ;; KMAX), native's five.
  (define (with-sizes report sizes)
    (append report (list (cons 'sizes sizes))))

  ;; control-sizes, other-sizes : (Listof Natural)
  ;; What the decoy's five size functions answer: by default, and under
  ;; sizes-other, where all five differ from each other and from a release's.
  (define control-sizes '(32 16 64 16 64))
  (define other-sizes '(33 8 80 9 81))

  ;; constants-keys : (Listof Symbol)
  ;; The fourteen constants' keys, in step 7's order: native's answers' keys.
  (define constants-keys
    '(pwhash-strbytes pwhash-strprefix
      pwhash-opslimit-min pwhash-opslimit-max pwhash-opslimit-interactive
      pwhash-opslimit-moderate pwhash-opslimit-sensitive
      pwhash-memlimit-min pwhash-memlimit-max pwhash-memlimit-interactive
      pwhash-memlimit-moderate pwhash-memlimit-sensitive
      pwhash-passwd-min pwhash-passwd-max))

  ;; control-constants, other-constants : (Listof (U Natural String #f))
  ;; What the decoy's fourteen constant functions answer, in constants-keys'
  ;; order: by default, the releases' own; under pwhash-limits-other, values
  ;; no release has, the twins opslimit_max (9) and passwd_max (100) apart.
  (define control-constants
    '(128 "$argon2id$" 1 4294967295 2 3 4
      8192 4398046510080 67108864 268435456 1073741824 0 4294967295))
  (define other-constants
    '(160 "$argon2i$" 2 9 5 6 7
      16384 1048576 24576 32768 40960 1 100))

  ;; with-constants : Report (Listof Any) -> Report
  ;; REPORT with the probe's --constants field after it: (constants (KEY . VALUE)
  ;; ...), native's fourteen recorded constants by key.
  (define (with-constants report constants)
    (append report (list (cons 'constants (map cons constants-keys constants)))))

  ;; loaded-lines : String Symbol Report -> (Listof Pair)
  (define (loaded-lines path source report)
    (append (list (cons 'loaded path) (cons 'source source)) report))

  ;; refused-lines : Symbol (U String #f) (U Symbol #f) Any (Listof String)
  ;;                 (Listof Any) -> (Listof Pair)
  ;; IRRITANTS are the condition's: the path, as the one irritant, for each
  ;; refusal that has a path.
  (define (refused-lines reason path source detail candidates irritants)
    (list (cons 'reason reason) (cons 'who 'chez-sodium) (cons 'path path)
          (cons 'source source) (cons 'detail detail) (cons 'candidates candidates)
          (cons 'irritants irritants)))

  ;; loaded : String Symbol Report (U (Listof String) #f) -> Expected
  (define (loaded path source report calls)
    (outcome 0 (loaded-lines path source report) '() '() calls))

  ;; refused : Symbol (U String #f) (U Symbol #f) Any (Listof String)
  ;;           (U (Listof String) #f) [(Listof Any)] -> Expected
  (define refused
    (case-lambda
      ((reason path source detail candidates calls)
       (refused reason path source detail candidates calls (list path)))
      ((reason path source detail candidates calls irritants)
       (outcome 1 (refused-lines reason path source detail candidates irritants)
                '() '() calls))))

  ;; --- the floors ---------------------------------------------------------------------

  ;; read-floor-values : -> (U (List String String) (List 'no-floors Any))
  ;; libsodium's floor from packaging/floors.sexp, as text, and the version
  ;; one patch below it: the decoy's versions (ADR-0011). A floor whose patch
  ;; is 0 has no version one patch below it: that is (no-floors ...), and a
  ;; floor change edits this procedure. Never a raise.
  (define (read-floor-values)
    (guard (e (#t (list 'no-floors (describe e))))
      (let* ((floors (read-floors))
             (parts (floor-numbers floors 'sodium)))
        (if (> (caddr parts) 0)
            (list (floor-text floors 'sodium)
                  (string-append (number->string (car parts)) "."
                                 (number->string (cadr parts)) "."
                                 (number->string (- (caddr parts) 1))))
            (list 'no-floors 'patch-is-zero)))))

  ;; --- the entries -----------------------------------------------------------------------

  ;; every-entry : (Listof String)
  ;; The entry points (chez-sodium private native) requires, in its order
  ;; (ADR-0002): the three version entries, sodium_init, then the rest,
  ;; sodium_memzero, randombytes_buf, crypto_generichash, its five size
  ;; functions, sodium_memcmp, crypto_pwhash_str, _str_verify and
  ;; _str_needs_rehash, then the password hash's fourteen constant functions. An entry that native requires and the decoy lacks
  ;; refuses the control, and the control's row fails. A row holds this list
  ;; to the convention table's names, whole and in order, so an entry dropped
  ;; from it takes its row with it only by failing that one.
  (define every-entry
    '("sodium_version_string" "sodium_library_version_major" "sodium_library_version_minor"
      "sodium_init" "sodium_memzero"
      "randombytes_buf" "crypto_generichash"
      "crypto_generichash_bytes" "crypto_generichash_bytes_min" "crypto_generichash_bytes_max"
      "crypto_generichash_keybytes_min" "crypto_generichash_keybytes_max"
      "sodium_memcmp"
      "crypto_pwhash_str" "crypto_pwhash_str_verify" "crypto_pwhash_str_needs_rehash"
      "crypto_pwhash_strbytes" "crypto_pwhash_strprefix"
      "crypto_pwhash_opslimit_min" "crypto_pwhash_opslimit_max"
      "crypto_pwhash_opslimit_interactive" "crypto_pwhash_opslimit_moderate"
      "crypto_pwhash_opslimit_sensitive"
      "crypto_pwhash_memlimit_min" "crypto_pwhash_memlimit_max"
      "crypto_pwhash_memlimit_interactive" "crypto_pwhash_memlimit_moderate"
      "crypto_pwhash_memlimit_sensitive"
      "crypto_pwhash_passwd_min" "crypto_pwhash_passwd_max"))

  ;; first-entries : (Listof String)
  ;; every-entry's first five: the load's own.
  (define first-entries (list-head every-entry 5))

  ;; verb-entries : (Listof String)
  ;; every-entry's next eight, the byte verbs', bound after sodium_memzero.
  (define verb-entries (list-head (list-tail every-entry 5) 8))

  ;; password-entries : (Listof String)
  ;; The password hash's three calls, strbytes, strprefix and the five
  ;; opslimits: ten.
  (define password-entries (list-head (list-tail every-entry 13) 10))

  ;; limit-entries : (Listof String)
  ;; The five memlimits and the two password-length functions: seven.
  (define limit-entries (list-tail every-entry 23))

  ;; size-calls : (Listof String)
  ;; The load's step 7, first part: each size function called once, in this
  ;; order, after every entry point is bound.
  (define size-calls
    '("crypto_generichash_bytes()" "crypto_generichash_bytes_min()"
      "crypto_generichash_bytes_max()" "crypto_generichash_keybytes_min()"
      "crypto_generichash_keybytes_max()"))

  ;; constant-calls : (Listof String)
  ;; The load's step 7, second part: each of the password hash's fourteen
  ;; constant functions called once, in this order, after the five sizes.
  (define constant-calls
    '("crypto_pwhash_strbytes()" "crypto_pwhash_strprefix()"
      "crypto_pwhash_opslimit_min()" "crypto_pwhash_opslimit_max()"
      "crypto_pwhash_opslimit_interactive()" "crypto_pwhash_opslimit_moderate()"
      "crypto_pwhash_opslimit_sensitive()"
      "crypto_pwhash_memlimit_min()" "crypto_pwhash_memlimit_max()"
      "crypto_pwhash_memlimit_interactive()" "crypto_pwhash_memlimit_moderate()"
      "crypto_pwhash_memlimit_sensitive()"
      "crypto_pwhash_passwd_min()" "crypto_pwhash_passwd_max()"))

  ;; --- decoys --------------------------------------------------------------------------

  (define decoy-source "tests/decoy-libsodium.c")

  (define (lacks entry) (string-append "-DDECOY_LACKS_" entry))

  ;; lacks-build : String -> String
  ;; The name of the build that leaves ENTRY out.
  (define (lacks-build entry) (string-append "lacks-" entry))

  ;; all-builds : (Listof (Pairof String (Listof String)))
  ;; Each build's name and its switches: a lacking build for each entry.
  (define all-builds
    (append (list (list "control")
                  (list "marked" "-DDECOY_MARKER")
                  (list "not-sodium" "-DDECOY_NOT_SODIUM"))
            (map (lambda (entry) (list (lacks-build entry) (lacks entry)))
                 every-entry)))

  ;; decoy-builds : (Listof String) -> (Listof (Pairof String (Listof String)))
  ;; The builds NAMES names, in all-builds' order, each once. A name that is
  ;; no build is left out, and the row that uses it finds no such build.
  (define (decoy-builds names)
    (filter (lambda (build) (member (car build) names)) all-builds))

  ;; compile-decoy : (String -> String) FloorValues String (Listof String)
  ;;                 -> (U 0 (List Integer String String) (List 'raised String))
  ;; Compiles the decoy as BUILD at (SO-OF BUILD) under SWITCHES, with the
  ;; floor's versions from FLOOR-VALUES: 0, or the compiler's whole answer when
  ;; it failed.
  (define (compile-decoy so-of floor-values build switches)
    (guard (e (#t (list 'raised (describe e))))
      (let* ((answer (capture-command
                      (append (c-compiler getenv)
                              (list "-Wall" "-Werror" "-shared" "-fPIC" "-o" (so-of build) decoy-source
                                    (string-append "-DDECOY_VERSION=\"" (car floor-values) "\"")
                                    (string-append "-DDECOY_BELOW=\"" (cadr floor-values) "\""))
                              switches))))
        (if (eqv? (car answer) 0) 0 answer))))

  ;; compile-decoys : (String -> String) FloorValues (Listof (Pairof String (Listof String)))
  ;;                  -> (Listof (Pairof String Any))
  ;; Every build of BUILDS, compiled once, in order: each name and its status.
  (define (compile-decoys so-of floor-values builds)
    (let loop ((rest builds) (done '()))
      (if (null? rest)
          (reverse done)
          (let ((status (compile-decoy so-of floor-values (caar rest) (cdar rest))))
            (loop (cdr rest) (cons (cons (caar rest) status) done))))))

  ;; decoy-status : (Listof (Pairof String Any)) String -> Any
  ;; BUILD's compile status in COMPILED, or (no-such-build BUILD).
  (define (decoy-status compiled build)
    (cond ((assoc build compiled) => cdr) (else (list 'no-such-build build))))

  ;; decoy-row-in : (String -> String) (String -> Any) String (U String #f) (Listof String) String
  ;;                (String -> Expected) -> Void
  ;; The test DESCRIPTION: the probe, with ARGS, on BUILD, at (SO-OF BUILD),
  ;; under SWITCH; the build's compile, (COMPILED-STATUS BUILD), must have
  ;; answered 0, then EXPECTED of its path. Every row references
  ;; loaded-libsodium three times, so each log asserted whole also shows that
  ;; the load ran once. A suite names it decoy-row, with its own two.
  (define (decoy-row-in so-of compiled-status build switch args description expected)
    (test-equal (string-append "decoy " build
                               (if switch (string-append " under \"" switch "\"") "")
                               ": " description)
      (cons 0 (expected (so-of build)))
      (cons (compiled-status build)
            (probe-with (cons (override (so-of build)) (switch-args switch)) args))))

  ;; The call log's entries, as tests/decoy-libsodium.c writes them: first the
  ;; switch it read, then each call.
  (define (read-switch switch) (string-append "decoy(" switch ")"))
  (define version-calls
    '("sodium_version_string()" "sodium_library_version_major()" "sodium_library_version_minor()"))
  (define init-call "sodium_init()")
  (define (log-of switch . calls) (cons (read-switch switch) calls))
  ;; init-calls : String -> (Listof String)
  ;; The calls up to sodium_init: a refusal at sodium_init's answer has no more.
  (define (init-calls switch)
    (append (list (read-switch switch)) version-calls (list init-call)))
  ;; loaded-calls : String -> (Listof String)
  ;; A successful load's calls: the three version entries, sodium_init, then
  ;; the five size calls and the fourteen constant calls. Every other entry
  ;; point is bound and never called.
  (define (loaded-calls switch)
    (append (init-calls switch) size-calls constant-calls))

  ;; missing-api-rows : (String (U String #f) (Listof String) String (String -> Expected) -> Void)
  ;;                    (Listof String) -> Void
  ;; Each entry point of ENTRIES left out, one at a time, through the suite's
  ;; DECOY-ROW: refused by name before anything calls it, never Chez's "no
  ;; entry for". The three version entries are each bound before any is
  ;; called, so a library lacking one has had no call; sodium_init is bound
  ;; after the three have answered; each later entry after sodium_init has,
  ;; and before any size or constant is read, so its refusal's log has neither.
  (define (missing-api-rows decoy-row entries)
    (for-each
     (lambda (entry)
       (decoy-row (lacks-build entry) #f '()
         (string-append "a library without " entry " is missing-api, naming it")
         (lambda (so)
           (refused 'missing-api so 'override entry '()
                    (cond ((string=? entry "sodium_init")
                           (cons (read-switch "control") version-calls))
                          ((member entry (list-tail every-entry 4))
                           (init-calls "control"))
                          (else (log-of "control")))))))
     entries))

  ;; --- the world ---------------------------------------------------------------------

  ;; field : Any Symbol -> Pair
  ;; The (KEY . VALUE) the probe printed for KEY, or (KEY . absent).
  (define (field answer key)
    (or (and (pair? answer) (pair? (cdr answer)) (list? (cadr answer))
             (for-all pair? (cadr answer))
             (assq key (cadr answer)))
        (cons key 'absent)))

  ;; make-directory : String -> (U 'made (List 'not-made Any))
  ;; mkdir -p PATH, or what went wrong; never a raise.
  (define (make-directory path)
    (guard (e (#t (list 'not-made (describe e))))
      (let ((answer (capture-command (list "mkdir" "-p" path))))
        (if (and (eqv? (car answer) 0) (file-directory? path)) 'made (list 'not-made answer)))))

  ;; process-world : -> (U 'guix 'fhs (List 'raised String))
  ;; The world of this process's /proc/self/maps, as native reads it. A
  ;; probe runs the same Chez, so it lives in the same world.
  (define (process-world)
    (let ((maps (guard (e (#t #f))
                  (call-with-port (open-file-input-port "/proc/self/maps" (file-options)
                                                        (buffer-mode block)
                                                        (make-transcoder (utf-8-codec)))
                    get-string-all))))
      (guard (e (#t (list 'raised (describe e))))
        (libsodium-world (if (string? maps) maps #f)))))

  ;; unset-override : (Listof String)
  ;; The override and the decoy's switch unset: discovery chooses.
  (define unset-override (cons* "-u" "CHEZ_SODIUM_LIBRARY" (switch-args #f)))

  ;; no-profiles-env : String String String -> (Listof String)
  ;; No profile to search: GUIX_ENVIRONMENT, GUIX_PROFILE and HOME each an
  ;; empty directory, so that discovery lists all five sources and none holds
  ;; a library: what not-found needs in a Guix world.
  (define (no-profiles-env environment profile home)
    (append unset-override
            (list (string-append "GUIX_ENVIRONMENT=" environment)
                  (string-append "GUIX_PROFILE=" profile)
                  (string-append "HOME=" home))))

  ;; guix-candidates-in : String String String -> (Listof String)
  ;; The candidates a Guix world checks with those three directories, in
  ;; discovery's order: libsodium.so.26, then .so.23, in each.
  (define (guix-candidates-in environment profile home)
    (append-map
     (lambda (directory)
       (list (string-append directory "/libsodium.so.26")
             (string-append directory "/libsodium.so.23")))
     (list (string-append environment "/lib")
           (string-append profile "/lib")
           (string-append home "/.guix-home/profile/lib")
           (string-append home "/.guix-profile/lib")
           "/run/current-system/profile/lib")))

  (define (append-map f lst) (apply append (map f lst)))

  ;; --- preflight -------------------------------------------------------------------------

  ;; The gate's directory of child logs, from the prefix make test-memory
  ;; exports: the directory of its --log-file=DIR/%p.valgrind word; #f outside
  ;; the gate.
  (define gate-log-dir
    (let ((prefix (getenv "CHEZ_SODIUM_GATE_CHILD")))
      (and prefix
           (let loop ((words (split-words prefix)))
             (cond ((null? words) #f)
                   ((and (string-prefix? "--log-file=" (car words))
                         (string-suffix? "/%p.valgrind" (car words)))
                    (let ((word (car words)))
                      (substring word (string-length "--log-file=")
                                 (- (string-length word) (string-length "/%p.valgrind")))))
                   (else (loop (cdr words))))))))

  ;; gate-logs : -> (Listof String)
  ;; The names in the gate's directory of child logs, sorted; none outside the
  ;; gate.
  (define (gate-logs)
    (if gate-log-dir
        (guard (e (#t (list 'unreadable)))
          (list-sort string<? (directory-list gate-log-dir)))
        '()))

  ;; command-of-log : String -> (U String (List 'no-command String))
  ;; The program and arguments of the Command: line of the Valgrind log NAME in
  ;; the gate's directory.
  (define (command-of-log name)
    (guard (e (#t (list 'no-command (describe e))))
      (let ((text (call-with-port
                   (open-file-input-port (string-append gate-log-dir "/" name) (file-options)
                                         (buffer-mode block) (make-transcoder (utf-8-codec)))
                   get-string-all)))
        (let loop ((lines (lines-of text)))
          (cond ((null? lines) (list 'no-command name))
                ((command-line-of (car lines)) => (lambda (command) command))
                (else (loop (cdr lines))))))))

  ;; lines-of : String -> (Listof String)
  (define (lines-of text)
    (let loop ((i 0) (start 0) (found '()))
      (cond ((= i (string-length text))
             (reverse (if (> i start) (cons (substring text start i) found) found)))
            ((char=? (string-ref text i) #\newline)
             (loop (+ i 1) (+ i 1) (cons (substring text start i) found)))
            (else (loop (+ i 1) start found)))))

  ;; command-line-of : String -> (U String #f)
  ;; What follows "==PID== Command: " on LINE, else #f.
  (define (command-line-of line)
    (let ((marker "== Command: "))
      (and (string-prefix? "==" line)
           (let loop ((i 2))
             (cond ((>= (+ i (string-length marker)) (string-length line)) #f)
                   ((string=? (substring line i (+ i (string-length marker))) marker)
                    (substring line (+ i (string-length marker)) (string-length line)))
                   ((char-numeric? (string-ref line i)) (loop (+ i 1)))
                   (else #f))))))

  ;; preflight-in : String (Listof String) -> (List Integer String String Pair)
  ;; tests/preflight.sps with LIBDIRS under ENV-ARGS: its exit status, stdout
  ;; and stderr, then (valgrind . yes) when exactly one log is new in the gate's
  ;; directory and its Command: line is the child's own, whole; (valgrind . no)
  ;; when none is, as outside the gate; else what the new logs were. Preflight
  ;; prints no such line itself: it is what make build runs.
  (define (preflight-in libdirs env-args)
    (let* ((before (gate-logs))
           (answer (spawn-in libdirs env-args "tests/preflight.sps" '()))
           (after (gate-logs))
           (new (filter (lambda (name) (not (member name before))) after))
           (command (join (list chez "--libdirs" libdirs "--program" "tests/preflight.sps"))))
      (append answer
              (list (cons 'valgrind
                          (cond ((null? new) 'no)
                                ((and (null? (cdr new)) (equal? (command-of-log (car new)) command))
                                 'yes)
                                (else (list 'logs new (map command-of-log new)))))))))

  ;; preflight : (Listof String) -> (List Integer String String Pair)
  (define (preflight env-args) (preflight-in "src" env-args))

  ;; counts-line : String
  ;; Preflight's last line: every count zero.
  (define counts-line "  counts:     ((block . 0))\n")

  ;; text : Any ... -> (U String (List 'unbuildable Any))
  ;; PARTS displayed one after another, or a sentinel no output equals when a
  ;; part is no string, number or symbol.
  (define (text . parts)
    (if (for-all (lambda (p) (or (string? p) (number? p) (symbol? p))) parts)
        (call-with-string-output-port
         (lambda (port) (for-each (lambda (p) (display p port)) parts)))
        (list 'unbuildable parts)))

  ;; accepted-text : Any Symbol Report -> (U String (List 'unbuildable Any))
  ;; What preflight prints when it accepts the library at PATH, from SOURCE,
  ;; that says REPORT of itself.
  (define (accepted-text path source report)
    (text "chez-sodium: libsodium loaded and accepted\n"
          "  path:       " path " (" source ")\n"
          "  version:    " (cdr (assq 'version report))
          " (library " (cdr (assq 'major report)) "." (cdr (assq 'minor report)) ")\n"
          counts-line)))
