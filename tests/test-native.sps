#!r6rs
;;; The suite for (chez-sodium private native), the load of libsodium and its
;;; helpers (ADR-0001, ADR-0002, ADR-0007, ADR-0008), in a process of its own.
;;; It is the first suite to load libsodium, and make test-memory runs it
;;; under Valgrind.
;;;
;;; Native's body is the load, and a guard in a program cannot catch a raise
;;; from an imported library's body. So this suite reaches native through
;;; eval, under a guard: a refused library names the row "native loads", and
;;; every row that needs native fails by name, where an import would kill the
;;; suite, unnamed, before its first line. Refusals themselves are the
;;; library-loading suites', each in a process of its own.
;;;
;;;   the load       the path and source equal what this suite chose itself:
;;;                  CHEZ_SODIUM_LIBRARY when it is set, else discovery on
;;;                  this suite's own inputs. The version, major, minor and
;;;                  sodium_init's answers equal what tests/libsodium-oracle.c
;;;                  reads in C from that same file, and the recorded answer
;;;                  is 0, the first in a fresh process. The answer is a
;;;                  fresh list, with fresh strings, at every call
;;;   the bindings   each of the five answers: the version string, major and
;;;                  minor, sodium_init (1 after the load, twice), and
;;;                  sodium_memzero over exactly N bytes. The codes of the
;;;                  three bound after them that a verb calls
;;;                  (randombytes_buf, crypto_generichash, sodium_memcmp)
;;;                  are test-native-codes'; the five size functions' values
;;;                  are the sizes' rows, below
;;;   the sizes      crypto_generichash's five sizes, read once at the load,
;;;                  equal what the C oracle reads through the library and
;;;                  through the header's macros, and brief 3.4's 32, 16, 64,
;;;                  16 and 64
;;;   bytes          call-with-bytes: a bytevector's bytes, U+0000 and bytes
;;;                  past ASCII kept, in a counted block of at least one byte,
;;;                  never NULL for none, written 0 for none; freed on
;;;                  return, raise and escape, re-entry refused; a value that
;;;                  is no bytevector refused by its kind alone, from the WHO
;;;                  it is given, with no secret in the condition.
;;;                  foreign-bytes and c-string->bytevector read bytes back
;;;                  undecoded into fresh bytevectors, and c-string->string
;;;                  reads through the second: a version string that begins
;;;                  with a byte order mark is no version
;;;   the writers   call-with-c-string, call-with-utf8 and foreign-ascii-string
;;;                  are test-blocks' rows; here the source rows hold that
;;;                  neither writer copies its string, and the password hash's
;;;                  seventeen bindings and fourteen constants are held to the
;;;                  oracle's lines and to the measured numbers
;;;   call-in-section
;;;                  its answer, whatever the shape; interrupts off inside;
;;;                  a raise of anything reaches a handler at depth 1, as
;;;                  the same object; a guard that does not match around it
;;;                  receives the caller's own object; and under an engine,
;;;                  at every fuel from 1 until the job completes, it
;;;                  answers right, raises nothing and leaves no block
;;;   after the section
;;;                  each helper's refusals are raised outside the critical
;;;                  dynamic-wind thunks that make and free its block: a
;;;                  with-exception-handler handler of one runs at depth 1,
;;;                  with interrupts enabled (disable-interrupts answers 1
;;;                  outside any section). A row each for re-entry, and for
;;;                  the free of a block PROC freed itself: that dead block is
;;                  refused unwiped. A write to it is seen by test-wipe's
;;                  dead-block row in any run (the next block of its size is
;;                  the same chunk, and still holds what PROC left), and by
;;                  Valgrind, under make test-memory, as "Invalid write of
;;                  size 1". test-blocks' W3 holds the same rule one level down
;;   the body       native.sls read as data, every form, define-syntax
;;;                  templates included: the load is one definition, its
;;;                  steps in order; every foreign-procedure form (thirty,
;;;                  two of them __collect_safe) is bound eagerly, the whole second argument of bind-required and
;;;                  the whole init of its let* binding; the load's work is in
;;;                  that definition alone; foreign-block and
;;;                  free-foreign-block! appear only in call-with-block's
;;;                  definition, which hands free-foreign-block! the wipe;
;;;                  call-with-bytes copies nothing. With one good library in
;;;                  one process none of these can be seen by behaviour: the
;;;                  load runs once, and every check passes. A decoy library
;;;                  sees them
;;;
;;; Every computation that can raise runs under a guard with a sentinel of its
;;; own: SRFI-64 makes #f of a raise in an actual expression, and catches
;;; none in an expected expression or a top-level definition. No expected
;;; value here is #f for something that can raise. Effects run in order,
;;; through let* and named lets, never map. Every engine row refers to native
;;; once, at the top of the suite, before its first engine: a library first
;;; reached inside an engine that is then abandoned stays wedged.
;;;
;;; The oracle is a child process: C reading libsodium, not chez-sodium's
;;; native layer, and it keeps no counts. Under make test-memory it runs under
;;; the gate's own Valgrind (tests/libsodium-oracle.sls).
(import (rnrs)
        (rnrs eval)
        (rnrs mutable-pairs)
        (rnrs mutable-strings)
        (srfi :64)
        (only (chezscheme) foreign-ref foreign-set! getenv immutable-string? machine-type void
              library-exports disable-interrupts enable-interrupts make-engine)
        (chez-sodium-testing)
        (libsodium-oracle)
        (chez-sodium private counters)
        (chez-sodium private memory)
        (chez-sodium private discovery)
        (only (chez-sodium private verify) check-version)
        (only (chez-sodium private conditions)
              chez-sodium-error? sodium-library-unavailable? sodium-library-unavailable-reason))

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

;; --- native, reached through eval -----------------------------------------------------------

;; native-load : (U 'loaded (List 'raised String))
;; Whether (chez-sodium private native) loaded: its body runs at this first
;; reference, under a guard. It is also the one reference every engine row
;; follows.
(define native-load
  (guard (e (#t (list 'raised (describe e))))
    (eval '(loaded-libsodium) (environment '(chez-sodium private native)))
    'loaded))

;; The counts once the load has returned.
(define counts-after-load (native-counts))

;; native-procedure : Symbol -> Procedure
;; NAME's procedure in (chez-sodium private native); when the load failed, or
;; NAME is not exported, a procedure that raises that, with NAME, every time
;; it is called, so each test that calls it fails by name.
(define (native-procedure name)
  (guard (e (#t (lambda args
                  (error name "(chez-sodium private native) could not be reached" (describe e)))))
    (eval name (environment '(chez-sodium private native)))))

(define loaded-libsodium (native-procedure 'loaded-libsodium))
(define sodium-version (native-procedure 'sodium-version))
(define sodium-version-string (native-procedure 'sodium-version-string))
(define sodium-library-version-major (native-procedure 'sodium-library-version-major))
(define sodium-library-version-minor (native-procedure 'sodium-library-version-minor))
(define sodium-init (native-procedure 'sodium-init))
(define sodium-memzero (native-procedure 'sodium-memzero))
(define randombytes-buf (native-procedure 'randombytes-buf))
(define crypto-generichash (native-procedure 'crypto-generichash))
(define sodium-memcmp (native-procedure 'sodium-memcmp))
;; The five sizes are numbers, fetched the same way: a failed fetch answers a
;; procedure, which no size row expects.
(define generichash-bytes (native-procedure 'generichash-bytes))
(define generichash-bytes-min (native-procedure 'generichash-bytes-min))
(define generichash-bytes-max (native-procedure 'generichash-bytes-max))
(define generichash-keybytes-min (native-procedure 'generichash-keybytes-min))
(define generichash-keybytes-max (native-procedure 'generichash-keybytes-max))
(define call-in-section (native-procedure 'call-in-section))
(define call-with-block (native-procedure 'call-with-block))
(define call-with-bytes (native-procedure 'call-with-bytes))
(define foreign-bytes (native-procedure 'foreign-bytes))
(define c-string->bytevector (native-procedure 'c-string->bytevector))
(define c-string->string (native-procedure 'c-string->string))

;; info : Any
;; The load's record, or (raised TEXT).
(define info
  (guard (e (#t (list 'raised (describe e))))
    (loaded-libsodium)))

;; --- helpers ---------------------------------------------------------------------------------

(define zero-counts '((block . 0)))

;; counts-with : (Listof (Pairof Symbol Integer)) -> (Listof (Pairof Symbol Integer))
;; zero-counts, with each kind in CHANGES at its count.
(define (counts-with changes)
  (map (lambda (entry) (cond ((assq (car entry) changes) => (lambda (c) c)) (else entry)))
       zero-counts))

;; shape : Any -> Any
;; A raised object as a row compares it: an assertion violation by its who and
;; irritants, any other condition as text, anything else as itself. Never a
;; message.
(define (shape e)
  (cond ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
         (list 'assertion-violation (condition-who e) (condition-irritants e)))
        ((condition? e) (list 'other (describe e)))
        (else e)))

;; raised : (-> Any) -> Any
;; What THUNK raised: (assertion-violation WHO IRRITANTS), (other TEXT)
;; for any other raise, or (no-raise VALUE).
(define (raised thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (message-condition? e)
                  (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (list 'no-raise (thunk))))

;; poke! : Natural (Listof Natural) -> Void
(define (poke! address bytes)
  (let loop ((i 0) (bytes bytes))
    (unless (null? bytes)
      (foreign-set! 'unsigned-8 address i (car bytes))
      (loop (+ i 1) (cdr bytes)))))

;; peek : Natural Natural -> (Listof Natural)
(define (peek address n)
  (let loop ((i (- n 1)) (found '()))
    (if (< i 0) found (loop (- i 1) (cons (foreign-ref 'unsigned-8 address i) found)))))

;; make-list-of : Natural Any -> (Listof Any)
(define (make-list-of n x) (if (= n 0) '() (cons x (make-list-of (- n 1) x))))

;; no-wipe : Natural Natural -> #f
;; A wipe that does nothing: the blocks this suite makes itself need none, and
;; a block freed with it keeps what it held.
(define (no-wipe address size) #f)

;; with-block : Natural (Natural -> Any) -> Any
;; PROC's answer, given a counted block of SIZE bytes, freed after.
(define (with-block size proc)
  (let ((block (foreign-block size)))
    (dynamic-wind
      (lambda () #f)
      (lambda () (proc block))
      (lambda () (free-foreign-block! block no-wipe)))))

(define (sorted-names names)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) names))

;; string-has? : String String -> Boolean
;; Whether TEXT holds NEEDLE.
(define (string-has? text needle)
  (let ((n (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i n) (string-length text)) #f)
            ((string=? (substring text i (+ i n)) needle) #t)
            (else (loop (+ i 1)))))))

;; A refusal is compared by its kind, who and irritants, never its message
;; text (ADR-0006).

;; --- what this suite chose, and what the oracle read there -------------------------------------

;; maps-text : -> (U String #f)
;; /proc/self/maps, read whole; #f when it cannot be read, as off Linux.
(define (maps-text)
  (guard (e (#t #f))
    (let ((text (call-with-port
                 (open-file-input-port "/proc/self/maps" (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 get-string-all)))
      (and (string? text) text))))

;; expected-choice : (U (Pairof String Symbol) (List 'raised String))
;; The path and source, chosen here without native: CHEZ_SODIUM_LIBRARY as
;; given when it is set, as the container sets it; otherwise discovery's
;; answer on this suite's own inputs, as on CI's main job.
(define expected-choice
  (guard (e (#t (list 'raised (describe e))))
    (let ((override (getenv "CHEZ_SODIUM_LIBRARY")))
      (if override
          (cons override 'override)
          (call-with-values
           (lambda () (choose-libsodium getenv (machine-type) (maps-text) file-exists?))
           cons)))))

(define expected-path
  (and (pair? expected-choice) (string? (car expected-choice)) (car expected-choice)))

;; oracle : (U (Listof (Pairof Symbol Any)) (List 'no-oracle Symbol Any))
(define oracle
  (if expected-path
      (libsodium-oracle getenv expected-path)
      (list 'no-oracle 'no-path expected-choice)))

;; read-by-oracle : Symbol -> Pair
;; The oracle's (FIELD . VALUE), or (FIELD no-oracle) when it failed.
(define (read-by-oracle field)
  (or (and (list? oracle) (for-all pair? oracle) (assq field oracle))
      (list field 'no-oracle)))

;; recorded : Symbol -> Any
;; KEY's value in the load's record.
(define (recorded key)
  (if (and (list? info) (assq key info))
      (cdr (assq key info))
      (list 'no-record key info)))

;; reported : Symbol -> Pair
;; What native reports for FIELD, as (FIELD . VALUE), or (FIELD raised TEXT).
;; init is (RECORDED DIRECT): the answer the load recorded, and a call of
;; sodium_init made after it, in that order.
(define (reported field)
  (cons field
        (guard (e (#t (list 'raised (describe e))))
          (case field
            ((version major minor) (recorded field))
            ((init) (let* ((first (recorded 'init))
                           (second (sodium-init)))
                      (list first second)))
            (else 'no-accessor)))))

(test-begin "native")

;; --- the load ----------------------------------------------------------------------------------

(test-equal "(chez-sodium private native) loads, reached through eval"
  'loaded
  native-load)

(test-equal "every count is zero once the load has returned"
  zero-counts
  counts-after-load)

;; No back door: the exports, written out whole. Neither foreign-block nor
;; free-foreign-block! is among them (ADR-0012).
(test-equal "(chez-sodium private native) exports exactly the load's record, the eleven raw bindings, the five sizes, the fourteen password constants, call-in-section and the block, byte and string helpers, and neither foreign-block nor free-foreign-block!"
  (sorted-names '(loaded-libsodium sodium-version
                  sodium-version-string sodium-library-version-major sodium-library-version-minor
                  sodium-init sodium-memzero
                  randombytes-buf crypto-generichash sodium-memcmp
                  generichash-bytes generichash-bytes-min generichash-bytes-max
                  generichash-keybytes-min generichash-keybytes-max
                  crypto-pwhash-str crypto-pwhash-str-verify crypto-pwhash-str-needs-rehash
                  pwhash-strbytes pwhash-strprefix
                  pwhash-opslimit-min pwhash-opslimit-max pwhash-opslimit-interactive
                  pwhash-opslimit-moderate pwhash-opslimit-sensitive
                  pwhash-memlimit-min pwhash-memlimit-max pwhash-memlimit-interactive
                  pwhash-memlimit-moderate pwhash-memlimit-sensitive
                  pwhash-passwd-min pwhash-passwd-max
                  call-in-section call-with-block call-with-bytes foreign-bytes
                  call-with-c-string call-with-utf8 foreign-ascii-string
                  c-string->bytevector c-string->string))
  (guard (e (#t (list 'raised (describe e))))
    (sorted-names (library-exports '(chez-sodium private native)))))

;; Two calls are two lists, two strings each, and nothing a caller does to one
;; reaches the next: a shared answer would hand out one mutable string.
(test-equal "loaded-libsodium answers a fresh list at every call: its keys in order, equal and never eq?, fresh strings, and what a caller changes in one never reaches the next"
  '((path source version major minor init) #t #f #f #f #t)
  (guard (e (#t (list 'raised (describe e))))
    (let* ((a (loaded-libsodium))
           (b (loaded-libsodium))
           (keys (map car a))
           (same-equal (equal? a b))
           (same-list (eq? a b))
           (same-path (eq? (cdr (assq 'path a)) (cdr (assq 'path b))))
           (same-version (eq? (cdr (assq 'version a)) (cdr (assq 'version b)))))
      (string-set! (cdr (assq 'path a)) 0 #\X)
      (string-set! (cdr (assq 'version a)) 0 #\X)
      (set-cdr! (assq 'major a) 9999)
      (let ((c (loaded-libsodium)))
        (list keys same-equal same-list same-path same-version (equal? b c))))))

;; The load called sodium_init once: a call here is the second, and answers 1.
;; A load that never called it, or recorded a constant, leaves this call the
;; first, answering 0. So this row stays before every other that calls it: the
;; first direct call in the process is the one that tells.
(test-equal "sodium-init, called after the load, answers 1, and again 1: the load called it first"
  '(1 1)
  (guard (e (#t (list 'raised (describe e))))
    (let* ((first (sodium-init))
           (second (sodium-init)))
      (list first second))))

(test-equal "this suite chose a path itself: CHEZ_SODIUM_LIBRARY when set, else discovery's"
  'chosen
  (if expected-path 'chosen expected-choice))

(test-equal "the load's path and source are the ones this suite chose"
  (guard (e (#t (list 'unchosen (describe e))))
    (list (car expected-choice) (cdr expected-choice)))
  (guard (e (#t (list 'raised (describe e))))
    (list (recorded 'path) (recorded 'source))))

(test-equal "the C oracle read the library at that path"
  'read
  (if (eq? (car oracle) 'no-oracle) oracle 'read))

;; The oracle runs under Valgrind exactly when the gate asked, so a child that
;; escaped the gate fails here, by name.
(test-equal "the C oracle ran under Valgrind exactly when the gate asked"
  (if (getenv "CHEZ_SODIUM_GATE_CHILD") '(valgrind . yes) '(valgrind . no))
  (read-by-oracle 'valgrind))

(for-each
 (lambda (field)
   (test-equal (string-append "native's " (symbol->string field) " is the C oracle's, whole")
     (read-by-oracle field)
     (reported field)))
 oracle-fields)

;; crypto_generichash's five sizes, native's against the oracle's line
;; (NAME F M): F is the size function's answer through the library, M the
;; header's macro. A size native read from another function, or twice, or
;; wrote in Scheme, is not both.

;; native-size : Symbol -> Any
;; NAME's size as native answers it, or (raised TEXT).
(define (native-size name)
  (guard (e (#t (list 'raised (describe e))))
    (case name
      ((generichash-bytes) generichash-bytes)
      ((generichash-bytes-min) generichash-bytes-min)
      ((generichash-bytes-max) generichash-bytes-max)
      ((generichash-keybytes-min) generichash-keybytes-min)
      ((generichash-keybytes-max) generichash-keybytes-max)
      (else 'no-such-size))))

;; oracle-size : Symbol Natural -> Any
;; The oracle's line (NAME F M)'s F (INDEX 1) or M (INDEX 2), or no-oracle.
(define (oracle-size name index)
  (let ((line (read-by-oracle name)))
    (if (and (list? line) (= (length line) 3)) (list-ref line index) (list name 'no-oracle))))

(for-each
 (lambda (name)
   (test-equal (string-append "native's " (symbol->string name)
                              " is F of the oracle's line (" (symbol->string name) " F M): the size function's answer")
     (oracle-size name 1)
     (native-size name))
   (test-equal (string-append "native's " (symbol->string name)
                              " is M of the oracle's line (" (symbol->string name) " F M): the header's macro")
     (oracle-size name 2)
     (native-size name)))
 oracle-size-fields)

(test-equal "the five sizes are brief 3.4's 32, 16, 64, 16 and 64, written here: native's, and the oracle's F and M of each line"
  '((generichash-bytes 32 32 32) (generichash-bytes-min 16 16 16) (generichash-bytes-max 64 64 64)
    (generichash-keybytes-min 16 16 16) (generichash-keybytes-max 64 64 64))
  (let loop ((names oracle-size-fields) (found '()))
    (if (null? names)
        (reverse found)
        (loop (cdr names)
              (cons (list (car names) (native-size (car names))
                          (oracle-size (car names) 1) (oracle-size (car names) 2))
                    found)))))

;; The password hash's fourteen constants, native's against the oracle's line
;; (NAME F M), as the sizes are, and against the numbers measured at 1.0.18
;; and 1.0.22, written out here. A constant read from another function, called
;; twice or written in Scheme is not all of F, M and the number. The twins,
;; opslimit-max and passwd-max, answer the same at every release, so no row
;; here tells one read into the other's key; the decoy's rows do.

;; native-constant : Symbol -> Any
;; NAME's constant as native answers it, or (raised TEXT).
(define (native-constant name)
  (guard (e (#t (list 'raised (describe e))))
    (eval name (environment '(chez-sodium private native)))))

(for-each
 (lambda (name)
   (test-equal (string-append "native's " (symbol->string name)
                              " is F of the oracle's line (" (symbol->string name) " F M): the function's answer")
     (oracle-size name 1)
     (native-constant name))
   (test-equal (string-append "native's " (symbol->string name)
                              " is M of the oracle's line (" (symbol->string name) " F M): the header's macro")
     (oracle-size name 2)
     (native-constant name)))
 oracle-pwhash-fields)

(test-equal "native's pwhash-strprefix is an immutable string, or #f for NULL: every importer shares it, so none can alter it"
  'ok
  (let ((prefix (native-constant 'pwhash-strprefix)))
    (cond ((not prefix) 'ok)
          ((not (string? prefix)) (list 'not-a-string prefix))
          ((immutable-string? prefix) 'ok)
          (else 'mutable))))

(test-equal "the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line"
  '((pwhash-strbytes 128 128 128)
    (pwhash-strprefix "$argon2id$" "$argon2id$" "$argon2id$")
    (pwhash-opslimit-min 1 1 1)
    (pwhash-opslimit-max 4294967295 4294967295 4294967295)
    (pwhash-opslimit-interactive 2 2 2)
    (pwhash-opslimit-moderate 3 3 3)
    (pwhash-opslimit-sensitive 4 4 4)
    (pwhash-memlimit-min 8192 8192 8192)
    (pwhash-memlimit-max 4398046510080 4398046510080 4398046510080)
    (pwhash-memlimit-interactive 67108864 67108864 67108864)
    (pwhash-memlimit-moderate 268435456 268435456 268435456)
    (pwhash-memlimit-sensitive 1073741824 1073741824 1073741824)
    (pwhash-passwd-min 0 0 0)
    (pwhash-passwd-max 4294967295 4294967295 4294967295))
  (let loop ((names oracle-pwhash-fields) (found '()))
    (if (null? names)
        (reverse found)
        (loop (cdr names)
              (cons (list (car names) (native-constant (car names))
                          (oracle-size (car names) 1) (oracle-size (car names) 2))
                    found)))))

;; The oracle's hex mode: C hashes and C verifies the bytes a hex string
;; spells, at libsodium's minimum limits. A hash that verified for anything,
;; or a verify that answered 0 for anything, fails the rows against a wrong
;; password and against each other's empty one.

;; bytes->hex : Bytevector -> String
(define (bytes->hex bytes)
  (let loop ((i (- (bytevector-length bytes) 1)) (digits '()))
    (if (< i 0)
        (apply string-append digits)
        (loop (- i 1)
              (cons (let ((h (number->string (bytevector-u8-ref bytes i) 16)))
                      (if (< (string-length h) 2) (string-append "0" h) h))
                    digits)))))

;; hex-verdicts : (Listof Any)
;; The (valgrind . ...) line of each hex-mode run since the last
;; take-verdicts, or the (no-oracle ...) answer of one that gave none.
(define hex-verdicts '())

;; take-verdicts! : -> (Listof Any)
;; The runs' verdicts, each distinct one once, in the order first seen; the
;; record is emptied.
(define (take-verdicts!)
  (let ((seen (let loop ((rest (reverse hex-verdicts)) (kept '()))
                (cond ((null? rest) (reverse kept))
                      ((member (car rest) kept) (loop (cdr rest) kept))
                      (else (loop (cdr rest) (cons (car rest) kept)))))))
    (set! hex-verdicts '())
    seen))

;; hex-answer : Symbol Any -> Any
;; ANSWER's value when it is (KEY VALUE VERDICT), the verdict recorded; ANSWER
;; itself otherwise, recorded as the verdict too, so a run that gave none fails
;; the row that asserts the verdicts.
(define (hex-answer key answer)
  (if (and (list? answer) (= (length answer) 3) (eq? (car answer) key))
      (begin (set! hex-verdicts (cons (caddr answer) hex-verdicts))
             (cadr answer))
      (begin (set! hex-verdicts (cons answer hex-verdicts))
             answer)))

;; oracle-hash : String -> (U String Any)
;; The hash string the oracle's hex mode made for HEX, or what it answered.
(define (oracle-hash hex)
  (guard (e (#t (list 'raised (describe e))))
    (hex-answer 'hash (libsodium-oracle-hash getenv expected-path hex))))

;; oracle-verify : String String -> Any
;; The oracle's verify code for STRING and HEX, or what it answered.
(define (oracle-verify string hex)
  (guard (e (#t (list 'raised (describe e))))
    (hex-answer 'verify (libsodium-oracle-verify getenv expected-path string hex))))

;; expected-verdicts : (Listof Pair)
;; What every hex-mode run must report: under Valgrind exactly when the gate asked.
(define expected-verdicts
  (list (if (getenv "CHEZ_SODIUM_GATE_CHILD") '(valgrind . yes) '(valgrind . no))))

(define hex-nonascii (bytes->hex (string->utf8 "p\x00E4;ssw\x00F6;rd\x20AC;")))
(define hex-nonascii-changed (bytes->hex (string->utf8 "p\x00E4;ssw\x00F6;rd\x20AD;")))

(test-equal "the oracle's hex mode hashes at the minimum limits and verifies its own hash: right 0, wrong -1, for a non-ASCII password, a password with a NUL, and the empty one, every run under Valgrind exactly when the gate asked"
  (list '("$argon2id$v=19$m=8,t=1,p=1$" 93)
        '("$argon2id$v=19$m=8,t=1,p=1$" 93)
        '("$argon2id$v=19$m=8,t=1,p=1$" 93)
        '(0 -1) '(0 -1) '(0 -1)
        expected-verdicts)
  (let* ((h1 (oracle-hash hex-nonascii))
         (h2 (oracle-hash "610062"))
         (h3 (oracle-hash ""))
         (shape (lambda (h) (if (string? h)
                                (list (substring h 0 (min 27 (string-length h))) (string-length h))
                                h))))
    (let* ((v1 (list (oracle-verify h1 hex-nonascii) (oracle-verify h1 hex-nonascii-changed)))
           (v2 (list (oracle-verify h2 "610062") (oracle-verify h2 "610063")))
           (v3 (list (oracle-verify h3 "") (oracle-verify h3 "61"))))
      (list (shape h1) (shape h2) (shape h3) v1 v2 v3 (take-verdicts!)))))

(test-equal "the oracle's hex mode: a hash of \"a\" does not verify the empty password, and the empty hash does not verify \"a\"; two hashes of one password differ"
  (list -1 -1 #f expected-verdicts)
  (let* ((ha (oracle-hash "61")) (he (oracle-hash "")) (ha2 (oracle-hash "61"))
         (a (oracle-verify ha "")) (b (oracle-verify he "61")))
    (list a b (equal? ha ha2) (take-verdicts!))))

;; sodium_init's first answer in a process, 0, and its second, 1, written out
;; as the oracle reads them in a fresh process, not computed from native.
(test-equal "the C oracle's own sodium_init answers are 0, then 1, in a fresh process"
  '(init 0 1)
  (read-by-oracle 'init))

(test-equal "sodium-version is the recorded version, the oracle's, and a fresh string at every call: what a caller changes in one never reaches the next"
  (list (cdr (read-by-oracle 'version)) (cdr (read-by-oracle 'version)) #f "X")
  (guard (e (#t (list 'raised (describe e))))
    (let* ((a (sodium-version))
           (b (sodium-version))
           (same (eq? a b))
           (changed (begin (string-set! a 0 #\X) (substring a 0 1)))
           (c (sodium-version)))
      (list c (recorded 'version) same changed))))

(test-equal "sodium-version-string's address reads as the version, and the library's major and minor are the oracle's, never swapped"
  (list (cdr (read-by-oracle 'version)) (cdr (read-by-oracle 'major)) (cdr (read-by-oracle 'minor)))
  (guard (e (#t (list 'raised (describe e))))
    (let* ((version (c-string->string (sodium-version-string)))
           (major (sodium-library-version-major))
           (minor (sodium-library-version-minor)))
      (list version major minor))))

(test-equal "sodium-memzero zeroes exactly N bytes: 16 of 16, 15 of 16 with the last left, none of 16; it answers the unspecified value, and nothing is left counted"
  (list (list (void) (make-list-of 16 0))
        (list (void) (append (make-list-of 15 0) '(#x41)))
        (list (void) (make-list-of 16 #x41))
        zero-counts)
  (guard (e (#t (list 'raised (describe e))))
    (let ((run (lambda (n)
                 (with-block 16
                   (lambda (block)
                     (poke! block (make-list-of 16 #x41))
                     (let ((answer (sodium-memzero block n)))
                       (list answer (peek block 16))))))))
      (let* ((a (run 16))
             (b (run 15))
             (c (run 0)))
        (list a b c (native-counts))))))

;; --- c-string->string, and the byte order mark -----------------------------------------------

(test-equal "c-string->string answers #f for NULL, compared as the symbol null, and refuses what is no address"
  (list 'null
        (list 'assertion-violation 'c-string->string '(x))
        (list 'assertion-violation 'c-string->string '(-1))
        (list 'assertion-violation 'c-string->string '(1.5)))
  (let* ((null (guard (e (#t (list 'raised (describe e))))
                 (let ((r (c-string->string 0))) (if (eq? r #f) 'null r))))
         (a (raised (lambda () (c-string->string 'x))))
         (b (raised (lambda () (c-string->string -1))))
         (c (raised (lambda () (c-string->string 1.5)))))
    (list null a b c)))

;; Chez's utf8->string drops one leading U+FEFF. Each block is read as bytes
;; the row writes itself, so no encoder is under test. Invalid bytes are
;; replaced, never refused: the second block's FF is U+FFFD.
(test-equal "c-string->string reads EF BB BF 61 as U+FEFF then a, keeps a second U+FEFF, keeps one before an invalid byte (replaced, not refused), and reads a BOM-less block and a 2-byte EF BB as before"
  (list "\xFEFF;a" "\xFEFF;\xFEFF;a" "\xFEFF;\xFFFD;" "a\xFEFF;" "\xFFFD;")
  (guard (e (#t (list 'raised (describe e))))
    (let ((read (lambda (bytes)
                  (with-block 8
                    (lambda (block)
                      (poke! block (append bytes '(0)))
                      (c-string->string block))))))
      (let* ((a (read '(#xEF #xBB #xBF #x61)))
             (b (read '(#xEF #xBB #xBF #xEF #xBB #xBF #x61)))
             (c (read '(#xEF #xBB #xBF #xFF)))
             (d (read '(#x61 #xEF #xBB #xBF)))
             (e2 (read '(#xEF #xBB))))
        (list a b c d e2)))))

;; The restoration of U+FEFF protects the floor: a version string that is a
;; byte order mark and then 1.0.18 would read as "1.0.18" through a plain
;; utf8->string, and pass the floor. As it is, it reads with the mark, and
;; check-version refuses it. The control, "1.0.18" itself, is accepted, so the
;; refusal is the mark's.
(test-equal "a version string of EF BB BF 31 2E 30 2E 31 38 reads as U+FEFF then 1.0.18, and check-version refuses it as below-floor, where plain 1.0.18 passes"
  (list "\xFEFF;1.0.18" '(refused below-floor) 'accepted)
  (guard (e (#t (list 'raised (describe e))))
    (let* ((read (with-block 16
                   (lambda (block)
                     (poke! block '(#xEF #xBB #xBF #x31 #x2E #x30 #x2E #x31 #x38 0))
                     (c-string->string block))))
           (check (lambda (version)
                    (guard (e (#t (if (sodium-library-unavailable? e)
                                      (list 'refused (sodium-library-unavailable-reason e))
                                      (list 'other (describe e)))))
                      (check-version version "/some/libsodium.so.23" 'system)
                      'accepted))))
      (list read (check read) (check "1.0.18")))))

;; --- call-with-bytes, foreign-bytes and c-string->bytevector -------------------------------------
;; A hashed input and a read-back run cross in counted blocks and are copied by
;; native's own code (ADR-0001). No other library may read or write foreign
;; memory (check-seam).

;; long-bytes : Bytevector
;; 5,000 bytes, each its index modulo 256, so a copy that drops, repeats or
;; shifts a byte is told apart.
(define long-bytes
  (let ((b (make-bytevector 5000 0)))
    (let loop ((i 0))
      (when (< i 5000)
        (bytevector-u8-set! b i (mod i 256))
        (loop (+ i 1))))
    b))

;; in-block : Bytevector -> Any
;; What call-with-bytes hands PROC for BYTES: whether the address is a
;; pointer, never NULL; the block's first (max 1 n) bytes, read with
;; foreign-ref, as a bytevector, or same when they equal BYTES whole; and the
;; counts while PROC runs. Or what was raised.
(define (in-block bytes)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (call-with-bytes 'hash! bytes
      (lambda (address)
        (let* ((pointer? (and (integer? address) (exact? address) (positive? address)))
               (read (and pointer?
                          (u8-list->bytevector (peek address (max 1 (bytevector-length bytes)))))))
          (list (if pointer? 'pointer address)
                (if (and read (> (bytevector-length bytes) 0) (equal? read bytes)) 'same read)
                (native-counts)))))))

(test-equal "call-with-bytes hands C a bytevector's bytes in a counted block, never NULL: none is one byte, 0; 00, 61 00 62, 00 00 00 and C3 A9 FF FE 80 as given, U+0000 kept; 5,000 bytes whole; one block counted while PROC runs, and none after"
  (list (list 'pointer #vu8(0) (counts-with '((block . 1))))
        (list 'pointer 'same (counts-with '((block . 1))))
        (list 'pointer 'same (counts-with '((block . 1))))
        (list 'pointer 'same (counts-with '((block . 1))))
        (list 'pointer 'same (counts-with '((block . 1))))
        (list 'pointer 'same (counts-with '((block . 1))))
        zero-counts)
  (let* ((a (in-block #vu8()))
         (b (in-block #vu8(0)))
         (c (in-block #vu8(#x61 0 #x62)))
         (d (in-block #vu8(0 0 0)))
         (e (in-block #vu8(#xC3 #xA9 #xFF #xFE #x80)))
         (f (in-block long-bytes)))
    (list a b c d e f (native-counts))))

;; B5. call-with-bytes writes the byte for an empty bytevector itself. On a
;; fresh heap the byte is already 0, so "reads 0" proves nothing; the block
;; has to be one that held something else.
;; A plain run catches an unwritten byte through this row. Under the gate the
;; row is skipped, and Valgrind catches it instead: a read of the unwritten byte
;; is "Conditional jump or move depends on uninitialised value(s)". That the
;; one-byte block is wiped is held in every run by test-wipe's
;; empty-bytes-dirtied and return-1 rows. The one-byte block freed here is
;; the one malloc hands back, where it does (glibc's tcache), but the
;; allocator writes its own words over a freed block's first bytes, so the
;; byte may read anything. The CONTROL is the same reuse by a block nothing
;; writes: where it reads 0 or is not the same block, the row cannot tell a
;; written 0 from an unwritten one, and is skipped, named, with a line saying
;; why. Valgrind never reuses a block at once, so under the gate the row is
;; skipped.
(define empty-row-name "call-with-bytes writes the one byte for an empty bytevector itself: a reused block whose byte an unwritten block leaves non-zero reads 0")

(define empty-row-run
  (guard (e (#t (list 'raised (describe e))))
    (let* ((dirty (lambda ()
                    (with-block 1 (lambda (block) (poke! block '(#xFF)) block))))
           (freed (dirty))
           (control (with-block 1 (lambda (block) (list (eqv? block freed) (car (peek block 1))))))
           (freed-again (dirty)))
      (call-with-bytes 'hash! #vu8()
        (lambda (address)
          (list 'ran
                (and (eqv? address freed) (eqv? freed freed-again) (car control) (not (eqv? (cadr control) 0)))
                (if (positive? address) (peek address 1) 'null)))))))

;; reuse-unavailable? : Any -> Boolean
;; Whether a run completed where its control could not tell written from
;; unwritten.
(define (reuse-unavailable? run)
  (and (pair? run) (eq? (car run) 'ran) (pair? (cdr run)) (not (cadr run))))

;; skip-unavailable! : String Any -> Void
;; When RUN is reuse-unavailable?, say so by NAME and skip the test of that
;; name that follows: a skip is its own result, never a pass.
(define (skip-unavailable! name run)
  (when (reuse-unavailable? run)
    (display "UNAVAILABLE ")
    (display name)
    (display ": malloc did not hand back the block just freed, or an unwritten byte of it reads 0")
    (newline)
    (test-skip name)))

(skip-unavailable! empty-row-name empty-row-run)
(test-equal empty-row-name
  '(ran #t (0))
  empty-row-run)

(test-equal "call-with-bytes: a raise from PROC frees the block, and reaches the caller; so does an escape"
  (list 'proc-raised 'escaped zero-counts)
  (let* ((a (guard (e ((eq? e 'from-proc) 'proc-raised)
                      (#t (list 'other (describe e))))
              (call-with-bytes 'hash! #vu8(1 2 3) (lambda (address) (raise 'from-proc)))))
         (b (guard (e (#t (list 'other (describe e))))
              (call/cc
               (lambda (k)
                 (call-with-bytes 'hash! #vu8(1 2 3) (lambda (address) (k 'escaped))))))))
    (list a b (native-counts))))

(test-equal "call-with-bytes: re-entering PROC through a continuation, once the block is freed, raises from its WHO, and PROC runs once"
  (list (list 'assertion-violation 'hash! '()) 1 zero-counts)
  (let ((k #f) (runs 0))
    (let ((r (guard (e ((and (assertion-violation? e) (who-condition? e) (message-condition? e)
                             (irritants-condition? e))
                        (list 'assertion-violation (condition-who e) (condition-irritants e)))
                       (#t (list 'other (describe e))))
               (call-with-bytes 'hash! #vu8(1 2 3)
                 (lambda (address)
                   (call/cc (lambda (c) (set! k c)))
                   (set! runs (+ runs 1))))
               (if (= runs 1) (k #f) (list 'reentered runs)))))
      (list r runs (native-counts)))))

;; at-raise : (-> Any) (Condition -> Any) -> (List Any Any)
;; What THUNK raised, through HANDLE, and the native counts at the moment of
;; the raise: read by a handler that runs before any dynamic-wind's after
;; thunk, then raises on. The counts after are a separate reading.
(define (at-raise thunk handle)
  (let ((seen 'no-raise))
    (let ((r (guard (e (#t (handle e)))
               (with-exception-handler
                 (lambda (c) (set! seen (native-counts)) (raise c))
                 thunk))))
      (list r seen))))

;; refused-at-raise : (-> Any) -> (List Any Any Symbol)
;; What THUNK, a call-with-bytes whose PROC records that it ran, raised; the
;; counts at the raise; and whether PROC ran.
(define (refused-at-raise make-thunk)
  (let* ((ran #f)
         (r (at-raise (make-thunk (lambda (address) (set! ran #t) 'ran))
                      shape)))
    (append r (list (if ran 'proc-ran 'proc-not-run)))))

;; B4. A bytevector is a secret: a value that is no bytevector is named by its
;; kind alone, whatever it is, and the condition shown whole holds none of
;; its text. A symbol, a number and a list of characters are shown as they
;; are by shown-value, which is for sizes: refuse-secret is what keeps them
;; out. Each row is (VALUE KIND TEXT), TEXT what must not appear in the
;; condition, or #f where nothing can be told apart.
(define refused-values
  (list (list "hunter2" 'string "hunter2")
        (list 'hunter2 'symbol "hunter2")
        (list 12345 'number "12345")
        (list (list #\h #\u #\n #\t #\e #\r) 'list "#\\h")
        (list (vector 1 2) 'vector "#(1 2)")
        (list #f 'boolean #f)))

(for-each
 (lambda (row)
   (let ((value (car row)) (kind (cadr row)) (text (caddr row)))
     (test-equal (string-append "call-with-bytes refuses a " (symbol->string kind)
                                " as no bytevector, from its WHO, irritants (not-a-bytevector bytes (kind "
                                (symbol->string kind) ")), with nothing allocated at the raise and PROC not run")
       (list (list 'assertion-violation 'hash!
                   (list 'not-a-bytevector 'bytes (list 'kind kind)))
             zero-counts 'proc-not-run)
       (refused-at-raise (lambda (proc) (lambda () (call-with-bytes 'hash! value proc)))))
     (test-equal (string-append "call-with-bytes' refusal of a " (symbol->string kind)
                                " is an assertion violation and no &chez-sodium-error, and the condition shown whole holds none of its text")
       '(assertion-violation not-a-library-condition no-secret-text)
       (guard (e (#t (list (if (assertion-violation? e) 'assertion-violation 'other)
                           (if (chez-sodium-error? e) 'a-library-condition 'not-a-library-condition)
                           (if (and text (string-has? (describe e) text)) 'secret-text 'no-secret-text))))
         (call-with-bytes 'hash! value (lambda (address) 'ran))
         '(no-raise)))))
 refused-values)

(test-equal "call-with-bytes refuses a PROC that is no procedure, from its WHO, and a WHO that is no symbol, from itself, each by shown-value, with nothing allocated at the raise and PROC not run"
  (list (list (list 'assertion-violation 'hash! '(not-a-procedure)) zero-counts 'proc-not-run)
        (list (list 'assertion-violation 'call-with-bytes '((kind string))) zero-counts 'proc-not-run)
        zero-counts)
  (let* ((a (refused-at-raise (lambda (proc) (lambda () (call-with-bytes 'hash! #vu8(1) 'not-a-procedure)))))
         (b (refused-at-raise (lambda (proc) (lambda () (call-with-bytes "hash!" #vu8(1) proc))))))
    (list a b (native-counts))))

;; in-written-block : (Listof Natural) (Natural -> Any) -> Any
;; PROC's answer, given a counted block of at least BYTES' length holding
;; BYTES, freed after; or what was raised.
(define (in-written-block bytes proc)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (with-block (max 1 (length bytes))
      (lambda (block) (poke! block bytes) (proc block)))))

(test-equal "foreign-bytes reads N bytes at an address, undecoded, into a bytevector: 00 61 00 FF 80 C3 whole, its first 2, none at the block, and none at NULL, which it never reads"
  (list #vu8(0 #x61 0 #xFF #x80 #xC3) #vu8(0 #x61) #vu8() #vu8())
  (let* ((a (in-written-block '(0 #x61 0 #xFF #x80 #xC3) (lambda (b) (foreign-bytes b 6))))
         (b (in-written-block '(0 #x61 0 #xFF #x80 #xC3) (lambda (b) (foreign-bytes b 2))))
         (c (in-written-block '(#x61) (lambda (b) (foreign-bytes b 0))))
         (d (guard (e (#t (list 'raised (describe e)))) (foreign-bytes 0 0))))
    (list a b c d)))

(test-equal "foreign-bytes answers a fresh bytevector: the block written after the read leaves it, and two reads are two bytevectors"
  (list #vu8(1 2 3) 'two)
  (in-written-block '(1 2 3)
    (lambda (block)
      (let* ((first (foreign-bytes block 3))
             (second (foreign-bytes block 3)))
        (poke! block '(9 9 9))
        (list first (if (eq? first second) 'one 'two))))))

(test-equal "foreign-bytes refuses an address and a count that are no exact naturals, each named by its field and shown-value, and NULL with bytes to read, from itself"
  (list (list 'assertion-violation 'foreign-bytes '(address x))
        (list 'assertion-violation 'foreign-bytes '(address -1))
        (list 'assertion-violation 'foreign-bytes '(address 1.5))
        (list 'assertion-violation 'foreign-bytes '(count x))
        (list 'assertion-violation 'foreign-bytes '(count -1))
        (list 'assertion-violation 'foreign-bytes '(count 1.5))
        (list 'assertion-violation 'foreign-bytes '(null-address 1)))
  (let* ((a (raised (lambda () (foreign-bytes 'x 1))))
         (b (raised (lambda () (foreign-bytes -1 1))))
         (c (raised (lambda () (foreign-bytes 1.5 1))))
         (d (in-written-block '(1) (lambda (block) (raised (lambda () (foreign-bytes block 'x))))))
         (e (in-written-block '(1) (lambda (block) (raised (lambda () (foreign-bytes block -1))))))
         (f (in-written-block '(1) (lambda (block) (raised (lambda () (foreign-bytes block 1.5))))))
         (g (raised (lambda () (foreign-bytes 0 1)))))
    (list a b c d e f g)))

(test-equal "c-string->bytevector reads the bytes up to the NUL, undecoded: 61 62, none, FF, EF BB BF kept, C3 A9 before a NUL and 78; #f for NULL, compared as the symbol null"
  (list #vu8(#x61 #x62) #vu8() #vu8(#xFF) #vu8(#xEF #xBB #xBF) #vu8(#xC3 #xA9) 'null)
  (let* ((a (in-written-block '(#x61 #x62 0) c-string->bytevector))
         (b (in-written-block '(0) c-string->bytevector))
         (c (in-written-block '(#xFF 0) c-string->bytevector))
         (d (in-written-block '(#xEF #xBB #xBF 0) c-string->bytevector))
         (e (in-written-block '(#xC3 #xA9 0 #x78 0) c-string->bytevector))
         (f (guard (e (#t (list 'raised (describe e))))
              (let ((r (c-string->bytevector 0))) (if (eq? r #f) 'null r)))))
    (list a b c d e f)))

(test-equal "c-string->bytevector answers a fresh bytevector: the block written after the read leaves it, and two reads are two bytevectors"
  (list #vu8(1 2 3) 'two)
  (in-written-block '(1 2 3 0)
    (lambda (block)
      (let* ((first (c-string->bytevector block))
             (second (c-string->bytevector block)))
        (poke! block '(9 9 9 0))
        (list first (if (eq? first second) 'one 'two))))))

(test-equal "c-string->bytevector refuses what is no address, from itself, by shown-value"
  (list (list 'assertion-violation 'c-string->bytevector '(x))
        (list 'assertion-violation 'c-string->bytevector '(-1))
        (list 'assertion-violation 'c-string->bytevector '(1.5)))
  (let* ((a (raised (lambda () (c-string->bytevector 'x))))
         (b (raised (lambda () (c-string->bytevector -1))))
         (c (raised (lambda () (c-string->bytevector 1.5)))))
    (list a b c)))

;; --- call-in-section ------------------------------------------------------------------------------

;; interrupt-depth : -> Positive-Integer
;; How many critical sections this thread is inside, plus one: what
;; disable-interrupts answers, put back at once. 1 outside any section.
(define (interrupt-depth)
  (let ((n (disable-interrupts)))
    (enable-interrupts)
    n))

;; handler-depth : (-> Any) -> (U (List 'raised-at-depth Symbol Any) (List 'no-raise Any))
;; The depth a with-exception-handler handler runs at for the first thing
;; THUNK raises, read before anything else, and what it raised, shaped. The
;; handler escapes, so nothing returns into the raise.
(define (handler-depth thunk)
  (call/cc
   (lambda (k)
     (with-exception-handler
      (lambda (c)
        (let* ((depth (interrupt-depth))
               (what (shape c)))
          (k (list 'raised-at-depth
                   (string->symbol (string-append "depth-" (number->string depth)))
                   what))))
      (lambda () (list 'no-raise (thunk)))))))

;; depth-and-object : (-> Any) -> (List Symbol Any)
;; The depth a handler of THUNK's first raise runs at, and the raised object
;; itself, unshaped, so a row can ask whether it is the one raised.
(define (depth-and-object thunk)
  (call/cc
   (lambda (k)
     (with-exception-handler
      (lambda (c)
        (let ((depth (interrupt-depth)))
          (k (list (string->symbol (string-append "depth-" (number->string depth))) c))))
      (lambda () (list 'no-raise (thunk)))))))

;; C1: the answer is the thunk's value, whatever its shape; none is read as a
;; raise.
(test-equal "call-in-section answers THUNK's value: #f, 0, (), a list headed raised, and a string, none of them raised"
  (list #f 0 '() '(raised 5) "text")
  (guard (e (#t (list 'raised (describe e))))
    (let* ((a (call-in-section (lambda () #f)))
           (b (call-in-section (lambda () 0)))
           (c (call-in-section (lambda () '())))
           (d (call-in-section (lambda () (list 'raised 5))))
           (e2 (call-in-section (lambda () "text"))))
      (list a b c d e2))))

;; C2: inside the section interrupts are off, and outside it before and after
;; they are on.
(test-equal "call-in-section runs THUNK in one critical section: the interrupt depth is 1 before, 2 inside and 1 after"
  '(1 2 1)
  (let* ((before (interrupt-depth))
         (inside (call-in-section (lambda () (interrupt-depth))))
         (after (interrupt-depth)))
    (list before inside after)))

;; C3: a raise of anything is caught inside and raised again after the section,
;; as the same object: a handler of it runs at depth 1.
(test-equal "call-in-section raises what THUNK raised after its section: a symbol, a list, #f, a string and a condition each reach a handler at depth 1, as the very object"
  '((depth-1 same) (depth-1 same) (depth-1 same) (depth-1 same) (depth-1 same))
  (let* ((objects (list 'boom (list 'boom) #f (string #\b #\o #\o #\m) (make-assertion-violation)))
         (out '()))
    (for-each
     (lambda (object)
       (let ((r (depth-and-object (lambda () (call-in-section (lambda () (raise object)))))))
         (set! out (cons (list (car r) (if (eq? (cadr r) object) 'same 'different)) out))))
     objects)
    (reverse out)))

;; C4: a guard that does not match, between the caller and call-in-section,
;; re-enters the raise's extent to raise again. Around a bare call-with-bytes
;; that re-entry is refused, and the refusal replaces the caller's object;
;; under call-in-section the raise is already outside the extent, and the
;; caller's own object arrives.
(test-equal "an outer guard that does not match: around call-in-section, the caller's own object arrives; around a bare call-with-bytes, the re-entry's refusal replaces it"
  (list '(caught mine) '(caught (assertion-violation hash! ())))
  (let* ((around (lambda (body)
                   (guard (outer (#t (list 'caught (shape outer))))
                     (guard (inner ((string? inner) 'never))
                       (body)))))
         (under (around (lambda ()
                          (call-in-section
                           (lambda () (call-with-bytes 'hash! #vu8(1) (lambda (a) (raise 'mine))))))))
         (bare (around (lambda ()
                         (call-with-bytes 'hash! #vu8(1) (lambda (a) (raise 'mine)))))))
    (list under bare)))

;; --- under an engine ---------------------------------------------------------------------------
;; An engine spends no ticks inside a critical section, so no expiry falls in
;; call-in-section's, and an expiry in the prologue before it is resumed
;; harmlessly. Each row runs a job at every fuel from 1 until the first fuel at
;; which it completes without expiring, and asserts the outcome at each, never
;; the count of expiries. native was reached at the top of this suite, before
;; the first engine.

;; run-in-engine : Natural (-> Any) -> (List Any Natural)
;; THUNK run in an engine of FUEL ticks per run, resumed at each expiry until
;; it completes: (done VALUE) or (raised OBJECT), then how many times it
;; expired.
(define (run-in-engine fuel thunk)
  (let ((expiries 0))
    (let ((outcome
           (guard (e (#t (list 'raised e)))
             (let loop ((eng (make-engine thunk)))
               (eng fuel
                    (lambda (ticks answer) (list 'done answer))
                    (lambda (next) (set! expiries (+ expiries 1)) (loop next)))))))
      (list outcome expiries))))

;; sweep : (-> (-> Any)) (Any -> Boolean) -> Any
;; make-thunk's job run at each fuel from 1: every outcome must satisfy RIGHT?
;; and leave every count zero. 'every-fuel-right and 'reached-a-completing-fuel
;; when a fuel completes with no expiry; otherwise (wrong-at-fuel N OUTCOME
;; COUNTS), or never-completed past 5,000.
(define (sweep make-thunk right?)
  (let loop ((fuel 1))
    (if (> fuel 5000)
        'never-completed
        (let* ((run (run-in-engine fuel (make-thunk)))
               (counts (native-counts)))
          (cond ((not (and (right? (car run)) (equal? counts zero-counts)))
                 (list 'wrong-at-fuel fuel (shape-outcome (car run)) counts))
                ((= (cadr run) 0) '(every-fuel-right reached-a-completing-fuel))
                (else (loop (+ fuel 1))))))))

;; shape-outcome : Any -> Any
(define (shape-outcome outcome)
  (if (and (pair? outcome) (eq? (car outcome) 'raised))
      (list 'raised (shape (cadr outcome)))
      outcome))

(define sixty-four-bytes
  (let ((b (make-bytevector 64 0)))
    (let loop ((i 0))
      (when (< i 64) (bytevector-u8-set! b i (+ i 1)) (loop (+ i 1))))
    b))

(test-equal "C5 call-in-section around call-with-bytes of 64 bytes, under an engine at every fuel from 1 until it completes: each run answers the 64 bytes, raises nothing, and leaves no block"
  '(every-fuel-right reached-a-completing-fuel)
  (sweep (lambda ()
           (lambda ()
             (call-in-section
              (lambda ()
                (call-with-bytes 'hash! sixty-four-bytes
                  (lambda (address) (u8-list->bytevector (peek address 64))))))))
         (lambda (outcome) (equal? outcome (list 'done sixty-four-bytes)))))

(test-equal "C6 under an engine at every fuel: a raise from PROC caught inside THUNK answers as data, and a raise out of THUNK reaches the caller as the same object, both with no block left"
  '((every-fuel-right reached-a-completing-fuel) (every-fuel-right reached-a-completing-fuel))
  (let* ((boom (list 'boom))
         (caught (sweep (lambda ()
                          (lambda ()
                            (call-in-section
                             (lambda ()
                               (guard (e ((eq? e boom) 'caught-in-thunk))
                                 (call-with-bytes 'hash! sixty-four-bytes
                                   (lambda (address) (raise boom))))))))
                        (lambda (outcome) (equal? outcome '(done caught-in-thunk)))))
         (escaped (sweep (lambda ()
                           (lambda () (call-in-section (lambda () (raise boom)))))
                         (lambda (outcome)
                           (and (pair? outcome) (eq? (car outcome) 'raised)
                                (eq? (cadr outcome) boom))))))
    (list caught escaped)))

;; --- raised after the section ---------------------------------------------------------------------
;; A raise made inside a critical section, or a critical dynamic-wind thunk,
;; reaches a with-exception-handler handler with interrupts still disabled:
;; there an engine never expires, and another thread's collection waits for
;; the handler. Each row's handler reads its depth, as depth-N, and
;; what was raised.

;; reentered : ((Positive-Integer -> Any) -> Any) -> Any
;; What a handler of a re-entry into WITH's PROC sees: PROC keeps its
;; continuation, returns, and is entered again once its block is freed.
(define (reentered with)
  (let ((k #f) (runs 0))
    (let ((r (handler-depth
              (lambda ()
                (with (lambda (address)
                        (call/cc (lambda (c) (set! k c)))
                        (set! runs (+ runs 1))))
                (if (= runs 1) (k #f) (list 'reentered runs))))))
      (list r runs (native-counts)))))

(test-equal "D1 call-with-bytes refuses a re-entry outside its critical thunks, and its argument refusals come before any: a handler of each runs at depth 1, and PROC runs once"
  (list (list (list 'raised-at-depth 'depth-1 (list 'assertion-violation 'hash! '())) 1 zero-counts)
        (list 'raised-at-depth 'depth-1
              (list 'assertion-violation 'hash! '(not-a-bytevector bytes (kind string))))
        (list 'raised-at-depth 'depth-1 (list 'assertion-violation 'hash! '(x)))
        (list 'raised-at-depth 'depth-1 (list 'assertion-violation 'call-with-bytes '(42))))
  (let* ((a (reentered (lambda (proc) (call-with-bytes 'hash! #vu8(1 2 3) proc))))
         (b (handler-depth (lambda () (call-with-bytes 'hash! "abc" (lambda (address) address)))))
         (c (handler-depth (lambda () (call-with-bytes 'hash! #vu8(1) 'x))))
         (d (handler-depth (lambda () (call-with-bytes 42 #vu8(1) (lambda (address) address))))))
    (list a b c d)))

;; PROC frees the block it was handed, so the free on the way out finds no
;; live block there: free-foreign-block!'s refusal, raised outside the
;; critical after thunk that tried the free. The block is dead, so it is
;; refused unwiped, and nothing is freed twice. The refusal, its depth and the
;; counts hold in any run. That nothing wrote to the dead block holds only
;; under make test-memory, whose Valgrind reports a write to freed memory as
;; "Invalid write of size 1" (see the header).
(define (freed-by-proc-refusal wrap)
  (let* ((given #f)
         (r (handler-depth
             (lambda ()
               (wrap
                (lambda ()
                  (call-with-bytes 'hash! #vu8(1 2 3)
                    (lambda (address)
                      (set! given address)
                      (free-foreign-block! address no-wipe)
                      'freed-by-proc))))))))
    (list (if (and (eq? (car r) 'raised-at-depth)
                   (equal? (caddr r) (list 'assertion-violation 'free-foreign-block! (list given))))
              (list (car r) (cadr r) '(assertion-violation free-foreign-block! (that-block)))
              r)
          (native-counts))))

(test-equal "D2 call-with-bytes raises a failed free outside its critical after thunk: a PROC that freed its block itself makes free-foreign-block! refuse the dead block, unwiped, and a handler of that runs at depth 1; every count is zero after"
  (list (list 'raised-at-depth 'depth-1 '(assertion-violation free-foreign-block! (that-block))) zero-counts)
  (freed-by-proc-refusal (lambda (thunk) (thunk))))

(test-equal "D3 the same refusal through call-in-section is raised again after the outer section: a handler of it runs at depth 1; every count is zero after"
  (list (list 'raised-at-depth 'depth-1 '(assertion-violation free-foreign-block! (that-block))) zero-counts)
  (freed-by-proc-refusal call-in-section))

;; D4. The allocation's refusal. call-with-block is asked for more bytes than
;; any address space holds: foreign-alloc's refusal is caught in the critical
;; before thunk and raised once the extent is left, so a handler of it runs at
;; depth 1. Without the guard there, it would run at depth 2, inside the thunk.
(test-equal "D4 call-with-block asked for (greatest-fixnum) bytes raises foreign-alloc's refusal after its critical before thunk: a handler of it runs at depth 1, PROC does not run, and every count is zero after"
  (list 'depth-1 'proc-not-run zero-counts)
  (let* ((ran #f)
         (r (depth-and-object
             (lambda ()
               (call-with-block 'hash! (greatest-fixnum)
                 (lambda (block) #f)
                 (lambda (block) (set! ran #t) 'ran))))))
    (list (car r) (if ran 'proc-ran 'proc-not-run) (native-counts))))

;; --- the body, read as data ----------------------------------------------------------------------
;; Neither the order of the load's steps nor whether a binding is eager can be
;; seen with one good library in one process: every check passes, and the load
;; runs once. So native.sls is read as data, forms and never comments, as a
;; decoy library will hold the same by behaviour. Every scan reads the
;; elements of each list, never its tail, except occurs?, which looks for a
;; name anywhere, a dotted tail included, and so misses nothing a template
;; could hide.

(define native-source "src/chez-sodium/private/native.sls")

;; native-body : (U (Listof Any) (List 'unreadable Any))
;; The forms of native's library body, after its name, export and import.
(define native-body
  (guard (e (#t (list 'unreadable (describe e))))
    (let ((form (call-with-port
                 (open-file-input-port native-source (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (if (and (list? form) (> (length form) 4) (eq? (car form) 'library))
          (cddddr form)
          (list 'unreadable 'not-a-library-form)))))

(define body-read? (not (and (pair? native-body) (eq? (car native-body) 'unreadable))))

;; occurs? : Symbol Any -> Boolean
;; Whether NAME is X, or anywhere in it: in a list's elements, in a dotted
;; tail, or in a vector.
(define (occurs? name x)
  (cond ((eq? x name) #t)
        ((pair? x) (or (occurs? name (car x)) (occurs? name (cdr x))))
        ((vector? x) (occurs? name (vector->list x)))
        (else #f)))

;; forms-headed : Symbol Any -> (Listof Any)
;; Every list headed by HEAD anywhere in X, in reading order. It looks at the
;; elements of each list, never at a tail: the tail of (syntax foreign-procedure)
;; is (foreign-procedure), and is no form.
(define (forms-headed head x)
  (cond ((and (pair? x) (eq? (car x) head)) (list x))
        ((pair? x)
         (let loop ((rest x) (found '()))
           (if (pair? rest)
               (loop (cdr rest) (append found (forms-headed head (car rest))))
               found)))
        (else '())))

;; definition-form : Symbol -> Any
;; The top-level (define NAME EXPR) or (define (NAME . ARGS) BODY ...) of NAME,
;; or no-definition.
(define (definition-form name)
  (let loop ((forms native-body))
    (cond ((null? forms) 'no-definition)
          ((let ((form (car forms)))
             (and (pair? form) (eq? (car form) 'define) (pair? (cdr form))
                  (or (eq? (cadr form) name)
                      (and (pair? (cadr form)) (eq? (car (cadr form)) name)))))
           (car forms))
          (else (loop (cdr forms))))))

;; definition-of : Symbol -> Any
;; The expression of native's top-level (define NAME EXPR), or no-definition.
(define (definition-of name)
  (let ((form (definition-form name)))
    (if (and (pair? form) (= (length form) 3) (eq? (cadr form) name))
        (caddr form)
        'no-definition)))

;; load-answers-form : -> Any
;; The one top-level (define load-answers (load-step (call-in-section (lambda ()
;; (let* ...))))), or a description of what was found instead.
(define (load-answers-forms)
  (filter (lambda (form)
            (and (pair? form) (eq? (car form) 'define) (pair? (cdr form))
                 (eq? (cadr form) 'load-answers)))
          native-body))

;; the-let* : -> (U (Pair Any Any) #f)
;; The let* of the one load-answers definition, when its shape is exactly
;; load-step of call-in-section of a zero-argument lambda whose body is it.
(define (the-let*)
  (let ((forms (load-answers-forms)))
    (and (= (length forms) 1)
         (let ((form (car forms)))
           (and (= (length form) 3)
                (let ((step (caddr form)))
                  (and (list? step) (= (length step) 2) (eq? (car step) 'load-step)
                       (let ((section (cadr step)))
                         (and (list? section) (= (length section) 2)
                              (eq? (car section) 'call-in-section)
                              (let ((thunk (cadr section)))
                                (and (list? thunk) (= (length thunk) 3)
                                     (eq? (car thunk) 'lambda) (null? (cadr thunk))
                                     (let ((body (caddr thunk)))
                                       (and (pair? body) (eq? (car body) 'let*)
                                            body)))))))))))))

;; bindings-of : Any -> (Listof Any)
(define (bindings-of let*-form) (cadr let*-form))

;; step-names : (Listof Symbol)
;; The load's own names an init may use, in the order a row lists them.
(define step-names
  '(chosen raw-version-string raw-major raw-minor raw-init version init))

(test-equal "E1 the load is one definition: (define load-answers (load-step (call-in-section (lambda () (let* ...)))))"
  'one-definition-of-that-shape
  (if body-read?
      (let ((forms (load-answers-forms)))
        (cond ((not (= (length forms) 1)) (list 'definitions (length forms)))
              ((the-let*) 'one-definition-of-that-shape)
              (else (list 'other-shape (car forms)))))
      native-body))

;; The load's steps, in order: each let* binding's name, the head of its init,
;; and which of step-names the init uses, so a step moved, dropped or swapped
;; for another's, or that stopped calling its binding or checking its answer,
;; changes the list too.
(test-equal "E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the seventeen bound after sodium_memcmp's in step 6's order, then the five size reads and the fourteen constant reads in step 7's order; each with the head of its init and the load's names it uses"
  '((chosen call-with-values)
    (libsodium-loaded guard chosen)
    (raw-version-string bind-required chosen)
    (raw-major bind-required chosen)
    (raw-minor bind-required chosen)
    (version c-string->string raw-version-string)
    (major raw-major raw-major)
    (minor raw-minor raw-minor)
    (version-checked check-version chosen version)
    (raw-init bind-required chosen)
    (init raw-init raw-init)
    (init-checked check-init chosen init)
    (raw-memzero bind-required chosen)
    (raw-randombytes-buf bind-required chosen)
    (raw-generichash bind-required chosen)
    (raw-generichash-bytes bind-required chosen)
    (raw-generichash-bytes-min bind-required chosen)
    (raw-generichash-bytes-max bind-required chosen)
    (raw-generichash-keybytes-min bind-required chosen)
    (raw-generichash-keybytes-max bind-required chosen)
    (raw-memcmp bind-required chosen)
    (raw-pwhash-str bind-required chosen)
    (raw-pwhash-str-verify bind-required chosen)
    (raw-pwhash-str-needs-rehash bind-required chosen)
    (raw-pwhash-strbytes bind-required chosen)
    (raw-pwhash-strprefix bind-required chosen)
    (raw-pwhash-opslimit-min bind-required chosen)
    (raw-pwhash-opslimit-max bind-required chosen)
    (raw-pwhash-opslimit-interactive bind-required chosen)
    (raw-pwhash-opslimit-moderate bind-required chosen)
    (raw-pwhash-opslimit-sensitive bind-required chosen)
    (raw-pwhash-memlimit-min bind-required chosen)
    (raw-pwhash-memlimit-max bind-required chosen)
    (raw-pwhash-memlimit-interactive bind-required chosen)
    (raw-pwhash-memlimit-moderate bind-required chosen)
    (raw-pwhash-memlimit-sensitive bind-required chosen)
    (raw-pwhash-passwd-min bind-required chosen)
    (raw-pwhash-passwd-max bind-required chosen)
    (bytes raw-generichash-bytes)
    (bytes-min raw-generichash-bytes-min)
    (bytes-max raw-generichash-bytes-max)
    (keybytes-min raw-generichash-keybytes-min)
    (keybytes-max raw-generichash-keybytes-max)
    (strbytes raw-pwhash-strbytes)
    (strprefix c-string->string)
    (opslimit-min raw-pwhash-opslimit-min)
    (opslimit-max raw-pwhash-opslimit-max)
    (opslimit-interactive raw-pwhash-opslimit-interactive)
    (opslimit-moderate raw-pwhash-opslimit-moderate)
    (opslimit-sensitive raw-pwhash-opslimit-sensitive)
    (memlimit-min raw-pwhash-memlimit-min)
    (memlimit-max raw-pwhash-memlimit-max)
    (memlimit-interactive raw-pwhash-memlimit-interactive)
    (memlimit-moderate raw-pwhash-memlimit-moderate)
    (memlimit-sensitive raw-pwhash-memlimit-sensitive)
    (passwd-min raw-pwhash-passwd-min)
    (passwd-max raw-pwhash-passwd-max))
  (if (and body-read? (the-let*))
      (map (lambda (binding)
             (let ((expr (cadr binding)))
               (cons* (car binding)
                      (if (pair? expr) (car expr) expr)
                      (filter (lambda (name) (occurs? name expr)) step-names))))
           (bindings-of (the-let*)))
      native-body))

;; collect-safe-bindings : -> (Listof Symbol)
;; The let* names whose bind-required form's foreign-procedure carries the
;; __collect_safe convention, in the load's order.
(define (collect-safe-bindings)
  (let loop ((bindings (bindings-of (the-let*))) (found '()))
    (if (null? bindings)
        (reverse found)
        (let ((expr (cadr (car bindings))))
          (loop (cdr bindings)
                (if (and (list? expr) (= (length expr) 3) (eq? (car expr) 'bind-required)
                         (pair? (caddr expr)) (eq? (car (caddr expr)) 'foreign-procedure)
                         (memq '__collect_safe (caddr expr)))
                    (cons (car (car bindings)) found)
                    found))))))

(test-equal "E3 every foreign-procedure form in native.sls binds eagerly: thirty in all, exactly crypto_pwhash_str and crypto_pwhash_str_verify __collect_safe, each the whole second argument of (bind-required chosen ...) and directly the init of its let* binding, none inside a lambda"
  (list '((raw-version-string chosen "sodium_version_string")
          (raw-major chosen "sodium_library_version_major")
          (raw-minor chosen "sodium_library_version_minor")
          (raw-init chosen "sodium_init")
          (raw-memzero chosen "sodium_memzero")
          (raw-randombytes-buf chosen "randombytes_buf")
          (raw-generichash chosen "crypto_generichash")
          (raw-generichash-bytes chosen "crypto_generichash_bytes")
          (raw-generichash-bytes-min chosen "crypto_generichash_bytes_min")
          (raw-generichash-bytes-max chosen "crypto_generichash_bytes_max")
          (raw-generichash-keybytes-min chosen "crypto_generichash_keybytes_min")
          (raw-generichash-keybytes-max chosen "crypto_generichash_keybytes_max")
          (raw-memcmp chosen "sodium_memcmp")
          (raw-pwhash-str chosen "crypto_pwhash_str")
          (raw-pwhash-str-verify chosen "crypto_pwhash_str_verify")
          (raw-pwhash-str-needs-rehash chosen "crypto_pwhash_str_needs_rehash")
          (raw-pwhash-strbytes chosen "crypto_pwhash_strbytes")
          (raw-pwhash-strprefix chosen "crypto_pwhash_strprefix")
          (raw-pwhash-opslimit-min chosen "crypto_pwhash_opslimit_min")
          (raw-pwhash-opslimit-max chosen "crypto_pwhash_opslimit_max")
          (raw-pwhash-opslimit-interactive chosen "crypto_pwhash_opslimit_interactive")
          (raw-pwhash-opslimit-moderate chosen "crypto_pwhash_opslimit_moderate")
          (raw-pwhash-opslimit-sensitive chosen "crypto_pwhash_opslimit_sensitive")
          (raw-pwhash-memlimit-min chosen "crypto_pwhash_memlimit_min")
          (raw-pwhash-memlimit-max chosen "crypto_pwhash_memlimit_max")
          (raw-pwhash-memlimit-interactive chosen "crypto_pwhash_memlimit_interactive")
          (raw-pwhash-memlimit-moderate chosen "crypto_pwhash_memlimit_moderate")
          (raw-pwhash-memlimit-sensitive chosen "crypto_pwhash_memlimit_sensitive")
          (raw-pwhash-passwd-min chosen "crypto_pwhash_passwd_min")
          (raw-pwhash-passwd-max chosen "crypto_pwhash_passwd_max"))
        30
        '(raw-pwhash-str raw-pwhash-str-verify))
  (if (and body-read? (the-let*))
      (list (let loop ((bindings (bindings-of (the-let*))) (found '()))
              (if (null? bindings)
                  (reverse found)
                  (let* ((binding (car bindings)) (expr (cadr binding)))
                    (loop (cdr bindings)
                          (if (and (list? expr) (= (length expr) 3) (eq? (car expr) 'bind-required)
                                   (pair? (caddr expr)) (eq? (car (caddr expr)) 'foreign-procedure))
                              (cons (list (car binding) (cadr expr)
                                          (or (find string? (cdr (caddr expr))) 'no-name))
                                    found)
                              found)))))
            (length (forms-headed 'foreign-procedure native-body))
            (collect-safe-bindings))
      native-body))

;; E4. The load's work is in that one section: the loader, discovery, the floor,
;; sodium_init's check and every bind occur in no other top-level form. The
;; one exception is the macro that defines bind-required, which names itself.
(define (load-work-outside)
  (let loop ((forms native-body) (found '()))
    (if (null? forms)
        (reverse found)
        (let* ((form (car forms))
               (name (if (and (pair? form) (pair? (cdr form)))
                         (let ((target (cadr form))) (if (pair? target) (car target) target))
                         form))
               (own (and (pair? form) (eq? (car form) 'define-syntax) (eq? name 'bind-required)))
               (used (filter (lambda (symbol) (and (occurs? symbol form)
                                                   (not (and own (eq? symbol 'bind-required)))))
                             '(load-shared-object choose-libsodium check-version check-init
                               bind-required))))
          (loop (cdr forms)
                (if (or (null? used) (eq? name 'load-answers))
                    found
                    (cons (cons name used) found)))))))

(test-equal "E4 the load's work is in the one definition: load-shared-object, choose-libsodium, check-version, check-init and bind-required occur in no other top-level form, and all five occur in it"
  (list '() '(load-shared-object choose-libsodium check-version check-init bind-required))
  (if body-read?
      (list (load-work-outside)
            (filter (lambda (symbol) (occurs? symbol (load-answers-forms)))
                    '(load-shared-object choose-libsodium check-version check-init bind-required)))
      native-body))

(test-equal "E5 the answers are top-level definitions (define NAME (answer 'KEY)): the record's six, the load's five raw bindings, the verbs' three, the five sizes, then the password hash's three bindings and fourteen constants, each under its own key"
  '((libsodium-path path) (libsodium-source source) (libsodium-version version)
    (libsodium-major major) (libsodium-minor minor) (libsodium-init init)
    (sodium-version-string sodium-version-string)
    (sodium-library-version-major sodium-library-version-major)
    (sodium-library-version-minor sodium-library-version-minor)
    (sodium-init sodium-init)
    (sodium-memzero sodium-memzero)
    (randombytes-buf randombytes-buf)
    (crypto-generichash crypto-generichash)
    (sodium-memcmp sodium-memcmp)
    (generichash-bytes generichash-bytes)
    (generichash-bytes-min generichash-bytes-min)
    (generichash-bytes-max generichash-bytes-max)
    (generichash-keybytes-min generichash-keybytes-min)
    (generichash-keybytes-max generichash-keybytes-max)
    (crypto-pwhash-str crypto-pwhash-str)
    (crypto-pwhash-str-verify crypto-pwhash-str-verify)
    (crypto-pwhash-str-needs-rehash crypto-pwhash-str-needs-rehash)
    (pwhash-strbytes pwhash-strbytes)
    (pwhash-strprefix pwhash-strprefix)
    (pwhash-opslimit-min pwhash-opslimit-min)
    (pwhash-opslimit-max pwhash-opslimit-max)
    (pwhash-opslimit-interactive pwhash-opslimit-interactive)
    (pwhash-opslimit-moderate pwhash-opslimit-moderate)
    (pwhash-opslimit-sensitive pwhash-opslimit-sensitive)
    (pwhash-memlimit-min pwhash-memlimit-min)
    (pwhash-memlimit-max pwhash-memlimit-max)
    (pwhash-memlimit-interactive pwhash-memlimit-interactive)
    (pwhash-memlimit-moderate pwhash-memlimit-moderate)
    (pwhash-memlimit-sensitive pwhash-memlimit-sensitive)
    (pwhash-passwd-min pwhash-passwd-min)
    (pwhash-passwd-max pwhash-passwd-max))
  (if body-read?
      (let loop ((forms native-body) (found '()))
        (if (null? forms)
            (reverse found)
            (let ((form (car forms)))
              (loop (cdr forms)
                    (if (and (pair? form) (= (length form) 3) (eq? (car form) 'define)
                             (symbol? (cadr form))
                             (let ((value (caddr form)))
                               (and (list? value) (= (length value) 2) (eq? (car value) 'answer)
                                    (pair? (cadr value)) (eq? (car (cadr value)) 'quote))))
                        (cons (list (cadr form) (cadr (cadr (caddr form)))) found)
                        found)))))
      native-body))

(test-equal "E6 native's first definition is step 0, earlier-failure, which raises a recorded load-failure again"
  '(earlier-failure calls-load-failure)
  (if body-read?
      (let ((first (find (lambda (form) (and (pair? form) (eq? (car form) 'define))) native-body)))
        (list (and first (cadr first))
              (if (and first (occurs? 'load-failure first) (occurs? 'raise first))
                  'calls-load-failure
                  first)))
      native-body))

;; E7. Every top-level form but call-with-block's definition is read, the
;; define-syntax of a macro too: a template that built a block, or freed one,
;; would pass check-seam's rule (m), which reads imports and exports alone.
(define (blocks-outside-call-with-block)
  (let loop ((forms native-body) (found '()))
    (if (null? forms)
        (reverse found)
        (let* ((form (car forms))
               (target (and (pair? form) (pair? (cdr form)) (cadr form)))
               (name (if (pair? target) (car target) target))
               (used (filter (lambda (symbol) (occurs? symbol form))
                             '(foreign-block free-foreign-block!))))
          (loop (cdr forms)
                (if (or (null? used) (eq? name 'call-with-block))
                    found
                    (cons (cons name used) found)))))))

(test-equal "E7 foreign-block and free-foreign-block! occur in no top-level form of native's body, define-syntax templates included, but call-with-block's definition, which holds both"
  (list '() '(foreign-block free-foreign-block!))
  (if body-read?
      (list (blocks-outside-call-with-block)
            (filter (lambda (symbol) (occurs? symbol (definition-form 'call-with-block)))
                    '(foreign-block free-foreign-block!)))
      native-body))

;; native-imports : -> (U (Listof Any) (List 'unreadable Any))
;; The import specs of native's library form, each as written.
(define native-imports
  (guard (e (#t (list 'unreadable (describe e))))
    (let ((form (call-with-port
                 (open-file-input-port native-source (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (if (and (list? form) (> (length form) 4) (eq? (car form) 'library)
               (list? (cadddr form)) (eq? (car (cadddr form)) 'import))
          (cdr (cadddr form))
          (list 'unreadable 'no-import-clause)))))

;; all-forms-headed : Symbol Any -> (Listof Any)
;; Every list headed by HEAD anywhere in X, nested ones too, in reading order,
;; elements only.
(define (all-forms-headed head x)
  (cond ((not (pair? x)) '())
        (else
         (let loop ((rest x) (found (if (eq? (car x) head) (list x) '())))
           (if (pair? rest)
               (loop (cdr rest) (append found (all-forms-headed head (car rest))))
               found)))))

;; E11. memory is imported once, whole: a second import, renamed, prefixed or
;; narrowed, would give native a way to make and free a block that neither
;; check-seam's rule (m), which reads what a library exports, nor E7, which
;; reads names, can see.
(test-equal "E11 native imports (chez-sodium private memory) exactly once, as the plain import set, with no only, rename, prefix, except or for around it, and no other import spec mentions memory"
  '(((chez-sodium private memory)) ((chez-sodium private memory)))
  (if (and body-read? (list? native-imports) (not (and (pair? native-imports) (eq? (car native-imports) 'unreadable))))
      (list (filter (lambda (spec) (equal? spec '(chez-sodium private memory))) native-imports)
            (filter (lambda (spec) (occurs? 'memory spec)) native-imports))
      native-imports))

;; E12. call-with-block's critical before thunk: its inner dynamic-wind takes
;; #t as its first argument, so its before and after thunks run in critical
;; sections. The outer one, the re-entry guard, does not.
(test-equal "E12 call-with-block's definition holds two dynamic-wind forms: the outer plain, the inner with #t as its first argument"
  '((4 #f) (5 #t))
  (if body-read?
      (map (lambda (form) (list (length form) (and (pair? (cdr form)) (eq? (cadr form) #t))))
           (all-forms-headed 'dynamic-wind (definition-form 'call-with-block)))
      native-body))

(test-equal "E8 call-with-block's definition holds exactly one foreign-block form and one free-foreign-block! form, and the second argument of that free is sodium-memzero"
  '(1 1 sodium-memzero)
  (if body-read?
      (let* ((definition (definition-form 'call-with-block))
             (makes (forms-headed 'foreign-block definition))
             (frees (forms-headed 'free-foreign-block! definition)))
        (list (length makes) (length frees)
              (if (and (= (length frees) 1) (>= (length (car frees)) 3))
                  (list-ref (car frees) 2)
                  frees)))
      native-body))

(test-equal "E9 call-with-bytes' definition copies nothing: no bytevector-copy, bytevector-copy!, bytevector->u8-list, make-bytevector, utf8->string, string->utf8 or subbytevector"
  '()
  (if body-read?
      (let ((definition (definition-form 'call-with-bytes)))
        (if (eq? definition 'no-definition)
            (list 'no-definition)
            (filter (lambda (symbol) (occurs? symbol definition))
                    '(bytevector-copy bytevector-copy! bytevector->u8-list make-bytevector
                      utf8->string string->utf8 subbytevector))))
      native-body))

;; symbols-in : Any -> (Listof Symbol)
;; Every distinct symbol anywhere in X, sorted by name.
(define (symbols-in x)
  (let loop ((todo (list x)) (found '()))
    (cond ((null? todo)
           (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) found))
          ((symbol? (car todo))
           (loop (cdr todo) (if (memq (car todo) found) found (cons (car todo) found))))
          ((pair? (car todo)) (loop (cons (caar todo) (cons (cdar todo) (cdr todo))) found))
          ((vector? (car todo)) (loop (cons (vector->list (car todo)) (cdr todo)) found))
          (else (loop (cdr todo) found)))))

;; Each string writer holds an allow-list: every symbol its definition may
;; mention, compared whole. A deny-list misses what it does not name: a
;; writer that built a string of its own with make-string and string-set!
;; would pass one. Adding a symbol to a writer is a change to this list.
(test-equal "E13 the string writers copy no secret: call-with-c-string's and call-with-utf8's definitions mention exactly the symbols of their allow-lists, whole"
  '((+ < <= >= and assertion-violation begin block c call-with-block call-with-c-string
       changed char->integer check-who define foreign-set! i if intact lambda let loop n
       not-a-string proc procedure? quote refuse-secret set! shown-value string string-length
       string-ref string? unless unsigned-8 who)
    (+ < = > assertion-violation at begin bitwise-and bitwise-arithmetic-shift-right
       bitwise-ior block c call-with-block call-with-utf8 case changed char->integer check-who
       cond define else exact-natural? foreign-set! i if intact lambda len let let* loop max n
       not-a-string proc procedure? quote refuse-secret set! shown-value string string-length
       string-ref string? unless unsigned-8 who width))
  (if body-read?
      (map (lambda (name)
             (let ((definition (definition-form name)))
               (if (eq? definition 'no-definition)
                   (list 'no-definition)
                   (symbols-in definition))))
           '(call-with-c-string call-with-utf8))
      native-body))

(test-equal "E10 sodium-version's body is (string-copy libsodium-version), and loaded-libsodium builds its two strings with string-copy of the path and the version"
  '((string-copy libsodium-version)
    ((string-copy libsodium-path) (string-copy libsodium-version)))
  (if body-read?
      (let ((version (definition-form 'sodium-version))
            (loaded (definition-form 'loaded-libsodium)))
        (list (if (and (pair? version) (= (length version) 3)) (caddr version) version)
              (forms-headed 'string-copy loaded)))
      native-body))

;; --- every count is zero ---------------------------------------------------------------------

(test-equal "every count is zero at the end"
  zero-counts
  (native-counts))

(test-end "native")

(exit (suite-exit-status runner))
