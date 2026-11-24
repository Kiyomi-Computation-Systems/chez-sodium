#!r6rs
;;; (libsodium-oracle): what a libsodium says about itself, read by a C
;;; program compiled at test time, tests/libsodium-oracle.c. The suites that
;;; check what chez-sodium reports compare it with this.
;;;
;;;   libsodium-oracle  the fields, read from the library at a path
;;;   oracle-fields     their names, in the order the program prints them
;;;   oracle-size-fields  the five size lines' names, each (NAME F M), printed
;;;                     after the fields and before (valgrind . ...)
;;;   c-compiler        $CC as a command's words, for every compile
;;;   split-words       a string cut at whitespace
;;;
;;; The program is compiled into a fresh directory of call-with-temp-directory's,
;;; never a fixed path, and removed with it. It dlopens the path it is given,
;;; exactly, and links no libsodium (the program's header). It runs through
;;; gated-command, so under make test-memory the gate's own Valgrind runs it,
;;; with a log of its own: the gate takes a child named libsodium-oracle, as it
;;; takes Chez (ADR-0011).
;;;
;;; Test-only: it lives in tests/, which make test puts on Chez's library
;;; path, not in src/.
(library (libsodium-oracle)
  (export libsodium-oracle oracle-fields oracle-size-fields c-compiler split-words)
  (import (rnrs)
          (chez-sodium-testing))

  ;; oracle-fields : (Listof Symbol)
  ;; What the oracle prints, in its order: sodium_version_string,
  ;; sodium_library_version_major and _minor, then sodium_init's first two
  ;; answers. It then prints (valgrind . yes) or (valgrind . no): whether it
  ;; ran under memcheck. libsodium-oracle answers it after these fields,
  ;; never among them, so that a suite comparing each field with another
  ;; source leaves it out.
  (define oracle-fields '(version major minor init))

  ;; oracle-size-fields : (Listof Symbol)
  ;; The size lines, in the order the oracle prints them, after sodium_init's
  ;; and before valgrind's: each (NAME F M), F the size function's answer
  ;; through the library and M the header's macro, in step 7's order.
  (define oracle-size-fields
    '(generichash-bytes generichash-bytes-min generichash-bytes-max
      generichash-keybytes-min generichash-keybytes-max))

  ;; split-words : String -> (Listof String)
  ;; TEXT cut at each run of spaces, tabs and newlines, empty pieces
  ;; dropped.
  (define (split-words text)
    (let loop ((i 0) (start 0) (found '()))
      (define (piece) (if (> i start) (cons (substring text start i) found) found))
      (cond ((= i (string-length text)) (reverse (piece)))
            ((memv (string-ref text i) '(#\space #\tab #\newline))
             (loop (+ i 1) (+ i 1) (piece)))
            (else (loop (+ i 1) start found)))))

  ;; c-compiler : (String -> (U String #f)) -> (Listof String)
  ;; The C compiler as a command's first words: CC, read with GETENV, split
  ;; at whitespace, so CC='ccache gcc' runs ccache with gcc as its first
  ;; argument; ("cc") when CC is unset or blank.
  (define (c-compiler getenv)
    (let ((words (split-words (or (getenv "CC") ""))))
      (if (null? words) '("cc") words)))

  ;; libsodium-oracle : (String -> (U String #f)) String
  ;;                    -> (U (Listof (Pairof Symbol Any)) (List 'no-oracle Symbol Any))
  ;; Compiles tests/libsodium-oracle.c with (c-compiler GETENV), -Wall and
  ;; -Werror into a fresh directory from call-with-temp-directory, runs it on
  ;; PATH through (gated-command GETENV ...), and answers what it printed,
  ;; read as data: (FIELD . VALUE), or (init FIRST SECOND), for each of
  ;; oracle-fields, in order, then (NAME F M) for each of oracle-size-fields,
  ;; then (valgrind . yes) or (valgrind . no).
  ;; Anything else is (no-oracle STEP EVIDENCE), naming the step that went
  ;; wrong: compile, run, output (that is not the fields), or raised, with the
  ;; text of a raise, which includes mktemp's answer being refused. It never
  ;; raises. The directory is removed, a raise included.
  (define (libsodium-oracle getenv path)
    (guard (e (#t (list 'no-oracle 'raised (describe e))))
      (call-with-temp-directory
       (lambda (dir)
         (run-oracle getenv (string-append dir "/libsodium-oracle") path)))))

  ;; run-oracle : (String -> (U String #f)) String String -> Any
  (define (run-oracle getenv program path)
    (let ((compiled (capture-command
                     (append (c-compiler getenv)
                             (list "-Wall" "-Werror" "-o" program "tests/libsodium-oracle.c"
                                   "-ldl")))))
      (if (not (= (car compiled) 0))
          (list 'no-oracle 'compile compiled)
          (let ((ran (capture-command (gated-command getenv (list program path)))))
            (if (not (= (car ran) 0))
                (list 'no-oracle 'run ran)
                (let ((data (read-all (cadr ran))))
                  (if (and (list? data)
                           (= (length data)
                              (+ (length oracle-fields) (length oracle-size-fields) 1))
                           (for-all (lambda (datum field)
                                      (and (pair? datum) (eq? (car datum) field)))
                                    data (append oracle-fields oracle-size-fields '(valgrind))))
                      data
                      (list 'no-oracle 'output (cadr ran)))))))))

  ;; read-all : String -> (U (Listof Any) #f)
  ;; TEXT read as a sequence of data, or #f when it does not read.
  (define (read-all text)
    (guard (e (#t #f))
      (let ((port (open-string-input-port text)))
        (let loop ((data '()))
          (let ((datum (read port)))
            (if (eof-object? datum)
                (reverse data)
                (loop (cons datum data)))))))))
