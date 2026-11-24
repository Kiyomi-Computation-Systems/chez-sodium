#!r6rs
;;; tests/verb-probe.sps: runs verb calls against (chez-sodium private
;;; byte-verbs), in a process of its own, and prints what each did as data,
;;; one datum per line, for tests/test-library-loading-verbs.sps, through
;;; tests/library-loading.sls, to read. It is not a suite: its name lies
;;; outside the tests/test-*.sps glob, so make test never runs it directly
;;; (ADR-0011).
;;;
;;;   verb-probe.sps CALL ...
;;;
;;; Each CALL is one argument: the text of an expression, read as data and
;;; evaluated in an environment of (rnrs) and (chez-sodium private
;;; byte-verbs), so it names the three verbs, and builds a bytevector with
;;; make-bytevector or a #vu8 literal. A call is run under an inner guard for
;;; something else, (guard (e ((string? e) 'inner)) CALL), inside an outer
;;; guard that takes everything: a raise that the inner guard's clauses do not
;;; match is raised again from inside the call's extent, as a verb's caller
;;; meets it. After each call the probe prints one line:
;;;
;;;   (OUTCOME GROWTH)
;;;
;;; OUTCOME is what the call answered, or:
;;;   (refused WHO IRRITANTS)       an assertion violation, by its &who and its
;;;                                 &irritants, never its message
;;;   (failed WHO FUNCTION CODE)    a &sodium-failed
;;;   (raised WHO TYPES)            anything else raised
;;;   unreadable                    the argument was no datum
;;; GROWTH is the text the decoy's call log gained since the line before, as a
;;; string, without its leading space: "" when no C was called. The first
;;; growth starts after the verbs' library has loaded, so it holds no load
;;; call. A library that is no decoy has no log, and its growth is always "".
;;;
;;; Then (counts . ALIST): (chez-sodium private counters)' native-counts, which
;;; the suite requires every one zero; and (valgrind . yes) or (valgrind . no):
;;; whether this process runs under Valgrind's memcheck, read from
;;; /proc/self/maps, which the suite requires to be yes exactly when the
;;; memory gate asked (ADR-0011).
;;;
;;; Why eval, and no import of (chez-sodium private byte-verbs): Chez runs the
;;; libraries a program imports before the program's body, so a guard in the
;;; body never sees a raise from an imported library's body, which is the
;;; load. This program evaluates each call, and the first reference to the
;;; library, inside its guards.
(import (rnrs)
        (rnrs eval)
        (only (chezscheme) foreign-entry? foreign-procedure foreign-ref)
        (chez-sodium private conditions)
        (chez-sodium private counters))

;; show : Any -> Void
;; One datum on a line of its own.
(define (show datum)
  (write datum)
  (newline))

;; raised-facts : Any -> (List (U Symbol #f) (Listof Symbol))
;; What a raise is, without its text: its &who, or #f, and its types.
(define (raised-facts obj)
  (list (and (condition? obj) (who-condition? obj) (condition-who obj))
        (if (condition? obj)
            (let loop ((rest (list (cons 'serious serious-condition?) (cons 'error error?)
                                   (cons 'violation violation?)
                                   (cons 'assertion assertion-violation?)
                                   (cons 'who who-condition?) (cons 'message message-condition?)
                                   (cons 'irritants irritants-condition?)))
                       (found '()))
              (cond ((null? rest) (reverse found))
                    (((cdar rest) obj) (loop (cdr rest) (cons (caar rest) found)))
                    (else (loop (cdr rest) found))))
            '())))

;; outcome-of : Any -> Any
;; A raised object as the probe prints it.
(define (outcome-of e)
  (cond ((sodium-failed? e)
         (list 'failed (and (who-condition? e) (condition-who e))
               (sodium-failed-function e) (sodium-failed-code e)))
        ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
         (list 'refused (condition-who e) (condition-irritants e)))
        (else (cons 'raised (raised-facts e)))))

;; read-c-string : Natural -> String
;; The NUL-terminated bytes at ADDRESS, decoded as UTF-8.
(define (read-c-string address)
  (let* ((n (let scan ((i 0))
              (if (eqv? (foreign-ref 'unsigned-8 address i) 0) i (scan (+ i 1)))))
         (bytes (make-bytevector n)))
    (let fill ((i 0))
      (when (< i n)
        (bytevector-u8-set! bytes i (foreign-ref 'unsigned-8 address i))
        (fill (+ i 1))))
    (utf8->string bytes)))

;; call-log : -> String
;; The decoy's call log so far, or "" for a library that has none.
(define (call-log)
  (if (foreign-entry? "decoy_calls")
      (read-c-string ((foreign-procedure "decoy_calls" () uptr)))
      ""))

;; under-valgrind? : -> Boolean
;; Whether /proc/self/maps maps memcheck's preload; #f when it cannot be read.
(define (under-valgrind?)
  (guard (e (#t #f))
    (let ((maps (call-with-port
                 (open-file-input-port "/proc/self/maps" (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 get-string-all))
          (needle "vgpreload_memcheck"))
      (let ((n (string-length maps)) (m (string-length needle)))
        (let loop ((i 0))
          (cond ((> (+ i m) n) #f)
                ((string=? (substring maps i (+ i m)) needle) #t)
                (else (loop (+ i 1)))))))))

;; datum-of : String -> Any
;; TEXT read as one datum, or the symbol unreadable.
(define (datum-of text)
  (guard (e (#t 'unreadable))
    (read (open-string-input-port text))))

(define verbs (environment '(rnrs) '(chez-sodium private byte-verbs)))

;; The first reference to the library runs its body, the load, so the log's
;; baseline holds the load's calls and a call's growth holds its own.
(define loaded
  (guard (e (#t (outcome-of e)))
    (eval 'random-bytes verbs)
    'loaded))

;; growth : String -> (Pair String String)
;; The log's text beyond BEFORE, without the space that joins it, and the whole
;; log: the next call's BEFORE.
(define (growth before)
  (let* ((now (call-log))
         (n (string-length before)))
    (cons (cond ((and (>= (string-length now) n) (string=? (substring now 0 n) before))
                 (let ((tail (substring now n (string-length now))))
                   (if (and (> (string-length tail) 0) (char=? (string-ref tail 0) #\space))
                       (substring tail 1 (string-length tail))
                       tail)))
                (else (string-append "log-changed:" now)))
          now)))

(unless (eq? loaded 'loaded)
  (show (list 'not-loaded loaded)))

(let loop ((calls (cdr (command-line))) (before (call-log)))
  (unless (null? calls)
    (let* ((datum (datum-of (car calls)))
           (outcome (if (eq? datum 'unreadable)
                        'unreadable
                        (guard (e (#t (outcome-of e)))
                          (eval `(guard (e ((string? e) 'inner)) ,datum) verbs))))
           (grown (growth before)))
      (show (list outcome (car grown)))
      (loop (cdr calls) (cdr grown)))))

(show (cons 'counts (native-counts)))
(show (cons 'valgrind (if (under-valgrind?) 'yes 'no)))
