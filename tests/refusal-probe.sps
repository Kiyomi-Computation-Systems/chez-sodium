#!r6rs
;;; tests/refusal-probe.sps: loads libsodium as chez-sodium does, in a
;;; process of its own, and prints what happened as data, one datum per
;;; line, for the tests/test-library-loading-*.sps suites, through
;;; tests/library-loading.sls, to read. It is not a suite: its name lies outside the
;;; tests/test-*.sps glob, so make test never runs it directly (ADR-0011).
;;;
;;;   refusal-probe.sps [--then-override PATH] [--marker NAME] [--message yes]
;;;                     [--init-before yes] [--init-after yes] [--wipe N]
;;;                     [--sizes yes]
;;;   refusal-probe.sps --drive yes [--overflow yes]
;;;
;;; It references loaded-libsodium three times, each inside its guard. The
;;; first reference prints what happened:
;;;
;;;   loaded:   (loaded . PATH) (source . SYMBOL) (version . STRING)
;;;             (major . N) (minor . N) (init . N), (chez-sodium private
;;;             native)'s record of the load, and the exit status is 0
;;;   refused:  (reason . SYMBOL) (who . WHO) (path . P) (source . S)
;;;             (detail . D) (candidates . LIST) (irritants . LIST), and the
;;;             exit status is 1. WHO is the condition's &who. LIST of
;;;             irritants is the condition's &irritants, or #f when it has
;;;             none. With --message, (message . TEXT) follows: the
;;;             condition's &message, which tests/preflight.sps prints as
;;;             its remedy. Tests never assert it as text (ADR-0006);
;;;             test-library-loading-preflight compares preflight's remedy
;;;             line with it
;;;   anything else raised: (raised WHO TYPES), and the exit status is 2.
;;;             WHO is the condition's &who, or #f; TYPES lists, by name, the
;;;             condition types it is, in a fixed order: serious, error,
;;;             violation, assertion, warning, who, message, irritants,
;;;             library-unavailable. Never its text (ADR-0006)
;;;
;;; With --sizes, a load prints one more field, right after (init . N):
;;; (sizes B BMIN BMAX KMIN KMAX), the five sizes (chez-sodium private
;;; native) exports, in the order its load reads them: generichash-bytes,
;;; -bytes-min, -bytes-max, -keybytes-min, -keybytes-max. Without it the
;;; output is as it was.
;;;
;;; With --then-override, CHEZ_SODIUM_LIBRARY is set to PATH after the
;;; first reference, and (then-override . VALUE) shows what getenv then
;;; reads. The two later references print one line, (again . (A B)). Each is
;;; `same` when the reference answered what the first did: the very
;;; condition (eq?) for a refusal or a raise, an equal? record for a load,
;;; since loaded-libsodium answers a fresh list at each call; else
;;; (loaded PATH), (refused REASON) or (raised WHO TYPES). That a load ran
;;; once is shown by the decoy's call log, whole, beside it.
;;;
;;; With --init-before, before anything of chez-sodium's runs, the probe loads
;;; CHEZ_SODIUM_LIBRARY itself, binds sodium_init on its own, and calls it:
;;; (init-before . N) is the first line, or (init-before raised WHO TYPES).
;;; With --init-after, once the first reference has loaded and the later
;;; two are done, it calls sodium_init directly once more: (init-after . N),
;;; right after the (again . ...) line. Both are for the real libsodium: a
;;; decoy would log the probe's own calls.
;;;
;;; With --wipe N, once the first reference has loaded, the probe makes a
;;; block of N bytes of A (call-with-bytes, inside call-in-section) and
;;; frees it: (wipe . ok), or (wipe raised WHO TYPES), after (again . ...).
;;; The decoy's log then holds the wipe's call.
;;;
;;; Then (counts . ALIST): (chez-sodium private counters)' native-counts,
;;; read once the references are done. The counters count per process, and a
;;; suite's suite-exit-status reads only its own, so this process prints its
;;; counts, and its suite requires every one zero, refusals included
;;; (ADR-0011).
;;;
;;; With --marker, (marker . present) or (marker . absent) follows: whether
;;; this process has the entry point NAME, as foreign-entry? answers.
;;;
;;; Then (valgrind . yes) or (valgrind . no): whether this process runs under
;;; Valgrind's memcheck, read from /proc/self/maps, which then maps memcheck's
;;; preload. Under make test-memory, the test-library-loading suites run
;;; this probe through the gate's own Valgrind, and require yes there and no
;;; elsewhere, so a child the gate should check that ran outside it fails its
;;; row (ADR-0011).
;;;
;;; Last comes (calls . LOG) when the most recently loaded library has the
;;; entry point decoy_calls, as tests/decoy-libsodium.c does: its call log,
;;; read byte by byte from the address the call returns, never through
;;; Chez's string type (ADR-0001).
;;;
;;; With --drive, none of the above runs, and nothing of chez-sodium's loads.
;;; The probe loads CHEZ_SODIUM_LIBRARY itself, which is a decoy, binds the
;;; eight entry points of the verbs on its own with foreign-procedure, calls
;;; each on blocks it makes with foreign-alloc, and prints, one datum a line:
;;;
;;;   (sizes B BMIN BMAX KMIN KMAX)  the five size functions' answers
;;;   (randombytes . BYTES)          a 9-byte request on a block of 10, the
;;;                                  block as it is after the call
;;;   (generichash ANSWER BYTES)     outlen 7, a 3-byte input and a 2-byte key,
;;;                                  on an output block of 8, as it is after
;;;   (memcmp EQUAL DIFFER LEN0 NULL-FIRST NULL-SECOND)
;;;                                  sodium_memcmp's answers: equal blocks of
;;;                                  4 bytes, blocks that differ, length 0 on
;;;                                  blocks that differ, then a NULL operand
;;;                                  at length 4, first and second
;;;   (calls . LOG)                  the decoy's call log so far
;;;
;;; With --overflow also, it then binds sodium_init, calls it a thousand
;;; times and once more, and prints (head . S) (tail . S) (unmoved . yes|no)
;;; (overflows . N) (fits . yes|no): the log's first 14 characters and last
;;; 36 once full, whether one more call moved it, how many overflow entries
;;; it holds, and whether it is under its 4096 bytes. Then (counts . ...) and
;;; (valgrind . ...), as below.
;;;
;;; Why eval, and no import of (chez-sodium private native): Chez runs the
;;; libraries a program imports before the program's body, so a guard in the
;;; body never sees a raise from an imported library's body.
;;; Native's body is the load. So this program evaluates (loaded-libsodium)
;;; in native's environment inside the guard, and the load runs within it.
;;; The libraries it imports load nothing: conditions define types and
;;; procedures, and the counters count.
(import (rnrs)
        (only (chezscheme) eval environment foreign-alloc foreign-entry? foreign-free
              foreign-procedure foreign-ref foreign-set! load-shared-object putenv getenv)
        (chez-sodium private conditions)
        (chez-sodium private counters))

;; show : Symbol Any -> Void
;; One datum, (KEY . VALUE), on a line of its own.
(define (show key value)
  (write (cons key value))
  (newline))

;; condition-types : Any -> (Listof Symbol)
;; The names of the condition types OBJ is, in a fixed order; none for what
;; is no condition.
(define (condition-types obj)
  (if (condition? obj)
      (let loop ((rest (list (cons 'serious serious-condition?) (cons 'error error?)
                             (cons 'violation violation?) (cons 'assertion assertion-violation?)
                             (cons 'warning warning?) (cons 'who who-condition?)
                             (cons 'message message-condition?)
                             (cons 'irritants irritants-condition?)
                             (cons 'library-unavailable sodium-library-unavailable?)))
                 (found '()))
        (cond ((null? rest) (reverse found))
              (((cdar rest) obj) (loop (cdr rest) (cons (caar rest) found)))
              (else (loop (cdr rest) found))))
      '()))

;; raised-facts : Any -> (List (U Symbol #f) (Listof Symbol))
;; What a raise is, without its text: its &who, or #f, and its types.
(define (raised-facts obj)
  (list (and (condition? obj) (who-condition? obj) (condition-who obj))
        (condition-types obj)))

;; option : String -> (U String #f)
;; The argument after NAME on the command line, or #f.
(define (option name)
  (let loop ((args (cdr (command-line))))
    (cond ((or (null? args) (null? (cdr args))) #f)
          ((string=? (car args) name) (cadr args))
          (else (loop (cdr args))))))

(define native (environment '(rnrs) '(chez-sodium private native)))

;; direct-init : -> Integer
;; sodium_init, bound here and called: the probe's own binding.
(define (direct-init)
  ((eval '(foreign-procedure "sodium_init" () int) (environment '(chezscheme)))))

;; reference : -> (Pairof Symbol Any)
;; One reference to loaded-libsodium: (loaded . INFO), (refused . CONDITION)
;; or (raised . OBJECT).
(define (reference)
  (guard (e ((sodium-library-unavailable? e) (cons 'refused e))
            (#t (cons 'raised e)))
    (cons 'loaded (eval '(loaded-libsodium) native))))

;; later : (Pairof Symbol Any) (Pairof Symbol Any) -> Any
;; What a later reference did, against the first.
(define (later first answer)
  (cond ((and (eq? (car answer) 'loaded) (eq? (car first) 'loaded)
              (equal? (cdr answer) (cdr first)))
         'same)
        ((eq? (cdr answer) (cdr first)) 'same)
        ((eq? (car answer) 'loaded) (list 'loaded (cdr (assq 'path (cdr answer)))))
        ((eq? (car answer) 'refused)
         (list 'refused (sodium-library-unavailable-reason (cdr answer))))
        (else (cons 'raised (raised-facts (cdr answer))))))

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

;; under-valgrind? : -> Boolean
;; Whether /proc/self/maps maps memcheck's preload; #f when it cannot be
;; read.
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

;; --init-before: the probe's own load and call, before the first reference.
(when (option "--init-before")
  (show 'init-before
        (guard (e (#t (cons 'raised (raised-facts e))))
          (load-shared-object (getenv "CHEZ_SODIUM_LIBRARY"))
          (direct-init))))

;; --- --drive: the decoy's entry points, called directly -----------------------------------

;; bind : String Any -> Procedure
;; The foreign procedure NAME of the loaded library, written as C names it.
(define (bind name signature)
  (eval `(foreign-procedure ,name ,@signature) (environment '(chezscheme))))

;; block-of : Bytevector -> Natural
;; A fresh block holding BYTES, and one byte at least.
(define (block-of bytes)
  (let ((address (foreign-alloc (max 1 (bytevector-length bytes)))))
    (let fill ((i 0))
      (when (< i (bytevector-length bytes))
        (foreign-set! 'unsigned-8 address i (bytevector-u8-ref bytes i))
        (fill (+ i 1))))
    address))

;; block-bytes : Natural Natural -> Bytevector
;; The N bytes at ADDRESS.
(define (block-bytes address n)
  (let ((bytes (make-bytevector n)))
    (let fill ((i 0))
      (when (< i n)
        (bytevector-u8-set! bytes i (foreign-ref 'unsigned-8 address i))
        (fill (+ i 1))))
    bytes))

;; occurrences-of : String String -> Natural
(define (occurrences-of text word)
  (let ((n (string-length text)) (m (string-length word)))
    (let loop ((i 0) (found 0))
      (cond ((> (+ i m) n) found)
            ((string=? (substring text i (+ i m)) word) (loop (+ i m) (+ found 1)))
            (else (loop (+ i 1) found))))))

;; drive-calls : -> String
(define (drive-calls)
  (read-c-string ((bind "decoy_calls" '(() uptr)))))

;; drive-overflow : -> Void
;; A thousand sodium_init calls fill the log; one more must change nothing.
(define (drive-overflow)
  (let ((init (bind "sodium_init" '(() int))))
    (let loop ((i 0))
      (when (< i 1000) (init) (loop (+ i 1))))
    (let* ((kept (string-copy (drive-calls)))
           (length (string-length kept))
           (ignored (init))
           (after (drive-calls)))
      (show 'head (substring kept 0 14))
      (show 'tail (substring kept (- length 36) length))
      (show 'unmoved (if (string=? kept after) 'yes 'no))
      (show 'overflows (occurrences-of after "overflow"))
      (show 'fits (if (< length 4096) 'yes 'no)))))

;; drive : -> Void
(define (drive)
  (load-shared-object (getenv "CHEZ_SODIUM_LIBRARY"))
  (let* ((sizes (let loop ((names '("crypto_generichash_bytes" "crypto_generichash_bytes_min"
                                    "crypto_generichash_bytes_max"
                                    "crypto_generichash_keybytes_min"
                                    "crypto_generichash_keybytes_max"))
                           (found '()))
                  (if (null? names)
                      (reverse found)
                      (loop (cdr names) (cons ((bind (car names) '(() size_t))) found)))))
         (randombytes-buf (bind "randombytes_buf" '((uptr size_t) void)))
         (generichash (bind "crypto_generichash" '((uptr size_t uptr unsigned-64 uptr size_t) int)))
         (memcmp (bind "sodium_memcmp" '((uptr uptr size_t) int)))
         (random-block (block-of (make-bytevector 10 #x11)))
         (out-block (block-of (make-bytevector 8 #x11)))
         (in-block (block-of (u8-list->bytevector (list 1 2 3))))
         (key-block (block-of (u8-list->bytevector (list 4 5))))
         (a (block-of (u8-list->bytevector (list 1 2 3 4))))
         (same (block-of (u8-list->bytevector (list 1 2 3 4))))
         (other (block-of (u8-list->bytevector (list 1 2 3 5)))))
    (show 'sizes sizes)
    (randombytes-buf random-block 9)
    (show 'randombytes (block-bytes random-block 10))
    (let ((answer (generichash out-block 7 in-block 3 key-block 2)))
      (show 'generichash (list answer (block-bytes out-block 8))))
    (let* ((equal-answer (memcmp a same 4))
           (differ-answer (memcmp a other 4))
           (len0-answer (memcmp a other 0))
           (null-first (memcmp 0 other 4))
           (null-second (memcmp a 0 4)))
      (show 'memcmp (list equal-answer differ-answer len0-answer null-first null-second)))
    (show 'calls (drive-calls))
    (when (option "--overflow") (drive-overflow))
    (for-each foreign-free (list random-block out-block in-block key-block a same other))))

(when (option "--drive")
  (drive)
  (show 'counts (native-counts))
  (show 'valgrind (if (under-valgrind?) 'yes 'no))
  (exit 0))

(define first (reference))

(define status
  (case (car first)
    ((loaded)
     (let ((info (cdr first)))
       (for-each (lambda (key)
                   (show (if (eq? key 'path) 'loaded key) (cdr (assq key info))))
                 '(path source version major minor init))
       (when (option "--sizes")
         (show 'sizes
               (guard (e (#t (cons 'raised (raised-facts e))))
                 (map (lambda (name) (eval name native))
                      '(generichash-bytes generichash-bytes-min generichash-bytes-max
                        generichash-keybytes-min generichash-keybytes-max)))))
       0))
    ((refused)
     (let ((e (cdr first)))
       (show 'reason (sodium-library-unavailable-reason e))
       (show 'who (and (who-condition? e) (condition-who e)))
       (show 'path (sodium-library-unavailable-path e))
       (show 'source (sodium-library-unavailable-source e))
       (show 'detail (sodium-library-unavailable-detail e))
       (show 'candidates (sodium-library-unavailable-candidates e))
       (show 'irritants (and (irritants-condition? e) (condition-irritants e)))
       (when (option "--message")
         (show 'message (and (message-condition? e) (condition-message e))))
       1))
    (else
     (show 'raised (raised-facts (cdr first)))
     2)))

(let ((path (option "--then-override")))
  (when path
    (putenv "CHEZ_SODIUM_LIBRARY" path)
    (show 'then-override (getenv "CHEZ_SODIUM_LIBRARY"))))

(let* ((second (reference))
       (third (reference)))
  (show 'again (list (later first second) (later first third))))

(when (and (option "--init-after") (eq? (car first) 'loaded))
  (show 'init-after (guard (e (#t (cons 'raised (raised-facts e)))) (direct-init))))

(let ((n (option "--wipe")))
  (when (and n (eq? (car first) 'loaded))
    (show 'wipe
          (guard (e (#t (cons 'raised (raised-facts e))))
            (eval `(call-in-section
                    (lambda ()
                      (call-with-bytes 'probe (make-bytevector ,(string->number n) 65)
                                       (lambda (address) 'ok))))
                  native)))))

(show 'counts (native-counts))

(let ((marker (option "--marker")))
  (when marker
    (show 'marker (if (foreign-entry? marker) 'present 'absent))))

(show 'valgrind (if (under-valgrind?) 'yes 'no))

(when (foreign-entry? "decoy_calls")
  (show 'calls (read-c-string ((foreign-procedure "decoy_calls" () uptr)))))

(exit status)
