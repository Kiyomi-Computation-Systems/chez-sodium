# M1 slice 1 mutation log: the pure core, and the exit checks removed

Every run was in the Guix container (`scripts/guix-env`): Chez 10.4.0, threaded. Two Sonnet
builders wrote the work and its log: the core (`conditions`, `load-state`, `discovery`,
`verify` and their suites) and the exit checks' removal. Each mutant changed one file in place,
by one exact replacement, and the file was restored and compared with `cmp`.

## Reproduced by the caller

- **Exit checks, mutation 2** (`suite-exit-status` ignores a counted block): 3 rows of
  `test-chez-sodium-testing` fail, as logged.
- **Discovery, the soname order swapped** to `.so.23` before `.so.26`: 25 rows of
  `test-discovery` fail.
- **Verify, a leading zero accepted** (`natural-text?` answers `#t`): 1 row of `test-verify`
  fails.
- **Clean rerun** after all of them, and after `checked-accessor` gained its rule symbol: `make
  test` 11 of 11, `make check-test-fails` all 12 cases, `make test-memory` 11 of 11, `make
  check-memory-gate` all 59 cases, `make check-clean`. `make check-nothreads` fails, naming the
  six libraries, as it must on a threaded Chez.

## The core

Each entry: Guards (the rows meant to catch it), Mutation (one exact replacement, made in place), Result, Clean rerun (the suite green after restoring, and `cmp` of the file against its backup).

### Red against a stub

Each suite was run against a stub of its library (same exports, no behaviour; the conditions stub has
real condition types with every accessor answering #f) by putting the stub directory first on
`--libdirs`. All four failed, and none with the suite dying before it named a row.

| Suite | Pass | Fail |
|---|---|---|
| test-conditions | 13 | 38 |
| test-load-state | 2 | 14 |
| test-discovery | 3 | 64 |
| test-verify | 0 | 18 |

A run that "passed" a row against a stub only did so where the row's expected value is the stub's
answer (for example a predicate false for a non-condition).

### Notes on the entries

- "conditions: sodium-failed-code reads the function" is a control: its replacement adds an unused
  definition, so it must SURVIVE. It does, which shows the harness reports a survivor.
- The mutant "refuse-secret adds the length" was first written with one parenthesis too few and
  died at read time; it was rerun corrected, and the corrected entry is the last in this log.
- Every entry's clean rerun is the suite green after the file was restored, and `cmp` against the
  backup made before the mutation.

### Entries

### conditions: reason init-failed dropped

- Guards: lu-reasons, lu-ctor-each, each-reason, near-reasons
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `missing-api init-failed))\n\n  ;; The fields` to `missing-api))\n\n  ;; The fields`
- Result: KILLED; 4 failing row(s); first: the reasons are exactly ADR-0002's six, amended, in order; the constructor takes each of the six reasons; each reason, built with the fields it carries, answers every field
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: reason misspelt (below-floor to below-flor)

- Guards: lu-reasons, constructor rows
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `load-failed below-floor missing-api init-failed))` to `load-failed below-flor missing-api init-failed))`
- Result: KILLED; 9 failing row(s); first: library-unavailable: an error, a chez-sodium-error and a library-unavailable; library-unavailable carries its reason, path, source, detail and candidates; the reasons are exactly ADR-0002's six, amended, in order
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: former reason not-threadsafe left in

- Guards: lu-reasons, not-threadsafe refusal
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `below-floor missing-api init-failed))\n\n  ;; The fields` to `below-floor missing-api init-failed not-threadsafe))\n\n  ;; The fields`
- Result: KILLED; 2 failing row(s); first: the reasons are exactly ADR-0002's six, amended, in order; the constructor refuses no-ssl, #f, a number, () and a reason spelled as a string, and che
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: secret-shown uses shown-value

- Guards: secret-kinds matrix, refuse-secret kinds, row-16 row
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(list 'kind (kind-of x)))\n\n  ;; refuse-field` to `(shown-value x))\n\n  ;; refuse-field`
- Result: KILLED; 13 failing row(s); first: every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a ; checked-accessor answers the accessor's value for what the predicate holds, and refuses th; secret-shown names every value by its kind alone, never the value: a string, a symbol, num
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: refuse-secret uses shown-value for the value

- Guards: refuse-secret shape per kind, row-16 row
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `rule parameter (secret-shown value)))` to `rule parameter (shown-value value)))`
- Result: KILLED; 3 failing row(s); first: refuse-secret raises an assertion violation from WHO, irritants the rule, the parameter an; refuse-secret shows a symbol, a number and a list of chars as their kinds, never as they a; a refusal by refuse-secret prints none of the secret, whatever its kind
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: refuse-secret swaps rule and parameter

- Guards: rs-shape, order row
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `rule parameter (secret-shown value)))` to `parameter rule (secret-shown value)))`
- Result: KILLED; 3 failing row(s); first: refuse-secret raises an assertion violation from WHO, irritants the rule, the parameter an; refuse-secret shows a symbol, a number and a list of chars as their kinds, never as they a; refuse-secret says the rule and the parameter it was given, in that order, whatever the wh
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: refuse-secret raises from itself, not WHO

- Guards: refuse-secret shape per kind
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(assertion-violation who "a secret parameter is refused by its kind alone"` to `(assertion-violation 'refuse-secret "a secret parameter is refused by its kind alone"`
- Result: KILLED; 3 failing row(s); first: refuse-secret raises an assertion violation from WHO, irritants the rule, the parameter an; refuse-secret shows a symbol, a number and a list of chars as their kinds, never as they a; refuse-secret says the rule and the parameter it was given, in that order, whatever the wh
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: refuse-secret does not check WHO

- Guards: rs-args
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(unless (symbol? who)\n      (refuse-field 'refuse-secret 'who "a symbol" who))` to ``
- Result: KILLED; 1 failing row(s); first: refuse-secret refuses a who, a rule or a parameter that is no symbol, from itself, naming 
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: refuse-field shows through shown-value

- Guards: rs-args (a number shown as it is), make-sodium-failed refusals
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `field (secret-shown value)))\n\n  ;; refuse-secret` to `field (shown-value value)))\n\n  ;; refuse-secret`
- Result: KILLED; 5 failing row(s); first: refuse-secret refuses a who, a rule or a parameter that is no symbol, from itself, naming ; make-sodium-failed refuses a function that is no string, naming the field first and the va; make-sodium-failed refuses a code that is no exact integer, naming the field first and the
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: checked-accessor shows through shown-value

- Guards: accessor refusal rows (number, symbol, boolean)
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(assertion-violation who (string-append "not " what) (secret-shown x)))\n      (accessor x)))` to `(assertion-violation who (string-append "not " what) (shown-value x)))\n      (accessor x)))`
- Result: KILLED; 3 failing row(s); first: every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a ; checked-accessor answers the accessor's value for what the predicate holds, and refuses th; the &sodium-failed accessors refuse another type's condition, the root alone, a string, a 
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: checked-accessor unchecked

- Guards: accessor refusal rows
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(unless (predicate x)\n        (assertion-violation who` to `(unless #t\n        (assertion-violation who`
- Result: KILLED; 6 failing row(s); first: every accessor refuses a string by its kind, naming the accessor, not the string; every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a ; no accessor prints the secret it refused, bare, in a list or in a vector
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: accessor reads the wrong field (reason reads path)

- Guards: lu-fields, each-reason
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `"a &sodium-library-unavailable" unchecked-sodium-library-unavailable-reason))` to `"a &sodium-library-unavailable" unchecked-sodium-library-unavailable-path))`
- Result: KILLED; 6 failing row(s); first: library-unavailable carries its reason, path, source, detail and candidates; the constructor takes each of the six reasons; each reason, built with the fields it carries, answers every field
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: &who dropped from raise-library-unavailable

- Guards: rlu-whole
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(make-who-condition 'chez-sodium)\n                      (make-message-condition message)` to `(make-message-condition message)`
- Result: KILLED; 2 failing row(s); first: raise-library-unavailable raises the whole condition: the types, who chez-sodium, a messag; raise-library-unavailable with no path or source, and no irritants
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: &who dropped from raise-sodium-failed

- Guards: sf-raise-whole, three-simple
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(raise (condition c (make-who-condition who)` to `(raise (condition c`
- Result: KILLED; 3 failing row(s); first: raise-sodium-failed raises the whole condition: an error and a chez-sodium-error, no asser; raise-sodium-failed names the who it is given, and the fields it is given; raise-sodium-failed's condition is exactly three simple conditions: the type, its &who and
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: raise-library-unavailable returns (raise-continuable)

- Guards: rlu-return
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(raise (condition (make-sodium-library-unavailable` to `(raise-continuable (condition (make-sodium-library-unavailable`
- Result: KILLED; 1 failing row(s); first: raise-library-unavailable never returns: a handler that returns gets nothing back, and the
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: raise-sodium-failed returns (raise-continuable)

- Guards: sf-raise-return
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(raise (condition c (make-who-condition who)` to `(raise-continuable (condition c (make-who-condition who)`
- Result: KILLED; 1 failing row(s); first: raise-sodium-failed never returns: a handler that returns gets nothing back, and the raise
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: raise-sodium-failed does not check WHO

- Guards: sf-raise-bad-who
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(check-raise-who 'raise-sodium-failed who)\n` to ``
- Result: KILLED; 1 failing row(s); first: raise-sodium-failed refuses a who that is no symbol, from itself, naming the field, before
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: make-sodium-failed takes any code

- Guards: sf-ctor
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(unless (exact-integer? code)` to `(unless #t`
- Result: KILLED; 2 failing row(s); first: make-sodium-failed refuses a code that is no exact integer, naming the field first and the; raise-sodium-failed refuses a function or a code the constructor refuses, from the constru
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: make-sodium-failed takes any function

- Guards: sf-ctor
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(unless (string? function)` to `(unless #t`
- Result: KILLED; 2 failing row(s); first: make-sodium-failed refuses a function that is no string, naming the field first and the va; raise-sodium-failed refuses a function or a code the constructor refuses, from the constru
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: &sodium-failed under &error, not the root

- Guards: matrix, parents
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(define-condition-type &sodium-failed &chez-sodium-error` to `(define-condition-type &sodium-failed &error`
- Result: KILLED; 4 failing row(s); first: raise-sodium-failed raises the whole condition: an error and a chez-sodium-error, no asser; raise-sodium-failed names the who it is given, and the fields it is given; the matrix, whole: each of the two library conditions is an error and a chez-sodium-error,
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: sodium-failed-code reads the function

- Guards: (control: no effect expected)
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(code unchecked-sodium-failed-code))` to `(code unchecked-sodium-failed-code))\n  (define unchecked-sodium-failed-code2 unchecked-sodium-failed-function)`
- Result: SURVIVED; 0 failing row(s)
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: sodium-failed accessors swapped

- Guards: sf-fields
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(checked-accessor 'sodium-failed-code sodium-failed? "a &sodium-failed"\n                      unchecked-sodium-failed-code))` to `(checked-accessor 'sodium-failed-code sodium-failed? "a &sodium-failed"\n                      unchecked-sodium-failed-function))`
- Result: KILLED; 5 failing row(s); first: an &sodium-failed carries its function and its code; an &sodium-failed's fields are not swapped: another fixture, other values; a code is any exact integer: negative, zero, positive and beyond a fixnum
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: kind-of takes a pair for other

- Guards: kind-of, secret-kinds
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(cond ((string? x) 'string)\n          ((or (pair? x) (null? x)) 'list)` to `(cond ((string? x) 'string)\n          ((null? x) 'list)`
- Result: KILLED; 11 failing row(s); first: every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a ; checked-accessor answers the accessor's value for what the predicate holds, and refuses th; kind-of, written out: a string, a list, () among them, a number, exact and inexact, a bool
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: constructor accepts any reason

- Guards: lu-refuse rows
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `(unless (memq reason sodium-library-unavailable-reasons)` to `(unless #t`
- Result: KILLED; 6 failing row(s); first: the constructor refuses a symbol that is not a reason; the constructor refuses no-ssl, #f, a number, () and a reason spelled as a string, and che; the constructor refuses each reason upper-cased, with a suffix, or missing its last charac
- Clean rerun: green (51 passes), file restored (cmp): identical

### load-state: load-step records nothing

- Guards: recording rows, later-failure rows
- Mutation: `exact replacement` in `src/chez-sodium/private/load-state.sls`: `(record-load-failure! c)\n                       (raise c)` to `(raise c)`
- Result: KILLED; 3 failing row(s); first: load-step records what it raised; a later load-step raises its own serious condition, unchanged, and the first stays recorde; record-load-failure! keeps the first failure, and raises nothing, for a later plain error 
- Clean rerun: green (16 passes), file restored (cmp): identical

### load-state: a later failure replaces the first

- Guards: keeps the first
- Mutation: `exact replacement` in `src/chez-sodium/private/load-state.sls`: `(unless failure\n      (set! failure c)))` to `(set! failure c))`
- Result: KILLED; 2 failing row(s); first: a later load-step raises its own serious condition, unchanged, and the first stays recorde; record-load-failure! keeps the first failure, and raises nothing, for a later plain error 
- Clean rerun: green (16 passes), file restored (cmp): identical

### load-state: load-step raises continuably

- Guards: not continuably
- Mutation: `exact replacement` in `src/chez-sodium/private/load-state.sls`: `(raise c))))\n         expr)` to `(raise-continuable c))))\n         expr)`
- Result: KILLED; 1 failing row(s); first: load-step raises its failure, not continuably: a handler that returns gets nothing back, a
- Clean rerun: green (16 passes), file restored (cmp): identical

### load-state: as-serious passes anything through

- Guards: as-serious rows, twice rows
- Mutation: `exact replacement` in `src/chez-sodium/private/load-state.sls`: `(if (serious-condition? obj)\n        obj` to `(if #t\n        obj`
- Result: KILLED; 8 failing row(s); first: as-serious makes a symbol or a number a chez-sodium-error from chez-sodium, carrying it; as-serious makes #f, a string, a list and () such an error too, carrying each as its one i; as-serious makes a warning or a bare message an error, carrying it
- Clean rerun: green (16 passes), file restored (cmp): identical

### load-state: record accepts a non-serious condition

- Guards: refuses a condition that is not serious
- Mutation: `exact replacement` in `src/chez-sodium/private/load-state.sls`: `(unless (serious-condition? c)\n      (assertion-violation 'record-load-failure!` to `(unless #t\n      (assertion-violation 'record-load-failure!`
- Result: KILLED; 1 failing row(s); first: record-load-failure! refuses a condition that is not serious
- Clean rerun: green (16 passes), file restored (cmp): identical

### load-state: guard catches serious conditions only

- Guards: twice rows (a symbol would wedge)
- Mutation: `exact replacement` in `src/chez-sodium/private/load-state.sls`: `(guard (e (#t (let ((c (as-serious e)))` to `(guard (e ((serious-condition? e) (let ((c (as-serious e)))`
- Result: KILLED; 6 failing row(s); first: load-step raises a symbol made serious, carrying it; load-step records what it raised; a later load-step raises its own serious condition, unchanged, and the first stays recorde
- Clean rerun: green (16 passes), file restored (cmp): identical

### discovery: .so.23 before .so.26

- Guards: guix/fhs lists, both-sonames
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `'("libsodium.so.26" "libsodium.so.23"))` to `'("libsodium.so.23" "libsodium.so.26"))`
- Result: KILLED; 25 failing row(s); first: guix: the candidate list, in ADR-0002's order; guix: GUIX_ENVIRONMENT unset contributes nothing; guix: GUIX_ENVIRONMENT set but empty contributes nothing
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: the bare libsodium.so tried

- Guards: lists, bare-only
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `'("libsodium.so.26" "libsodium.so.23"))` to `'("libsodium.so.26" "libsodium.so.23" "libsodium.so"))`
- Result: KILLED; 23 failing row(s); first: guix: the candidate list, in ADR-0002's order; guix: GUIX_ENVIRONMENT unset contributes nothing; guix: GUIX_ENVIRONMENT set but empty contributes nothing
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: an FHS directory in the Guix world

- Guards: guix: standard directory never chosen, lists
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `((guix) (guix-candidates getenv))` to `((guix) (append (guix-candidates getenv) (fhs-candidates (linux-triple machine-type))))`
- Result: KILLED; 11 failing row(s); first: guix: the candidate list, in ADR-0002's order; guix: GUIX_ENVIRONMENT unset contributes nothing; guix: GUIX_ENVIRONMENT set but empty contributes nothing
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: a Guix profile in the FHS world

- Guards: fhs: profile never chosen, lists
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `((fhs) (fhs-candidates (linux-triple machine-type)))` to `((fhs) (append (fhs-candidates (linux-triple machine-type)) (guix-candidates getenv)))`
- Result: KILLED; 9 failing row(s); first: fhs: the candidate list for ta6le, in ADR-0002's order; fhs: the candidate list for a6le is the same, under x86_64-linux-gnu; fhs: the candidate list for tarm64le and arm64le, under aarch64-linux-gnu
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: the override checked with exists?

- Guards: override never asked, asked list
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `((absolute? override) (values override 'override))` to `((and (absolute? override) (exists? override)) (values override 'override))`
- Result: KILLED; 3 failing row(s); first: override: it is never checked with exists?, since loading decides; override: absolute means a slash first: "/" alone is chosen; override: a libsodium.so.23 path is chosen as given, whatever else exists, and is never as
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: the override searched (falls back to the FHS list)

- Guards: override never asked, so23 row
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `((absolute? override) (values override 'override))` to `((absolute? override) (first-existing (cons (cons override 'override) (fhs-candidates #f)) exists?))`
- Result: KILLED; 3 failing row(s); first: override: it is never checked with exists?, since loading decides; override: absolute means a slash first: "/" alone is chosen; override: a libsodium.so.23 path is chosen as given, whatever else exists, and is never as
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: LD_LIBRARY_PATH read

- Guards: reads rows
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `(let ((override (getenv "CHEZ_SODIUM_LIBRARY")))` to `(let ((override (getenv "CHEZ_SODIUM_LIBRARY")) (ld (getenv "LD_LIBRARY_PATH")))`
- Result: KILLED; 3 failing row(s); first: discovery reads only CHEZ_SODIUM_LIBRARY when a valid override is set, on every platform; discovery reads only CHEZ_SODIUM_LIBRARY when an invalid override is set, on every platfor; with no override, discovery reads GUIX_ENVIRONMENT, GUIX_PROFILE and HOME in a Guix world 
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: soname-major order across directories

- Guards: dir-major row, fhs list
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `(define (append-map f lst)\n    (apply append (map f lst)))` to `(define (append-map f lst)\n    (let ((all (apply append (map f lst))))\n      (append (filter (lambda (p) (string-suffix? "26" (car p))) all)\n              (f`
- Result: KILLED; 14 failing row(s); first: fhs: the candidate list for ta6le, in ADR-0002's order; fhs: the candidate list for a6le is the same, under x86_64-linux-gnu; fhs: the candidate list for tarm64le and arm64le, under aarch64-linux-gnu
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: macos-system left in the sources

- Guards: sources
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `guix-system system))` to `guix-system system macos-system))`
- Result: KILLED; 2 failing row(s); first: libsodium-sources: exactly the seven sources, in order; every source but the override's is yielded by some candidate list
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: a relative GUIX_PROFILE accepted

- Guards: relative GUIX_PROFILE row
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `(absolute-or-false (getenv "GUIX_PROFILE"))` to `(getenv "GUIX_PROFILE")`
- Result: KILLED; 1 failing row(s); first: guix: a relative GUIX_PROFILE contributes nothing
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: every machine type is Linux

- Guards: platform rows
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `(string-suffix? "le" (symbol->string machine-type))` to `(string-suffix? "" (symbol->string machine-type))`
- Result: KILLED; 4 failing row(s); first: platform: a machine type ending in osx has no candidates, on both architectures, threaded ; platform: any other has no candidates, so not-found with an empty list; platform: the nt, nb and qnx machine types have no candidates either, not-found with an em
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: Guix libc not required under /gnu/store/

- Guards: world rows
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `(string-prefix? "/gnu/store/" path)\n         (string=?` to `(string=?`
- Result: KILLED; 18 failing row(s); first: no other variable is an override: the candidates decide; platform: a machine type ending in le is Linux; world: libc.so.6 under /usr/lib is fhs
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: a relative override accepted

- Guards: override relative/bare rows
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `((absolute? override) (values` to `((> (string-length override) 0) (values`
- Result: KILLED; 5 failing row(s); first: override: a relative path is invalid-override, carrying the value, with no fallback; override: a bare name is invalid-override; override: a slash anywhere but first is invalid-override, with the value as detail, in eve
- Clean rerun: green (67 passes), file restored (cmp): identical

### discovery: not-found without its candidates

- Guards: not-found row
- Mutation: `exact replacement` in `src/chez-sodium/private/discovery.sls`: `(refuse 'not-found #f #f #f paths` to `(refuse 'not-found #f #f #f '()`
- Result: KILLED; 6 failing row(s); first: guix: a standard directory is never chosen, even when every one exists; guix: with no variable set, the one candidate is the system profile's; guix: with only HOME set, the home profiles and the system's, in order
- Clean rerun: green (67 passes), file restored (cmp): identical

### verify: version compared as a string

- Guards: v-below, v-above (1.0.9 and 1.0.100)
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(version<=? sodium-floor version)` to `(string<=? "1.0.18" version-string)`
- Result: KILLED; 3 failing row(s); first: check-version: at and above the floor, in every part: accepted; check-version: below the floor, in every part: below-floor with the string as detail; the two checks decide alone: a pass of one never hides the refusal of the other, in either
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: a leading zero accepted

- Guards: v-unreadable
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(or (= n 1) (not (char=? (string-ref part 0) #\0)))` to `#t`
- Result: KILLED; 1 failing row(s); first: check-version: a string that is not three naturals is below-floor, with that string as det
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: floor one patch higher

- Guards: floor rows
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(define sodium-floor '(1 0 18))` to `(define sodium-floor '(1 0 19))`
- Result: KILLED; 7 failing row(s); first: the floor is 1.0.18; the floor is the libsodium floor of packaging/floors.sexp; check-version: the floor of packaging/floors.sexp is accepted
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: floor one patch lower

- Guards: floor rows
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(define sodium-floor '(1 0 18))` to `(define sodium-floor '(1 0 17))`
- Result: KILLED; 7 failing row(s); first: the floor is 1.0.18; the floor is the libsodium floor of packaging/floors.sexp; check-version: one patch below the floor of packaging/floors.sexp is below-floor, with tha
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: a sign accepted

- Guards: v-unreadable (signs)
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(and (char>=? c #\0) (char<=? c #\9)))` to `(or (char=? c #\+) (char=? c #\-) (and (char>=? c #\0) (char<=? c #\9))))`
- Result: KILLED; 1 failing row(s); first: check-version: a string that is not three naturals is below-floor, with that string as det
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: char-numeric? for digits

- Guards: v-nonascii
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(and (char>=? c #\0) (char<=? c #\9)))` to `(char-numeric? c))`
- Result: KILLED; 1 failing row(s); first: check-version: a digit that is not ASCII, or a trailing no-break space, is below-floor
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: a leading space trimmed

- Guards: v-unreadable (leading space)
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(let ((parts (split-dots s)))` to `(let ((parts (split-dots (if (and (> (string-length s) 0) (char=? (string-ref s 0) #\space)) (substring s 1 (string-length s)) s))))`
- Result: KILLED; 1 failing row(s); first: check-version: a string that is not three naturals is below-floor, with that string as det
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: a fourth part accepted

- Guards: v-unreadable (1.0.18.0)
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(and (= (length parts) 3)` to `(and (>= (length parts) 3)`
- Result: KILLED; 1 failing row(s); first: check-version: a string that is not three naturals is below-floor, with that string as det
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: patch compared alone

- Guards: v-below (0.99.99), v-above (2.0.0)
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(define (version<=? a b)\n    (cond ((null? a) #t)` to `(define (version<=? a b)\n    (cond ((pair? a) (<= (caddr a) (caddr b)))\n          ((null? a) #t)`
- Result: KILLED; 2 failing row(s); first: check-version: at and above the floor, in every part: accepted; check-version: below the floor, in every part: below-floor with the string as detail
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: NULL accepted

- Guards: v-null
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(if (and version (version<=? sodium-floor version))` to `(if (or (not version-string) (and version (version<=? sodium-floor version)))`
- Result: KILLED; 2 failing row(s); first: check-version: NULL, #f, is below-floor, with detail #f; every refusal is a chez-sodium-error from who chez-sodium, with a message, for the default
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: a non-string version not refused

- Guards: non-string row
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(unless (or (not version-string) (string? version-string))` to `(unless #t`
- Result: KILLED; 1 failing row(s); first: check-version: an object that is neither a string nor #f is an assertion violation from ch
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: the message appends the version even for NULL

- Guards: v-null, who/message row
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(if version-string\n                (string-append "libsodium " version-string " is older than chez-sodium's floor, ")\n                "libsodium's version str` to `(string-append "libsodium " version-string " is older than chez-sodium's floor, ")`
- Result: KILLED; 2 failing row(s); first: check-version: NULL, #f, is below-floor, with detail #f; every refusal is a chez-sodium-error from who chez-sodium, with a message, for the default
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: below-floor detail dropped

- Guards: below rows
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `'below-floor path source version-string '()` to `'below-floor path source #f '()`
- Result: KILLED; 7 failing row(s); first: check-version: one patch below the floor of packaging/floors.sexp is below-floor, with tha; check-version: 1.0.17 is below-floor, with the version, path and source; check-version: below the floor, in every part: below-floor with the string as detail
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: check-init accepts 2

- Guards: check-init refusals
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(or (= answer 0) (= answer 1))` to `(or (= answer 0) (= answer 1) (= answer 2))`
- Result: KILLED; 2 failing row(s); first: check-init: any other integer is init-failed, detail the answer, with the path and source; the two checks decide alone: a pass of one never hides the refusal of the other, in either
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: check-init accepts every answer below 2

- Guards: check-init refusals (-1)
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(or (= answer 0) (= answer 1))` to `(<= answer 1)`
- Result: KILLED; 2 failing row(s); first: check-init: any other integer is init-failed, detail the answer, with the path and source; every refusal is a chez-sodium-error from who chez-sodium, with a message, for the default
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: check-init refuses 1

- Guards: check-init 0 and 1 accepted
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(or (= answer 0) (= answer 1))` to `(= answer 0)`
- Result: KILLED; 1 failing row(s); first: check-init: 0, the first call, and 1, already initialized, are accepted
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: check-init takes an inexact answer

- Guards: check-init type rows
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `(unless (exact-integer? answer)` to `(unless #t`
- Result: KILLED; 1 failing row(s); first: check-init: an answer that is no exact integer is an assertion violation from check-init, 
- Clean rerun: green (18 passes), file restored (cmp): identical

### verify: init-failed detail dropped

- Guards: check-init refusals
- Mutation: `exact replacement` in `src/chez-sodium/private/verify.sls`: `'init-failed path source answer '()` to `'init-failed path source #f '()`
- Result: KILLED; 2 failing row(s); first: check-init: any other integer is init-failed, detail the answer, with the path and source; the two checks decide alone: a pass of one never hides the refusal of the other, in either
- Clean rerun: green (18 passes), file restored (cmp): identical

### conditions: refuse-secret adds the length to its irritant

- Guards: refuse-secret shape per kind
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `rule parameter (secret-shown value)))` to `rule parameter (append (secret-shown value) (list (if (string? value) (string-length value) 0)))))`
- Result: KILLED; 3 failing row(s); first: refuse-secret raises an assertion violation from WHO, irritants the rule, the parameter an; refuse-secret shows a symbol, a number and a list of chars as their kinds, never as they a; refuse-secret says the rule and the parameter it was given, in that order, whatever the wh
- Clean rerun: green (51 passes), file restored (cmp): identical

### Added: checked-accessor takes a rule

### conditions: the two accessor rule symbols swapped (sodium-failed-code under the library rule)

- Guards: acc rows for the &sodium-failed accessors
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `'sodium-failed-code 'not-a-sodium-failed` to `'sodium-failed-code 'not-a-sodium-library-unavailable`
- Result: KILLED; 1 failing row(s); first: the &sodium-failed accessors refuse another type's condition, the root alone, a string, a 
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: library accessor rule symbol swapped (reason under the failed rule)

- Guards: acc-1..3
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `'sodium-library-unavailable-reason 'not-a-sodium-library-unavailable` to `'sodium-library-unavailable-reason 'not-a-sodium-failed`
- Result: KILLED; 2 failing row(s); first: every accessor refuses a string by its kind, naming the accessor, not the string; every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a 
- Clean rerun: green (51 passes), file restored (cmp): identical

### conditions: checked-accessor drops the rule symbol from its irritants

- Guards: acc-1..3, acc-sf, checked-accessor row
- Mutation: `exact replacement` in `src/chez-sodium/private/conditions.sls`: `rule (secret-shown x)))\n      (accessor x)))` to `(secret-shown x)))\n      (accessor x)))`
- Result: KILLED; 4 failing row(s); first: every accessor refuses a string by its kind, naming the accessor, not the string; every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a ; checked-accessor answers the accessor's value for what the predicate holds, and refuses th
- Clean rerun: green (51 passes), file restored (cmp): identical


### The exit checks

### 1. counters export row
- Guards: test-counters' row "exports exactly native-kinds, count-up!, count-down! and native-counts: no reset".
- Mutation: in src/chez-sodium/private/counters.sls, `(export native-kinds count-up! count-down! native-counts)` -> `(export native-kinds count-up! count-down! native-counts locked)`.
- Result: FAIL on that row (actual listed `locked`), suite exit 1.
- Clean rerun: file restored; test-counters 11 passes, rc 0.

### 2. suite-exit-status ignores a counted block
- Guards: the native-objects-left rows in test-chez-sodium-testing.
- Mutation: in tests/chez-sodium-testing.sls, `(left (filter (lambda (entry) (not (eqv? (cdr entry) 0))) (native-counts))))` -> `(left (filter (lambda (entry) #f) (native-counts))))`.
- Result: 3 rows FAIL (two "native objects left" rows, "a failure, and a native object left"), rc 1.
- Clean rerun: file restored; test-chez-sodium-testing 62 passes, rc 0.
