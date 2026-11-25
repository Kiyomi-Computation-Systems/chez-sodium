#!r6rs
;;; The convention suite (ADR-0001): every foreign-procedure form
;;; under src/, read as data, held to a table with one row per binding. It never
;;; loads libsodium. tests/test-constants.sps holds each row's C prototype to
;;; sodium.h, and the map from its C types to its Chez types.
;;;
;;;   the table      written-out names, arguments, results and conventions,
;;;                  so a table loosened with the binding it holds still
;;;                  fails; each row's shape; every row cites ADR-0001 and
;;;                  ADR-0002, and every record cited exists; the allowlists,
;;;                  written out, are the types the table uses and void as a
;;;                  result
;;;   conventions    convention-of reads exactly nothing as plain and
;;;                  __collect_safe alone as collect-safe; anything else, a
;;;                  __varargs_after count among it, as other, which no row
;;;                  holds
;;;   src/           no violation, and the thirty forms are all native's
;;;   fixtures       tests/fixtures/conventions/<case>/, each the one fault it
;;;                  names, and the whole list of violations asserted: a form
;;;                  outside native, an entry that is no string literal, type
;;;                  lists that are not literal, a plain binding of a
;;;                  collect-safe row and the reverse, a form with no row, a
;;;                  row with no form, a C name bound twice, a file that
;;;                  cannot be read, words that are no form, a Scheme object
;;;                  as a type, a variadic convention, and the symbol
;;;                  foreign-procedure anywhere but a form's head, the import
;;;                  entry and one fender of bind-required: a stray reference
;;;   sweeps         each row of the table, changed in each field in turn,
;;;                  held against the real src/; each row removed in turn
;;;   the allowlist  against its whole complement: every type Chez 10.4
;;;                  accepts that the table does not use, each in a fixture
;;;                  binding as an argument and as a result, and each type the
;;;                  table uses as an argument alone, bound as a result; the
;;;                  suite asks Chez itself that each is accepted
;;;
;;; Every computation that can raise runs under a guard with a sentinel of
;;; its own: SRFI-64 makes #f of a raise in an actual expression, and catches
;;; none in an expected expression or a top-level definition. No expected
;;; value here is #f, and none depends on the order of a call's arguments.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (only (chezscheme) directory-list load-shared-object)
        (chez-sodium-testing)
        (foreign-conventions)
        (only (library-loading) every-entry))

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

;; --- what the table must say, written out ---------------------------------------------

;; expected-names : (Listof String)
;; ADR-0002's order: the version string, major and minor, sodium_init,
;; sodium_memzero, then the verbs' eight and the password hash's seventeen, as
;; native binds them in step 6.
(define expected-names
  '("sodium_version_string" "sodium_library_version_major"
    "sodium_library_version_minor" "sodium_init" "sodium_memzero"
    "randombytes_buf" "crypto_generichash" "crypto_generichash_bytes"
    "crypto_generichash_bytes_min" "crypto_generichash_bytes_max"
    "crypto_generichash_keybytes_min" "crypto_generichash_keybytes_max"
    "sodium_memcmp"
    "crypto_pwhash_str"
    "crypto_pwhash_str_verify"
    "crypto_pwhash_str_needs_rehash"
    "crypto_pwhash_strbytes"
    "crypto_pwhash_strprefix"
    "crypto_pwhash_opslimit_min"
    "crypto_pwhash_opslimit_max"
    "crypto_pwhash_opslimit_interactive"
    "crypto_pwhash_opslimit_moderate"
    "crypto_pwhash_opslimit_sensitive"
    "crypto_pwhash_memlimit_min"
    "crypto_pwhash_memlimit_max"
    "crypto_pwhash_memlimit_interactive"
    "crypto_pwhash_memlimit_moderate"
    "crypto_pwhash_memlimit_sensitive"
    "crypto_pwhash_passwd_min"
    "crypto_pwhash_passwd_max"))

;; collect-safe-names : (Listof String)
;; The calls that can block (ADR-0001): the two that run as long
;; as a hash's limits ask.
(define collect-safe-names '("crypto_pwhash_str" "crypto_pwhash_str_verify"))

;; accepted-types : (Listof Any)
;; Every foreign type Chez 10.4 accepts (CSUG 4.2) that the table does not
;; use. The allowlist must refuse each, as an argument and as a result.
(define accepted-types
  '(integer-8 integer-16 unsigned-16 integer-24 unsigned-24
    integer-32 unsigned-32 integer-40 unsigned-40 integer-48 unsigned-48
    integer-56 unsigned-56 integer-64 unsigned-int double
    unsigned-8 double-float single-float short
    unsigned-short unsigned long unsigned-long long-long
    unsigned-long-long float char wchar fixnum boolean iptr void*
    u8* u16* u32* utf-8 utf-16le utf-16be utf-32le utf-32be string wstring
    scheme-object ptr ssize_t ptrdiff_t wchar_t
    (* int) (& int) (* unsigned-8) (* uptr) (& uptr)))

;; argument-only-types : (Listof Symbol)
;; The types the table writes as an argument and never as a result: the
;; result allowlist must refuse each.
(define argument-only-types '(unsigned-64))

;; refused-by-chez-types : (Listof Any)
;; Types Chez itself refuses, and an ftype's bare name: the allowlist refuses
;; them too.
(define refused-by-chez-types
  '(time_t bool sodium_state (* void) (* sodium_state) (& sodium_state)))

;; --- small helpers ---------------------------------------------------------------------

;; written : Any -> String
(define (written x)
  (guard (e (#t "<unprintable>"))
    (call-with-string-output-port (lambda (p) (write x p)))))

;; starts-with? : String String -> Boolean
(define (starts-with? text prefix)
  (and (>= (string-length text) (string-length prefix))
       (string=? (substring text 0 (string-length prefix)) prefix)))

;; sorted-strings : (Listof String) -> (Listof String)
(define (sorted-strings strings) (list-sort string<? strings))

;; unique : (Listof Any) -> (Listof Any)
;; LST without a later repeat, in order of first appearance.
(define (unique lst)
  (let loop ((rest lst) (seen '()))
    (cond ((null? rest) (reverse seen))
          ((member (car rest) seen) (loop (cdr rest) seen))
          (else (loop (cdr rest) (cons (car rest) seen))))))

;; sorted-symbols : (Listof Symbol) -> (Listof Symbol)
(define (sorted-symbols symbols)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) symbols))

;; checked : (-> Any) -> Any
;; The thunk's answer, or (raised TEXT): a raise is an answer a row can name.
(define (checked thunk)
  (guard (e (#t (list 'raised (describe e))))
    (thunk)))

;; the real table, and the root the fixtures sit under
(define table conventions-table)
(define fixtures "tests/fixtures/conventions")

;; found-in : String Table -> (Listof Violation)
;; The violations of the fixture case CASE against TABLE.
(define (found-in case-name rows)
  (checked (lambda () (violations (string-append fixtures "/" case-name) rows))))

;; rows-named : (Listof String) -> Table
;; The real table's rows of these names, in the table's order.
(define (rows-named names)
  (filter (lambda (row) (member (row-name row) names)) table))

;; synthetic : String (Listof Any) Any -> Row
;; A row that says exactly what a fixture binding says, so that nothing but
;; the allowlist can refuse it.
(define (synthetic name arguments result)
  (list name (list "int" '()) arguments result 'plain '()))

;; with-field : Row Symbol Any -> Row
;; ROW with its convention, arguments or result replaced.
(define (with-field row field value)
  (let ((name (row-name row)) (proto (row-prototype row)) (records (row-records row)))
    (case field
      ((convention) (list name proto (row-arguments row) (row-result row) value records))
      ((arguments) (list name proto value (row-result row) (row-convention row) records))
      (else (list name proto (row-arguments row) value (row-convention row) records)))))

;; replace-row : Table String Row -> Table
(define (replace-row rows name new)
  (map (lambda (row) (if (string=? (row-name row) name) new row)) rows))

;; other-type : Symbol -> Symbol
;; An allowed type that is not T.
(define (other-type t) (if (eq? t 'int) 'uptr 'int))

;; flipped : Symbol -> Symbol
;; Another convention than C: plain's is collect-safe, and collect-safe's
;; plain.
(define (flipped c) (if (eq? c 'plain) 'collect-safe 'plain))

(define size-names
  '("crypto_generichash_bytes" "crypto_generichash_bytes_min" "crypto_generichash_bytes_max"
    "crypto_generichash_keybytes_min" "crypto_generichash_keybytes_max"))

(define native-file "chez-sodium/private/native.sls")

(test-begin "conventions")

;; --- the table ---------------------------------------------------------------------------

(test-equal "table: it has a row for each of the thirty entry points, in ADR-0002's order, and no other"
  expected-names
  (map row-name table))

;; (library-loading)'s every-entry is what test-library-loading-missing makes
;; a missing-api row for, one build and one row per name. Held whole and in
;; order: an entry dropped from it would take its build and its row with it.
(test-equal "table: its names are (library-loading)'s every-entry, the thirty required entry points, whole and in order"
  (list (map row-name table) 30)
  (list every-entry (length every-entry)))

(test-equal "table: every row is (NAME (RESULT (PARAMETER ...)) (ARGUMENT ...) RESULT CONVENTION (RECORD ...)); its argument types are as many as its prototype's parameters"
  '()
  (filter (lambda (row)
            (not (and (list? row) (= (length row) 6)
                      (string? (row-name row))
                      (let ((p (row-prototype row)))
                        (and (list? p) (= (length p) 2) (string? (car p))
                             (list? (cadr p)) (for-all string? (cadr p))
                             (= (length (cadr p)) (length (row-arguments row)))))
                      (list? (row-arguments row)) (for-all symbol? (row-arguments row))
                      (symbol? (row-result row))
                      (memq (row-convention row) '(plain collect-safe))
                      (pair? (row-records row)) (for-all string? (row-records row)))))
          table))

(test-equal "table: every row is plain but crypto_pwhash_str and crypto_pwhash_str_verify, which are collect-safe (ADR-0001, decision 7)"
  (map (lambda (name) (if (member name collect-safe-names) 'collect-safe 'plain))
       expected-names)
  (map row-convention table))

;; The thirty rows, written out, so that a table loosened together with the
;; binding it holds still fails: the table's own arguments, results and
;; conventions are compared with these, never with each other.
(define the-bound-rows
  '(("sodium_version_string" () uptr plain)
    ("sodium_library_version_major" () int plain)
    ("sodium_library_version_minor" () int plain)
    ("sodium_init" () int plain)
    ("sodium_memzero" (uptr size_t) void plain)
    ("randombytes_buf" (uptr size_t) void plain)
    ("crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int plain)
    ("crypto_generichash_bytes" () size_t plain)
    ("crypto_generichash_bytes_min" () size_t plain)
    ("crypto_generichash_bytes_max" () size_t plain)
    ("crypto_generichash_keybytes_min" () size_t plain)
    ("crypto_generichash_keybytes_max" () size_t plain)
    ("sodium_memcmp" (uptr uptr size_t) int plain)
    ("crypto_pwhash_str" (uptr uptr unsigned-64 unsigned-64 size_t) int collect-safe)
    ("crypto_pwhash_str_verify" (uptr uptr unsigned-64) int collect-safe)
    ("crypto_pwhash_str_needs_rehash" (uptr unsigned-64 size_t) int plain)
    ("crypto_pwhash_strbytes" () size_t plain)
    ("crypto_pwhash_strprefix" () uptr plain)
    ("crypto_pwhash_opslimit_min" () size_t plain)
    ("crypto_pwhash_opslimit_max" () size_t plain)
    ("crypto_pwhash_opslimit_interactive" () size_t plain)
    ("crypto_pwhash_opslimit_moderate" () size_t plain)
    ("crypto_pwhash_opslimit_sensitive" () size_t plain)
    ("crypto_pwhash_memlimit_min" () size_t plain)
    ("crypto_pwhash_memlimit_max" () size_t plain)
    ("crypto_pwhash_memlimit_interactive" () size_t plain)
    ("crypto_pwhash_memlimit_moderate" () size_t plain)
    ("crypto_pwhash_memlimit_sensitive" () size_t plain)
    ("crypto_pwhash_passwd_min" () size_t plain)
    ("crypto_pwhash_passwd_max" () size_t plain)))

(test-equal "table: the thirty rows are written out: the version string an address, major, minor and sodium_init an int, sodium_memzero and randombytes_buf a uptr and a size_t answering void, crypto_generichash its uptr, size_t, uptr, unsigned-64, uptr, size_t answering int, the five sizes a size_t, sodium_memcmp two addresses and a size_t answering int; crypto_pwhash_str its two addresses, two unsigned-64 and a size_t, and crypto_pwhash_str_verify its two addresses and an unsigned-64, each answering int and collect-safe; crypto_pwhash_str_needs_rehash an address, an unsigned-64 and a size_t answering int; the strbytes, the ten limits and the two password bounds a size_t, and the prefix an address; every other row plain (ADR-0001, decisions 3, 4 and 7)"
  the-bound-rows
  (map (lambda (name)
         (let ((row (car (rows-named (list name)))))
           (list name (row-arguments row) (row-result row) (row-convention row))))
       (map car the-bound-rows)))

(test-equal "table: the allowlists are int, uptr, size_t and unsigned-64 as arguments, and int, uptr, size_t and void as results"
  '((int uptr size_t unsigned-64) (int uptr size_t void))
  (list allowed-argument-types allowed-result-types))

(test-equal "table: the types its rows use are exactly the allowlists': every type an argument or a non-void result is the argument allowlist, and every result, and void, the result allowlist; no type is allowed that no row uses"
  (list (sorted-symbols allowed-argument-types) (sorted-symbols allowed-result-types))
  ;; void is a result only, so it joins the argument side never.
  (list (sorted-symbols (unique (append (apply append (map row-arguments table))
                                        (filter (lambda (t) (not (eq? t 'void)))
                                                (map row-result table)))))
        (sorted-symbols (unique (cons 'void (map row-result table))))))

(test-equal "table: the type only an argument uses is unsigned-64, which the result allowlist refuses"
  (list (sorted-symbols argument-only-types) '())
  (list (sorted-symbols (filter (lambda (t) (not (memq t (map row-result table))))
                                (unique (apply append (map row-arguments table)))))
        (filter (lambda (t) (memq t allowed-result-types)) argument-only-types)))

(test-equal "table: no row writes a type its allowlist refuses"
  '()
  (filter (lambda (row)
            (not (and (for-all (lambda (t) (memq t allowed-argument-types)) (row-arguments row))
                      (memq (row-result row) allowed-result-types))))
          table))

;; The records a row cites exist: ADR-NNNN is a file under .plans/decisions.
(define record-files
  (checked (lambda () (directory-list ".plans/decisions"))))

(define (cited-number record)
  (and (starts-with? record "ADR-") (>= (string-length record) 8)
       (substring record 4 8)))

;; The two numbers are required by name: another number that names a file
;; would pass a check that only asked the cited records to exist.
(test-equal "table: every row cites ADR-0001 and ADR-0002, and every record cited is a decision record that exists"
  '()
  (filter
   (lambda (row)
     (let ((numbers (map cited-number (row-records row))))
       (not (and (member "0001" numbers) (member "0002" numbers)
                 (list? record-files)
                 (for-all (lambda (n)
                            (and n (exists (lambda (f) (starts-with? f (string-append n "-")))
                                           record-files)))
                          numbers)))))
   table))

;; --- conventions --------------------------------------------------------------------------

;; Written out, so a reader loosened with its table still fails.
(test-equal "conventions: plain is nothing before the entry, and collect-safe is __collect_safe alone"
  '((plain) (collect-safe __collect_safe))
  convention-forms)

(test-equal "conventions: convention-of reads nothing as plain, and __collect_safe alone as collect-safe"
  '(plain collect-safe)
  (map convention-of '(() (__collect_safe))))

(test-equal "conventions: convention-of reads anything else as other, whole: __collect_safe twice, a convention unknown, and a __varargs_after count, of 2, of 0 or of 3, its two words bare, written \"2\", or beside __collect_safe, since no bound function is variadic"
  '((other __collect_safe __collect_safe) (other __collect_unsafe)
    (other (__varargs_after 2)) (other (__varargs_after 0)) (other (__varargs_after 3))
    (other __varargs_after 2) (other (__varargs_after "2"))
    (other __collect_safe (__varargs_after 2)) (other (__varargs_after 2) __collect_safe)
    (other (__varargs_after 2) (__varargs_after 2)))
  (map convention-of '((__collect_safe __collect_safe) (__collect_unsafe)
                       ((__varargs_after 2)) ((__varargs_after 0)) ((__varargs_after 3))
                       (__varargs_after 2) ((__varargs_after "2"))
                       (__collect_safe (__varargs_after 2)) ((__varargs_after 2) __collect_safe)
                       ((__varargs_after 2) (__varargs_after 2)))))

;; --- src/ ----------------------------------------------------------------------------------

(define src-items (checked (lambda () (scan-tree "src"))))

;; form-entry : Pair -> Any
;; The third from the end of (foreign-procedure CONVENTION ... ENTRY (ARGUMENT ...) RESULT).
(define (form-entry form)
  (let ((r (reverse (cdr form))))
    (if (>= (length r) 3) (caddr r) 'no-entry)))

(test-equal "src: every foreign-procedure form under src/ is one of the thirty bindings of (chez-sodium private native), in its one file and its one library, once each"
  (list (list native-file) '((chez-sodium private native)) (sorted-strings expected-names))
  (if (and (list? src-items) (for-all (lambda (i) (eq? (car i) 'binding)) src-items))
      (list (unique (map cadr src-items))
            (unique (map caddr src-items))
            (sorted-strings (map (lambda (i) (let ((e (form-entry (cadddr i)))) (if (string? e) e "?")))
                                 src-items)))
      src-items))

(test-equal "src: no violation: each form is a literal binding held to its row, and each row has its form"
  '()
  (checked (lambda () (violations "src" table))))

;; --- fixtures -------------------------------------------------------------------------------

(test-equal "fixture decoys: the word foreign-procedure in a comment, a string, #'foreign-procedure outside bind-required, a quoted symbol, the tail of a list and an import is no form; three real forms are, one nested in a let and a lambda, one in a vector; and the three uses that are no form, the syntax mention, the quoted symbol and the list's last element, are stray references, the import's entry not"
  `(3 ((stray-reference ,native-file) (stray-reference ,native-file) (stray-reference ,native-file)))
  (let ((items (checked (lambda () (scan-tree (string-append fixtures "/decoys"))))))
    (list (if (list? items) (length items) items)
          (found-in "decoys"
                    (rows-named '("sodium_init" "sodium_version_string" "sodium_memzero"))))))

;; A stray reference: the symbol where no form is headed by it, so that the
;; bindings it could make are unseen. Each fixture is the one fault it names,
;; with no row to answer for a binding.
(test-equal "fixture stray-alias: a keyword alias, (define-syntax fp (identifier-syntax foreign-procedure)), and a binding through it, fail, by file"
  `((stray-reference ,native-file))
  (found-in "stray-alias" '()))

(test-equal "fixture stray-define: (define fp foreign-procedure) fails, by file"
  `((stray-reference ,native-file))
  (found-in "stray-define" '()))

(test-equal "fixture stray-quoted: the symbol in a quoted list fails, by file"
  `((stray-reference ,native-file))
  (found-in "stray-quoted" '()))

(test-equal "fixture stray-syntax: a second (syntax foreign-procedure), in bind-required's fender, fails; the first, the import entry and the form's head do not"
  `((stray-reference ,native-file))
  (found-in "stray-syntax" (rows-named '("sodium_init"))))

(test-equal "fixture stray-other-macro: a (syntax foreign-procedure) in the fender of a macro that is not bind-required fails"
  `((stray-reference ,native-file))
  (found-in "stray-other-macro" (rows-named '("sodium_init"))))

(test-equal "fixture permitted: the import entry, bind-required's one fender mention and a form's head are all there is, and nothing fails"
  '()
  (found-in "permitted" (rows-named '("sodium_init"))))

(test-equal "fixture stray-optional-binder: a macro named bind-optional has no allowance: its one fender mention fails, though bind-required's does not"
  `((stray-reference ,native-file))
  (found-in "stray-optional-binder" (rows-named '("sodium_init" "sodium_version_string"))))

(test-equal "fixture stray-optional-syntax: both of bind-optional's fender mentions fail, with no bind-required there to lend its allowance"
  `((stray-reference ,native-file) (stray-reference ,native-file))
  (found-in "stray-optional-syntax" (rows-named '("sodium_version_string"))))

(test-equal "fixture plain-collect-safe-row: sodium_init bound plain, against a row that says collect-safe, fails, by name"
  '((mismatch "sodium_init" convention collect-safe plain))
  (found-in "plain-collect-safe-row"
            (list (with-field (car (rows-named '("sodium_init"))) 'convention 'collect-safe))))

(test-equal "fixture safe-other: sodium_init bound __collect_safe, against its plain row, fails, by name"
  '((mismatch "sodium_init" convention plain collect-safe))
  (found-in "safe-other" (rows-named '("sodium_init"))))

(test-equal "fixture collect-safe-ok: sodium_init bound __collect_safe, against a row that says collect-safe, holds, so the reader reads __collect_safe alone as collect-safe and not as plain"
  '()
  (found-in "collect-safe-ok"
            (list (with-field (car (rows-named '("sodium_init"))) 'convention 'collect-safe))))

(test-equal "fixture varargs-refused: sodium_memzero written with (__varargs_after 2) is no convention, and fails, by name, against its plain row"
  '((mismatch "sodium_memzero" convention plain (other (__varargs_after 2))))
  (found-in "varargs-refused" (rows-named '("sodium_memzero"))))

(test-equal "fixture scheme-object-u8: a u8* argument, a Scheme object, fails, twice, by name: refused, and not the row's"
  '((type-refused "sodium_memzero" argument 0 u8*)
    (mismatch "sodium_memzero" arguments (uptr size_t) (u8* size_t)))
  (found-in "scheme-object-u8" (rows-named '("sodium_memzero"))))

(test-equal "fixture scheme-object-string: a string result, a Scheme object, fails, twice, by name"
  '((type-refused "sodium_version_string" result string)
    (mismatch "sodium_version_string" result uptr string))
  (found-in "scheme-object-string" (rows-named '("sodium_version_string"))))

(test-equal "fixture scheme-object-utf8: a utf-8 result, a Scheme object, fails, twice, by name"
  '((type-refused "sodium_version_string" result utf-8)
    (mismatch "sodium_version_string" result uptr utf-8))
  (found-in "scheme-object-utf8" (rows-named '("sodium_version_string"))))

(test-equal "fixture outside: a form in another library fails, naming the file, the library and the entry"
  '((outside-native "chez-sodium/private/other.sls" (chez-sodium private other) "sodium_init"))
  (found-in "outside" (rows-named '("sodium_init"))))

(test-equal "fixture outside-no-library: a form in a file that holds no library fails too"
  '((outside-native "chez-sodium/stray.sls" #f "sodium_init"))
  (found-in "outside-no-library" (rows-named '("sodium_init"))))

(test-equal "fixture entry-not-literal: an entry that is a name, a call, a quoted symbol, a convention, or missing fails, naming each form"
  `((entry-not-literal ,native-file (foreign-procedure entry-name (uptr) int))
    (entry-not-literal ,native-file
                       (foreign-procedure (string-append "sodium_" "init") (uptr) int))
    (entry-not-literal ,native-file (foreign-procedure (quote sodium_init) (uptr) int))
    (entry-not-literal ,native-file (foreign-procedure __collect_safe (uptr) int))
    (entry-not-literal ,native-file (foreign-procedure)))
  (found-in "entry-not-literal" '()))

(test-equal "fixture types-not-literal: an argument list that is a name, is improper, holds a number or is a vector, and a result that is a string, fail, naming each entry"
  '((types-not-literal "sodium_init" argument-types int)
    (types-not-literal "sodium_library_version_major" (uptr . uptr) int)
    (types-not-literal "sodium_library_version_minor" (uptr) "uptr")
    (types-not-literal "sodium_memzero" (7) uptr)
    (types-not-literal "sodium_version_string" #(uptr uptr) uptr))
  (found-in "types-not-literal" '()))

(test-equal "fixture no-row: a binding the table has no row for fails, by name"
  '((no-row "randombytes_buf"))
  (found-in "no-row" '()))

(test-equal "fixture bound-twice: a C name bound twice in one file fails, once, by name"
  '((bound-twice "sodium_init"))
  (found-in "bound-twice" (rows-named '("sodium_init"))))

(test-equal "fixture bound-twice-two-files: and bound once in each of two files fails the same"
  '((bound-twice "sodium_init"))
  (found-in "bound-twice-two-files" (rows-named '("sodium_init"))))

(test-equal "fixture unreadable: a file the reader cannot read fails, naming the file"
  `((unreadable ,native-file))
  (found-in "unreadable" '()))

(test-equal "fixture positions: a refused type fails at each position: first, middle and last argument, the result, void as an argument; void as a result, a size_t result, and int, uptr, size_t and unsigned-64 as arguments, are allowed"
  '((type-refused "p_first" argument 0 string)
    (type-refused "p_middle" argument 1 string)
    (type-refused "p_last" argument 2 string)
    (type-refused "p_result" result string)
    (type-refused "p_void_argument" argument 0 void))
  (found-in "positions"
            (list (synthetic "p_first" '(string int int) 'int)
                  (synthetic "p_middle" '(int string int) 'int)
                  (synthetic "p_last" '(int int string) 'int)
                  (synthetic "p_result" '(int int int) 'string)
                  (synthetic "p_void_argument" '(void) 'int)
                  (synthetic "p_void_result" '(int) 'void)
                  (synthetic "p_allowed" '(size_t int uptr unsigned-64) 'int)
                  (synthetic "p_size_result" '() 'size_t))))

;; --- rows against the real src/, changed in turn ---------------------------------------------

(test-equal "sweep: a row removed fails, by name, for each of the thirty rows"
  (map (lambda (name) (list (list 'no-row name))) expected-names)
  (map (lambda (name)
         (checked (lambda ()
                    (violations "src" (filter (lambda (row) (not (string=? (row-name row) name)))
                                              table)))))
       expected-names))

(test-equal "sweep: a row with no form fails, by name"
  '((no-form "sodium_extra"))
  (checked (lambda ()
             (violations "src" (append table (list (synthetic "sodium_extra" '() 'int)))))))

(test-equal "sweep: a row's convention flipped fails, by name, for each of the thirty rows: plain to collect-safe, and the two collect-safe rows to plain"
  (list 30
        (map (lambda (row)
               (list (list 'mismatch (row-name row) 'convention (flipped (row-convention row))
                           (row-convention row))))
             table))
  (list (length table)
        (map (lambda (row)
               (checked (lambda ()
                          (violations "src" (replace-row table (row-name row)
                                                         (with-field row 'convention
                                                                     (flipped (row-convention row))))))))
             table)))

(test-equal "sweep: a row's result type changed fails, by name, for each of the thirty rows: int to uptr, and uptr, size_t and void to int"
  (list 30
        (map (lambda (row)
               (list (list 'mismatch (row-name row) 'result (other-type (row-result row)) (row-result row))))
             table))
  (list (length table)
        (map (lambda (row)
               (checked (lambda ()
                          (violations "src" (replace-row table (row-name row)
                                                         (with-field row 'result (other-type (row-result row))))))))
             table)))

;; every argument of every row, changed at its own position
(define argument-cases
  (apply append
         (map (lambda (row)
                (let loop ((i 0) (found '()))
                  (if (= i (length (row-arguments row)))
                      (reverse found)
                      (loop (+ i 1)
                            (cons (list row i
                                        (let swap ((rest (row-arguments row)) (j 0))
                                          (cond ((null? rest) '())
                                                ((= j i) (cons (other-type (car rest)) (cdr rest)))
                                                (else (cons (car rest) (swap (cdr rest) (+ j 1)))))))
                                  found)))))
              table)))

(test-equal "sweep: a row's argument type changed at each position fails, by name, for each of the twenty-four arguments of the rows"
  (list 24
        (map (lambda (c)
               (list (list 'mismatch (row-name (car c)) 'arguments (caddr c) (row-arguments (car c)))))
             argument-cases))
  (list (length argument-cases)
        (map (lambda (c)
               (checked (lambda ()
                          (violations "src" (replace-row table (row-name (car c))
                                                         (with-field (car c) 'arguments (caddr c)))))))
             argument-cases)))

;; A length is size_t. A row that writes it as uptr, as unsigned-64 or as int
;; is not what native binds, and the reader says so by name. uptr is allowed
;; on both sides, so only the row catches it; test-constants' map holds the
;; row to the header from the other side.
(test-equal "sweep: sodium_memzero's size_t argument written uptr, unsigned-64 and int in its row each fails, by name, against the real src/"
  '(((mismatch "sodium_memzero" arguments (uptr uptr) (uptr size_t)))
    ((mismatch "sodium_memzero" arguments (uptr unsigned-64) (uptr size_t)))
    ((mismatch "sodium_memzero" arguments (uptr int) (uptr size_t))))
  (map (lambda (type)
         (checked (lambda ()
                    (violations "src" (replace-row table "sodium_memzero"
                                                   (with-field (car (rows-named '("sodium_memzero")))
                                                               'arguments (list 'uptr type)))))))
       '(uptr unsigned-64 int)))

;; crypto_generichash's lengths: outlen and keylen are size_t, and inlen is
;; unsigned long long, so unsigned-64. A row that swaps them is not what native
;; binds, though both types are allowed as arguments: only the row catches it.
(test-equal "sweep: crypto_generichash's inlen written size_t, its outlen written unsigned-64, its keylen written unsigned-64, and its inlen written uptr in its row each fails, by name, against the real src/"
  '(((mismatch "crypto_generichash" arguments (uptr size_t uptr size_t uptr size_t)
               (uptr size_t uptr unsigned-64 uptr size_t)))
    ((mismatch "crypto_generichash" arguments (uptr unsigned-64 uptr unsigned-64 uptr size_t)
               (uptr size_t uptr unsigned-64 uptr size_t)))
    ((mismatch "crypto_generichash" arguments (uptr size_t uptr unsigned-64 uptr unsigned-64)
               (uptr size_t uptr unsigned-64 uptr size_t)))
    ((mismatch "crypto_generichash" arguments (uptr size_t uptr uptr uptr size_t)
               (uptr size_t uptr unsigned-64 uptr size_t))))
  (map (lambda (arguments)
         (checked (lambda ()
                    (violations "src" (replace-row table "crypto_generichash"
                                                   (with-field (car (rows-named '("crypto_generichash")))
                                                               'arguments arguments))))))
       '((uptr size_t uptr size_t uptr size_t)
         (uptr unsigned-64 uptr unsigned-64 uptr size_t)
         (uptr size_t uptr unsigned-64 uptr unsigned-64)
         (uptr size_t uptr uptr uptr size_t))))

;; A size function answers size_t. Written uptr, unsigned-64 or int in its row,
;; it fails by name.
(test-equal "sweep: each size function's size_t result written uptr, unsigned-64 and int in its row fails, by name, against the real src/"
  (map (lambda (name)
         (map (lambda (type)
                (list (list 'mismatch name 'result type 'size_t)))
              '(uptr unsigned-64 int)))
       size-names)
  (map (lambda (name)
         (map (lambda (type)
                (checked (lambda ()
                           (violations "src" (replace-row table name
                                                          (with-field (car (rows-named (list name)))
                                                                      'result type))))))
              '(uptr unsigned-64 int)))
       size-names))

;; --- the allowlist, against its whole complement --------------------------------------------

;; Chez itself is asked: each type of the complement must be one it accepts,
;; as an argument and as a result, so the list is the foreign types Chez 10.4
;; takes and not a guess. A control, a type Chez refuses, is refused.
(define libc-loaded
  (checked (lambda ()
             (load-shared-object "libc.so.6")
             'loaded)))

(define (chez-takes? type position)
  (guard (e (#t 'refused))
    (eval (if (eq? position 'argument)
              `(foreign-procedure "getpid" (,type) int)
              `(foreign-procedure "getpid" () ,type))
          (environment '(chezscheme)))
    'accepted))

(test-equal "complement: libc loaded, for Chez to resolve an entry point to ask about"
  'loaded libc-loaded)

(test-equal "complement: Chez accepts each type as an argument, and refuses the control"
  '(() refused)
  (list (filter (lambda (t) (not (eq? (chez-takes? t 'argument) 'accepted))) accepted-types)
        (chez-takes? 'not-a-type 'argument)))

(test-equal "complement: Chez accepts each type as a result, and each type the table uses as an argument alone, and refuses the control"
  '(() refused)
  (list (filter (lambda (t) (not (eq? (chez-takes? t 'result) 'accepted)))
                (append accepted-types argument-only-types))
        (chez-takes? 'not-a-type 'result)))

(test-equal "complement: Chez refuses the types the list adds, so the two lists are apart"
  '()
  (filter (lambda (t) (eq? (chez-takes? t 'argument) 'accepted)) refused-by-chez-types))

(test-equal "complement: none of the types is one the allowlist allows"
  '()
  (filter (lambda (t) (or (memq t allowed-argument-types) (memq t allowed-result-types)))
          (append accepted-types refused-by-chez-types)))

;; The fixture binds each type, as the one argument of fx_argument_N and as
;; the result of fx_result_N; then each type of argument-only-types as the
;; result of fx_result_only_K; and void as an argument of fx_void_argument.
(define complement (append accepted-types refused-by-chez-types))

;; result-only : (Listof (Pairof String Symbol))
;; fx_result_only_K and its type, for each of argument-only-types.
(define result-only
  (let loop ((rest argument-only-types) (k 0) (found '()))
    (if (null? rest)
        (reverse found)
        (loop (cdr rest) (+ k 1)
              (cons (cons (string-append "fx_result_only_" (number->string k)) (car rest)) found)))))

(define complement-rows
  (let loop ((rest complement) (i 0) (rows '()))
    (if (null? rest)
        (append (reverse rows)
                (map (lambda (entry) (synthetic (car entry) '() (cdr entry))) result-only)
                (list (synthetic "fx_void_argument" '(void) 'int)))
        (loop (cdr rest) (+ i 1)
              (cons (synthetic (string-append "fx_result_" (number->string i)) '() (car rest))
                    (cons (synthetic (string-append "fx_argument_" (number->string i))
                                     (list (car rest)) 'int)
                          rows))))))

(define complement-refusals
  (let loop ((rest complement) (i 0) (found '()))
    (if (null? rest)
        (append (reverse found)
                (map (lambda (entry) (list 'type-refused (car entry) 'result (cdr entry))) result-only)
                (list '(type-refused "fx_void_argument" argument 0 void)))
        (loop (cdr rest) (+ i 1)
              (cons (list 'type-refused (string-append "fx_result_" (number->string i)) 'result (car rest))
                    (cons (list 'type-refused (string-append "fx_argument_" (number->string i))
                                'argument 0 (car rest))
                          found))))))

(test-equal "complement: the fixture binds every type, each row says exactly what its binding says, and the allowlist refuses every one, as an argument and as a result, each type the table uses as an argument alone as a result, and void as an argument"
  (list 120 complement-refusals)
  (list (length complement-refusals) (found-in "types" complement-rows)))

(test-end "conventions")

(exit (suite-exit-status runner))
