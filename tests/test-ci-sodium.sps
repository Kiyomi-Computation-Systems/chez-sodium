#!r6rs
;;; The suite for scripts/ci/check-sodium.sh and scripts/ci/build-sodium.sh,
;;; the two scripts behind CI's floor and current lanes, and for
;;; check-sodium.sh --discovery, the step after make build on main: they build
;;; libsodium from its release tarball, and check what was built, or what main
;;; loaded, before any suite runs on it (ADR-0002; ADR-0003; ADR-0011).
;;;
;;; Both scripts find packaging/floors.sexp from their own place, through
;;; scripts/ci/floor.sh, so every row runs a copy of scripts/ci in a fresh
;;; tree whose floors file is the row's own. The rows run the scripts with sh,
;;; not by their own names, so a lost execute bit is not what they find. Each
;;; row asserts the script's exit status, its whole stdout and its whole
;;; stderr, written here by hand, never read back from the scripts.
;;;
;;;   - check-sodium.sh PREFIX: each row compiles, with $CC, a stub
;;;     PREFIX/lib/libsodium.so.NN that answers the row's version, major,
;;;     minor and minimal, and writes a PREFIX/include/sodium.h that defines
;;;     the row's three macros. The base row's floor is 8.1.2, a version no
;;;     libsodium has, so a version written in the script fails it. Every other
;;;     row is one edit of a passing row, and names what it breaks. The rows
;;;     put PREFIX/include first on C_INCLUDE_PATH and this suite's own value
;;;     after it, since in a Guix container the variable holds gcc's kernel
;;;     headers too; a row that needs no sodium.h on the path uses a CC
;;;     stand-in, since both the container's directory and /usr/include hold
;;;     a real one;
;;;   - check-sodium.sh --discovery: each row hands the script a CHEZ and a CC
;;;     stand-in, each by its path, that print what the row says and log their
;;;     calls;
;;;   - build-sodium.sh: each row puts a shim/ directory first on PATH, whose
;;;     curl, sha256sum, tar and make are POSIX sh scripts that log each call
;;;     (tar makes a configure that logs its own), and a cc that logs its
;;;     own. PATH holds nothing else but links to the tools the scripts need,
;;;     so a row can leave one out; sh, CHEZ and the real compiler are
;;;     handed over by their paths. Each row asserts the calls, whole and in
;;;     order, besides the output. The pins are literals here, a reviewed copy
;;;     of the script's.
;;;
;;; The children are sh, the C compiler, the shims and, through
;;; check-sodium.sh, a Chez that runs the script's own probe on a stub. None
;;; reaches (chez-sodium private native) or loads libsodium, which is what the
;;; memory gate holds, and a shell cannot run under it: the gate requires a
;;; child's Command: to be Chez or the oracle. So they run outside it, through
;;; capture-command, as test-check-floors' check-chez.sh rows do (ADR-0011).
;;;
;;; Each computation that can raise runs under a guard that names what was
;;; raised, since SRFI-64 turns a raise in the actual expression into #f and
;;; does not catch one in the expected expression. No expected value is #f.
;;; Effects run in order, through let*, named lets and for-each, never map.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (only (floors) read-floors floor-text)
        (only (libsodium-oracle) c-compiler)
        (only (chezscheme) directory-list getenv))

(define runner (test-runner-simple))
(test-runner-current runner)

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

;; outcome : (-> Any) -> (U (List 'returned Any) (List 'raised String))
(define (outcome thunk)
  (guard (e (#t (list 'raised (describe e))))
    (list 'returned (thunk))))

(test-begin "ci-sodium")

(define (set? value) (and (string? value) (not (string=? value ""))))

(define chez (getenv "CHEZ"))

(test-equal "CHEZ names the Chez that check-sodium.sh runs its probe with"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

(define cc-words (c-compiler getenv))

(test-equal "CC is one word, as the scripts read it"
  1
  (length cc-words))

(unless (= (length cc-words) 1)
  (exit 1))

(define cc (car cc-words))

;; The container's include path also holds gcc's kernel headers, so a row's
;; PREFIX/include goes first and this value after it.
(define ambient (getenv "C_INCLUDE_PATH"))

;; cip-after : String -> String
(define (cip-after dir)
  (if (set? ambient) (string-append dir ":" ambient) dir))

;; --- strings -------------------------------------------------------------------------

(define (string-prefix? prefix s)
  (let ((n (string-length s)) (m (string-length prefix)))
    (and (>= n m) (string=? (substring s 0 m) prefix))))

(define (q s) (string-append "\"" s "\""))

(define (text-of lines)
  (apply string-append (map (lambda (line) (string-append line "\n")) lines)))

(define (text-lines text)
  (let loop ((chars (string->list text)) (line '()) (found '()))
    (cond ((null? chars)
           (reverse (if (null? line) found (cons (list->string (reverse line)) found))))
          ((char=? (car chars) #\newline)
           (loop (cdr chars) '() (cons (list->string (reverse line)) found)))
          (else (loop (cdr chars) (cons (car chars) line) found)))))

(define (shell-word s)
  (call-with-string-output-port
   (lambda (p)
     (put-char p #\')
     (string-for-each (lambda (c) (if (char=? c #\') (put-string p "'\\''") (put-char p c))) s)
     (put-char p #\'))))

(define (string-suffix? suffix s)
  (let ((n (string-length s)) (m (string-length suffix)))
    (and (>= n m) (string=? (substring s (- n m) n) suffix))))

(define (split-spaces s)
  (let loop ((chars (string->list s)) (word '()) (found '()))
    (cond ((null? chars)
           (reverse (if (null? word) found (cons (list->string (reverse word)) found))))
          ((char=? (car chars) #\space)
           (loop (cdr chars) '() (if (null? word) found (cons (list->string (reverse word)) found))))
          (else (loop (cdr chars) (cons (car chars) word) found)))))

(define (first-line text)
  (let ((lines (text-lines text)))
    (and (= (length lines) 1) (car lines))))

(define (find-from text part start)
  (let ((n (string-length text)) (m (string-length part)))
    (let loop ((i start))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring text i (+ i m)) part) i)
            (else (loop (+ i 1)))))))

;; work-written : String String String -> (Pairof String Natural)
;; TEXT with each BASE followed by mktemp's six characters written NAME, and
;; how many different ones it named.
(define (work-written text base name)
  (let loop ((i 0) (pieces '()) (seen '()))
    (let ((at (find-from text base i)))
      (if (or (not at) (> (+ at (string-length base) 6) (string-length text)))
          (cons (apply string-append (reverse (cons (substring text i (string-length text)) pieces)))
                (length seen))
          (let* ((end (+ at (string-length base) 6))
                 (suffix (substring text (+ at (string-length base)) end)))
            (loop end (cons* name (substring text i at) pieces)
                  (if (member suffix seen) seen (cons suffix seen))))))))

;; --- trees ---------------------------------------------------------------------------

(define (write-file path text)
  (call-with-port (open-file-output-port path (file-options no-fail) (buffer-mode block)
                                         (make-transcoder (utf-8-codec)))
    (lambda (port) (put-string port text))))

(define (checked what argv)
  (let ((answer (capture-command argv)))
    (unless (equal? answer (list 0 "" ""))
      (error 'checked what answer))))

(define (write-file-in dir name text)
  (let* ((path (string-append dir "/" name))
         (slash (let loop ((i (- (string-length path) 1)))
                  (if (char=? (string-ref path i) #\/) i (loop (- i 1))))))
    (checked "mkdir" (list "mkdir" "-p" (substring path 0 slash)))
    (write-file path text)))

(define (floors-text sodium)
  (string-append "((chez \"9.8.7\")\n (sodium \"" sodium "\"))\n"))

;; with-tree : (U String #f) (String -> Any) -> Any
;; PROC on ROOT, a fresh directory holding a copy of the real scripts/ci and
;; a packaging/floors.sexp with FLOORS-TEXT, or none for #f.
(define (with-tree floors-text proc)
  (call-with-temp-directory
   (lambda (root)
     (checked "mkdir" (list "mkdir" "-p" (string-append root "/scripts")
                            (string-append root "/packaging")))
     (checked "cp" (list "cp" "-R" "scripts/ci" (string-append root "/scripts/ci")))
     (when floors-text
       (write-file (string-append root "/packaging/floors.sexp") floors-text))
     (proc root))))

;; env-order : (Listof String) -> (Listof String)
;; ENV-ARGS with every -u NAME pair first: env reads -u only before the first
;; assignment.
(define (env-order env-args)
  (let loop ((rest env-args) (unsets '()) (sets '()))
    (cond ((null? rest) (append (reverse unsets) (reverse sets)))
          ((and (string=? (car rest) "-u") (pair? (cdr rest)))
           (loop (cddr rest) (cons* (cadr rest) "-u" unsets) sets))
          (else (loop (cdr rest) unsets (cons (car rest) sets))))))

(define (file-or-none path)
  (if (file-exists? path)
      (call-with-port (open-file-input-port path (file-options) (buffer-mode block)
                                            (make-transcoder (utf-8-codec)))
        get-string-all)
      'none))

(define (text-or-empty path)
  (let ((text (file-or-none path)))
    (cond ((eq? text 'none) "") ((eof-object? text) "") (else text))))

;; --- the reviewed copies -----------------------------------------------------------------

(define floor-version "8.1.2")
(define current-version "1.0.22")
(define floor-so "libsodium.so.23")
(define current-so "libsodium.so.26")
(define floor-what "the libsodium floor")
(define current-what "the pinned current libsodium")

;; The SHA-256 of each role's tarball: the floor's and the current release's.
(define floor-archive "6f504490b342a4f8a4c4a02fc9b866cbef8622d5df4e5452b46be121e46636c1")
(define current-archive "adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349")
(define other-digest (make-string 64 #\5))

;; --- check-sodium.sh: the stub and its header -----------------------------------------------
;;
;; A Lib is (list VERSION MAJOR MINOR MINIMAL): what the stub answers to
;; sodium_version_string (#f for NULL), sodium_library_version_major, _minor
;; and sodium_library_minimal. A Header is (list VERSION MAJOR MINOR), the C
;; text of each #define, or #f to leave it undefined.

(define floor-lib (list floor-version 10 3 0))
(define floor-header (list (q floor-version) "10" "3"))
(define current-lib (list current-version 26 4 0))
(define current-header (list (q current-version) "26" "4"))

(define (c-string s)
  (call-with-string-output-port
   (lambda (p)
     (put-char p #\")
     (string-for-each (lambda (c)
                        (when (memv c '(#\" #\\)) (put-char p #\\))
                        (put-char p c))
                      s)
     (put-char p #\"))))

(define (stub-source lib)
  (string-append
   "const char *sodium_version_string(void) { return "
   (if (car lib) (c-string (car lib)) "0") "; }\n"
   "int sodium_library_version_major(void) { return " (number->string (cadr lib)) "; }\n"
   "int sodium_library_version_minor(void) { return " (number->string (caddr lib)) "; }\n"
   "int sodium_library_minimal(void) { return " (number->string (cadddr lib)) "; }\n"))

;; make-library! : String String String Lib -> (U 0 (List 'compile Any))
(define (make-library! root dir name lib)
  (let ((source (string-append root "/stub.c")))
    (checked "mkdir" (list "mkdir" "-p" dir))
    (write-file source (stub-source lib))
    (let ((answer (capture-command
                   (append (list cc) (list "-Wall" "-Werror" "-shared" "-fPIC"
                                          "-o" (string-append dir "/" name) source)))))
      (if (eqv? (car answer) 0) 0 (list 'compile answer)))))

(define (header-text header)
  (string-append
   (if (car header) (string-append "#define SODIUM_VERSION_STRING " (car header) "\n") "")
   (if (cadr header) (string-append "#define SODIUM_LIBRARY_VERSION_MAJOR " (cadr header) "\n") "")
   (if (caddr header) (string-append "#define SODIUM_LIBRARY_VERSION_MINOR " (caddr header) "\n") "")))

;; --- check-sodium.sh: the rows' machinery ------------------------------------------------------
;;
;; A Spec is an association list: floors, lib (a Lib, or none), header (a
;; Header, or none), soname, args and env (each a procedure of the tree's
;; root and PREFIX), and setup (a procedure of the same two, run after the
;; stub is made: 0, or what went wrong).

(define (lib-path prefix so) (string-append prefix "/lib/" so))
(define (header-path prefix) (string-append prefix "/include/sodium.h"))

;; lane-env : String -> (String String -> (Listof String))
;; The environment a lane's check step gives: the override naming PREFIX's
;; library for SONAME, the header's directory first on C_INCLUDE_PATH, and this
;; suite's CC and CHEZ. CPATH, which the compiler searches first, is unset.
(define (lane-env so)
  (lambda (root prefix)
    (list (string-append "CHEZ_SODIUM_LIBRARY=" (lib-path prefix so))
          (string-append "C_INCLUDE_PATH=" (cip-after (string-append prefix "/include")))
          (string-append "CC=" cc)
          (string-append "CHEZ=" chez)
          "-u" "CPATH")))

;; env-with : String (U (String String -> String) #f) (String String -> Words) -> (String String -> Words)
;; BASE with NAME set to what VALUE gives, or unset for #f.
(define (env-with name value base)
  (lambda (root prefix)
    (let ((others (filter (lambda (word) (not (string-prefix? (string-append name "=") word)))
                          (base root prefix))))
      (if value
          (cons (string-append name "=" (value root prefix)) others)
          (cons* "-u" name others)))))

(define floor-spec
  (list (cons 'floors (floors-text floor-version))
        (cons 'lib floor-lib)
        (cons 'header floor-header)
        (cons 'soname floor-so)
        (cons 'args (lambda (root prefix) (list prefix)))
        (cons 'env (lane-env floor-so))
        (cons 'setup (lambda (root prefix) 0))))

(define current-spec
  (append (list (cons 'floors #f)
                (cons 'lib current-lib)
                (cons 'header current-header)
                (cons 'soname current-so)
                (cons 'args (lambda (root prefix) (list prefix "--current")))
                (cons 'env (lane-env current-so)))
          floor-spec))

(define (spec-with spec . changes)
  (let loop ((rest changes) (spec spec))
    (if (null? rest)
        spec
        (loop (cddr rest) (cons (cons (car rest) (cadr rest)) spec)))))

(define (spec-ref spec key) (cdr (assq key spec)))

(define (make-prefix! root prefix spec)
  (let* ((lib (spec-ref spec 'lib))
         (built (if (eq? lib 'none)
                    0
                    (make-library! root (string-append prefix "/lib") (spec-ref spec 'soname) lib))))
    (cond ((not (eqv? built 0)) built)
          (else
           (let ((header (spec-ref spec 'header)))
             (unless (eq? header 'none)
               (write-file-in prefix "include/sodium.h" (header-text header))))
           ((spec-ref spec 'setup) root prefix)))))

(define (check-row name spec expected-of)
  (test-equal (string-append "check-sodium.sh: " name)
    '(returned same)
    (outcome
     (lambda ()
       (with-tree (spec-ref spec 'floors)
         (lambda (root)
           (let* ((prefix (string-append root "/prefix"))
                  (made (make-prefix! root prefix spec)))
             (if (not (eqv? made 0))
                 (list 'setup made)
                 (let* ((got (capture-command
                              (append (list "env")
                                      (env-order ((spec-ref spec 'env) root prefix))
                                      (list "sh" (string-append root "/scripts/ci/check-sodium.sh"))
                                      ((spec-ref spec 'args) root prefix))))
                        (want (expected-of root prefix)))
                   (if (equal? got want) 'same (list 'got got 'want want)))))))))))

;; --- check-sodium.sh: what it answers, written by hand ---------------------------------------

(define (passes prefix so version major minor what)
  (list 0
        (string-append
         "check-sodium.sh: " (lib-path prefix so) " is libsodium " version " (library "
         major "." minor "), " what ", and no minimal build\n"
         "check-sodium.sh: " cc " finds <sodium.h> at " (header-path prefix)
         ", which declares the same release, and CHEZ_SODIUM_LIBRARY names the library\n")
        ""))

(define (floor-passes prefix) (passes prefix floor-so floor-version "10" "3" floor-what))
(define (current-passes prefix) (passes prefix current-so current-version "26" "4" current-what))

(define (refused . words)
  (list 1 "" (string-append "check-sodium.sh: " (apply string-append words) "\n")))

(define (usage-answer)
  (list 2 "" "usage: check-sodium.sh PREFIX [--current] | --discovery\n"))

(define env-why "the library this checks, so that make build and make test load it")

(define (override-unset prefix so)
  (refused "CHEZ_SODIUM_LIBRARY is unset, but must be " (lib-path prefix so) ", " env-why))

(define (override-is prefix so how)
  (refused "CHEZ_SODIUM_LIBRARY is '" how "', but must be " (lib-path prefix so) ", " env-why))

(define (header-elsewhere prefix found)
  (refused cc " finds <sodium.h> at " found ", not " (header-path prefix)
           ": C_INCLUDE_PATH must name " prefix "/include first, so that the suites compile against the library's own header"))

(define (header-version-refused prefix defined what wanted)
  (refused (header-path prefix) " defines SODIUM_VERSION_STRING " defined ", but " what " is "
           (q wanted)))

(define (header-naturals prefix major minor)
  (refused (header-path prefix) " defines SODIUM_LIBRARY_VERSION_MAJOR '" major
           "' and SODIUM_LIBRARY_VERSION_MINOR '" minor "', which are not both naturals"))

(define (library-version-refused prefix so answered what wanted)
  (refused (lib-path prefix so) " answers " (q answered) " to sodium_version_string(), but " what
           " is " (q wanted)))

(define (library-numbers-refused prefix so major minor hmajor hminor)
  (refused (lib-path prefix so) " answers " major "." minor
           " to sodium_library_version_major() and _minor(), but " (header-path prefix)
           " declares " hmajor "." hminor))

(define (minimal-refused prefix so answer)
  (refused (lib-path prefix so) " answers " answer
           " to sodium_library_minimal(), but a lane's libsodium must answer 0: no minimal build"))

(define (no-library prefix so)
  (refused "no library at " (lib-path prefix so) ": it is not a regular file"))

(define (floor-sh-refused detail)
  (list 1 ""
        (string-append "floor.sh: packaging/floors.sexp: " detail "\n"
                       "check-sodium.sh: no libsodium floor to check against\n")))

;; A CC stand-in for check rows that need the compiler to say something else.
(define (stand-in-cc root listing status err)
  (let ((path (string-append root "/cc-stand-in")))
    (write-file path
      (string-append "#!/bin/sh\n"
                     "case \" $* \" in\n"
                     "  *\" -dM \"*) exit 0 ;;\n"
                     "esac\n"
                     (if (string=? err "") "" (string-append "printf '%s\\n' " (c-string err) " >&2\n"))
                     (if listing (string-append "printf '%s' " (c-string listing) "\n") "")
                     "exit " (number->string status) "\n"))
    (checked "chmod" (list "chmod" "755" path))
    path))

;; --- check-sodium.sh: passes -------------------------------------------------------------

(check-row "the floor's library, its header and the lane's env pass, with the identity named"
  floor-spec (lambda (root prefix) (floor-passes prefix)))

(check-row "--current: the pinned release's library passes, in a tree with no floors file"
  current-spec (lambda (root prefix) (current-passes prefix)))

(check-row "--current: it passes whatever floor the tree has: the floors file is not read"
  (spec-with current-spec 'floors (floors-text "9.9.9"))
  (lambda (root prefix) (current-passes prefix)))

(check-row "the env names no version: version, current_version, soname and what set to the other release's change nothing"
  (spec-with floor-spec
             'env (lambda (root prefix)
                    (append ((lane-env floor-so) root prefix)
                            (list "version=1.0.22" "current_version=8.1.3" "soname=libsodium.so.26"
                                  "what=elsewhere"))))
  (lambda (root prefix) (floor-passes prefix)))

(check-row "major and minor are the header's, not the floor's: a library and header agreeing on 9 and 7 pass"
  (spec-with floor-spec 'lib (list floor-version 9 7 0) 'header (list (q floor-version) "9" "7"))
  (lambda (root prefix) (passes prefix floor-so floor-version "9" "7" floor-what)))

;; --- check-sodium.sh: the soname and the files ------------------------------------------------

(define (move-library! root prefix from to)
  (checked "mv" (list "mv" (lib-path prefix from) (lib-path prefix to)))
  0)

(check-row "the floor given a prefix whose only library is libsodium.so.26 is refused, naming the .23 path"
  (spec-with floor-spec 'soname current-so
             'env (lane-env floor-so))
  (lambda (root prefix) (no-library prefix floor-so)))

(check-row "--current given a prefix whose only library is libsodium.so.23 is refused, naming the .26 path"
  (spec-with current-spec 'soname floor-so)
  (lambda (root prefix) (no-library prefix current-so)))

(check-row "the floor with both sonames present and the override naming .26 is refused at the override"
  (spec-with floor-spec
             'setup (lambda (root prefix)
                      (checked "cp" (list "cp" (lib-path prefix floor-so) (lib-path prefix current-so)))
                      0)
             'env (lane-env current-so))
  (lambda (root prefix) (override-is prefix floor-so (lib-path prefix current-so))))

(check-row "a library that is a directory is refused"
  (spec-with floor-spec 'lib 'none
             'setup (lambda (root prefix)
                      (checked "mkdir" (list "mkdir" "-p" (lib-path prefix floor-so)))
                      (write-file-in prefix "include/sodium.h" (header-text floor-header))
                      0))
  (lambda (root prefix) (no-library prefix floor-so)))

(check-row "a dangling link as the library is refused"
  (spec-with floor-spec 'lib 'none
             'setup (lambda (root prefix)
                      (checked "mkdir" (list "mkdir" "-p" (string-append prefix "/lib")))
                      (checked "ln" (list "ln" "-s" "libsodium.so.23.3.0" (lib-path prefix floor-so)))
                      (write-file-in prefix "include/sodium.h" (header-text floor-header))
                      0))
  (lambda (root prefix) (no-library prefix floor-so)))

(check-row "a library that is a link to a real file, as make install leaves it, passes"
  (spec-with floor-spec 'soname "libsodium.so.23.3.0"
             'setup (lambda (root prefix)
                      (checked "ln" (list "ln" "-s" "libsodium.so.23.3.0" (lib-path prefix floor-so)))
                      0))
  (lambda (root prefix) (floor-passes prefix)))

(check-row "no library file is refused, naming its path"
  (spec-with floor-spec 'lib 'none)
  (lambda (root prefix) (no-library prefix floor-so)))

(check-row "no header file is refused, naming its path"
  (spec-with floor-spec 'header 'none)
  (lambda (root prefix)
    (refused "no header at " (header-path prefix) ": it is not a regular file")))

;; --- check-sodium.sh: the override --------------------------------------------------------------

(check-row "CHEZ_SODIUM_LIBRARY unset is refused"
  (spec-with floor-spec 'env (env-with "CHEZ_SODIUM_LIBRARY" #f (lane-env floor-so)))
  (lambda (root prefix) (override-unset prefix floor-so)))

(check-row "CHEZ_SODIUM_LIBRARY set but empty is refused"
  (spec-with floor-spec 'env (env-with "CHEZ_SODIUM_LIBRARY" (lambda (root prefix) "") (lane-env floor-so)))
  (lambda (root prefix) (override-is prefix floor-so "")))

(check-row "CHEZ_SODIUM_LIBRARY relative, lib/libsodium.so.23, is refused"
  (spec-with floor-spec 'env (env-with "CHEZ_SODIUM_LIBRARY" (lambda (root prefix) "lib/libsodium.so.23")
                                       (lane-env floor-so)))
  (lambda (root prefix) (override-is prefix floor-so "lib/libsodium.so.23")))

(check-row "CHEZ_SODIUM_LIBRARY naming a copy of the same library elsewhere is refused"
  (spec-with floor-spec
             'setup (lambda (root prefix)
                      (checked "mkdir" (list "mkdir" "-p" (string-append root "/elsewhere")))
                      (checked "cp" (list "cp" (lib-path prefix floor-so)
                                          (string-append root "/elsewhere/" floor-so)))
                      0)
             'env (env-with "CHEZ_SODIUM_LIBRARY"
                            (lambda (root prefix) (string-append root "/elsewhere/" floor-so))
                            (lane-env floor-so)))
  (lambda (root prefix) (override-is prefix floor-so (string-append root "/elsewhere/" floor-so))))

(check-row "CHEZ_SODIUM_LIBRARY naming the bare libsodium.so link is refused"
  (spec-with floor-spec
             'setup (lambda (root prefix)
                      (checked "ln" (list "ln" "-s" floor-so (string-append prefix "/lib/libsodium.so")))
                      0)
             'env (env-with "CHEZ_SODIUM_LIBRARY" (lambda (root prefix) (string-append prefix "/lib/libsodium.so"))
                            (lane-env floor-so)))
  (lambda (root prefix) (override-is prefix floor-so (string-append prefix "/lib/libsodium.so"))))

;; --- check-sodium.sh: the header the compiler finds -------------------------------------------

;; another-header : Header -> (String String -> 0)
;; A setup that makes ROOT/other/sodium.h, defining HEADER.
(define (another-header header)
  (lambda (root prefix)
    (write-file-in root "other/sodium.h" (header-text header))
    0))

(check-row "C_INCLUDE_PATH naming another sodium.h first, PREFIX/include second, is refused, naming the one found"
  (spec-with floor-spec
             'setup (another-header floor-header)
             'env (env-with "C_INCLUDE_PATH"
                            (lambda (root prefix)
                              (string-append root "/other:" (cip-after (string-append prefix "/include"))))
                            (lane-env floor-so)))
  (lambda (root prefix) (header-elsewhere prefix (string-append root "/other/sodium.h"))))

(check-row "C_INCLUDE_PATH without PREFIX/include, so the compiler finds another sodium.h, is refused"
  (spec-with floor-spec
             'setup (another-header floor-header)
             'env (env-with "C_INCLUDE_PATH" (lambda (root prefix) (cip-after (string-append root "/other")))
                            (lane-env floor-so)))
  (lambda (root prefix) (header-elsewhere prefix (string-append root "/other/sodium.h"))))

(check-row "a compiler that lists no sodium.h is refused"
  (spec-with floor-spec
             'env (lambda (root prefix)
                    (cons (string-append "CC=" (stand-in-cc root "find.o: find.c\n" 0 ""))
                          (filter (lambda (w) (not (string-prefix? "CC=" w))) ((lane-env floor-so) root prefix)))))
  (lambda (root prefix)
    (refused (string-append root "/cc-stand-in") " lists no sodium.h among the files #include <sodium.h> reads")))

(check-row "a compiler that fails is refused with its own words, whole"
  (spec-with floor-spec
             'env (lambda (root prefix)
                    (cons (string-append "CC=" (stand-in-cc root #f 1 "cc: the compiler's own words")
                                         )
                          (filter (lambda (w) (not (string-prefix? "CC=" w))) ((lane-env floor-so) root prefix)))))
  (lambda (root prefix)
    (list 1 ""
          (string-append "check-sodium.sh: " root "/cc-stand-in could not preprocess a file that includes <sodium.h>:\n"
                         "cc: the compiler's own words\n"))))

;; --- check-sodium.sh: the header's identity -------------------------------------------------

(define (floor-with-header header)
  (spec-with floor-spec 'header header))

(check-row "a header whose SODIUM_VERSION_STRING is 8.1.3 is refused"
  (floor-with-header (list (q "8.1.3") "10" "3"))
  (lambda (root prefix) (header-version-refused prefix (q "8.1.3") floor-what floor-version)))

(check-row "a header whose version is the floor's with a digit after it is refused"
  (floor-with-header (list (q "8.1.23") "10" "3"))
  (lambda (root prefix) (header-version-refused prefix (q "8.1.23") floor-what floor-version)))

(check-row "a header and a library both 8.1.3, agreeing with each other and not the floor, are refused at the header"
  (spec-with floor-spec 'lib (list "8.1.3" 10 3 0) 'header (list (q "8.1.3") "10" "3"))
  (lambda (root prefix) (header-version-refused prefix (q "8.1.3") floor-what floor-version)))

(check-row "a header that does not define SODIUM_VERSION_STRING is refused"
  (floor-with-header (list #f "10" "3"))
  (lambda (root prefix) (header-version-refused prefix "" floor-what floor-version)))

(check-row "a header without SODIUM_LIBRARY_VERSION_MAJOR is refused"
  (floor-with-header (list (q floor-version) #f "3"))
  (lambda (root prefix) (header-naturals prefix "" "3")))

(check-row "a header without SODIUM_LIBRARY_VERSION_MINOR is refused"
  (floor-with-header (list (q floor-version) "10" #f))
  (lambda (root prefix) (header-naturals prefix "10" "")))

(check-row "a header whose major is not a natural is refused"
  (floor-with-header (list (q floor-version) "x" "3"))
  (lambda (root prefix) (header-naturals prefix "x" "3")))

;; --- check-sodium.sh: the library's identity -----------------------------------------------------

(define (floor-with-lib lib) (spec-with floor-spec 'lib lib))

(check-row "a library answering 8.1.3 is refused"
  (floor-with-lib (list "8.1.3" 10 3 0))
  (lambda (root prefix) (library-version-refused prefix floor-so "8.1.3" floor-what floor-version)))

(check-row "a library answering the floor with a digit after it is refused"
  (floor-with-lib (list "8.1.23" 10 3 0))
  (lambda (root prefix) (library-version-refused prefix floor-so "8.1.23" floor-what floor-version)))

(check-row "a library answering NULL for its version is refused"
  (floor-with-lib (list #f 10 3 0))
  (lambda (root prefix) (library-version-refused prefix floor-so "#f" floor-what floor-version)))

(check-row "a library answering an empty version is refused"
  (floor-with-lib (list "" 10 3 0))
  (lambda (root prefix) (library-version-refused prefix floor-so "" floor-what floor-version)))

(check-row "a library whose major differs from the header's is refused"
  (floor-with-lib (list floor-version 11 3 0))
  (lambda (root prefix) (library-numbers-refused prefix floor-so "11" "3" "10" "3")))

(check-row "a library whose minor differs from the header's is refused"
  (floor-with-lib (list floor-version 10 4 0))
  (lambda (root prefix) (library-numbers-refused prefix floor-so "10" "4" "10" "3")))

(check-row "a library whose major and minor both differ is refused"
  (floor-with-lib (list floor-version 11 4 0))
  (lambda (root prefix) (library-numbers-refused prefix floor-so "11" "4" "10" "3")))

(check-row "a library whose major is right and minor wrong, in a header of 9 and 7, is refused"
  (spec-with floor-spec 'lib (list floor-version 9 8 0) 'header (list (q floor-version) "9" "7"))
  (lambda (root prefix) (library-numbers-refused prefix floor-so "9" "8" "9" "7")))

(check-row "a minimal build, answering 1 to sodium_library_minimal, is refused though all else is right"
  (floor-with-lib (list floor-version 10 3 1))
  (lambda (root prefix) (minimal-refused prefix floor-so "1")))

(check-row "a library answering 2 to sodium_library_minimal is refused"
  (floor-with-lib (list floor-version 10 3 2))
  (lambda (root prefix) (minimal-refused prefix floor-so "2")))

;; --- check-sodium.sh: the probe ---------------------------------------------------------------

(check-row "a library file that is no shared object is refused with the probe's own words naming it"
  (spec-with floor-spec
             'lib 'none
             'setup (lambda (root prefix)
                      (write-file-in prefix "lib/libsodium.so.23" "not a library\n")
                      (write-file-in prefix "include/sodium.h" (header-text floor-header))
                      0))
  (lambda (root prefix)
    (let ((lib (lib-path prefix floor-so)))
      (list 1 ""
            (string-append "check-sodium.sh: " chez " could not read " lib ":\n"
                           "Exception: (while loading " lib ") " lib
                           ": file too short\n")))))

(check-row "a CHEZ that fails is refused with its own words, whole"
  (spec-with floor-spec
             'env (env-with "CHEZ" (lambda (root prefix)
                                     (let ((path (string-append root "/failing-chez")))
                                       (write-file path "#!/bin/sh\necho boom >&2\nexit 3\n")
                                       (checked "chmod" (list "chmod" "755" path))
                                       path))
                            (lane-env floor-so)))
  (lambda (root prefix)
    (list 1 ""
          (string-append "check-sodium.sh: " root "/failing-chez could not read " (lib-path prefix floor-so)
                         ":\nboom\n"))))

;; The probe is run as Chez's own script, with no library path and no program:
;; a stand-in CHEZ logs its arguments, then runs the real Chez.
(check-row "the probe is Chez's own script on the library: the arguments are -q, --script, the script and the library"
  (spec-with floor-spec
             'env (env-with "CHEZ" (lambda (root prefix)
                                     (let ((path (string-append root "/logging-chez")))
                                       (write-file path
                                         (string-append "#!/bin/sh\nprintf '%s\\n' \"$*\" >" root "/chez-calls\nexec "
                                                        (shell-word chez) " \"$@\"\n"))
                                       (checked "chmod" (list "chmod" "755" path))
                                       path))
                            (lane-env floor-so)))
  (lambda (root prefix)
    (let* ((calls (text-lines (text-or-empty (string-append root "/chez-calls"))))
           (words (if (= (length calls) 1) (split-spaces (car calls)) '())))
      (if (and (= (length words) 4)
               (equal? (list (car words) (cadr words)) '("-q" "--script"))
               (string-suffix? "/read.ss" (caddr words))
               (string=? (cadddr words) (lib-path prefix floor-so)))
          (floor-passes prefix)
          (list 'chez-calls calls)))))

;; --- check-sodium.sh: the floor and --current ---------------------------------------------------

(check-row "a malformed floor is refused, with floor.sh's line and then the script's"
  (spec-with floor-spec 'floors (floors-text "8.1"))
  (lambda (root prefix)
    (floor-sh-refused "the sodium version \"8.1\" is not three dot-separated naturals, major.minor.patch")))

(check-row "no floors file, without --current, is refused"
  (spec-with floor-spec 'floors #f)
  (lambda (root prefix) (floor-sh-refused "it cannot be read")))

(check-row "--current: the floor's library and header are refused, at the library, which is looked for first"
  (spec-with current-spec 'lib floor-lib 'header floor-header 'soname floor-so)
  (lambda (root prefix) (no-library prefix current-so)))

(check-row "--current: the floor's header with the current library is refused, at the header"
  (spec-with current-spec 'header floor-header)
  (lambda (root prefix) (header-version-refused prefix (q floor-version) current-what current-version)))

(check-row "--current: the pinned release's header with a library one digit off is refused, at the library"
  (spec-with current-spec 'lib (list "1.0.23" 26 4 0))
  (lambda (root prefix) (library-version-refused prefix current-so "1.0.23" current-what current-version)))

(check-row "--current: current_version and version set to the floor's in the env, with the floor's library, are still refused"
  (spec-with current-spec
             'lib floor-lib 'header floor-header
             'env (lambda (root prefix)
                    (append ((lane-env current-so) root prefix)
                            (list (string-append "current_version=" floor-version)
                                  (string-append "version=" floor-version)))))
  (lambda (root prefix) (header-version-refused prefix (q floor-version) current-what current-version)))

;; --- check-sodium.sh: usage --------------------------------------------------------------

(define (usage-row name args)
  (check-row name (spec-with floor-spec 'args args) (lambda (root prefix) (usage-answer))))

(usage-row "no prefix is a usage error" (lambda (root prefix) '()))
(usage-row "two prefixes are a usage error" (lambda (root prefix) (list prefix prefix)))
(usage-row "--nothreads, check-chez.sh's flag, is a usage error" (lambda (root prefix) (list prefix "--nothreads")))
(usage-row "--no-load, a flag libsodium has no use for, is a usage error" (lambda (root prefix) (list prefix "--no-load")))
(usage-row "--discovery given a prefix is a usage error" (lambda (root prefix) (list "--discovery" prefix)))
(usage-row "a prefix then --discovery is a usage error" (lambda (root prefix) (list prefix "--discovery")))
(usage-row "three arguments are a usage error" (lambda (root prefix) (list prefix "--current" "--current")))
(usage-row "--current alone is a usage error" (lambda (root prefix) (list "--current")))
(usage-row "--current --current is a usage error" (lambda (root prefix) (list "--current" "--current")))

(check-row "a relative prefix is refused, naming it"
  (spec-with floor-spec 'args (lambda (root prefix) (list "lib")))
  (lambda (root prefix) (list 2 "" "check-sodium.sh: PREFIX must be an absolute path, not 'lib'\n")))

;; --- check-sodium.sh --discovery -------------------------------------------------------------
;;
;; Each row's tree holds shim/chez and shim/cc, which print the files of the
;; same names the row writes and log their calls; the script is handed them
;; by their paths, in CHEZ and CC, with TMPDIR in the tree.

(define system-path "/usr/lib/x86_64-linux-gnu/libsodium.so.23")
(define system-header "/usr/include/sodium.h")

;; report : String String String String String -> String
;; The four lines make build prints when it accepts a library.
(define (report path-and-source version major minor counts)
  (text-of (list "chez-sodium: libsodium loaded and accepted"
                 (string-append "  path:       " path-and-source)
                 (string-append "  version:    " version " (library " major "." minor ")")
                 (string-append "  counts:     " counts))))

(define good-report (report (string-append system-path " (system)") floor-version "10" "3" "((block . 0))"))

(define good-find
  (string-append "find.o: find.c \\\n /usr/include/stdc-predef.h \\\n " system-header
                 " \\\n /usr/include/sodium/version.h\n"))

(define (macros-text header) (header-text header))

(define disc-base
  (list (cons 'floors (floors-text floor-version))
        (cons 'out good-report)
        (cons 'err "")
        (cons 'status 0)
        (cons 'find good-find)
        (cons 'macros (macros-text floor-header))
        (cons 'cc-status 0)
        (cons 'cc-err "")
        (cons 'override #f)))

(define (disc-shim root name)
  (string-append
   "#!/bin/sh\n"
   "root=" (shell-word root) "\n"
   "{ printf '%s' \"${0##*/}\"; for a in \"$@\"; do printf ' %s' \"$a\"; done; printf '\\n'; } >>\"$root/calls\"\n"
   (if (string=? name "chez")
       (string-append "cat \"$root/report-err\" >&2\n"
                      "cat \"$root/report-out\"\n"
                      "exit \"$(cat \"$root/report-status\")\"\n")
       (string-append "if [ \"$(cat \"$root/cc-status\")\" != 0 ]; then\n"
                      "  cat \"$root/cc-err\" >&2\n"
                      "  exit \"$(cat \"$root/cc-status\")\"\n"
                      "fi\n"
                      "case \" $* \" in\n"
                      "  *\" -dM \"*) cat \"$root/macros\" ;;\n"
                      "  *) cat \"$root/find.d\" ;;\n"
                      "esac\n"))))

;; normalized : String String -> (List String Natural)
;; TEXT with ROOT/tmp/check-sodium.XXXXXX written CWORK, and how many.
(define (normalized root text)
  (work-written text (string-append root "/tmp/check-sodium.") "CWORK"))

;; disc-row : String Settings (String -> Expected) -> Unit
;; Expected is (list STATUS STDOUT STDERR CALLS), CALLS the lines the two
;; stand-ins logged, with ROOT written as ROOT and the work directory CWORK.
(define (disc-row name changes expected-of)
  (let ((spec (append changes disc-base)))
    (test-equal (string-append "check-sodium.sh --discovery: " name)
      '(returned same)
      (outcome
       (lambda ()
         (with-tree (spec-ref spec 'floors)
           (lambda (root)
             (checked "mkdir" (list "mkdir" (string-append root "/shim") (string-append root "/tmp")))
             (for-each (lambda (n)
                         (let ((path (string-append root "/shim/" n)))
                           (write-file path (disc-shim root n))
                           (checked "chmod" (list "chmod" "755" path))))
                       '("chez" "cc"))
             (write-file (string-append root "/report-out") (spec-ref spec 'out))
             (write-file (string-append root "/report-err") (spec-ref spec 'err))
             (write-file (string-append root "/report-status") (number->string (spec-ref spec 'status)))
             (write-file (string-append root "/find.d") (spec-ref spec 'find))
             (write-file (string-append root "/macros") (spec-ref spec 'macros))
             (write-file (string-append root "/cc-status") (number->string (spec-ref spec 'cc-status)))
             (write-file (string-append root "/cc-err") (spec-ref spec 'cc-err))
             (let* ((override (spec-ref spec 'override))
                    (ran (capture-command
                          (append (list "env")
                                  (env-order (append (if override
                                                         (list (string-append "CHEZ_SODIUM_LIBRARY=" override))
                                                         (list "-u" "CHEZ_SODIUM_LIBRARY"))
                                                     (list "-u" "CPATH"
                                                           (string-append "TMPDIR=" root "/tmp")
                                                           (string-append "CC=" root "/shim/cc")
                                                           (string-append "CHEZ=" root "/shim/chez"))))
                                  (list "sh" (string-append root "/scripts/ci/check-sodium.sh") "--discovery"))))
                    (calls (normalized root (text-or-empty (string-append root "/calls"))))
                    (left (directory-list (string-append root "/tmp")))
                    (got (list (car ran) (cadr ran) (caddr ran) (car calls) left))
                    (want (expected-of root)))
               (if (equal? got want) 'same (list 'got got 'want want))))))))))

;; disc-answer : Integer String String (Listof String) -> (List ...)
;; With tmp/ left empty: the work directory removed.
(define (disc-answer status stdout stderr calls)
  (list status stdout stderr (text-of calls) '()))

(define (preflight-call root)
  (string-append "chez --libdirs " root "/src --program " root "/tests/preflight.sps"))

(define cc-calls (list "cc -E -M CWORK/find.c" "cc -dM -E CWORK/find.c"))

(define (cc-m-calls root) (list (preflight-call root) "cc -E -M CWORK/find.c"))

(define (disc-refused root calls . words)
  (disc-answer 1 "" (string-append "check-sodium.sh: " (apply string-append words) "\n") calls))

(define (disc-passes root version major minor)
  (disc-answer 0
               (string-append "check-sodium.sh: make build loaded " system-path
                              " (system), libsodium " version " (library " major "." minor
                              "), " floor-what "\n"
                              "check-sodium.sh: " root "/shim/cc finds <sodium.h> at " system-header
                              ", which declares the same release, and CHEZ_SODIUM_LIBRARY is unset\n")
               ""
               (cons (preflight-call root) cc-calls)))

(define (disc-with-report r) (list (cons 'out r)))

(define (report-refused root calls read)
  (disc-answer 1 ""
               (string-append
                "check-sodium.sh: make build's report is not, line for line, these three lines and then a counts line whose every count is 0:\n"
                "  expected: chez-sodium: libsodium loaded and accepted\n"
                "  expected:   path:       " system-path " (system)\n"
                "  expected:   version:    " floor-version " (library 10.3)\n"
                "  expected: (counts line: a list of (kind . 0))\n"
                (apply string-append (map (lambda (l) (string-append "  read:     " l "\n")) read)))
               calls))

(define (full-calls root) (cons (preflight-call root) cc-calls))

(disc-row "the floor's report and header pass, with the one preflight call and the two compiler calls, whole"
  '()
  (lambda (root) (disc-passes root floor-version "10" "3")))

(disc-row "a floor of 9.0.1 and a report and header of it pass: the floor is read, not written in the script"
  (list (cons 'floors (floors-text "9.0.1"))
        (cons 'out (report (string-append system-path " (system)") "9.0.1" "10" "3" "((block . 0))"))
        (cons 'macros (macros-text (list (q "9.0.1") "10" "3"))))
  (lambda (root)
    (disc-answer 0
                 (string-append "check-sodium.sh: make build loaded " system-path
                                " (system), libsodium 9.0.1 (library 10.3), " floor-what "\n"
                                "check-sodium.sh: " root "/shim/cc finds <sodium.h> at " system-header
                                ", which declares the same release, and CHEZ_SODIUM_LIBRARY is unset\n")
                 "" (full-calls root))))

(disc-row "major and minor are the header's: a report and header of 9.7 pass"
  (list (cons 'out (report (string-append system-path " (system)") floor-version "9" "7" "((block . 0))"))
        (cons 'macros (macros-text (list (q floor-version) "9" "7"))))
  (lambda (root) (disc-passes root floor-version "9" "7")))

(disc-row "a malformed floors file is refused with floor.sh's line, then the script's, and nothing runs"
  (list (cons 'floors (floors-text "8.1")))
  (lambda (root)
    (disc-answer 1 ""
                 (string-append "floor.sh: packaging/floors.sexp: the sodium version \"8.1\" is not three dot-separated naturals, major.minor.patch\n"
                                "check-sodium.sh: no libsodium floor to check against\n")
                 '())))

;; An override is refused before anything runs.
(define (override-refused root)
  (disc-answer 1 ""
               "check-sodium.sh: CHEZ_SODIUM_LIBRARY is set, but this job loads libsodium by discovery, and must load the system's\n"
               '()))

(disc-row "CHEZ_SODIUM_LIBRARY set to a library is refused, and no program ran"
  (list (cons 'override "/opt/libsodium.so.23"))
  override-refused)

(disc-row "CHEZ_SODIUM_LIBRARY set to the system's own path is refused"
  (list (cons 'override system-path))
  override-refused)

(disc-row "CHEZ_SODIUM_LIBRARY set but empty is refused"
  (list (cons 'override ""))
  override-refused)

(disc-row "a preflight that refuses, though its stdout is the accepted report, is refused, showing its stderr"
  (list (cons 'status 1) (cons 'err "chez-sodium: libsodium refused\n(reason . not-found)\n"))
  (lambda (root)
    (disc-answer 1 ""
                 (string-append "check-sodium.sh: make build's program, " root "/shim/chez --libdirs " root
                                "/src --program " root "/tests/preflight.sps, refused or failed; its stderr:\n"
                                "chez-sodium: libsodium refused\n(reason . not-found)\n")
                 (list (preflight-call root)))))

(disc-row "a preflight that exits 0 and writes to stderr is refused"
  (list (cons 'err "a warning\n"))
  (lambda (root)
    (disc-answer 1 ""
                 "check-sodium.sh: make build's program wrote to stderr, though it exited 0:\na warning\n"
                 (list (preflight-call root)))))

(define (path-row name path-and-source)
  (disc-row name
    (list (cons 'out (report path-and-source floor-version "10" "3" "((block . 0))")))
    (lambda (root)
      (report-refused root (full-calls root)
                      (list "chez-sodium: libsodium loaded and accepted"
                            (string-append "  path:       " path-and-source)
                            (string-append "  version:    " floor-version " (library 10.3)")
                            "  counts:     ((block . 0))")))))

(path-row "another path, /usr/local/lib's, is refused" "/usr/local/lib/libsodium.so.23 (system)")
(path-row "the newer soname's path is refused" "/usr/lib/x86_64-linux-gnu/libsodium.so.26 (system)")
(path-row "the right path from another source is refused" (string-append system-path " (override)"))
(path-row "a path of /usr/lib is refused" "/usr/lib/libsodium.so.23 (system)")

(define (version-row name version major minor)
  (disc-row name
    (list (cons 'out (report (string-append system-path " (system)") version major minor "((block . 0))")))
    (lambda (root)
      (report-refused root (full-calls root)
                      (list "chez-sodium: libsodium loaded and accepted"
                            (string-append "  path:       " system-path " (system)")
                            (string-append "  version:    " version " (library " major "." minor ")")
                            "  counts:     ((block . 0))")))))

(version-row "another version, 8.1.3, is refused" "8.1.3" "10" "3")
(version-row "the floor with a digit after it is refused" "8.1.23" "10" "3")
(version-row "another minor, 10.4 against the header's 10.3, is refused" floor-version "10" "4")
(version-row "another major, 11.3 against the header's 10.3, is refused" floor-version "11" "3")

(disc-row "a report of 8.1.3 against a header of 8.1.3 and a floor of 8.1.2 is refused, at the header"
  (list (cons 'out (report (string-append system-path " (system)") "8.1.3" "10" "3" "((block . 0))"))
        (cons 'macros (macros-text (list (q "8.1.3") "10" "3"))))
  (lambda (root)
    (disc-refused root (full-calls root)
                  system-header " defines SODIUM_VERSION_STRING " (q "8.1.3") ", but " floor-what " is " (q floor-version))))

(disc-row "a header of 8.1.3 with a report of the floor is refused, at the header"
  (list (cons 'macros (macros-text (list (q "8.1.3") "10" "3"))))
  (lambda (root)
    (disc-refused root (full-calls root)
                  system-header " defines SODIUM_VERSION_STRING " (q "8.1.3") ", but " floor-what " is " (q floor-version))))

(disc-row "a header of the floor with a digit after it is refused"
  (list (cons 'macros (macros-text (list (q "8.1.23") "10" "3"))))
  (lambda (root)
    (disc-refused root (full-calls root)
                  system-header " defines SODIUM_VERSION_STRING " (q "8.1.23") ", but " floor-what " is " (q floor-version))))

(disc-row "a compiler that finds /usr/local/include/sodium.h is refused"
  (list (cons 'find "find.o: find.c \\\n /usr/local/include/sodium.h\n"))
  (lambda (root)
    (disc-refused root (cc-m-calls root)
                  root "/shim/cc finds <sodium.h> at /usr/local/include/sodium.h, not " system-header
                  ": the system's header must be the one found, so that the suites compile against it")))

(disc-row "a compiler that lists no sodium.h is refused"
  (list (cons 'find "find.o: find.c\n"))
  (lambda (root)
    (disc-refused root (cc-m-calls root)
                  root "/shim/cc lists no sodium.h among the files #include <sodium.h> reads")))

(disc-row "a compiler that fails is refused with its words"
  (list (cons 'cc-status 1) (cons 'cc-err "the compiler's words\n"))
  (lambda (root)
    (disc-answer 1 ""
                 (string-append "check-sodium.sh: " root "/shim/cc could not preprocess a file that includes <sodium.h>:\n"
                                "the compiler's words\n")
                 (list (preflight-call root) "cc -E -M CWORK/find.c"))))

(define (bad-report-row name out)
  (disc-row name (list (cons 'out out))
    (lambda (root) (report-refused root (full-calls root) (text-lines out)))))

(bad-report-row "a report with an extra line is refused" (string-append good-report "extra\n"))
(bad-report-row "a report with the counts line missing is refused"
  (text-of (list "chez-sodium: libsodium loaded and accepted"
                 (string-append "  path:       " system-path " (system)")
                 (string-append "  version:    " floor-version " (library 10.3)"))))
(bad-report-row "a report with a blank line first is refused" (string-append "\n" good-report))
(bad-report-row "a refusal's first line, with the rest, is refused"
  (text-of (list "chez-sodium: libsodium refused"
                 (string-append "  path:       " system-path " (system)")
                 (string-append "  version:    " floor-version " (library 10.3)")
                 "  counts:     ((block . 0))")))
(bad-report-row "a counts line of a nonzero count is refused"
  (report (string-append system-path " (system)") floor-version "10" "3" "((block . 3))"))
(bad-report-row "a counts line of an empty list is refused"
  (report (string-append system-path " (system)") floor-version "10" "3" "()"))
(bad-report-row "a counts line with an unclosed list is refused"
  (report (string-append system-path " (system)") floor-version "10" "3" "((block . 0)"))
(bad-report-row "a counts line with one nonzero count among zeros is refused"
  (report (string-append system-path " (system)") floor-version "10" "3" "((block . 0) (other . 2))"))

(disc-row "a counts line of several kinds, each 0, passes"
  (list (cons 'out (report (string-append system-path " (system)") floor-version "10" "3"
                           "((block . 0) (other . 0))")))
  (lambda (root) (disc-passes root floor-version "10" "3")))

;; The preflight command line is make build's: this row reads the Makefile as
;; data, and expects the script's call to be the recipe's words, with the
;; paths made absolute at the tree's root.
(define makefile-build-words
  (guard (e (#t (list 'raised (describe e))))
    (let loop ((lines (text-lines (text-or-empty "Makefile"))) (seen #f))
      (cond ((null? lines) 'no-recipe)
            ((and seen (string-prefix? "\t@$(CHEZ) " (car lines)))
             (let words ((chars (string->list (substring (car lines) 10 (string-length (car lines)))))
                         (word '()) (found '()))
               (cond ((null? chars)
                      (reverse (if (null? word) found (cons (list->string (reverse word)) found))))
                     ((char=? (car chars) #\space)
                      (words (cdr chars) '() (if (null? word) found (cons (list->string (reverse word)) found))))
                     (else (words (cdr chars) (cons (car chars) word) found)))))
            ((string-prefix? "build:" (car lines)) (loop (cdr lines) #t))
            (else (loop (cdr lines) seen))))))

(disc-row "the preflight call is make build's recipe, its paths made absolute"
  '()
  (lambda (root)
    (disc-answer 0
                 (cadr (disc-passes root floor-version "10" "3"))
                 ""
                 (cons (if (list? makefile-build-words)
                           (string-append
                            "chez"
                            (apply string-append
                                   (map (lambda (w)
                                          (string-append " " (if (member w '("src" "tests/preflight.sps"))
                                                                 (string-append root "/" w)
                                                                 w)))
                                        makefile-build-words)))
                           "no recipe")
                       cc-calls))))

;; --- build-sodium.sh: the tree -------------------------------------------------------------
;;
;; Besides scripts/ci and the floors file, each row's tree holds:
;;   shim/    curl, sha256sum, tar, make and cc, POSIX sh scripts. Each appends
;;            its name and arguments to ROOT/calls, one line a call. curl
;;            names its URL on stderr, then writes ROOT/served to its -o file
;;            when ROOT/serves lists the URL, and exits 22, as -f does for a
;;            404, when it does not. sha256sum answers FILE's digest from
;;            ROOT/digests, by FILE's name. tar makes the directory the
;;            archive's name gives, holding a configure, a copy of
;;            ROOT/configure-shim, unless ROOT/no-configure exists. configure
;;            logs its CC, any CFLAGS, CPPFLAGS and LDFLAGS and its directory,
;;            and writes the prefix it was given. make logs its directory and
;;            installs ROOT/stub-lib and ROOT/header under that prefix when
;;            told to install. The files of the names configure-fails,
;;            make-fails, install-fails and no-pthread make each of them fail
;;            or leave out what it should write. cc logs its own call and the
;;            two names a check reads from its environment, then runs the
;;            real compiler when ROOT/realcc names one;
;;   tools/   a link to each other tool the scripts and the shims run, and
;;            nothing else: PATH is shim/ and tools/;
;;   tmp/     TMPDIR, where each script makes its work directory, so a row
;;            sees it removed.

(define sh-path
  (guard (e (#t #f))
    (let ((found (capture-command (list "sh" "-c" "command -v sh"))))
      (and (eqv? (car found) 0) (first-line (cadr found))))))

(test-equal "sh is a file on this PATH, which the build rows run and link"
  'found
  (if (and (string? sh-path) (string-prefix? "/" sh-path)) 'found sh-path))

(define real-cc
  (guard (e (#t #f))
    (let ((found (capture-command (list "sh" "-c" "command -v \"$0\"" cc))))
      (and (eqv? (car found) 0) (first-line (cadr found))))))

(test-equal "CC is a file on this PATH, which the build rows that pass run as their compiler"
  'found
  (if (and (string? real-cc) (string-prefix? "/" real-cc)) 'found real-cc))

(define real-chez
  (guard (e (#t #f))
    (let ((found (capture-command (list "sh" "-c" "command -v \"$0\"" chez))))
      (and (eqv? (car found) 0) (first-line (cadr found))))))

(test-equal "CHEZ is a file on this PATH, which the build rows run check-sodium.sh's probe with"
  'found
  (if (and (string? real-chez) (string-prefix? "/" real-chez)) 'found real-chez))

(define row-tools
  '("sh" "dirname" "sed" "tr" "grep" "awk" "mktemp" "rm" "mkdir" "cp" "cat" "cmp" "head" "tail"))

(define log-call
  "{ printf '%s' \"${0##*/}\"; for a in \"$@\"; do printf ' %s' \"$a\"; done; printf '\\n'; } >>\"$root/calls\"\n")

(define (shim-text root name)
  (string-append
   "#!/bin/sh\n"
   "root=" (shell-word root) "\n"
   (cond
     ((string=? name "curl")
      (string-append
       log-call
       "out=\n"
       "url=\n"
       "while [ \"$#\" -gt 0 ]; do\n"
       "  case $1 in\n"
       "    -o) out=$2; shift 2 ;;\n"
       "    -*) shift ;;\n"
       "    *) url=$1; shift ;;\n"
       "  esac\n"
       "done\n"
       "echo \"curl: $url\" >&2\n"
       "grep -q -x -F -- \"$url\" \"$root/serves\" || exit 22\n"
       "cp \"$root/served\" \"$out\"\n"))
     ((string=? name "sha256sum")
      (string-append
       log-call
       "if [ \"$#\" -ne 1 ]; then\n"
       "  echo \"sha256sum shim: not FILE: $*\" >&2\n"
       "  exit 64\n"
       "fi\n"
       "[ -f \"$1\" ] || { echo \"sha256sum shim: no file $1\" >&2; exit 1; }\n"
       "digest=$(awk -v name=\"${1##*/}\" '$1 == name { print $2 }' \"$root/digests\")\n"
       "[ -n \"$digest\" ] || { echo \"sha256sum shim: no digest for ${1##*/}\" >&2; exit 1; }\n"
       "printf '%s  %s\\n' \"$digest\" \"$1\"\n"))
     ((string=? name "tar")
      (string-append
       log-call
       "if [ \"$#\" -ne 4 ] || [ \"$1\" != xzf ] || [ \"$3\" != -C ]; then\n"
       "  echo \"tar shim: not xzf ARCHIVE -C DIR: $*\" >&2\n"
       "  exit 64\n"
       "fi\n"
       "[ -f \"$2\" ] || { echo \"tar shim: no archive $2\" >&2; exit 2; }\n"
       "[ ! -f \"$root/tar-fails\" ] || { echo \"tar: the shim fails\" >&2; exit 2; }\n"
       "base=${2##*/}\n"
       "base=${base%.tar.gz}\n"
       "mkdir -p \"$4/$base\"\n"
       "[ -f \"$root/no-configure\" ] || cp \"$root/configure-shim\" \"$4/$base/configure\"\n"))
     ((string=? name "make")
      (string-append
       "{ printf '%s' \"${0##*/}\"; for a in \"$@\"; do printf ' %s' \"$a\"; done; printf ' [cwd=%s]\\n' \"$PWD\"; } >>\"$root/calls\"\n"
       "[ -f .prefix ] || { echo \"make: *** No targets specified and no makefile found.  Stop.\" >&2; exit 2; }\n"
       "case \"$*\" in\n"
       "  '') [ ! -f \"$root/make-fails\" ] || { echo \"make: *** [all] Error 1\" >&2; exit 2; } ;;\n"
       "  install)\n"
       "    [ ! -f \"$root/install-fails\" ] || { echo \"make: *** [install] Error 1\" >&2; exit 2; }\n"
       "    prefix=$(cat .prefix)\n"
       "    mkdir -p \"$prefix/lib\" \"$prefix/include\"\n"
       "    if [ -f \"$root/stub-lib\" ]; then\n"
       "      cp \"$root/stub-lib\" \"$prefix/lib/$(cat \"$root/soname\")\"\n"
       "      cp \"$root/header\" \"$prefix/include/sodium.h\"\n"
       "    fi ;;\n"
       "esac\n"))
     ((string=? name "configure")
      (string-append
       "{ printf 'configure'\n"
       "  [ -z \"${CC+set}\" ] || printf ' [CC=%s]' \"$CC\"\n"
       "  [ -z \"${CFLAGS+set}\" ] || printf ' [CFLAGS=%s]' \"$CFLAGS\"\n"
       "  [ -z \"${CPPFLAGS+set}\" ] || printf ' [CPPFLAGS=%s]' \"$CPPFLAGS\"\n"
       "  [ -z \"${LDFLAGS+set}\" ] || printf ' [LDFLAGS=%s]' \"$LDFLAGS\"\n"
       "  for a in \"$@\"; do printf ' %s' \"$a\"; done; printf ' [cwd=%s]\\n' \"$PWD\"; } >>\"$root/calls\"\n"
       "if [ -f \"$root/configure-fails\" ]; then\n"
       "  echo \"configure: error: the shim fails\" >&2\n"
       "  exit 1\n"
       "fi\n"
       "printf '%s\\n' \"${1#--prefix=}\" >.prefix\n"
       "mkdir -p src/libsodium\n"
       "if [ -f \"$root/no-pthread\" ]; then\n"
       "  printf 'DEFS = -DPACKAGE=1\\n' >src/libsodium/Makefile\n"
       "else\n"
       "  printf 'DEFS = -DPACKAGE=1 -DHAVE_PTHREAD=1\\n' >src/libsodium/Makefile\n"
       "fi\n"))
     (else
      (string-append
       "{ printf '%s' \"${0##*/}\"\n"
       "  [ -z \"${C_INCLUDE_PATH+set}\" ] || printf ' [C_INCLUDE_PATH=%s]' \"$C_INCLUDE_PATH\"\n"
       "  [ -z \"${CHEZ_SODIUM_LIBRARY+set}\" ] || printf ' [CHEZ_SODIUM_LIBRARY=%s]' \"$CHEZ_SODIUM_LIBRARY\"\n"
       "  for a in \"$@\"; do printf ' %s' \"$a\"; done; printf '\\n'; } >>\"$root/calls\"\n"
       "if [ -f \"$root/realcc\" ]; then\n"
       "  exec \"$(cat \"$root/realcc\")\" \"$@\"\n"
       "fi\n")))))

;; A Build-Spec is an association list: floors, args and env (as a Spec's,
;; env giving the words added to build-env's), shims (the names shim/ holds),
;; name (the tarball's name), digests (an association list of a file's name
;; and the digest sha256sum answers), serves (the URLs curl serves), flags
;; (the files that make a step fail), and stub and header (#f, or a Lib and a
;; Header: make install then writes that Lib as the soname and the Header as
;; sodium.h, and cc runs the real compiler), and soname.

(define (url-of name) (string-append "https://download.libsodium.org/libsodium/releases/" name))
(define (old-url-of name) (string-append "https://download.libsodium.org/libsodium/releases/old/" name))
(define (tarball version) (string-append "libsodium-" version ".tar.gz"))

(define build-floor-spec
  (list (cons 'floors (floors-text floor-version))
        (cons 'args (lambda (root prefix) (list prefix)))
        (cons 'env (lambda (root prefix) '()))
        (cons 'shims '("curl" "sha256sum" "tar" "make" "cc"))
        (cons 'name (tarball floor-version))
        (cons 'digests (list (cons (tarball floor-version) floor-archive)))
        (cons 'serves (list (url-of (tarball floor-version))))
        (cons 'flags '())
        (cons 'soname floor-so)
        (cons 'stub #f)
        (cons 'header #f)))

(define build-current-spec
  (append (list (cons 'floors #f)
                (cons 'args (lambda (root prefix) (list prefix "--current")))
                (cons 'name (tarball current-version))
                (cons 'digests (list (cons (tarball current-version) current-archive)))
                (cons 'serves (list (url-of (tarball current-version))))
                (cons 'soname current-so))
          build-floor-spec))

;; build-env : String String (Listof String) -> (Listof String)
;; The row's environment: PATH and TMPDIR in the tree, CHEZ this suite's Chez
;; by its path, since PATH no longer finds a bare name, CC, CFLAGS, CPPFLAGS,
;; LDFLAGS and the check's two names unset, and C_INCLUDE_PATH this suite's
;; own, which a Guix compiler needs; then EXTRA.
(define (build-env root prefix extra)
  (append (list "-u" "CHEZ_SODIUM_LIBRARY" "-u" "CPATH" "-u" "CC" "-u" "CFLAGS" "-u" "CPPFLAGS"
                "-u" "LDFLAGS" "-u" "C_INCLUDE_PATH"
                (string-append "PATH=" root "/shim:" root "/tools")
                (string-append "TMPDIR=" root "/tmp")
                (string-append "CHEZ=" (or real-chez chez)))
          (if (set? ambient) (list (string-append "C_INCLUDE_PATH=" ambient)) '())
          extra))

(define (make-build-tree! root spec)
  (let ((shims (spec-ref spec 'shims)))
    (checked "mkdir" (list "mkdir" (string-append root "/shim") (string-append root "/tools")
                           (string-append root "/tmp")))
    (for-each (lambda (name)
                (write-file (string-append root "/shim/" name) (shim-text root name)))
              shims)
    (write-file (string-append root "/configure-shim") (shim-text root "configure"))
    (checked "chmod" (append (list "chmod" "755" (string-append root "/configure-shim"))
                             (map (lambda (name) (string-append root "/shim/" name)) shims)))
    (checked "link the tools"
             (append (list "sh" "-c"
                           "cd \"$0\" && for t in \"$@\"; do p=$(command -v \"$t\") || exit 1; ln -s \"$p\" \"$t\" || exit 1; done"
                           (string-append root "/tools"))
                     row-tools))
    (write-file (string-append root "/digests")
                (apply string-append
                       (map (lambda (entry) (string-append (car entry) " " (cdr entry) "\n"))
                            (spec-ref spec 'digests))))
    (write-file (string-append root "/serves")
                (apply string-append (map (lambda (u) (string-append u "\n")) (spec-ref spec 'serves))))
    (write-file (string-append root "/served") "the archive curl's shim serves\n")
    (write-file (string-append root "/soname") (spec-ref spec 'soname))
    (for-each (lambda (flag) (write-file (string-append root "/" (symbol->string flag)) ""))
              (spec-ref spec 'flags))
    (when (spec-ref spec 'stub)
      (let ((made (make-library! root (string-append root "/stubdir") (spec-ref spec 'soname)
                                 (spec-ref spec 'stub))))
        (unless (eqv? made 0) (error 'make-build-tree! "the stub did not compile" made))
        (checked "cp" (list "cp" (string-append root "/stubdir/" (spec-ref spec 'soname))
                            (string-append root "/stub-lib")))
        (write-file (string-append root "/header") (header-text (spec-ref spec 'header)))
        (write-file (string-append root "/realcc") (or real-cc (error 'make-build-tree! "no real cc")))))))

;; normalized-build : String String -> (List String Natural Natural)
;; TEXT with ROOT/tmp/build-sodium.XXXXXX written WORK and
;; ROOT/tmp/check-sodium.XXXXXX written CWORK, and how many of each.
(define (normalized-build root text)
  (let* ((build (work-written text (string-append root "/tmp/build-sodium.") "WORK"))
         (check (work-written (car build) (string-append root "/tmp/check-sodium.") "CWORK")))
    (list (car check) (cdr build) (cdr check))))

;; prefix-state : String String -> (U 'no-prefix (List Any Any))
(define (prefix-state prefix so)
  (if (file-exists? prefix)
      (list (file-or-none (lib-path prefix so)) (file-or-none (header-path prefix)))
      'no-prefix))

;; A Build-Answer is (list STATUS STDOUT STDERR CALLS WORKS CHECK-WORKS
;; TMP-LEFT PREFIX-STATE).
(define (build-row name spec expected-of)
  (test-equal (string-append "build-sodium.sh: " name)
    '(returned same)
    (outcome
     (lambda ()
       (with-tree (spec-ref spec 'floors)
         (lambda (root)
           (let ((prefix (string-append root "/prefix")))
             (make-build-tree! root spec)
             (let* ((ran (capture-command
                          (append (list "env")
                                  (env-order (build-env root prefix ((spec-ref spec 'env) root prefix)))
                                  (list sh-path (string-append root "/scripts/ci/build-sodium.sh"))
                                  ((spec-ref spec 'args) root prefix))))
                    (calls (normalized-build root (text-or-empty (string-append root "/calls"))))
                    (stderr (normalized-build root (caddr ran)))
                    (stdout (normalized-build root (cadr ran)))
                    (left (directory-list (string-append root "/tmp")))
                    (state (prefix-state prefix (spec-ref spec 'soname)))
                    (got (list (car ran) (car stdout) (car stderr) (car calls) (cadr calls) (caddr calls)
                               left state))
                    (want (expected-of root prefix)))
               (if (equal? got want) 'same (list 'got got 'want want))))))))))

;; --- build-sodium.sh: what it answers and calls, written by hand ---------------------------------

(define (curl-call name url) (string-append "curl --proto =https -fsSL --retry 3 -o WORK/" name " " url))
(define (sha-call name) (string-append "sha256sum WORK/" name))
(define (tar-call name) (string-append "tar xzf WORK/" name " -C WORK"))
(define (dir-of name) (substring name 0 (- (string-length name) 7)))
(define (cfg-call name cc-name prefix)
  (string-append "configure [CC=" cc-name "] --prefix=" prefix " [cwd=WORK/" (dir-of name) "]"))
(define (make-call name) (string-append "make [cwd=WORK/" (dir-of name) "]"))
(define (install-call name) (string-append "make install [cwd=WORK/" (dir-of name) "]"))
(define (check-calls prefix so inc)
  (let ((head (string-append "cc [C_INCLUDE_PATH=" inc "] [CHEZ_SODIUM_LIBRARY=" (lib-path prefix so) "] ")))
    (list (string-append head "-E -M CWORK/find.c") (string-append head "-dM -E CWORK/find.c"))))

(define (list-head l n) (if (or (= n 0) (null? l)) '() (cons (car l) (list-head (cdr l) (- n 1)))))

;; calls-through : (Listof String) String String String String Natural String -> (Listof String)
;; FETCH, then the first N of: the digest, unpack, configure, make, make
;; install and the check's two compiler calls.
(define (calls-through fetch name cc-name prefix so n inc)
  (append fetch
          (list-head (append (list (sha-call name) (tar-call name) (cfg-call name cc-name prefix)
                                   (make-call name) (install-call name))
                             (check-calls prefix so inc))
                     n)))

(define (curl-says url) (string-append "curl: " url "\n"))
(define (default-inc prefix) (cip-after (string-append prefix "/include")))
(define (served-fetch name) (list (curl-call name (url-of name))))

(define (build-answer status stdout stderr calls works check-works state)
  (list status stdout stderr (text-of calls) works check-works '() state))

(define (build-refused . words)
  (string-append "build-sodium.sh: " (apply string-append words) "\n"))

(define (floor-hint)
  "if the libsodium floor in packaging/floors.sexp was raised, floor_archive in this script may still be the old floor's")
(define (current-hint)
  "if current_version was changed, current_archive in this script may still be the old release's")

(define (both-failed-stderr name hint)
  (string-append (curl-says (url-of name))
                 (build-refused "could not download " (url-of name) ", trying " (old-url-of name))
                 (curl-says (old-url-of name))
                 (build-refused "could not download " name " from " (url-of name) " or " (old-url-of name)
                                ": " hint)))

;; ends-no-library : String String String -> (String String -> Build-Answer)
;; The build ran to make install, which left no library, so the check refused.
(define (ends-no-library name so)
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (curl-says (url-of name))
                                 "check-sodium.sh: no library at " (lib-path prefix so)
                                 ": it is not a regular file\n")
                  (calls-through (served-fetch name) name "cc" prefix so 5 (default-inc prefix))
                  1 0 (list 'none 'none))))

(define (without spec . keys) (apply spec-with spec keys))

;; --- build-sodium.sh: the pins and what it downloads ---------------------------------------

(build-row "the floor's pin is the floor's tarball's SHA-256: the real digest reaches the build"
  build-floor-spec (ends-no-library (tarball floor-version) floor-so))

(build-row "--current: the current pin is the current tarball's SHA-256: the real digest reaches the build"
  build-current-spec (ends-no-library (tarball current-version) current-so))

(define (digest-refused name pins got pin fetch)
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (apply string-append (map (lambda (c) (curl-says (url-of name))) (list 1)))
                                 (build-refused name " has SHA-256 " got ", but " pins "_archive in this script pins " pin))
                  (calls-through fetch name "cc" prefix floor-so 1 "")
                  1 0 'no-prefix)))

(build-row "an archive whose SHA-256 is no pin's is refused, naming both, and nothing is unpacked"
  (spec-with build-floor-spec 'digests (list (cons (tarball floor-version) other-digest)))
  (digest-refused (tarball floor-version) "floor" other-digest floor-archive
                  (served-fetch (tarball floor-version))))

(build-row "the floor's tarball with the current pin's digest is refused, naming floor_archive"
  (spec-with build-floor-spec 'digests (list (cons (tarball floor-version) current-archive)))
  (digest-refused (tarball floor-version) "floor" current-archive floor-archive
                  (served-fetch (tarball floor-version))))

(build-row "--current: the current tarball with the floor pin's digest is refused, naming current_archive"
  (spec-with build-current-spec 'digests (list (cons (tarball current-version) floor-archive)))
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (curl-says (url-of (tarball current-version)))
                                 (build-refused (tarball current-version) " has SHA-256 " floor-archive
                                                ", but current_archive in this script pins " current-archive))
                  (calls-through (served-fetch (tarball current-version)) (tarball current-version) "cc" prefix current-so 1 "")
                  1 0 'no-prefix)))

;; The env rows run to the end, so the check's compiler calls show the env
;; build-sodium.sh hands it. They come after success-row's definition.

;; The old directory.
(define (failover-row name spec tarball-name so hint-only)
  (build-row name spec
    (lambda (root prefix)
      (build-answer 1 ""
                    (string-append (curl-says (url-of tarball-name))
                                   (build-refused "could not download " (url-of tarball-name) ", trying "
                                                  (old-url-of tarball-name))
                                   (curl-says (old-url-of tarball-name))
                                   "check-sodium.sh: no library at " (lib-path prefix so)
                                   ": it is not a regular file\n")
                    (calls-through (list (curl-call tarball-name (url-of tarball-name))
                                         (curl-call tarball-name (old-url-of tarball-name)))
                                   tarball-name "cc" prefix so 5 (default-inc prefix))
                    1 0 (list 'none 'none)))))

(failover-row "releases/ fails and releases/old/ serves: the floor's tarball is fetched from old/, and the build goes on"
  (spec-with build-floor-spec 'serves (list (old-url-of (tarball floor-version))))
  (tarball floor-version) floor-so #f)

(build-row "both directories serve: one curl only, from releases/"
  (spec-with build-floor-spec
             'serves (list (url-of (tarball floor-version)) (old-url-of (tarball floor-version))))
  (ends-no-library (tarball floor-version) floor-so))

(build-row "neither directory serves: both URLs are named, nothing else runs, and PREFIX is not made"
  (spec-with build-floor-spec 'serves '())
  (lambda (root prefix)
    (build-answer 1 "" (both-failed-stderr (tarball floor-version) (floor-hint))
                  (list (curl-call (tarball floor-version) (url-of (tarball floor-version)))
                        (curl-call (tarball floor-version) (old-url-of (tarball floor-version))))
                  1 0 'no-prefix)))

(build-row "--current: neither directory serves: the current release's hint, both URLs named"
  (spec-with build-current-spec 'serves '())
  (lambda (root prefix)
    (build-answer 1 "" (both-failed-stderr (tarball current-version) (current-hint))
                  (list (curl-call (tarball current-version) (url-of (tarball current-version)))
                        (curl-call (tarball current-version) (old-url-of (tarball current-version))))
                  1 0 'no-prefix)))

(failover-row "--current: releases/ fails and old/ serves: the same failover for the current release"
  (spec-with build-current-spec 'serves (list (old-url-of (tarball current-version))))
  (tarball current-version) current-so #f)

(build-row "--current: only releases/ serves, where the current release is: one curl"
  build-current-spec (ends-no-library (tarball current-version) current-so))

;; --- build-sodium.sh: the floor ------------------------------------------------------------------

(define (dotted ns)
  (let loop ((rest (cdr ns)) (text (number->string (car ns))))
    (if (null? rest) text (loop (cdr rest) (string-append text "." (number->string (car rest)))))))

(define real-floor-read
  (guard (e (#t 'floors-file-unreadable))
    (floor-text (read-floors) 'sodium)))

(test-equal "packaging/floors.sexp gives a libsodium floor, which the real-floor row below uses"
  'text
  (if (string? real-floor-read) 'text real-floor-read))

(define real-floor (if (string? real-floor-read) real-floor-read "0.0.0"))

(build-row "the real floors file: the tarball's name and URLs come from it, neither serving"
  (spec-with build-floor-spec 'floors (text-or-empty "packaging/floors.sexp") 'serves '())
  (lambda (root prefix)
    (build-answer 1 "" (both-failed-stderr (tarball real-floor) (floor-hint))
                  (list (curl-call (tarball real-floor) (url-of (tarball real-floor)))
                        (curl-call (tarball real-floor) (old-url-of (tarball real-floor))))
                  1 0 'no-prefix)))

(build-row "a floor of 8.12.103 reaches libsodium-8.12.103.tar.gz, its parts written as they are"
  (spec-with build-floor-spec
             'floors (floors-text "8.12.103")
             'name (tarball "8.12.103")
             'digests (list (cons (tarball "8.12.103") floor-archive))
             'serves (list (url-of (tarball "8.12.103"))))
  (ends-no-library (tarball "8.12.103") floor-so))

(build-row "a malformed floor fails before any download, with floor.sh's line, then the script's"
  (spec-with build-floor-spec 'floors (floors-text "8.1"))
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append "floor.sh: packaging/floors.sexp: the sodium version \"8.1\" is not three dot-separated naturals, major.minor.patch\n"
                                 "build-sodium.sh: no libsodium floor to build\n")
                  '() 0 0 'no-prefix)))

(build-row "--current reads no floors file: with none, the pinned release's tarball is reached"
  build-current-spec (ends-no-library (tarball current-version) current-so))

(build-row "--current with a floor of 8.1.2 in the tree reaches the pinned release, not the floor's tarball"
  (spec-with build-current-spec 'floors (floors-text floor-version))
  (ends-no-library (tarball current-version) current-so))

(build-row "current_version in the env moves nothing: the pinned release is still reached"
  (spec-with build-current-spec 'env (lambda (root prefix) (list "current_version=9.9.9")))
  (ends-no-library (tarball current-version) current-so))

;; --- build-sodium.sh: before any download --------------------------------------------------------

(define (tool-why name)
  (cond ((string=? name "curl") "downloads the archive")
        ((string=? name "sha256sum") "checks the SHA-256 of the archive")
        ((string=? name "tar") "unpacks the archive")
        ((string=? name "make") "builds libsodium")
        (else "is the C compiler CC names, cc by default, and builds libsodium")))

(define (missing-answer names)
  (lambda (root prefix)
    (build-answer 1 ""
                  (apply string-append
                         (map (lambda (n) (string-append "build-sodium.sh: cannot find " n ", which " (tool-why n) "\n"))
                              names))
                  '() 0 0 'no-prefix)))

(define all-shims '("curl" "sha256sum" "tar" "make" "cc"))
(define (shims-without . names) (filter (lambda (s) (not (member s names))) all-shims))

(for-each
 (lambda (tool)
   (build-row (string-append "no " tool " is named before any download")
     (spec-with build-floor-spec 'shims (shims-without tool))
     (missing-answer (list tool))))
 all-shims)

(build-row "none of the five: each is named, in order, before any download"
  (spec-with build-floor-spec 'shims '())
  (missing-answer all-shims))

;; --- build-sodium.sh: unpacking and building ---------------------------------------------------------

(build-row "an archive that holds no configure is refused after the unpack"
  (spec-with build-floor-spec 'flags '(no-configure))
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (curl-says (url-of (tarball floor-version)))
                                 (build-refused (tarball floor-version) " holds no " (dir-of (tarball floor-version)) "/configure"))
                  (calls-through (served-fetch (tarball floor-version)) (tarball floor-version) "cc" prefix floor-so 2 "")
                  1 0 'no-prefix)))

(define (step-failed-answer name step-name tail n)
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (curl-says (url-of name))
                                 "build-sodium.sh: " step-name " failed; the last 30 lines of its output:\n" tail)
                  (calls-through (served-fetch name) name "cc" prefix floor-so n "")
                  1 0 'no-prefix)))

(build-row "a tar that fails is refused, naming the archive, and nothing is built"
  (spec-with build-floor-spec 'flags '(tar-fails))
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (curl-says (url-of (tarball floor-version))) "tar: the shim fails\n"
                                 (build-refused "tar could not unpack " (tarball floor-version)))
                  (calls-through (served-fetch (tarball floor-version)) (tarball floor-version) "cc" prefix floor-so 2 "")
                  1 0 'no-prefix)))

(build-row "configure that fails shows its last lines, make never runs, and PREFIX is not made"
  (spec-with build-floor-spec 'flags '(configure-fails))
  (step-failed-answer (tarball floor-version) "configure" "configure: error: the shim fails\n" 3))

(build-row "make that fails shows its last lines, make install never runs, and PREFIX is not made"
  (spec-with build-floor-spec 'flags '(make-fails))
  (step-failed-answer (tarball floor-version) "make" "make: *** [all] Error 1\n" 4))

(build-row "make install that fails shows its last lines, and the check never runs"
  (spec-with build-floor-spec 'flags '(install-fails))
  (step-failed-answer (tarball floor-version) "make install" "make: *** [install] Error 1\n" 5))

(build-row "a configure that left out HAVE_PTHREAD is refused, and make never runs"
  (spec-with build-floor-spec 'flags '(no-pthread))
  (lambda (root prefix)
    (build-answer 1 ""
                  (string-append (curl-says (url-of (tarball floor-version)))
                                 (build-refused "configure built libsodium without pthreads: src/libsodium/Makefile has no -DHAVE_PTHREAD=1"))
                  (calls-through (served-fetch (tarball floor-version)) (tarball floor-version) "cc" prefix floor-so 3 "")
                  1 0 'no-prefix)))

(build-row "CC naming another compiler is the CC configure sees"
  (spec-with build-floor-spec
             'shims '("curl" "sha256sum" "tar" "make" "cc-other")
             'env (lambda (root prefix) (list (string-append "CC=" root "/shim/cc-other"))))
  (lambda (root prefix)
    (let ((name (tarball floor-version)))
      (build-answer 1 ""
                    (string-append (curl-says (url-of name))
                                   "check-sodium.sh: no library at " (lib-path prefix floor-so)
                                   ": it is not a regular file\n")
                    (calls-through (served-fetch name) name (string-append root "/shim/cc-other") prefix floor-so 5
                                   (default-inc prefix))
                    1 0 (list 'none 'none)))))

(build-row "CFLAGS, CPPFLAGS and LDFLAGS in the env never reach configure"
  (spec-with build-floor-spec
             'env (lambda (root prefix) (list "CFLAGS=-DX" "CPPFLAGS=-DY" "LDFLAGS=-Z")))
  (ends-no-library (tarball floor-version) floor-so))

;; --- build-sodium.sh: the check at its end ------------------------------------------------------------

;; The checks that reach the compiler: a library and header the stub makes, a
;; real compiler behind cc, and the real probe.
(define (success-row name spec so version major minor what lib header inc-of)
  (build-row name
    (spec-with spec 'stub lib 'header header)
    (lambda (root prefix)
      (let ((tarball-name (spec-ref spec 'name)))
        (build-answer
         0
         (string-append (cadr (passes-by "cc" prefix so version major minor what))
                        "build-sodium.sh: libsodium " version " built into " prefix "\n")
         (curl-says (url-of tarball-name))
         (calls-through (served-fetch tarball-name) tarball-name "cc" prefix so 7 (inc-of root prefix))
         1 1
         (list (file-or-none (string-append root "/stub-lib"))
               (header-text header)))))))

(define (passes-by cc-name prefix so version major minor what)
  (list 0
        (string-append
         "check-sodium.sh: " (lib-path prefix so) " is libsodium " version " (library "
         major "." minor "), " what ", and no minimal build\n"
         "check-sodium.sh: " cc-name " finds <sodium.h> at " (header-path prefix)
         ", which declares the same release, and CHEZ_SODIUM_LIBRARY names the library\n")
        ""))

(success-row "both right and a library that is the floor's: built, checked with the floor's soname, the last line printed, exit 0"
  build-floor-spec floor-so floor-version "10" "3" floor-what floor-lib floor-header
  (lambda (root prefix) (default-inc prefix)))

(success-row "--current, in a tree with no floors file: built the same way, checked with --current, exit 0"
  build-current-spec current-so current-version "26" "4" current-what current-lib current-header
  (lambda (root prefix) (default-inc prefix)))

(success-row "floor_archive, current_archive, version, current_version, role, pins and soname set in the env move nothing: the check still gets the floor's library and header, whole"
  (spec-with build-floor-spec
             'env (lambda (root prefix)
                    (list (string-append "floor_archive=" other-digest)
                          (string-append "current_archive=" other-digest)
                          "version=1.0.22" "current_version=9.9.9" "role=current" "pins=current"
                          "archive_pin=x" "soname=libsodium.so.26" "check_args=--current")))
  floor-so floor-version "10" "3" floor-what floor-lib floor-header
  (lambda (root prefix) (default-inc prefix)))

(success-row "--current: current_archive, current_version, version and soname set in the env move nothing"
  (spec-with build-current-spec
             'env (lambda (root prefix)
                    (list (string-append "current_archive=" other-digest)
                          "current_version=9.9.9" "version=8.1.2" "archive_pin=x" "soname=libsodium.so.23")))
  current-so current-version "26" "4" current-what current-lib current-header
  (lambda (root prefix) (default-inc prefix)))

(success-row "C_INCLUDE_PATH in the env: the build passes it on after PREFIX/include, and the check passes"
  (spec-with build-floor-spec
             'env (lambda (root prefix) (list (string-append "C_INCLUDE_PATH=" (cip-after (string-append root "/elsewhere"))))))
  floor-so floor-version "10" "3" floor-what floor-lib floor-header
  (lambda (root prefix) (string-append prefix "/include:" (cip-after (string-append root "/elsewhere")))))

(build-row "--current: a floor's library from make install is refused by the check, not by the build"
  (spec-with build-current-spec 'stub floor-lib 'header floor-header)
  (lambda (root prefix)
    (let ((name (tarball current-version)))
      (build-answer 1 ""
                    (string-append (curl-says (url-of name))
                                   "check-sodium.sh: " (header-path prefix) " defines SODIUM_VERSION_STRING "
                                   (q floor-version) ", but " current-what " is " (q current-version) "\n")
                    (calls-through (served-fetch name) name "cc" prefix current-so 7 (default-inc prefix))
                    1 1 (list (file-or-none (string-append root "/stub-lib")) (header-text floor-header))))))

(build-row "the floor's build made with a minimal library is refused by the check"
  (spec-with build-floor-spec 'stub (list floor-version 10 3 1) 'header floor-header)
  (lambda (root prefix)
    (let ((name (tarball floor-version)))
      (build-answer 1 ""
                    (string-append (curl-says (url-of name))
                                   "check-sodium.sh: " (lib-path prefix floor-so)
                                   " answers 1 to sodium_library_minimal(), but a lane's libsodium must answer 0: no minimal build\n")
                    (calls-through (served-fetch name) name "cc" prefix floor-so 7 (default-inc prefix))
                    1 1 (list (file-or-none (string-append root "/stub-lib")) (header-text floor-header))))))

;; --- both scripts: the execute bit ------------------------------------------------------------

(test-equal "both scripts are executable, as CI runs them by their names"
  '(returned (("scripts/ci/build-sodium.sh" . 0) ("scripts/ci/check-sodium.sh" . 0)))
  (outcome
   (lambda ()
     (let* ((build (car (capture-command (list "test" "-x" "scripts/ci/build-sodium.sh"))))
            (check (car (capture-command (list "test" "-x" "scripts/ci/check-sodium.sh")))))
       (list (cons "scripts/ci/build-sodium.sh" build) (cons "scripts/ci/check-sodium.sh" check))))))

;; --- build-sodium.sh: usage ---------------------------------------------------------------------

(define build-usage
  (lambda (root prefix)
    (build-answer 2 "" "usage: build-sodium.sh PREFIX [--current]\n" '() 0 0 'no-prefix)))

(define (build-usage-row name args)
  (build-row name (spec-with build-floor-spec 'args args) build-usage))

(build-usage-row "no prefix is a usage error" (lambda (root prefix) '()))
(build-usage-row "two prefixes are a usage error" (lambda (root prefix) (list prefix prefix)))
(build-usage-row "--nothreads, build-chez.sh's flag, is a usage error" (lambda (root prefix) (list prefix "--nothreads")))
(build-usage-row "three arguments are a usage error" (lambda (root prefix) (list prefix "--current" "--current")))
(build-usage-row "--no-load, a flag libsodium has no use for, is a usage error" (lambda (root prefix) (list prefix "--no-load")))
(build-usage-row "--discovery is a usage error" (lambda (root prefix) (list prefix "--discovery")))
(build-usage-row "--current --current is a usage error" (lambda (root prefix) (list "--current" "--current")))

(build-row "a relative prefix is refused, naming it, before any download"
  (spec-with build-floor-spec 'args (lambda (root prefix) (list "lib")))
  (lambda (root prefix)
    (build-answer 2 "" "build-sodium.sh: PREFIX must be an absolute path, not 'lib'\n" '() 0 0 'no-prefix)))

(test-end "ci-sodium")

(exit (suite-exit-status runner))
