#!r6rs
;;; The decoy's pointer rule, read from its source (ADR-0011, amended).
;;;
;;; A stand-in libsodium that includes sodium.h reads every pointer it is
;;; given through a volatile uintptr_t, and only that copy is tested, logged
;;; and written through. A plain test of a nonnull parameter fails
;;; -Werror=nonnull-compare and the compiler may delete it; but nonnull is
;;; per function, and covers only some of the pointers the verbs' entries
;;; take, so the compile holds the rule for those alone. This suite holds it
;;; for all.
;;;
;;; It reads every tests/*.c that includes sodium.h, as text, with comments
;;; and string literals stripped, and matches whole identifiers. In each
;;; definition of a function whose name begins sodium_, randombytes_ or
;;; crypto_, each pointer parameter, written with a * or as an array
;;; T NAME[...], occurs in the body exactly once, as (uintptr_t) NAME, the
;;; value of a volatile uintptr_t declaration, and occurs in no #define's
;;; replacement list, outside that macro's own parameters. A declaration with
;;; no body is not read, and neither are the file's other functions, such as
;;; the decoy's called.
;;;
;;; A scan answers the functions it read, each with its pointer parameters,
;;; and the breaches: (FUNCTION PARAMETER (uses N)) for a parameter that
;;; occurs N times, N not 1, (FUNCTION PARAMETER plain) for one that occurs
;;; once, other than as the copy, and (FUNCTION PARAMETER macro) for one a
;;; macro names.
;;;
;;; What it cannot read it refuses, by name, so that no definition vanishes
;;; silently; a function so refused is not among those read, and so fails
;;; the real files' whole list:
;;;
;;;   (FUNCTION unreadable head)       something but { ; , or an attribute
;;;                                    follows the parameter list: a macro
;;;                                    there, or a second head under #if
;;;   (FUNCTION unreadable name)       a family name, outside any braces, that
;;;                                    no ( follows: a parenthesised name, a
;;;                                    definition a macro makes
;;;   (FUNCTION unreadable parameter)  a parameter with an attribute, or a type
;;;                                    of any word but the scalar ones: a
;;;                                    typedef that may be a pointer
;;;   (extern unreadable block)        an extern "C" { around definitions
;;;
;;; What it does not read: a function whose name a macro builds, or whose
;;; name is no family name; and which arm of an #if holds, since every arm is
;;; text to it.
;;;
;;; This process loads no libsodium. Each expected value is one the scanner
;;; cannot produce by failing, and none is #f. Whatever can raise is computed
;;; under a guard, with a sentinel of its own.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (only (chezscheme) directory-list))

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

(test-begin "decoy-source")

;; --- the scanner -------------------------------------------------------------------------

;; strip : String Boolean -> String
;; TEXT with every comment replaced by spaces and, unless KEEP-STRINGS?, every
;; string and character literal too. Newlines stay, so lines keep their numbers.
(define (strip text keep-strings?)
  (let ((n (string-length text)))
    (call-with-string-output-port
     (lambda (out)
       (define (blank c) (write-char (if (char=? c #\newline) c #\space) out))
       (define (at i) (if (< i n) (string-ref text i) #\nul))
       (let loop ((i 0))
         (when (< i n)
           (let ((c (string-ref text i)))
             (cond
               ((and (char=? c #\/) (char=? (at (+ i 1)) #\*))
                (let skip ((j (+ i 2)))
                  (cond ((>= j n) (loop j))
                        ((and (char=? (string-ref text j) #\*) (char=? (at (+ j 1)) #\/))
                         (display "  " out)
                         (loop (+ j 2)))
                        (else (blank (string-ref text j)) (skip (+ j 1))))))
               ((and (char=? c #\/) (char=? (at (+ i 1)) #\/))
                (let skip ((j i))
                  (if (or (>= j n) (char=? (string-ref text j) #\newline))
                      (loop j)
                      (begin (write-char #\space out) (skip (+ j 1))))))
               ((or (char=? c #\") (char=? c #\'))
                (write-char (if keep-strings? c #\space) out)
                (let skip ((j (+ i 1)))
                  (cond ((>= j n) (loop j))
                        ((char=? (string-ref text j) #\\)
                         (if keep-strings?
                             (begin (write-char #\\ out) (write-char (at (+ j 1)) out))
                             (begin (write-char #\space out) (blank (at (+ j 1)))))
                         (skip (+ j 2)))
                        ((char=? (string-ref text j) c)
                         (write-char (if keep-strings? c #\space) out)
                         (loop (+ j 1)))
                        (else (if keep-strings?
                                  (write-char (string-ref text j) out)
                                  (blank (string-ref text j)))
                              (skip (+ j 1))))))
               (else (write-char c out) (loop (+ i 1)))))))))))

;; lines-of : String -> (Listof String)
(define (lines-of text)
  (let loop ((i 0) (start 0) (found '()))
    (cond ((= i (string-length text))
           (reverse (cons (substring text start i) found)))
          ((char=? (string-ref text i) #\newline)
           (loop (+ i 1) (+ i 1) (cons (substring text start i) found)))
          (else (loop (+ i 1) start found)))))

;; trim : String -> String
(define (trim s)
  (let loop ((a 0) (b (string-length s)))
    (cond ((and (< a b) (char-whitespace? (string-ref s a))) (loop (+ a 1) b))
          ((and (< a b) (char-whitespace? (string-ref s (- b 1)))) (loop a (- b 1)))
          (else (substring s a b)))))

;; directive : String -> (U String #f)
;; What follows the # of a preprocessor line, trimmed, or #f for any other line.
(define (directive line)
  (let ((s (trim line)))
    (and (> (string-length s) 0) (char=? (string-ref s 0) #\#)
         (trim (substring s 1 (string-length s))))))

;; includes-sodium? : String -> (U 'yes 'no)
;; Whether TEXT has an #include of <sodium.h> or "sodium.h" that is not in a
;; comment.
(define (includes-sodium? text)
  (if (let loop ((lines (lines-of (strip text #t))))
        (and (pair? lines)
             (or (let ((d (directive (car lines))))
                   (and d (>= (string-length d) 7)
                        (string=? (substring d 0 7) "include")
                        (member (trim (substring d 7 (string-length d)))
                                '("<sodium.h>" "\"sodium.h\""))
                        #t))
                 (loop (cdr lines)))))
      'yes
      'no))

;; code-text : String -> String
;; TEXT stripped, and without its preprocessor lines, backslash continuations
;; included.
(define (code-text text)
  (let loop ((lines (lines-of (strip text #f))) (kept '()) (continued? #f))
    (if (null? lines)
        (apply string-append (reverse kept))
        (let* ((line (car lines))
               (skip? (or continued? (and (directive line) #t)))
               (n (string-length line))
               (more? (and skip? (> n 0) (char=? (string-ref line (- n 1)) #\\))))
          (loop (cdr lines) (cons (if skip? "\n" (string-append line "\n")) kept) more?)))))

;; ident-start? : Char -> Boolean
(define (ident-start? c) (or (char-alphabetic? c) (char=? c #\_)))
(define (ident-char? c) (or (ident-start? c) (char-numeric? c)))

;; tokens : String -> (Vectorof String)
;; Identifiers, numbers and single punctuation characters, whole.
(define (tokens text)
  (let ((n (string-length text)))
    (let loop ((i 0) (found '()))
      (cond ((>= i n) (list->vector (reverse found)))
            ((char-whitespace? (string-ref text i)) (loop (+ i 1) found))
            ((ident-char? (string-ref text i))
             (let scan ((j i))
               (if (and (< j n) (ident-char? (string-ref text j)))
                   (scan (+ j 1))
                   (loop j (cons (substring text i j) found)))))
            (else (loop (+ i 1) (cons (string (string-ref text i)) found)))))))

(define (ident-token? token) (ident-start? (string-ref token 0)))

(define (prefix? prefix s)
  (and (>= (string-length s) (string-length prefix))
       (string=? (substring s 0 (string-length prefix)) prefix)))

;; family? : String -> Boolean
(define (family? name)
  (or (prefix? "sodium_" name) (prefix? "randombytes_" name) (prefix? "crypto_" name)))

;; matching : (Vectorof String) Natural String String -> Natural
;; The index of the token that closes the OPEN at INDEX, or the vector's length.
(define (matching toks index open close)
  (let loop ((i (+ index 1)) (depth 1))
    (cond ((>= i (vector-length toks)) i)
          ((string=? (vector-ref toks i) open) (loop (+ i 1) (+ depth 1)))
          ((string=? (vector-ref toks i) close)
           (if (= depth 1) i (loop (+ i 1) (- depth 1))))
          (else (loop (+ i 1) depth)))))

;; slice : (Vectorof String) Natural Natural -> (Listof String)
(define (slice toks from to)
  (let loop ((i (- to 1)) (found '()))
    (if (< i from) found (loop (- i 1) (cons (vector-ref toks i) found)))))

;; split-commas : (Listof String) -> (Listof (Listof String))
;; The parameters of a list, cut at the commas outside any bracket.
(define (split-commas toks)
  (let loop ((rest toks) (depth 0) (current '()) (done '()))
    (cond ((null? rest) (reverse (if (null? current) done (cons (reverse current) done))))
          ((and (= depth 0) (string=? (car rest) ","))
           (loop (cdr rest) 0 '() (cons (reverse current) done)))
          (else
           (loop (cdr rest)
                 (cond ((member (car rest) '("(" "[")) (+ depth 1))
                       ((member (car rest) '(")" "]")) (- depth 1))
                       (else depth))
                 (cons (car rest) current) done)))))

;; last-identifier : (Listof String) -> (U String #f)
(define (last-identifier toks)
  (let loop ((rest toks) (found #f))
    (cond ((null? rest) found)
          ((ident-token? (car rest)) (loop (cdr rest) (car rest)))
          (else (loop (cdr rest) found)))))

;; before : (Listof String) String -> (Listof String)
;; The tokens ahead of the first TOKEN.
(define (before toks token)
  (cond ((null? toks) '())
        ((string=? (car toks) token) '())
        (else (cons (car toks) (before (cdr toks) token)))))

;; scalar-words : (Listof String)
;; The words a parameter's type may be made of when it is no pointer.
(define scalar-words
  '("const" "volatile" "unsigned" "signed" "long" "short" "int" "char" "void" "double"
    "float" "_Bool" "size_t" "ssize_t" "uintptr_t" "intptr_t" "ptrdiff_t"
    "int8_t" "int16_t" "int32_t" "int64_t" "uint8_t" "uint16_t" "uint32_t" "uint64_t"))

;; function-pointer-name : (Listof String) -> (U String #f)
;; The identifier after (* in PARAM, a pointer to a function.
(define (function-pointer-name param)
  (let loop ((rest param))
    (cond ((or (null? rest) (null? (cdr rest))) #f)
          ((and (string=? (car rest) "(") (string=? (cadr rest) "*")
                (pair? (cddr rest)) (ident-token? (caddr rest)))
           (caddr rest))
          (else (loop (cdr rest))))))

;; classify-parameter : (Listof String) -> (U (List 'pointer String) 'none 'unreadable)
;; The parameter PARAM: a pointer, with its name, when it is written with a *,
;; as an array T NAME[...], or as a pointer to a function; no pointer, when
;; its type is made of scalar words alone; else unreadable. An attribute on
;; it, or a type this scanner has no word for, such as a typedef that may be
;; a pointer, is unreadable: it cannot be told from a pointer.
(define (classify-parameter param)
  (cond ((member "(" param)
         (let ((name (function-pointer-name param)))
           (if name (list 'pointer name) 'unreadable)))
        ((member "[" param)
         (let ((name (last-identifier (before param "["))))
           (if name (list 'pointer name) 'unreadable)))
        ((member "*" param)
         (let ((name (last-identifier param)))
           (if name (list 'pointer name) 'unreadable)))
        (else
         (let* ((idents (filter ident-token? param))
                (types (if (null? idents) '() (reverse (cdr (reverse idents))))))
           (if (for-all (lambda (word) (member word scalar-words)) types) 'none 'unreadable)))))

;; skip-attributes : (Vectorof String) Natural -> Natural
;; The index after any __attribute__((...)) from INDEX on.
(define (skip-attributes toks index)
  (if (and (< (+ index 1) (vector-length toks))
           (string=? (vector-ref toks index) "__attribute__")
           (string=? (vector-ref toks (+ index 1)) "("))
      (skip-attributes toks (+ (matching toks (+ index 1) "(" ")") 1))
      index))

;; occurrences : (Vectorof String) String -> (Listof Natural)
(define (occurrences body name)
  (let loop ((i (- (vector-length body) 1)) (found '()))
    (cond ((< i 0) found)
          ((string=? (vector-ref body i) name) (loop (- i 1) (cons i found)))
          (else (loop (- i 1) found)))))

;; copy? : (Vectorof String) Natural -> Boolean
;; Whether the token at INDEX is the NAME of
;; volatile uintptr_t V = (uintptr_t) NAME ;
(define (copy? body index)
  (and (>= index 7) (< (+ index 1) (vector-length body))
       (equal? (slice body (- index 7) (+ index 2))
               (list "volatile" "uintptr_t" (vector-ref body (- index 5)) "=" "("
                     "uintptr_t" ")" (vector-ref body index) ";"))
       (ident-token? (vector-ref body (- index 5)))))

;; breaches : (Vectorof String) (Listof String) String -> (Listof Any)
(define (breaches body params function)
  (let loop ((rest params) (found '()))
    (if (null? rest)
        (reverse found)
        (let* ((at (occurrences body (car rest)))
               (breach (cond ((not (= (length at) 1)) (list function (car rest) (list 'uses (length at))))
                             ((copy? body (car at)) #f)
                             (else (list function (car rest) 'plain)))))
          (loop (cdr rest) (if breach (cons breach found) found))))))

;; directives : String -> (Listof String)
;; Every preprocessor directive of TEXT, comments and strings stripped, the
;; text after its # trimmed, its backslash continuations joined.
(define (directives text)
  (let loop ((lines (lines-of (strip text #f))) (current #f) (found '()))
    (if (null? lines)
        (reverse (if current (cons current found) found))
        (let* ((line (car lines))
               (n (string-length line))
               (more? (and (> n 0) (char=? (string-ref line (- n 1)) #\\)))
               (body (if more? (substring line 0 (- n 1)) line)))
          (cond (current
                 (let ((joined (string-append current " " body)))
                   (if more?
                       (loop (cdr lines) joined found)
                       (loop (cdr lines) #f (cons joined found)))))
                ((directive body)
                 => (lambda (d)
                      (if more?
                          (loop (cdr lines) d found)
                          (loop (cdr lines) #f (cons d found)))))
                (else (loop (cdr lines) #f found)))))))

;; macro-words : String -> (Listof String)
;; The identifiers in the replacement lists of TEXT's #define lines, each
;; outside its own macro's parameters.
(define (macro-words text)
  (let loop ((rest (directives text)) (found '()))
    (if (null? rest)
        found
        (let ((d (car rest)))
          (loop (cdr rest)
                (if (and (> (string-length d) 6) (string=? (substring d 0 6) "define")
                         (char-whitespace? (string-ref d 6)))
                    (append (replacement-words (trim (substring d 6 (string-length d)))) found)
                    found))))))

;; replacement-words : String -> (Listof String)
;; The identifiers after the name, and after the parameter list when the
;; name is followed at once by a (, outside that list.
(define (replacement-words definition)
  (let* ((toks (tokens definition)) (n (vector-length toks)))
    (if (or (= n 0) (not (ident-token? (vector-ref toks 0))))
        '()
        (let* ((name-length (string-length (vector-ref toks 0)))
               (function-like? (and (> (string-length definition) name-length)
                                    (char=? (string-ref definition name-length) #\()))
               (close (if function-like? (matching toks 1 "(" ")") 0))
               (params (if function-like? (slice toks 2 (min close n)) '()))
               (start (if function-like? (+ close 1) 1)))
          (filter (lambda (token) (and (ident-token? token) (not (member token params))))
                  (if (< start n) (slice toks start n) '()))))))

;; scan : String -> (List (Listof (List String (Listof String))) (Listof Any))
;; The family functions TEXT defines with a body, each with its pointer
;; parameters, in order; and the breaches of the rule among them, and what
;; cannot be read:
;;   (FUNCTION PARAMETER (uses N)), (FUNCTION PARAMETER plain)  as above
;;   (FUNCTION PARAMETER macro)    a #define's replacement list names it
;;   (FUNCTION unreadable head)    anything but { ; , or an attribute follows
;;                                 the parameter list's )
;;   (FUNCTION unreadable name)    a family name no ( follows
;;   (FUNCTION unreadable parameter)  a parameter that is neither a pointer
;;                                 nor of scalar words
;;   (extern unreadable block)     an extern "C" { ... } around definitions
;; An unreadable function is not among the functions read.
(define (scan text)
  (let* ((toks (tokens (code-text text))) (n (vector-length toks)) (macros (macro-words text)))
    (let loop ((i 0) (depth 0) (functions '()) (found '()))
      (cond
        ((>= i n) (list (reverse functions) (reverse found)))
        ((string=? (vector-ref toks i) "{")
         (if (and (= depth 0) (> i 0) (string=? (vector-ref toks (- i 1)) "extern"))
             (loop (+ i 1) depth functions (cons (list "extern" 'unreadable 'block) found))
             (loop (+ i 1) (+ depth 1) functions found)))
        ((string=? (vector-ref toks i) "}") (loop (+ i 1) (max 0 (- depth 1)) functions found))
        ((and (= depth 0) (ident-token? (vector-ref toks i)) (family? (vector-ref toks i)))
         (let ((name (vector-ref toks i)))
           (if (and (< (+ i 1) n) (string=? (vector-ref toks (+ i 1)) "("))
               (let* ((close (matching toks (+ i 1) "(" ")"))
                      (after (skip-attributes toks (+ close 1)))
                      (next (if (< after n) (vector-ref toks after) #f)))
                 (cond
                   ((and next (string=? next "{"))
                    (let* ((end (matching toks after "{" "}"))
                           (classes (map classify-parameter
                                         (split-commas (slice toks (+ i 2) close)))))
                      (if (memq 'unreadable classes)
                          (loop (+ end 1) 0 functions
                                (cons (list name 'unreadable 'parameter) found))
                          (let ((params (map cadr (filter pair? classes))))
                            (loop (+ end 1) 0
                                  (cons (list name params) functions)
                                  (append
                                   (reverse
                                    (append
                                     (breaches (list->vector (slice toks (+ after 1) end))
                                               params name)
                                     (map (lambda (param) (list name param 'macro))
                                          (filter (lambda (param) (member param macros))
                                                  params))))
                                   found))))))
                   ((and next (member next '(";" ",")))
                    (loop (+ close 1) depth functions found))
                   (else
                    (loop (+ close 1) depth functions
                          (cons (list name 'unreadable 'head) found)))))
               (loop (+ i 1) depth functions (cons (list name 'unreadable 'name) found)))))
        (else (loop (+ i 1) depth functions found))))))

;; --- reading the real files --------------------------------------------------------------

;; read-text : String -> (U String (List 'unreadable String))
(define (read-text path)
  (guard (e (#t (list 'unreadable (describe e))))
    (call-with-port (open-file-input-port path (file-options) (buffer-mode block)
                                          (make-transcoder (utf-8-codec)))
      get-string-all)))

;; c-files : -> (U (Listof String) (List 'unreadable String))
;; Every tests/*.c, sorted.
(define (c-files)
  (guard (e (#t (list 'unreadable (describe e))))
    (map (lambda (name) (string-append "tests/" name))
         (list-sort string<?
                    (filter (lambda (name)
                              (and (> (string-length name) 2)
                                   (string=? (substring name (- (string-length name) 2)
                                                        (string-length name))
                                             ".c")))
                            (directory-list "tests"))))))

;; scan-real : -> (U (Listof (List String Any Any)) (List 'unreadable String))
;; Each tests/*.c that includes sodium.h, with its scan.
(define (scan-real)
  (let ((files (c-files)))
    (if (and (pair? files) (eq? (car files) 'unreadable))
        files
        (let loop ((rest files) (found '()))
          (if (null? rest)
              (reverse found)
              (let ((text (read-text (car rest))))
                (cond ((not (string? text)) (list 'unreadable (car rest) text))
                      ((eq? (includes-sodium? text) 'yes)
                       (loop (cdr rest) (cons (cons (car rest) (scan text)) found)))
                      (else (loop (cdr rest) found)))))))))

;; --- the real files ----------------------------------------------------------------------

;; Whole, in order: the decoy defines the thirteen entries the load binds, and
;; every pointer parameter of them is read through its copy. libsodium-oracle.c
;; includes sodium.h and defines none of their names. A function missing from
;; this list, or a breach, is the row's failure; the list is the standing
;; positive control of every row below.
(test-equal "the real tests/*.c that include sodium.h: the functions read, whole, and no breach"
  '(("tests/decoy-libsodium.c"
     (("sodium_version_string" ())
      ("sodium_library_version_major" ())
      ("sodium_library_version_minor" ())
      ("sodium_init" ())
      ("sodium_memzero" ("pnt"))
      ("randombytes_buf" ("buf"))
      ("crypto_generichash" ("out" "in" "key"))
      ("crypto_generichash_bytes" ())
      ("crypto_generichash_bytes_min" ())
      ("crypto_generichash_bytes_max" ())
      ("crypto_generichash_keybytes_min" ())
      ("crypto_generichash_keybytes_max" ())
      ("sodium_memcmp" ("b1" "b2")))
     ())
    ("tests/libsodium-oracle.c" () ()))
  (scan-real))

;; --- planted sources ---------------------------------------------------------------------

;; Each source is a whole C file's text. The breaches are asserted whole, by
;; function and parameter.

(define (lines . ls)
  (apply string-append (map (lambda (l) (string-append l "\n")) ls)))

(define (plant description source expected)
  (test-equal description expected (scan source)))

(plant "a conforming pointer: read once, as the copy, and the function is read"
  (lines "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) buf;"
         "  called(\"randombytes_buf(%s,%zu)\", p ? \"p\" : \"NULL\", size);"
         "}")
  '((("randombytes_buf" ("buf"))) ()))

(plant "a ternary over a pointer, beside its copy: buf occurs twice"
  (lines "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) buf;"
         "  called(\"x\", buf ? \"p\" : \"NULL\", size);"
         "}")
  '((("randombytes_buf" ("buf"))) (("randombytes_buf" "buf" (uses 2)))))

(plant "a ternary over a pointer, with no copy: buf occurs once, and plain"
  (lines "int sodium_memcmp(const void *const b1, const void *const b2, size_t len)"
         "{"
         "  volatile uintptr_t q = (uintptr_t) b2;"
         "  called(\"x\", b1 ? \"p\" : \"NULL\", q ? \"p\" : \"NULL\", len);"
         "  return 0;"
         "}")
  '((("sodium_memcmp" ("b1" "b2"))) (("sodium_memcmp" "b1" plain))))

(plant "a second use of a pointer, after its copy: buf occurs twice"
  (lines "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) buf;"
         "  memset(buf, 0xA5, size);"
         "}")
  '((("randombytes_buf" ("buf"))) (("randombytes_buf" "buf" (uses 2)))))

(plant "an array parameter used plainly: key is read, and it is plain"
  (lines "int crypto_x_thing(const unsigned char key[crypto_x_KEYBYTES], size_t n)"
         "{"
         "  return key[0] + (int) n;"
         "}")
  '((("crypto_x_thing" ("key"))) (("crypto_x_thing" "key" plain))))

(plant "an array parameter read through its copy passes: the array is a pointer"
  (lines "int crypto_x_thing(const unsigned char key[crypto_x_KEYBYTES], size_t n)"
         "{"
         "  volatile uintptr_t k = (uintptr_t) key;"
         "  return k != 0 ? (int) n : 0;"
         "}")
  '((("crypto_x_thing" ("key"))) ()))

(plant "a pointer that is never read: out occurs no time"
  (lines "int crypto_generichash(unsigned char *out, size_t outlen,"
         "                       const unsigned char *in, unsigned long long inlen,"
         "                       const unsigned char *key, size_t keylen)"
         "{"
         "  volatile uintptr_t i = (uintptr_t) in;"
         "  volatile uintptr_t k = (uintptr_t) key;"
         "  called(\"x\", i ? \"p\" : \"NULL\", k ? \"p\" : \"NULL\", outlen, inlen, keylen);"
         "  return 0;"
         "}")
  '((("crypto_generichash" ("out" "in" "key"))) (("crypto_generichash" "out" (uses 0)))))

(plant "a copy that is not volatile: it is plain"
  (lines "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  uintptr_t p = (uintptr_t) pnt;"
         "  called(\"x\", p ? \"p\" : \"NULL\", len);"
         "}")
  '((("sodium_memzero" ("pnt"))) (("sodium_memzero" "pnt" plain))))

(plant "a copy with more in its value than the pointer is plain"
  (lines "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) pnt + 1;"
         "  called(\"x\", p ? \"p\" : \"NULL\", len);"
         "}")
  '((("sodium_memzero" ("pnt"))) (("sodium_memzero" "pnt" plain))))

(plant "a helper that uses its pointer twice is outside the rule, and is not read"
  (lines "static void called(const char *format, ...)"
         "{"
         "  puts(format);"
         "  puts(format);"
         "}"
         "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) pnt;"
         "  called(\"x\", p ? \"p\" : \"NULL\", len);"
         "}")
  '((("sodium_memzero" ("pnt"))) ()))

(plant "a pointer named in a comment or a string is not a use"
  (lines "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  /* pnt */ volatile uintptr_t p = (uintptr_t) pnt; // pnt"
         "  called(\"pnt %s\", p ? \"pnt\" : \"NULL\", len);"
         "}")
  '((("sodium_memzero" ("pnt"))) ()))

(plant "a name that only contains the pointer's is not a use of it"
  (lines "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) pnt;"
         "  called(\"x\", pnt2, pnt_end, len);"
         "}")
  '((("sodium_memzero" ("pnt"))) ()))

(plant "a declaration with no body is not read, even with a pointer used nowhere"
  (lines "int crypto_x_thing(const unsigned char *key, size_t n);"
         "void randombytes_buf(void *const buf, const size_t size)"
         "            __attribute__ ((nonnull));")
  '(() ()))

(plant "a function outside sodium_, randombytes_ and crypto_ is not read"
  (lines "void decoy_thing(void *p)"
         "{"
         "  p = p;"
         "}")
  '(() ()))

(plant "a definition behind an attribute is read"
  (lines "int crypto_x_thing(const unsigned char *key) __attribute__ ((nonnull))"
         "{"
         "  return key[0];"
         "}")
  '((("crypto_x_thing" ("key"))) (("crypto_x_thing" "key" plain))))

(plant "a definition behind preprocessor lines is read, and the lines are not"
  (lines "#ifndef DECOY_LACKS_sodium_memzero"
         "#define SOMETHING(pnt) pnt pnt"
         "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) pnt;"
         "}"
         "#endif")
  '((("sodium_memzero" ("pnt"))) ()))

(plant "a parameter that is no pointer is not read, and a void list has none"
  (lines "size_t crypto_generichash_bytes(void)"
         "{"
         "  return 32;"
         "}"
         "void sodium_memzero(const size_t len)"
         "{"
         "}")
  '((("crypto_generichash_bytes" ()) ("sodium_memzero" ())) ()))

(plant "a second definition is read after a first: one breach each"
  (lines "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  called(size);"
         "}"
         "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  called(len);"
         "}")
  '((("randombytes_buf" ("buf")) ("sodium_memzero" ("pnt")))
    (("randombytes_buf" "buf" (uses 0)) ("sodium_memzero" "pnt" (uses 0)))))

(plant "a macro whose replacement list names a pointer parameter is a breach, though the parameter occurs once, as its copy"
  (lines "#define IN_GIVEN (in != NULL)"
         "int crypto_generichash(unsigned char *out, size_t outlen,"
         "                       const unsigned char *in, unsigned long long inlen,"
         "                       const unsigned char *key, size_t keylen)"
         "{"
         "  volatile uintptr_t o = (uintptr_t) out;"
         "  volatile uintptr_t i = (uintptr_t) in;"
         "  volatile uintptr_t k = (uintptr_t) key;"
         "  called(\"x\", o ? \"p\" : \"NULL\", IN_GIVEN ? \"p\" : \"NULL\", k ? \"p\" : \"NULL\");"
         "  return 0;"
         "}")
  '((("crypto_generichash" ("out" "in" "key"))) (("crypto_generichash" "in" macro))))

(plant "a macro over several lines, a backslash at the end of each, is read whole"
  (lines "#define LATER(x) \\"
         "  ((x) != 0 && \\"
         "   buf != NULL)"
         "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) buf;"
         "}")
  '((("randombytes_buf" ("buf"))) (("randombytes_buf" "buf" macro))))

(plant "an object-like macro naming a pointer parameter is a breach too"
  (lines "#define SHOWN buf"
         "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) buf;"
         "}")
  '((("randombytes_buf" ("buf"))) (("randombytes_buf" "buf" macro))))

(plant "a macro with the parameter's name as its own parameter is no breach"
  (lines "#define WITH(buf) ((buf) + 1)"
         "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) buf;"
         "}")
  '((("randombytes_buf" ("buf"))) ()))

(plant "a macro between the parameter list and the body: the head is unreadable, by name"
  (lines "int crypto_x_thing(const unsigned char *key) DECOY_NONNULL"
         "{"
         "  if (key) return 1;"
         "  return 0;"
         "}")
  '(() (("crypto_x_thing" unreadable head))))

(plant "an attribute on a pointer parameter: the parameter is unreadable, by function"
  (lines "void randombytes_buf(void *const buf __attribute__ ((unused)), const size_t size)"
         "{"
         "  if (buf) return;"
         "}")
  '(() (("randombytes_buf" unreadable parameter))))

(plant "a parenthesised name: the name has no ( after it, so it is unreadable"
  (lines "void (randombytes_buf)(void *const buf, const size_t size)"
         "{"
         "  if (buf) return;"
         "}")
  '(() (("randombytes_buf" unreadable name))))

(plant "a definition made by a macro: the name has no ( after it, so it is unreadable"
  (lines "DEFINE_ENTRY(randombytes_buf, void *buf)"
         "{"
         "  if (buf) return;"
         "}")
  '(() (("randombytes_buf" unreadable name))))

(plant "a definition inside extern \"C\" braces: the block is unreadable, by name, and the definition is read"
  (lines "extern \"C\" {"
         "void randombytes_buf(void *const buf, const size_t size)"
         "{"
         "  if (buf) return;"
         "}"
         "}")
  '((("randombytes_buf" ("buf")))
    (("extern" unreadable block) ("randombytes_buf" "buf" plain))))

(plant "a typedef'd pointer type: the parameter cannot be told from a number, so it is unreadable"
  (lines "int crypto_x_thing(crypto_x_key_t key, size_t n)"
         "{"
         "  if (key) return 1;"
         "  return 0;"
         "}")
  '(() (("crypto_x_thing" unreadable parameter))))

(plant "a struct parameter is unreadable too, and the function after it is still read"
  (lines "int crypto_x_thing(struct crypto_x_state state)"
         "{"
         "  return 0;"
         "}"
         "void sodium_memzero(void *const pnt, const size_t len)"
         "{"
         "  volatile uintptr_t p = (uintptr_t) pnt;"
         "}")
  '((("sodium_memzero" ("pnt"))) (("crypto_x_thing" unreadable parameter))))

(plant "a declaration followed by anything else, a ; or a , aside, is unreadable"
  (lines "int crypto_x_thing(const unsigned char *key) = 0;")
  '(() (("crypto_x_thing" unreadable head))))

(plant "declarations ending in ; or , are read as declarations"
  (lines "int crypto_x_thing(const unsigned char *key), crypto_y_thing(size_t n);")
  '(() ()))

(plant "#if/#else alternative heads: the first has no body of its own, so it is unreadable, by name; the second is read"
  (lines "#ifdef FAST"
         "void randombytes_buf(void *const buf, const size_t size)"
         "#else"
         "void randombytes_buf(void *buf, size_t size)"
         "#endif"
         "{"
         "  if (buf) return;"
         "}")
  '((("randombytes_buf" ("buf")))
    (("randombytes_buf" unreadable head) ("randombytes_buf" "buf" plain))))

;; --- which files are read ------------------------------------------------------------------

(define (includes description expected source)
  (test-equal description expected (includes-sodium? source)))

(includes "an include of <sodium.h> is read" 'yes
  (lines "#include <stdio.h>" "#include <sodium.h>"))
(includes "an include of \"sodium.h\" is read" 'yes
  (lines "  #  include \"sodium.h\" "))
(includes "an include in a comment is not" 'no
  (lines "/* #include <sodium.h> */" "// #include <sodium.h>"))
(includes "another header, and a use of the name, are not" 'no
  (lines "#include <sodium/utils.h>" "int sodium_h;"))

;; --- this process ----------------------------------------------------------------------------

(test-end "decoy-source")

(exit (suite-exit-status runner))
