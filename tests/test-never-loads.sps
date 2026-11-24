#!r6rs
;;; The suite that holds (chez-sodium-testing) and the counters it imports to
;;; loading no libsodium, and (chez-sodium)'s condition exports to the same.
;;; make check-suites, the copy check-test-fails makes, which holds only
;;; require-threaded and the counters in all but its leaks case, the launcher's
;;; env -i runs of make test, and the children test-chez-sodium-testing
;;; starts all import the testing library, and each would break, or become a
;;; child that reaches native code, if it loaded libsodium.
;;;
;;; Each library is read as data, with Chez's reader, and nothing in it is
;;; evaluated:
;;;
;;;   the allowlists  tests/chez-sodium-testing.sls' and counters.sls'
;;;                   import specs, each exactly its allowlist below, the
;;;                   (only (chezscheme) ...) name lists included: a planted
;;;                   import, or a name such as load-shared-object, is extra
;;;   the loaders     the libraries under src/ that load libsodium:
;;;                   (chez-sodium private native), the only one that calls
;;;                   load-shared-object (check-seam's rule (f)), and every
;;;                   library that imports a loader, found from src/'s
;;;                   imports, and asserted whole
;;;   the reach       the (chez-sodium ...) libraries the testing library
;;;                   imports, and every one they import, through src/: none
;;;                   is a loader, nor any library an allowlist names
;;;
;;; An allowlist that gained a loader, with an import to match, passes the
;;; first row and fails the last two. A loader that the data cannot see, a
;;; helper library under tests/ that imports (chez-sodium), say, is seen by
;;; the children:
;;;
;;;   the testing child  a fresh Chez imports (chez-sodium-testing) and
;;;                      references every export of it, so its body runs, then
;;;                      prints how many it referenced and whether
;;;                      /proc/self/maps names a libsodium: none mapped
;;;   the condition children
;;;                      a fresh Chez references every condition export of
;;;                      (chez-sodium), each through eval, and calls it. The
;;;                      body of a library runs when a binding it defines is
;;;                      referenced, and a re-export is the defining library's
;;;                      binding, so each runs (chez-sodium private
;;;                      conditions) alone. With CHEZ_SODIUM_LIBRARY naming no
;;;                      file each answers, nothing is mapped, and
;;;                      sodium-version alone raises load-failed. The control
;;;                      child, on the library the suite is given, answers
;;;                      and maps libsodium after sodium-version and not
;;;                      before, so the scan of the maps can say yes. A body
;;;                      in (chez-sodium) that nothing referenced, or an
;;;                      import of native that nothing uses, is invisible to
;;;                      both: test-public's no-body row and the loaders row
;;;                      hold those.
;;;
;;; The children that reach native's body start through gated-command, and
;;; print (valgrind . yes) exactly when the memory gate asked. The program
;;; text of a child names sodium-version only inside a quoted datum for eval:
;;; a program that names it anywhere runs native's body before its first line.
(import (rnrs)
        (only (rnrs eval) environment)
        (srfi :64)
        (only (chezscheme) directory-list file-directory? file-symbolic-link? getenv library-exports)
        (chez-sodium-testing))

;; SRFI-64 sets no exit status. This suite's last line turns the runner's
;; counts into one.
(define runner (test-runner-simple))
(test-runner-current runner)

;; The simple runner names a failing test but not its values. Print both.
(let ((simple-end (test-runner-on-test-end runner)))
  (test-runner-on-test-end! runner
    (lambda (r)
      (simple-end r)
      (when (memq (test-result-kind r) (quote (fail xpass)))
        (display "  expected: ")
        (write (test-result-ref r (quote expected-value)))
        (newline)
        (display "  actual:   ")
        (write (test-result-ref r (quote actual-value)))
        (newline)))))

;; --- the allowlists ---------------------------------------------------------
;; Each is a library's import specs, whole, as the file writes them. A change
;; to a library's imports changes its list here, in review.

(define testing-source "tests/chez-sodium-testing.sls")
(define counters-source "src/chez-sodium/private/counters.sls")

;; testing-allowlist : (Listof Any)
(define testing-allowlist
  '((rnrs)
    (srfi :64)
    (chez-sodium private counters)
    (only (chezscheme) base-exception-handler critical-section
          delete-directory display-condition exit-handler file-directory?
          get-process-id getenv make-mutex mkdir system with-mutex)
    (prefix (only (chezscheme) file-exists?) chez:)))

;; counters-allowlist : (Listof Any)
(define counters-allowlist
  '((chez-sodium private require-threaded)
    (rnrs)
    (only (chezscheme) critical-section make-mutex with-mutex)))

;; --- reading libraries as data ----------------------------------------------

;; read-library : String -> (U (List Name (Listof Spec)) (List 'unreadable String))
;; The library form at PATH, its first datum: its name and its import specs.
(define (read-library path)
  (guard (e (#t (list 'unreadable (string-append path ": " (describe e)))))
    (let ((form (call-with-port
                 (open-file-input-port path (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (if (and (list? form) (>= (length form) 4) (eq? (car form) 'library)
               (pair? (cadddr form)) (eq? (car (cadddr form)) 'import))
          (list (cadr form) (cdr (cadddr form)))
          (list 'unreadable (string-append path ": not a (library NAME (export ...) (import ...) ...) form"))))))

;; spec-library : Spec -> Name
;; The library an import spec names, through the wrappers R6RS and Chez
;; give: only, except, prefix, rename, for, library. A version reference
;; after a name, a list, is dropped.
(define (spec-library spec)
  (cond ((and (pair? spec) (memq (car spec) '(only except prefix rename for)) (pair? (cdr spec)))
         (spec-library (cadr spec)))
        ((and (pair? spec) (eq? (car spec) 'library) (pair? (cdr spec)))
         (spec-library (cadr spec)))
        ((pair? spec)
         (let ((parts (reverse spec)))
           (if (pair? (car parts)) (reverse (cdr parts)) spec)))
        (else spec)))

;; sls-files : String -> (Listof String)
;; Every .sls file under DIR, in sorted order, through no symbolic link.
(define (sls-files dir)
  (let loop ((names (list-sort string<? (directory-list dir))) (found '()))
    (if (null? names)
        (reverse found)
        (let ((path (string-append dir "/" (car names))))
          (loop (cdr names)
                (cond ((file-symbolic-link? path) found)
                      ((file-directory? path) (append (reverse (sls-files path)) found))
                      ((let ((n (string-length path)))
                         (and (> n 4) (string=? (substring path (- n 4) n) ".sls")))
                       (cons path found))
                      (else found)))))))

;; src-imports : (U (Listof (Pairof Name (Listof Name))) (List 'unreadable String))
;; Each library under src/ with the libraries it imports.
(define src-imports
  (guard (e (#t (list 'unreadable (describe e))))
    (let loop ((paths (sls-files "src")) (found '()))
      (if (null? paths)
          (reverse found)
          (let ((lib (read-library (car paths))))
            (if (eq? (car lib) 'unreadable)
                lib
                (loop (cdr paths)
                      (cons (cons (car lib) (map spec-library (cadr lib))) found))))))))

(define src-read? (not (and (pair? src-imports) (eq? (car src-imports) 'unreadable))))

;; imports-of : Name -> (Listof Name)
;; What the library NAME under src/ imports; none for a library outside it.
(define (imports-of name)
  (cond ((and src-read? (assoc name src-imports)) => cdr)
        (else '())))

;; name<? : Name Name -> Boolean
;; Library names ordered by how they are written, so a set of them is a list.
(define (written x) (call-with-string-output-port (lambda (p) (write x p))))
(define (name<? a b) (string<? (written a) (written b)))
(define (sorted names) (list-sort name<? names))

;; adjoin : (Listof Any) (Listof Any) -> (Listof Any)
(define (adjoin items set)
  (fold-left (lambda (set x) (if (member x set) set (cons x set))) set items))

;; native : Name
(define native '(chez-sodium private native))

;; loaders : (Listof Name)
;; native, and every library under src/ that imports a loader, found by
;; adding importers until none is left to add.
(define loaders
  (let grow ((found (list native)))
    (let ((more (filter (lambda (entry)
                          (and (not (member (car entry) found))
                               (exists (lambda (name) (member name found)) (cdr entry))))
                        (if src-read? src-imports '()))))
      (if (null? more)
          (sorted found)
          (grow (adjoin (map car more) found))))))

;; reach : (Listof Name) -> (Listof Name)
;; The (chez-sodium ...) libraries among NAMES, and every one they import,
;; and so on, through src/.
(define (reach names)
  (let walk ((todo names) (seen '()))
    (cond ((null? todo) (sorted seen))
          ((or (member (car todo) seen)
               (not (and (pair? (car todo)) (eq? (caar todo) 'chez-sodium))))
           (walk (cdr todo) seen))
          (else (walk (append (cdr todo) (imports-of (car todo))) (cons (car todo) seen))))))

;; differences : (Listof Any) (Listof Any) -> (List (Listof Any) (Listof Any))
;; (EXTRA MISSING): the specs in FOUND that ALLOWED lacks, and those it has
;; that FOUND lacks, each in the order written.
(define (differences found allowed)
  (list (filter (lambda (s) (not (member s allowed))) found)
        (filter (lambda (s) (not (member s found))) allowed)))

;; import-differences : String (Listof Any) -> Any
;; differences for the library at PATH against ALLOWED, or why it was not read.
(define (import-differences path allowed)
  (let ((lib (read-library path)))
    (if (eq? (car lib) 'unreadable)
        lib
        (cons (car lib) (differences (cadr lib) allowed)))))

(test-begin "never-loads")

(test-equal "(chez-sodium-testing) imports exactly its allowlist, no more and no less"
  '((chez-sodium-testing) () ())
  (import-differences testing-source testing-allowlist))

(test-equal "(chez-sodium private counters) imports exactly its allowlist, no more and no less"
  '((chez-sodium private counters) () ())
  (import-differences counters-source counters-allowlist))

(test-equal "the libraries under src/ that load libsodium, found from their imports: native, and each that imports a loader"
  (sorted '((chez-sodium)
            (chez-sodium private byte-verbs)
            (chez-sodium private native)))
  (if src-read? loaders src-imports))

;; What the testing library imports, read from its file, not its allowlist.
(define testing-read (read-library testing-source))

(test-equal "what the testing library reaches through src/ is the counters and require-threaded, and no library an allowlist names, nor one it reaches, loads libsodium"
  (list (sorted '((chez-sodium private counters) (chez-sodium private require-threaded)))
        '()
        '())
  (cond ((not src-read?) src-imports)
        ((eq? (car testing-read) 'unreadable) testing-read)
        (else
         (let* ((named (map spec-library (append testing-allowlist counters-allowlist)))
                (reached (reach (map spec-library (cadr testing-read)))))
           (list reached
                 (filter (lambda (name) (member name loaders)) (sorted (adjoin named '())))
                 (filter (lambda (name) (member name loaders)) reached))))))

;; --- the behaviour: children -------------------------------------------------

(define chez (getenv "CHEZ"))

;; The names (chez-sodium-testing) exports, as Chez lists them, sorted.
(define testing-exports
  (guard (e (#t (list (string->symbol (describe e)))))
    (sorted (library-exports '(chez-sodium-testing)))))

;; write-text : String String -> Void
(define (write-text path text)
  (call-with-port
   (open-file-output-port path (file-options no-fail) (buffer-mode block)
                          (make-transcoder (utf-8-codec)))
   (lambda (p) (put-string p text))))

;; written-text : Any -> String
(define (written-text datum)
  (call-with-string-output-port (lambda (p) (write datum p))))

;; lines : (Listof Any) -> String
;; Each datum written on a line of its own.
(define (lines data)
  (apply string-append (map (lambda (d) (string-append (written-text d) "\n")) data)))

;; The child's scan of /proc/self/maps for a needle: yes, no, or no-maps
;; where the file cannot be read, so a platform without it fails by value.
(define maps-scan-text
  (string-append
   "(define (maps)\n"
   "  (guard (e (#t #f))\n"
   "    (call-with-port\n"
   "     (open-file-input-port \"/proc/self/maps\" (file-options) (buffer-mode block)\n"
   "                           (make-transcoder (utf-8-codec)))\n"
   "     get-string-all)))\n"
   "(define (has? needle)\n"
   "  (let ((m (maps)))\n"
   "    (if (not m)\n"
   "        'no-maps\n"
   "        (let loop ((i 0))\n"
   "          (cond ((> (+ i (string-length needle)) (string-length m)) 'no)\n"
   "                ((string=? (substring m i (+ i (string-length needle))) needle) 'yes)\n"
   "                (else (loop (+ i 1))))))))\n"))

;; child-program : (Listof Symbol) -> String
;; A program that imports the testing library, makes a list of every name in
;; NAMES, and prints (COUNT MAPPED): how many it referenced, and yes or no
;; for a libsodium in /proc/self/maps.
(define (child-program names)
  (string-append
   "#!r6rs\n"
   "(import (rnrs) (chez-sodium-testing))\n"
   "(define referenced (list " (apply string-append (map (lambda (n) (string-append (symbol->string n) " ")) names)) "))\n"
   maps-scan-text
   "(write (list (length referenced) (has? \"libsodium\")))\n"
   "(newline)\n"
   "(exit 0)\n"))

;; run-child : (Listof Symbol) -> (U (List Integer String String) (List 'raised String))
(define (run-child names)
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (base)
       (let ((program (string-append base "/child.sps")))
         (write-text program (child-program names))
         (capture-command
          (list chez "--libdirs" "src:tests:build/scheme-libs" "--program" program)))))))

(test-equal "a child that references every export of (chez-sodium-testing) runs its body, and maps no libsodium: it prints the count of names and no"
  (list 0 (string-append "(" (number->string (length testing-exports)) " no)\n") "")
  (run-child testing-exports))

;; --- the condition exports ----------------------------------------------------

;; verb-names : (Listof Symbol)
;; The exports of (chez-sodium) that load libsodium. Every other export is a
;; condition export.
(define verb-names '(sodium-version random-bytes blake2b constant-time-bytevector=?))

;; condition-names : (Listof Symbol)
;; The exports of (chez-sodium) less the verbs, as Chez lists them, sorted.
(define condition-names
  (guard (e (#t (list (string->symbol (describe e)))))
    ;; environment loads (chez-sodium) so library-exports can list it, and
    ;; runs no body: nothing of it is referenced.
    (environment '(chez-sodium))
    (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
               (filter (lambda (n) (not (memq n verb-names)))
                       (library-exports '(chez-sodium))))))

;; checked-names : (Listof Symbol)
;; The condition exports the children's lines below call and check, written
;; out. A row holds them to condition-names.
(define checked-names
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
             '(chez-sodium-error?
               sodium-library-unavailable?
               sodium-library-unavailable-reason
               sodium-library-unavailable-path
               sodium-library-unavailable-source
               sodium-library-unavailable-detail
               sodium-library-unavailable-candidates
               sodium-failed?
               sodium-failed-function
               sodium-failed-code)))

(test-equal "the condition exports of (chez-sodium), its exports less the verbs, are exactly the names the condition children check"
  checked-names
  condition-names)

;; The program of the condition children. It does not import (chez-sodium),
;; and names sodium-version only inside quoted data for eval. A made
;; condition has a distinct value in each field, so an accessor that read the
;; wrong field cannot pass.
(define conditions-program
  (string-append
   "#!r6rs\n"
   "(import (rnrs) (rnrs eval) (only (chez-sodium private conditions) make-sodium-library-unavailable make-sodium-failed))\n"
   "(define env (environment '(rnrs) '(chez-sodium)))\n"
   "(define (pub n) (eval n env))\n"
   "(define referenced (map pub '(" (apply string-append (map (lambda (n) (string-append (symbol->string n) " ")) condition-names)) ")))\n"
   maps-scan-text
   "(define (yes-no x) (cond ((eq? x #t) 'yes) ((eq? x #f) 'no) (else (list 'neither x))))\n"
   "(define made (make-sodium-library-unavailable 'not-found \"/p\" 'system 7 '(\"c\")))\n"
   "(define made-failed (make-sodium-failed \"crypto_generichash\" 13))\n"
   "(define (refused thunk) (guard (e ((assertion-violation? e) 'refused) (#t 'other)) (list 'answered (thunk))))\n"
   "(define (show x) (write x) (newline))\n"
   "(define (field name) (list name ((pub name) made)))\n"
   "(show (cons 'before (has? \"libsodium\")))\n"
   "(show (list 'chez-sodium-error? (yes-no ((pub 'chez-sodium-error?) made)) (yes-no ((pub 'chez-sodium-error?) 42))))\n"
   "(show (list 'sodium-library-unavailable? (yes-no ((pub 'sodium-library-unavailable?) made)) (yes-no ((pub 'sodium-library-unavailable?) 42))))\n"
   "(show (field 'sodium-library-unavailable-reason))\n"
   "(show (field 'sodium-library-unavailable-path))\n"
   "(show (field 'sodium-library-unavailable-source))\n"
   "(show (field 'sodium-library-unavailable-detail))\n"
   "(show (field 'sodium-library-unavailable-candidates))\n"
   "(show (list 'sodium-failed? (yes-no ((pub 'sodium-failed?) made-failed)) (yes-no ((pub 'sodium-failed?) made)) (yes-no ((pub 'sodium-failed?) 42))))\n"
   "(show (list 'sodium-failed-function ((pub 'sodium-failed-function) made-failed) (refused (lambda () ((pub 'sodium-failed-function) 42)))))\n"
   "(show (list 'sodium-failed-code ((pub 'sodium-failed-code) made-failed) (refused (lambda () ((pub 'sodium-failed-code) 42)))))\n"
   "(show (list 'sodium-version\n"
   "  (guard (e (#t (list 'raised\n"
   "                      (yes-no ((pub 'chez-sodium-error?) e))\n"
   "                      ((pub 'sodium-library-unavailable-reason) e)\n"
   "                      ((pub 'sodium-library-unavailable-path) e)\n"
   "                      ((pub 'sodium-library-unavailable-source) e)\n"
   "                      ((pub 'sodium-library-unavailable-candidates) e))))\n"
   "    (list 'answered\n"
   "          (yes-no (equal? ((pub 'sodium-version))\n"
   "                          (cdr (assq 'version ((eval 'loaded-libsodium (environment '(rnrs) '(chez-sodium private native))))))))))))\n"
   "(show (cons 'after (has? \"libsodium\")))\n"
   "(show (cons 'valgrind (has? \"vgpreload_memcheck\")))\n"
   "(exit 0)\n"))

;; valgrind-answer : Symbol
;; yes exactly when the memory gate asked for it.
(define valgrind-answer (if (getenv "CHEZ_SODIUM_GATE_CHILD") 'yes 'no))

;; conditions-expected : Any Symbol -> String
;; The program's whole stdout. SODIUM-VERSION-ANSWER is what its call printed.
(define (conditions-expected sodium-version-answer after)
  (lines (list '(before . no)
               '(chez-sodium-error? yes no)
               '(sodium-library-unavailable? yes no)
               '(sodium-library-unavailable-reason not-found)
               '(sodium-library-unavailable-path "/p")
               '(sodium-library-unavailable-source system)
               '(sodium-library-unavailable-detail 7)
               '(sodium-library-unavailable-candidates ("c"))
               '(sodium-failed? yes no no)
               '(sodium-failed-function "crypto_generichash" refused)
               '(sodium-failed-code 13 refused)
               (list 'sodium-version sodium-version-answer)
               (cons 'after after)
               (cons 'valgrind valgrind-answer))))

;; run-conditions-child : (U String #f) -> (U (List Integer String String) (List 'raised String))
;; The program run through gated-command; with an override, under env, which
;; comes before the gate's own words so that Valgrind runs the Chez itself.
(define (run-conditions-child override)
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (base)
       (let ((program (string-append base "/conditions-child.sps")))
         (write-text program conditions-program)
         (capture-command
          (append (if override
                      (list "env" (string-append "CHEZ_SODIUM_LIBRARY=" override))
                      '())
                  (gated-command getenv
                                 (list chez "--libdirs" "src:tests:build/scheme-libs"
                                       "--program" program)))))))))

;; absent-path : (U String (List 'raised String))
;; An absolute path in a directory of this process, removed when it ends,
;; which this suite never puts a file in: it names no file. Made under a
;; guard: if the directory cannot be made, the path is the sentinel, and the
;; row that runs the child fails by name.
(define absent-directory
  (guard (e (#t (list 'raised (describe e))))
    (make-process-temp-directory)))
(define absent-path
  (if (string? absent-directory)
      (string-append absent-directory "/absent-libsodium.so")
      absent-directory))

(test-equal "with CHEZ_SODIUM_LIBRARY naming no file, a child calls every condition export of (chez-sodium) through eval, and each answers; nothing is mapped before or after; sodium-version alone raises load-failed, from the override, as a &chez-sodium-error; the child ran under Valgrind exactly when the gate asked"
  (list 0
        (conditions-expected (list 'raised 'yes 'load-failed absent-path 'override '()) 'no)
        "")
  (run-conditions-child absent-path))

(test-equal "the control child, on the library this suite is given: the same condition answers, no libsodium mapped before sodium-version, its answer native's version, and libsodium mapped after"
  (list 0 (conditions-expected '(answered yes) 'yes) "")
  (run-conditions-child #f))

(test-end "never-loads")

(exit (suite-exit-status runner))
