#!r6rs
;;; The suite for the prototypes of the convention table
;;; (tests/foreign-conventions.sls): each row's C prototype held to sodium.h
;;; by a C program compiled here, at test time (ADR-0001). It never loads
;;; libsodium, and the program calls none of its functions.
;;;
;;;   prototypes   the C program asks _Generic whether each function's type
;;;                is exactly the row's. _Generic does not evaluate its
;;;                operand, so nothing is called or linked, and the program
;;;                needs no libsodium at link time or at run time.
;;;   the map      a map written here, from each C type the rows write to its
;;;                one Chez type (int, size_t, unsigned long long, and any
;;;                pointer), holds the row's Chez types to its C types, after
;;;                the top-level qualifiers, const, volatile and restrict, are
;;;                dropped. A wrong row fails by name, and each kind of wrong
;;;                row is planted in the suite, beside a control written
;;;                right.
;;;
;;; The C program is compiled with $CC and no -I flag: the compiler's own
;;; search path must find sodium.h. A missing compiler or header fails a
;;; named row; this suite never skips. A compile is judged by its exit status
;;; alone.
;;;
;;; _Generic cannot tell size_t from unsigned long, which are one type on
;;; the 64-bit Linux this runs on; the map can, and holds the row's spelling.
;;;
;;; Every computation that can raise runs under a guard, before the tests,
;;; with a sentinel of its own: SRFI-64 does not catch a raise in an expected
;;; expression, nor in a suite's top-level definitions, and makes #f of one
;;; in an actual expression. No expected value here is #f from something that
;;; can raise.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (only (chezscheme) getenv)
        (chez-sodium-testing)
        (only (foreign-conventions) conventions-table row-name row-prototype row-arguments
              row-result row-convention))

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

;; --- small helpers ------------------------------------------------------------

;; split-words : String -> (Listof String)
;; TEXT cut at each run of spaces, tabs and newlines, empty pieces dropped.
(define (split-words text)
  (let loop ((i 0) (start 0) (found '()))
    (define (piece) (if (> i start) (cons (substring text start i) found) found))
    (cond ((= i (string-length text)) (reverse (piece)))
          ((memv (string-ref text i) '(#\space #\tab #\newline))
           (loop (+ i 1) (+ i 1) (piece)))
          (else (loop (+ i 1) start found)))))

;; c-compiler : -> (Listof String)
;; $CC as a command's words; ("cc") when CC is unset or blank.
(define (c-compiler)
  (let ((words (split-words (or (getenv "CC") ""))))
    (if (null? words) '("cc") words)))

;; --- the C program ------------------------------------------------------------------

;; c-program : (Listof (List String String)) -> String
;; Prints (header-version "S"), then for each prototype (prototype "NAME" N),
;; N 1 when the header declares NAME as a function of exactly FUNCTION-TYPE,
;; and 0 when it declares it otherwise. _Generic does not evaluate its operand,
;; so nothing is called or linked. The name is in parentheses, so a
;; function-like macro of its name would not be expanded. The version is a
;; macro of sodium.h's own, a string.
(define (c-program prototypes)
  (string-append
   "#include <sodium.h>\n"
   "#include <stdio.h>\n"
   "\n"
   "#define PROTOTYPE(f, t) printf(\"(prototype \\\"%s\\\" %d)\\n\", #f, _Generic((f), t: 1, default: 0))\n"
   "\n"
   "int main(void)\n"
   "{\n"
   "  printf(\"(header-version \\\"%s\\\")\\n\", SODIUM_VERSION_STRING);\n"
   (apply string-append
          (map (lambda (p) (string-append "  PROTOTYPE(" (car p) ", " (cadr p) ");\n"))
               prototypes))
   "  return 0;\n"
   "}\n"))

;; answer? : Any -> Boolean
(define (answer? d)
  (and (list? d)
       (or (and (= (length d) 2) (eq? (car d) 'header-version) (string? (cadr d)))
           (and (= (length d) 3) (eq? (car d) 'prototype) (string? (cadr d))
                (memv (caddr d) '(0 1)) #t))))

;; read-all : String -> (U (Listof Any) #f)
(define (read-all text)
  (guard (e (#t #f))
    (let ((port (open-string-input-port text)))
      (let loop ((data '()))
        (let ((datum (read port)))
          (if (eof-object? datum) (reverse data) (loop (cons datum data))))))))

(define (write-text path text)
  (call-with-port (open-file-output-port path (file-options) (buffer-mode block)
                                         (make-transcoder (utf-8-codec)))
    (lambda (port) (put-string port text))))

;; header-facts : (Listof (List String String))
;;                -> (U (List 'facts (Listof Answer)) (Pairof Symbol Any))
;; In a directory of its own: compiles and runs the program for PROTOTYPES.
;; The facts are what the program printed, read as data. Anything else names
;; the step that went wrong: compile or run (with the command's status, stdout
;; and stderr), output (what the program printed, which is not answers), or
;; raised.
(define (header-facts prototypes)
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (dir)
       (let ((source (string-append dir "/headers.c"))
             (program (string-append dir "/headers")))
         (write-text source (c-program prototypes))
         (let ((compiled (capture-command
                          (append (c-compiler) (list "-o" program source)))))
           (if (not (= (car compiled) 0))
               (cons 'compile compiled)
               (let ((ran (capture-command (list program))))
                 (if (not (= (car ran) 0))
                     (cons 'run ran)
                     (let ((data (read-all (cadr ran))))
                       (if (and data (for-all answer? data))
                           (list 'facts data)
                           (list 'output (cadr ran)))))))))))))

;; --- the prototypes ---------------------------------------------------------------------

;; The convention table (tests/foreign-conventions.sls) has a row per binding:
;; its C name, its prototype in sodium.h's own spelling and the Chez types it
;; binds with. The C program holds each prototype to the header, through
;; _Generic on the function itself, and the map below holds each row's Chez
;; types to its C types.

;; function-type : Row -> String
;; The row's prototype as a C pointer-to-function type: RESULT (*)(PARAMETERS),
;; (void) for none.
(define (function-type row)
  (let ((proto (row-prototype row)))
    (string-append (car proto) " (*)("
                   (if (null? (cadr proto))
                       "void"
                       (fold-left (lambda (acc p) (string-append acc ", " p))
                                  (car (cadr proto)) (cdr (cadr proto))))
                   ")")))

;; prototype-ask : Row -> (List String String)
(define (prototype-ask row) (list (row-name row) (function-type row)))

(define prototype-asks (map prototype-ask conventions-table))

;; c-words : String -> (Listof String)
;; C-TYPE's words with each * a word of its own, so that void *const is void,
;; *, const.
(define (c-words c-type)
  (split-words
   (apply string-append
          (map (lambda (c) (if (char=? c #\*) " * " (string c))) (string->list c-type)))))

;; without-qualifiers : String -> String
;; C-TYPE with each whole word const, volatile and restrict removed, and the
;; rest joined by single spaces: const size_t is size_t, void *const is
;; void *, and constant_t is untouched. Removing every qualifier word and not
;; only the top-level ones is safe: any pointer maps to uptr whatever it
;; points at.
(define (without-qualifiers c-type)
  (let ((words (filter (lambda (w) (not (member w '("const" "volatile" "restrict"))))
                       (c-words c-type))))
    (if (null? words)
        ""
        (fold-left (lambda (acc w) (string-append acc " " w)) (car words) (cdr words)))))

;; chez-type : String -> (U Symbol #f)
;; The Chez type a C type is bound as: int is int, size_t is size_t,
;; unsigned long long is unsigned-64, and any pointer, const char * among
;; them, is the address itself, uptr (ADR-0001). Any other
;; C type has no mapping, and a row that writes one fails until a record
;; decides it.
(define (chez-type c-type)
  (let* ((plain (without-qualifiers c-type))
         (words (split-words plain)))
    (cond ((string=? plain "int") 'int)
          ((string=? plain "size_t") 'size_t)
          ((string=? plain "unsigned long long") 'unsigned-64)
          ((and (pair? words) (string=? (car (reverse words)) "*")) 'uptr)
          (else #f))))

;; result-type : String -> (U Symbol #f)
;; A result's Chez type: chez-type's, and void for void, which only a result
;; may be (sodium_memzero's). chez-type still maps void to nothing, so a void
;; argument stays unmapped.
(define (result-type c-type)
  (if (string=? c-type "void") 'void (chez-type c-type)))

;; map-problems : Table -> (Listof (Pairof String Any))
;; (NAME MAPPED-ARGUMENTS MAPPED-RESULT ARGUMENTS RESULT) for each row whose
;; Chez types are not the map of its C types, in the table's order.
(define (map-problems rows)
  (filter (lambda (m) m)
          (map (lambda (row)
                 (let ((arguments (map chez-type (cadr (row-prototype row))))
                       (result (result-type (car (row-prototype row)))))
                   (if (and (equal? arguments (row-arguments row))
                            (eq? result (row-result row)))
                       #f
                       (list (row-name row) arguments result (row-arguments row)
                             (row-result row)))))
               rows)))

(define facts (header-facts prototype-asks))

(define answers (if (eq? (car facts) 'facts) (cadr facts) '()))

;; prototype-answer : String -> (U 0 1 'no-answer)
(define (prototype-answer name)
  (let ((entry (find (lambda (a) (and (eq? (car a) 'prototype) (string=? (cadr a) name))) answers)))
    (if entry (caddr entry) 'no-answer)))

;; verdicts-of : (Listof Row) -> (U (Listof (Pair String Any)) (Pair Symbol Any))
;; A fresh compile and run of the C program, asking only ROWS' prototypes:
;; each row's name and the program's answer, in order, or the step that
;; failed. It reads the answers by position, so a plant may name a function
;; another row names.
(define (verdicts-of rows)
  (guard (e (#t (list 'raised (describe e))))
    (let ((f (header-facts (map prototype-ask rows))))
      (if (eq? (car f) 'facts)
          (let ((asked (filter (lambda (a) (eq? (car a) 'prototype)) (cadr f))))
            (if (= (length asked) (length rows))
                (map (lambda (row a) (cons (row-name row) (caddr a))) rows asked)
                (list 'unanswered (length rows) (length asked))))
          f))))

;; plant : String String (Listof String) -> Row
;; A row that says exactly this prototype; the Chez types are not asked of it.
(define (plant name result parameters)
  (list name (list result parameters) '() 'int 'plain '()))

(test-begin "constants")

;; --- the oracle -----------------------------------------------------------------

(test-equal "oracle: the C program compiled and ran against sodium.h"
  'facts (if (eq? (car facts) 'facts) 'facts facts))

(test-equal "oracle: the program printed its header version, a string"
  'version
  (let ((entry (find (lambda (a) (eq? (car a) 'header-version)) answers)))
    (if (and entry (string? (cadr entry)) (> (string-length (cadr entry)) 0)) 'version 'none)))

;; --- the prototypes, against the header --------------------------------------------------

(test-equal "prototypes: the table has a row for each of the thirty entry points, asked once each, in one compile"
  (list 30 '("sodium_version_string" "sodium_library_version_major"
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
  (list (length conventions-table) (map car prototype-asks)))

(test-equal "prototypes: the header declares each row's prototype exactly: the rows it does not, each by name"
  '()
  (map row-name (filter (lambda (row) (not (eqv? (prototype-answer (row-name row)) 1)))
                        conventions-table)))

(test-equal "prototypes: every question got an answer, 1 or 0"
  '()
  (map row-name (filter (lambda (row) (eq? (prototype-answer (row-name row)) 'no-answer))
                        conventions-table)))

(test-equal "prototypes: each row's Chez types are the map of its C types, the rows that are not each by name"
  '()
  (map-problems conventions-table))

;; --- the map, written out -----------------------------------------------------------------

;; The map, written out: each C type the table's rows write, and its near
;; misses, which map to nothing. #f stands for no mapping: chez-type cannot
;; raise on a string.
(define map-types
  '("int" "size_t" "unsigned long long"
    "const char *" "void *" "void *const" "void * const" "const void *const"
    "unsigned char *" "char *" "const unsigned char *" "char **"
    "const size_t" "size_t const" "const int" "volatile int" "const unsigned long long"
    "unsigned int" "unsigned" "long" "unsigned long" "long long" "ssize_t" "uint32_t"
    "uint64_t" "unsigned char" "char" "signed char" "short" "float" "double"
    "long double" "bool" "void(*)(void*)" "void" "constant_t" "constint" "const" "" "..."))

(test-equal "map: int, size_t and unsigned long long are int, size_t and unsigned-64; any pointer is uptr; a top-level qualifier is dropped; and nothing else is mapped, a word that starts with const among it"
  '(int size_t unsigned-64
    uptr uptr uptr uptr uptr uptr uptr uptr uptr
    size_t size_t int int unsigned-64
    #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f)
  (map chez-type map-types))

(test-equal "map: the list is 40 C types, so no row above is dropped unseen"
  40 (length map-types))

;; result-type against its whole complement: the same C types, and void is
;; mapped for "void" alone; a C result merely spelled from void (void *) is
;; chez-type's answer, never void.
(test-equal "result-type: void for \"void\" alone, and chez-type's answer for every other C type of the map's list"
  '(int size_t unsigned-64
    uptr uptr uptr uptr uptr uptr uptr uptr uptr
    size_t size_t int int unsigned-64
    #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f void #f #f #f #f #f)
  (map result-type map-types))

;; answer? is what stops a program's output that is not an answer from being
;; read as one.
(test-equal "answer?: a version string, and a prototype's 0 or 1, are answers; a number for the version, a 2, a name that is no string, a third word, and a bare symbol are not"
  '(#t #t #t #f #f #f #f #f)
  (map answer? '((header-version "1.0.22") (prototype "sodium_init" 1) (prototype "sodium_init" 0)
                 (header-version 1) (prototype "sodium_init" 2) (prototype sodium_init 1)
                 (prototype "sodium_init" 1 2) header-version)))

(test-equal "map: void as an argument is unmapped, and a pointer to void is uptr, never void"
  '(#f uptr uptr)
  (map chez-type '("void" "void *" "const void *")))

;; --- planted wrong rows, each beside a control written right -------------------------------

;; Each plant is a prototype the header does not declare, and answers 0, by
;; name. Its control is the same function written as the header has it, and
;; answers 1.
(define plants
  ;; name, result, parameters, answer
  '(("sodium_version_string" "char *" () 0)
    ("sodium_version_string" "const char *" ("int") 0)
    ("sodium_library_version_major" "unsigned int" () 0)
    ("sodium_library_version_minor" "long" () 0)
    ("sodium_init" "void" () 0)
    ("sodium_init" "int" ("int") 0)
    ("sodium_memzero" "int" ("void *const" "const size_t") 0)
    ("sodium_memzero" "void" ("void *const") 0)
    ("sodium_memzero" "void" () 0)
    ("sodium_memzero" "void" ("void *const" "int") 0)
    ("sodium_memzero" "void" ("void *const" "unsigned int") 0)
    ("sodium_memzero" "void" ("void *const" "unsigned long long") 0)
    ("sodium_memzero" "void" ("int" "size_t") 0)
    ("sodium_memzero" "void" ("const void *" "size_t") 0)
    ("sodium_memzero" "void" ("char *" "size_t") 0)
    ;; randombytes_buf
    ("randombytes_buf" "void" ("void * const" "unsigned long long") 0)
    ("randombytes_buf" "void" ("void * const") 0)
    ("randombytes_buf" "int" ("void * const" "const size_t") 0)
    ("randombytes_buf" "void" ("const void *" "size_t") 0)
    ;; crypto_generichash: size_t as unsigned long long, and the reverse
    ("crypto_generichash" "int"
     ("unsigned char *" "unsigned long long" "const unsigned char *" "unsigned long long"
      "const unsigned char *" "size_t") 0)
    ("crypto_generichash" "int"
     ("unsigned char *" "size_t" "const unsigned char *" "size_t"
      "const unsigned char *" "size_t") 0)
    ("crypto_generichash" "int"
     ("unsigned char *" "size_t" "const unsigned char *" "unsigned long long"
      "const unsigned char *" "unsigned long long") 0)
    ("crypto_generichash" "int"
     ("unsigned char *" "size_t" "const unsigned char *" "unsigned long long"
      "const unsigned char *") 0)
    ("crypto_generichash" "int"
     ("char *" "size_t" "const unsigned char *" "unsigned long long"
      "const unsigned char *" "size_t") 0)
    ("crypto_generichash" "void"
     ("unsigned char *" "size_t" "const unsigned char *" "unsigned long long"
      "const unsigned char *" "size_t") 0)
    ;; the five sizes: int for size_t, an argument added, void for size_t
    ("crypto_generichash_bytes" "int" () 0)
    ("crypto_generichash_bytes" "size_t" ("int") 0)
    ("crypto_generichash_bytes" "void" () 0)
    ("crypto_generichash_bytes_min" "unsigned int" () 0)
    ("crypto_generichash_bytes_max" "int" () 0)
    ("crypto_generichash_keybytes_min" "long long" () 0)
    ("crypto_generichash_keybytes_max" "size_t" ("void *") 0)
    ;; sodium_memcmp
    ("sodium_memcmp" "int" ("const void *const" "const void *const" "unsigned long long") 0)
    ("sodium_memcmp" "int" ("const void *const" "size_t") 0)
    ("sodium_memcmp" "int" ("const void *const" "const void *const" "int") 0)
    ("sodium_memcmp" "void" ("const void *const" "const void *const" "size_t") 0)
    ("sodium_memcmp" "int" ("const void *const" "int" "size_t") 0)
    ("sodium_memcmp" "int" ("const char *" "const void *const" "size_t") 0)
    ;; crypto_pwhash_str: opslimit as size_t (the header's unsigned long long),
    ;; memlimit as unsigned long long, a dropped pointee const, a missing
    ;; parameter, a void result
    ("crypto_pwhash_str" "int"
     ("char *" "const char *" "unsigned long long" "size_t" "size_t") 0)
    ("crypto_pwhash_str" "int"
     ("char *" "const char *" "unsigned long long" "unsigned long long" "unsigned long long") 0)
    ("crypto_pwhash_str" "int"
     ("char *" "char *" "unsigned long long" "unsigned long long" "size_t") 0)
    ("crypto_pwhash_str" "int"
     ("char *" "const char *" "size_t" "unsigned long long" "size_t") 0)
    ("crypto_pwhash_str" "void"
     ("char *" "const char *" "unsigned long long" "unsigned long long" "size_t") 0)
    ;; crypto_pwhash_str_verify: passwdlen as size_t, a char * for the const
    ;; char * str, a missing parameter
    ("crypto_pwhash_str_verify" "int" ("const char *" "const char *" "size_t") 0)
    ("crypto_pwhash_str_verify" "int" ("char *" "const char *" "unsigned long long") 0)
    ("crypto_pwhash_str_verify" "int" ("const char *" "const char *") 0)
    ;; crypto_pwhash_str_needs_rehash: opslimit as size_t, memlimit as
    ;; unsigned long long, a result as size_t
    ("crypto_pwhash_str_needs_rehash" "int" ("const char *" "size_t" "size_t") 0)
    ("crypto_pwhash_str_needs_rehash" "int" ("const char *" "unsigned long long" "unsigned long long") 0)
    ("crypto_pwhash_str_needs_rehash" "size_t" ("const char *" "unsigned long long" "size_t") 0)
    ;; the prefix: char * for const char *, and an argument added
    ("crypto_pwhash_strprefix" "char *" () 0)
    ("crypto_pwhash_strprefix" "const char *" ("int") 0)
    ;; the fourteen constants: int, unsigned long long and void for size_t
    ("crypto_pwhash_strbytes" "int" () 0)
    ("crypto_pwhash_opslimit_min" "unsigned long long" () 0)
    ("crypto_pwhash_opslimit_max" "int" () 0)
    ("crypto_pwhash_opslimit_interactive" "unsigned int" () 0)
    ("crypto_pwhash_opslimit_moderate" "void" () 0)
    ("crypto_pwhash_opslimit_sensitive" "long long" () 0)
    ("crypto_pwhash_memlimit_min" "unsigned long long" () 0)
    ("crypto_pwhash_memlimit_max" "int" () 0)
    ("crypto_pwhash_memlimit_interactive" "unsigned int" () 0)
    ("crypto_pwhash_memlimit_moderate" "void" () 0)
    ("crypto_pwhash_memlimit_sensitive" "size_t" ("void *") 0)
    ("crypto_pwhash_passwd_min" "int" () 0)
    ("crypto_pwhash_passwd_max" "unsigned long long" () 0)))

(test-equal "the prototype check refuses each kind of wrong row, by name, the password hash's among them: a dropped pointee const, an extra and a missing parameter, a result int as unsigned int, long or void, a result void as int, size_t as int, unsigned int or unsigned long long (the opslimit trap) and unsigned long long as size_t, in randombytes_buf, crypto_generichash and the five sizes, a pointer as int, a pointee const added, and a pointer to another type, in sodium_memcmp too"
  (map (lambda (p) (cons (car p) (cadddr p))) plants)
  (verdicts-of (map (lambda (p) (plant (car p) (cadr p) (caddr p))) plants)))

(test-equal "the prototype check answers 1 for each of the thirty rows written as the header has it, and for each qualifier dropped or added"
  '(("sodium_version_string" . 1) ("sodium_library_version_major" . 1)
    ("sodium_library_version_minor" . 1) ("sodium_init" . 1) ("sodium_memzero" . 1)
    ("randombytes_buf" . 1) ("crypto_generichash" . 1) ("crypto_generichash_bytes" . 1)
    ("crypto_generichash_bytes_min" . 1) ("crypto_generichash_bytes_max" . 1)
    ("crypto_generichash_keybytes_min" . 1) ("crypto_generichash_keybytes_max" . 1)
    ("sodium_memcmp" . 1)
    ("crypto_pwhash_str" . 1)
    ("crypto_pwhash_str_verify" . 1)
    ("crypto_pwhash_str_needs_rehash" . 1)
    ("crypto_pwhash_strbytes" . 1)
    ("crypto_pwhash_strprefix" . 1)
    ("crypto_pwhash_opslimit_min" . 1)
    ("crypto_pwhash_opslimit_max" . 1)
    ("crypto_pwhash_opslimit_interactive" . 1)
    ("crypto_pwhash_opslimit_moderate" . 1)
    ("crypto_pwhash_opslimit_sensitive" . 1)
    ("crypto_pwhash_memlimit_min" . 1)
    ("crypto_pwhash_memlimit_max" . 1)
    ("crypto_pwhash_memlimit_interactive" . 1)
    ("crypto_pwhash_memlimit_moderate" . 1)
    ("crypto_pwhash_memlimit_sensitive" . 1)
    ("crypto_pwhash_passwd_min" . 1)
    ("crypto_pwhash_passwd_max" . 1)
    ("sodium_memzero" . 1) ("sodium_memzero" . 1) ("randombytes_buf" . 1)
    ("crypto_generichash" . 1) ("sodium_memcmp" . 1)
    ("crypto_pwhash_str" . 1) ("crypto_pwhash_str_verify" . 1)
    ("crypto_pwhash_str_needs_rehash" . 1))
  (verdicts-of (append conventions-table
                       (list (plant "sodium_memzero" "void" '("void *" "size_t"))
                             (plant "sodium_memzero" "void" '("void * const" "const size_t"))
                             (plant "randombytes_buf" "void" '("void *" "size_t"))
                             (plant "crypto_generichash" "int"
                                    '("unsigned char *const" "size_t" "const unsigned char *"
                                      "unsigned long long" "const unsigned char *" "const size_t"))
                             (plant "sodium_memcmp" "int" '("const void *" "const void *" "size_t"))
                             (plant "crypto_pwhash_str" "int"
                                    '("char *const" "const char *const" "const unsigned long long"
                                      "const unsigned long long" "const size_t"))
                             (plant "crypto_pwhash_str_verify" "int"
                                    '("const char *const" "const char *const" "const unsigned long long"))
                             (plant "crypto_pwhash_str_needs_rehash" "int"
                                    '("const char *const" "const unsigned long long" "const size_t"))))))

;; size_t and unsigned long are one type on LP64 Linux, which the C side
;; cannot see; the map below does, and fails the row.
(test-equal "the limit: sodium_memzero written with unsigned long is answered 1 by the header, since size_t is that type here, and unmapped by the map"
  '((("sodium_memzero" . 1)) (#f))
  (list (verdicts-of (list (plant "sodium_memzero" "void" '("void *" "unsigned long"))))
        (list (chez-type "unsigned long"))))

(test-equal "the prototype check fails the compile, by step, for a function the header lacks"
  '(compile #t)
  (let ((v (verdicts-of (list (plant "sodium_no_such_function" "int" '())))))
    (list (car v) (and (pair? (cdr v)) (integer? (cadr v)) (not (= (cadr v) 0))))))

;; --- the map check, planted ----------------------------------------------------------------

(test-equal "the map check names a size_t written uptr, unsigned-64 or int, and a pointer written int, each by name"
  '((("sodium_memzero" (uptr size_t) void (uptr uptr) void))
    (("sodium_memzero" (uptr size_t) void (uptr unsigned-64) void))
    (("sodium_memzero" (uptr size_t) void (uptr int) void))
    (("sodium_memzero" (uptr size_t) void (int size_t) void)))
  (map (lambda (arguments)
         (map-problems
          (list (list "sodium_memzero" '("void" ("void *const" "const size_t")) arguments
                      'void 'plain '()))))
       '((uptr uptr) (uptr unsigned-64) (uptr int) (int size_t))))

(test-equal "the map check names a result written wrong, each by name: sodium_init as uptr, void or size_t, sodium_version_string as int, sodium_memzero as int"
  '((("sodium_init" () int () uptr))
    (("sodium_init" () int () void))
    (("sodium_init" () int () size_t))
    (("sodium_version_string" () uptr () int))
    (("sodium_memzero" (uptr size_t) void (uptr size_t) int)))
  (list (map-problems (list (list "sodium_init" '("int" ()) '() 'uptr 'plain '())))
        (map-problems (list (list "sodium_init" '("int" ()) '() 'void 'plain '())))
        (map-problems (list (list "sodium_init" '("int" ()) '() 'size_t 'plain '())))
        (map-problems (list (list "sodium_version_string" '("const char *" ()) '() 'int 'plain '())))
        (map-problems (list (list "sodium_memzero" '("void" ("void *const" "const size_t"))
                                  '(uptr size_t) 'int 'plain '())))))

(test-equal "the map check names a void argument, which maps to nothing, and a prototype that ends \"...\", since nothing here is variadic"
  '((("sodium_memzero" (#f) void (void) void))
    (("sodium_init" (#f) int (int) int)))
  (list (map-problems (list (list "sodium_memzero" '("void" ("void")) '(void) 'void 'plain '())))
        (map-problems (list (list "sodium_init" '("int" ("...")) '(int) 'int 'plain '())))))

(test-equal "the map check maps a void result to void and nothing else to it: sodium_memzero written void is no problem, and sodium_init written void is one"
  '(() (("sodium_init" () int () void)))
  (list (map-problems
         (list (list "sodium_memzero" '("void" ("void *const" "const size_t")) '(uptr size_t)
                     'void 'plain '())))
        (map-problems (list (list "sodium_init" '("int" ()) '() 'void 'plain '())))))

(test-equal "the map check passes each row written right: the thirty rows, and sodium_memzero in its qualifier-free spelling"
  '(() ())
  (list (map-problems conventions-table)
        (map-problems (list (list "sodium_memzero" '("void" ("void *" "size_t")) '(uptr size_t)
                                  'void 'plain '())))))

;; The new rows' Chez types, each written wrong in turn, against the real
;; prototypes of crypto_generichash, a size function and sodium_memcmp.
(define generichash-prototype
  '("int" ("unsigned char *" "size_t" "const unsigned char *" "unsigned long long"
           "const unsigned char *" "size_t")))

(test-equal "the map check names crypto_generichash's inlen written size_t, its outlen and keylen written unsigned-64, and its out written int, each by name"
  '((("crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int
      (uptr size_t uptr size_t uptr size_t) int))
    (("crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int
      (uptr unsigned-64 uptr unsigned-64 uptr size_t) int))
    (("crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int
      (uptr size_t uptr unsigned-64 uptr unsigned-64) int))
    (("crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t) int
      (int size_t uptr unsigned-64 uptr size_t) int)))
  (map (lambda (arguments)
         (map-problems
          (list (list "crypto_generichash" generichash-prototype arguments 'int 'plain '()))))
       '((uptr size_t uptr size_t uptr size_t)
         (uptr unsigned-64 uptr unsigned-64 uptr size_t)
         (uptr size_t uptr unsigned-64 uptr unsigned-64)
         (int size_t uptr unsigned-64 uptr size_t))))

(test-equal "the map check names a size function's size_t result written uptr, unsigned-64 and int, and sodium_memcmp's size_t written unsigned-64 and its result written size_t, each by name"
  '((("crypto_generichash_bytes" () size_t () uptr))
    (("crypto_generichash_bytes_max" () size_t () unsigned-64))
    (("crypto_generichash_keybytes_min" () size_t () int))
    (("sodium_memcmp" (uptr uptr size_t) int (uptr uptr unsigned-64) int))
    (("sodium_memcmp" (uptr uptr size_t) int (uptr uptr size_t) size_t)))
  (list (map-problems (list (list "crypto_generichash_bytes" '("size_t" ()) '() 'uptr 'plain '())))
        (map-problems (list (list "crypto_generichash_bytes_max" '("size_t" ()) '() 'unsigned-64 'plain '())))
        (map-problems (list (list "crypto_generichash_keybytes_min" '("size_t" ()) '() 'int 'plain '())))
        (map-problems (list (list "sodium_memcmp" '("int" ("const void *const" "const void *const" "size_t"))
                                  '(uptr uptr unsigned-64) 'int 'plain '())))
        (map-problems (list (list "sodium_memcmp" '("int" ("const void *const" "const void *const" "size_t"))
                                  '(uptr uptr size_t) 'size_t 'plain '())))))

;; Every row of the table, its Chez result and each of its arguments written
;; wrong in turn, held to the row's own C types: each is one problem, named.
(define (other-chez t) (if (eq? t 'int) 'uptr 'int))

(define (row-with-arguments row arguments)
  (list (row-name row) (row-prototype row) arguments (row-result row) (row-convention row) '()))

(define (row-with-result row result)
  (list (row-name row) (row-prototype row) (row-arguments row) result (row-convention row) '()))

(test-equal "the map check names, for each of the thirty rows, its result written wrong, and each argument written wrong, one problem each"
  '()
  (filter
   (lambda (row)
     (let ((arguments (row-arguments row)))
       (not (and (= 1 (length (map-problems (list (row-with-result row (other-chez (row-result row)))))))
                 (let loop ((i 0))
                   (or (= i (length arguments))
                       (and (= 1 (length
                                  (map-problems
                                   (list (row-with-arguments
                                          row
                                          (let swap ((rest arguments) (j 0))
                                            (cond ((null? rest) '())
                                                  ((= j i) (cons (other-chez (car rest)) (cdr rest)))
                                                  (else (cons (car rest) (swap (cdr rest) (+ j 1)))))))))))
                            (loop (+ i 1)))))))))
   conventions-table))

(test-end "constants")

(exit (suite-exit-status runner))
