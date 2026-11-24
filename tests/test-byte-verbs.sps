#!r6rs
;;; The suite for (chez-sodium private byte-verbs) and (chez-sodium private
;;; cap): random-bytes, blake2b and constant-time-bytevector=?, against the
;;; library this suite loads, in a process of its own. make test-memory runs
;;; it under Valgrind.
;;;
;;; byte-verbs' body is native's load, which a guard in a program cannot
;;; catch from an import, so this suite reaches each verb through eval, under
;;; a guard: a library that cannot load fails every row that needs it by name,
;;; where an import would kill the suite before its first line.
;;;
;;;   R1   blake2b's answers: RFC 7693 Appendix E's self-test built here, its
;;;        48 outputs concatenated and hashed once at 32 bytes; every entry of
;;;        the BLAKE2 reference's known answers, from tests/fixtures/blake2b/;
;;;        BLAKE2b-256 and -512 of "abc" and of nothing, and three keyed
;;;        hashes whose key length is not their size, each from Python's
;;;        hashlib, never from libsodium
;;;   R13  random-bytes: the length asked for, 8 calls in which every position
;;;        takes at least two values, 0 answering #vu8() and 65537 refused
;;;   R14  constant-time-bytevector=?: equal pairs, a difference in the first
;;;        byte or the last, a prefix, other lengths, both empty
;;;   R15  every refusal, by ADR-0006's rule symbols, its who and irritants
;;;        whole, both ends of each cap and range, and the order the checks
;;;        run in
;;;   R16  a secret parameter is shown by its kind alone: a symbol, a number
;;;        and a list of characters, each as (kind K)
;;;   R18  each verb under an engine at every fuel from 1 until it completes
;;;   S    the verbs' bodies read as data: one call-in-section each, every
;;;        refusal before it, and every symbol inside it listed whole, so a
;;;        helper called there shows by name; the import clauses whole; the
;;;        cap written in cap.sls alone, and each verb's uses of it counted
;;;
;;; The decoy's halves, which show what reaches C, are
;;; tests/test-library-loading-verbs.sps.
;;;
;;; Every computation that can raise runs under a guard with a sentinel of its
;;; own: SRFI-64 makes #f of a raise in an actual expression, and catches none
;;; in an expected expression or a top-level definition. No expected value is
;;; #f for something that can raise: constant-time-bytevector=?'s #f is
;;; asserted as (no-raise #f). Nothing here depends on an order of evaluation:
;;; effects run through for-each, let* and named lets, and map is used only
;;; where its calls do not depend on one another. Every engine row follows a reference to each library at
;;; the top of the suite: a library first reached inside an engine that is then
;;; abandoned stays wedged.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (only (chezscheme) library-exports make-engine directory-list file-directory?)
        (chez-sodium-testing)
        (chez-sodium private counters))

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

;; The count is printed at test-end: a passing run says (pass N fail 0).
(test-begin "byte-verbs")

;; --- the libraries, reached through eval ---------------------------------------------------

;; library-value : (List Symbol ...) Symbol -> Any
;; NAME in the library LIB; when it cannot be reached, a procedure that raises
;; that, with NAME, every time it is called, so each test that calls it fails
;; by name.
(define (library-value lib name)
  (guard (e (#t (lambda args
                  (error name "library could not be reached" lib (describe e)))))
    (eval name (environment lib))))

(define verbs-lib '(chez-sodium private byte-verbs))
(define native-lib '(chez-sodium private native))
(define cap-lib '(chez-sodium private cap))

(define random-bytes (library-value verbs-lib 'random-bytes))
(define blake2b (library-value verbs-lib 'blake2b))
(define constant-time-bytevector=? (library-value verbs-lib 'constant-time-bytevector=?))
(define input-cap (library-value cap-lib 'input-cap))

;; The library's own sizes, read by native once at the load: the bounds the
;; refusals are asserted at.
(define bytes-default (library-value native-lib 'generichash-bytes))
(define bytes-min (library-value native-lib 'generichash-bytes-min))
(define bytes-max (library-value native-lib 'generichash-bytes-max))
(define keybytes-min (library-value native-lib 'generichash-keybytes-min))
(define keybytes-max (library-value native-lib 'generichash-keybytes-max))

;; --- helpers ---------------------------------------------------------------------------------

(define zero-counts '((block . 0)))

;; raised : (-> Any) -> Any
;; What THUNK did: (no-raise VALUE), (assertion-violation WHO IRRITANTS) for an
;; assertion violation, or (other TEXT) for any other raise. Never a message.
(define (raised thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (message-condition? e)
                  (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (list 'no-raise (thunk))))

;; refusal : Symbol Any ... -> Expected
;; The assertion violation of WHO whose irritants are IRRITANTS.
(define (refusal who . irritants)
  (list 'assertion-violation who irritants))

;; check : String Expected (-> Any) -> Void
;; One test: what THUNK did, as raised shows it, against EXPECTED.
(define (check name expected thunk)
  (test-equal name expected (raised thunk)))

;; append-map : (A -> (Listof B)) (Listof A) -> (Listof B)
(define (append-map f lst) (apply append (map f lst)))

;; bytevector : Natural ... -> Bytevector
(define (bytevector . bytes) (u8-list->bytevector bytes))

;; concatenate : (Listof Bytevector) -> Bytevector
(define (concatenate parts)
  (u8-list->bytevector (append-map bytevector->u8-list parts)))

(define hex-digits "0123456789abcdef")

;; bytes->hex : Bytevector -> String
(define (bytes->hex bytes)
  (let ((n (bytevector-length bytes)))
    (let loop ((i (- n 1)) (chars '()))
      (if (< i 0)
          (list->string chars)
          (let ((b (bytevector-u8-ref bytes i)))
            (loop (- i 1)
                  (cons (string-ref hex-digits (div b 16))
                        (cons (string-ref hex-digits (mod b 16)) chars))))))))

;; hex->bytes : String -> Bytevector
(define (hex->bytes text)
  (let* ((n (div (string-length text) 2)) (bytes (make-bytevector n 0)))
    (let loop ((i 0))
      (when (< i n)
        (bytevector-u8-set! bytes i (string->number (substring text (* 2 i) (+ 2 (* 2 i))) 16))
        (loop (+ i 1))))
    bytes))

;; counting : Natural Natural -> Bytevector
;; START, START+1, ... as N bytes.
(define (counting n start)
  (let ((bytes (make-bytevector n 0)))
    (let loop ((i 0))
      (when (< i n)
        (bytevector-u8-set! bytes i (mod (+ start i) 256))
        (loop (+ i 1))))
    bytes))

;; --- R1: the known answers ----------------------------------------------------------------------

;; selftest-seq : Natural Natural -> Bytevector
;; RFC 7693 Appendix E's pseudo-random generator: LEN bytes from SEED.
(define (selftest-seq len seed)
  (let ((out (make-bytevector len 0)))
    (let loop ((i 0) (a (mod (* #xDEAD4BAD seed) #x100000000)) (b 1))
      (when (< i len)
        (let ((t (mod (+ a b) #x100000000)))
          (bytevector-u8-set! out i (bitwise-and (bitwise-arithmetic-shift-right t 24) #xFF))
          (loop (+ i 1) b t))))
    out))

(define selftest-sizes '(20 32 48 64))
(define selftest-input-lengths '(0 3 128 129 255 1024))

;; selftest-outputs : -> (Listof Bytevector)
;; Appendix E's inner hashes, in its order, each through blake2b alone: for
;; each size, for each input length, the unkeyed hash of the input, then the
;; hash keyed by a key as long as the size. 48 of them.
(define (selftest-outputs)
  (let size-loop ((sizes selftest-sizes) (found '()))
    (if (null? sizes)
        (reverse found)
        (let ((size (car sizes)))
          (let length-loop ((lengths selftest-input-lengths) (found found))
            (if (null? lengths)
                (size-loop (cdr sizes) found)
                (let* ((input (selftest-seq (car lengths) (car lengths)))
                       (key (selftest-seq size size))
                       (plain (blake2b input size))
                       (keyed (blake2b input size key)))
                  (length-loop (cdr lengths) (cons keyed (cons plain found))))))))))

(check "R1 RFC 7693 Appendix E: its 48 outputs, 1968 bytes, concatenated and hashed once at 32 bytes through blake2b, are the RFC's c23a7800...d475; the self-test's sizes are 20, 32, 48 and 64, its input lengths 0, 3, 128, 129, 255 and 1024"
  (list 'no-raise (list 48 1968 "c23a7800d98123bd10f506c61e29da5603d763b8bbad2e737f5e765a7bccd475"))
  (lambda ()
    (let* ((outputs (selftest-outputs))
           (all (concatenate outputs)))
      (list (length outputs) (bytevector-length all) (bytes->hex (blake2b all 32))))))

;; The known answers: lines in/key/hash, blank-separated.

(define kat-path "tests/fixtures/blake2b/blake2b-kat.txt")

;; line-field : String String -> (U String #f)
;; What follows TAG on LINE, without trailing spaces, tabs and returns, else #f.
(define (line-field line tag)
  (let ((n (string-length tag)))
    (and (>= (string-length line) n)
         (string=? (substring line 0 n) tag)
         (let strip ((s (substring line n (string-length line))))
           (let ((m (string-length s)))
             (cond ((and (> m 0) (memv (string-ref s (- m 1)) '(#\return #\space #\tab)))
                    (strip (substring s 0 (- m 1))))
                   ((and (> m 0) (memv (string-ref s 0) '(#\space #\tab)))
                    (strip (substring s 1 m)))
                   (else s)))))))

;; read-kat : -> (Listof (List String String String))
;; Each entry's input, key and hash, as hex.
(define (read-kat)
  (call-with-input-file kat-path
    (lambda (port)
      (let loop ((in #f) (key #f) (found '()))
        (let ((line (get-line port)))
          (cond ((eof-object? line) (reverse found))
                ((line-field line "in:") => (lambda (v) (loop v key found)))
                ((line-field line "key:") => (lambda (v) (loop in v found)))
                ((line-field line "hash:")
                 => (lambda (v) (loop #f #f (cons (list in key v) found))))
                (else (loop in key found))))))))

(check "R1 the BLAKE2 reference's known answers: 256 entries read from the fixture, and every one is blake2b of its input at size 64 with its key"
  '(no-raise (256 256))
  (lambda ()
    (let ((entries (read-kat)))
      (list (length entries)
            (let loop ((rest entries) (matches 0))
              (if (null? rest)
                  matches
                  (let* ((entry (car rest))
                         (answer (guard (e (#t #f))
                                   (bytes->hex (blake2b (hex->bytes (car entry)) 64
                                                        (hex->bytes (cadr entry)))))))
                    (loop (cdr rest)
                          (if (equal? answer (caddr entry)) (+ matches 1) matches)))))))))

(define abc (string->utf8 "abc"))

;; The fixture is held to its size and to its first and last hash, written
;; here, so a file regenerated from libsodium itself shows.
(check "R1 the known-answers fixture is 135681 bytes, its first hash is 10ebb677...c51568 and its last 142709d6...d62ef2a461"
  (list 'no-raise
        (list 135681
              "10ebb67700b1868efb4417987acf4690ae9d972fb7a590c2f02871799aaa4786b5e996e8f0f4eb981fc214b005f42d2ff4233499391653df7aefcbc13fc51568"
              "142709d62e28fcccd0af97fad0f8465b971e82201dc51070faa0372aa43e92484be1c1e73ba10906d5d1853db6a4106e0a7bf9800d373d6dee2d46d62ef2a461"))
  (lambda ()
    (let ((entries (read-kat)))
      (list (bytevector-length
             (call-with-port (open-file-input-port kat-path) get-bytevector-all))
            (caddr (car entries))
            (caddr (car (reverse entries)))))))

;; hashlib's answers, measured once.
(define known-hashes
  (list
   (list "BLAKE2b-256 of \"abc\"" abc 32
         "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")
   (list "BLAKE2b-512 of \"abc\"" abc 64
         "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")
   (list "BLAKE2b-256 of nothing" (bytevector) 32
         "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8")
   (list "BLAKE2b-512 of nothing" (bytevector) 64
         "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce")))

(for-each
 (lambda (row)
   (check (string-append "R1 " (car row) " through blake2b at size " (number->string (caddr row)))
     (list 'no-raise (cadddr row))
     (lambda () (bytes->hex (blake2b (cadr row) (caddr row))))))
 known-hashes)

(check "R1 blake2b of \"abc\" with no size is BLAKE2b-256's: the default size, read from libsodium, is 32"
  (list 'no-raise (list bytes-default
                        "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319"))
  (lambda ()
    (let ((hash (blake2b abc)))
      (list (bytevector-length hash) (bytes->hex hash)))))

;; Keyed hashes whose key length is not their size: a key taken to be as long
;; as the size gives another hash.
(define keyed-hashes
  (list
   (list "a 16-byte key (01 to 10) at size 32 over \"abc\"" abc 32 (counting 16 1)
         "6a0e54342c7a2cccd02d678e5513f8a643a3b46b7a45db70a985c19f744701da")
   (list "a 64-byte key (00 to 3f) at size 20 over \"abc\"" abc 20 (counting 64 0)
         "f3464811aec9776024bd78c73dbaad63a62c509b")
   (list "a 17-byte key (00 to 10) at size 64 over nothing" (bytevector) 64 (counting 17 0)
         "38fe0c167cea82b31e9003034123f8e2bdf70ee4c4626e2793e07dc76bfe54eb6e9ace68eb1c801d1da105aad640e8a94bc556c5582416394b1bc96ef8a6941e")))

(for-each
 (lambda (row)
   (check (string-append "R1 " (car row) " through blake2b")
     (list 'no-raise (list-ref row 4))
     (lambda () (bytes->hex (blake2b (cadr row) (caddr row) (cadddr row))))))
 keyed-hashes)

;; --- R13: random-bytes ---------------------------------------------------------------------------

;; nonzero-tail? : Bytevector -> Boolean
;; Whether any of the last 16 bytes of BYTES is not 0: 2^-128 for a right
;; library, and a copy that stopped short leaves them all 0.
(define (nonzero-tail? bytes)
  (let ((n (bytevector-length bytes)))
    (let loop ((i (max 0 (- n 16))))
      (cond ((>= i n) #f)
            ((not (eqv? (bytevector-u8-ref bytes i) 0)) #t)
            (else (loop (+ i 1)))))))

(for-each
 (lambda (n)
   (check (string-append "R13 random-bytes " (number->string n)
                         " answers a bytevector of exactly that many bytes, the last 16 not all 0")
     (list 'no-raise (list #t n (if (>= n 32) #t 'not-asked)))
     (lambda ()
       (let ((bytes (random-bytes n)))
         (list (bytevector? bytes) (bytevector-length bytes)
               (if (>= n 32) (nonzero-tail? bytes) 'not-asked))))))
 '(1 32 65536))

(check "R13 random-bytes 0 answers #vu8()"
  '(no-raise #vu8())
  (lambda () (random-bytes 0)))

;; distinct-per-position : (Listof Bytevector) Natural -> (Listof Natural)
;; How many different values each of the first N positions takes across ROWS.
(define (distinct-per-position rows n)
  (let position-loop ((i 0) (counts '()))
    (if (= i n)
        (reverse counts)
        (position-loop
         (+ i 1)
         (cons (let value-loop ((rest rows) (seen '()))
                 (cond ((null? rest) (length seen))
                       ((memv (bytevector-u8-ref (car rest) i) seen) (value-loop (cdr rest) seen))
                       (else (value-loop (cdr rest) (cons (bytevector-u8-ref (car rest) i) seen)))))
               counts)))))

(check "R13 8 calls of random-bytes 64: every one of the 64 positions takes at least two values"
  '(no-raise #t)
  (lambda ()
    (let ((rows (let loop ((i 0) (found '()))
                  (if (= i 8) (reverse found) (loop (+ i 1) (cons (random-bytes 64) found))))))
      (and (for-all (lambda (r) (= (bytevector-length r) 64)) rows)
           (for-all (lambda (count) (>= count 2)) (distinct-per-position rows 64))))))

(check "R13 two calls of random-bytes 64 differ"
  '(no-raise #t)
  (lambda () (not (bytevector=? (random-bytes 64) (random-bytes 64)))))

;; --- R14: constant-time-bytevector=? -------------------------------------------------------------

;; Each row: its description, the operands, and the answer.
(define compare-rows
  (list
   (list "equal, one byte" (bytevector 7) (bytevector 7) #t)
   (list "equal, 32 bytes" (counting 32 1) (counting 32 1) #t)
   (list "equal, 65536 bytes" (make-bytevector 65536 9) (make-bytevector 65536 9) #t)
   (list "both empty" (bytevector) (bytevector) #t)
   (list "differ in the first byte only" (bytevector 1 2 3 4) (bytevector 9 2 3 4) #f)
   (list "differ in the last byte only" (bytevector 1 2 3 4) (bytevector 1 2 3 9) #f)
   (list "differ in the middle byte only" (bytevector 1 2 3 4 5) (bytevector 1 2 9 4 5) #f)
   (list "differ in one bit" (bytevector 1 2 3 4) (bytevector 1 2 3 5) #f)
   (list "differ in the last byte of 65536"
         (make-bytevector 65536 9)
         (let ((b (make-bytevector 65536 9))) (bytevector-u8-set! b 65535 8) b)
         #f)
   (list "a is a prefix of b" (bytevector 1 2 3) (bytevector 1 2 3 4) #f)
   (list "b is a prefix of a" (bytevector 1 2 3 4) (bytevector 1 2 3) #f)
   (list "a is empty, b is not" (bytevector) (bytevector 1) #f)
   (list "b is empty, a is not" (bytevector 1) (bytevector) #f)
   (list "lengths 1 and 65536" (bytevector 9) (make-bytevector 65536 9) #f)))

(for-each
 (lambda (row)
   (check (string-append "R14 constant-time-bytevector=?: " (car row)
                         (if (cadddr row) " answers #t" " answers #f, and raises nothing"))
     (list 'no-raise (cadddr row))
     (lambda () (constant-time-bytevector=? (cadr row) (caddr row)))))
 compare-rows)

;; --- R15, R16: the refusals ----------------------------------------------------------------------

;; secrets : (Listof (Pair Any Symbol))
;; What a secret-looking value of each kind is, and its kind.
(define secrets
  (list (cons 'hunter2 'symbol)
        (cons 4242424242 'number)
        (cons '(#\s #\e #\c #\r #\e #\t) 'list)
        (cons "secret-password" 'string)
        (cons #f 'boolean)))

;; kind : Symbol -> (List 'kind Symbol)
(define (kind k) (list 'kind k))

(define (bytes-of n) (make-bytevector n 1))

;; beside : (Number Number -> Number) Any -> (U Number Symbol)
;; BOUND moved one by OP; when native could not be reached, BOUND is a
;; procedure that raises, and this answers unreached, so the expected value
;; of a row cannot raise at the top level.
(define (beside op bound)
  (if (number? bound) (op bound 1) 'unreached))

;; --- random-bytes's refusals

(for-each
 (lambda (row)
   (check (string-append "R15 random-bytes " (car row) " is refused, not-a-natural, its n shown as it is")
     (refusal 'random-bytes 'not-a-natural 'n (cadr row))
     (lambda () (random-bytes (caddr row)))))
 (list (list "-1" -1 -1)
       (list "1.5" 1.5 1.5)
       (list "3.0, which is no exact natural" 3.0 3.0)
       (list "1/2" 1/2 1/2)
       (list "a symbol" 'many 'many)
       (list "a string, shown by its kind" (kind 'string) "32")
       (list "#f" #f #f)))

(check "R15 random-bytes 65537 is refused, over-the-cap, its n shown"
  (refusal 'random-bytes 'over-the-cap 'n 65537)
  (lambda () (random-bytes 65537)))

(check "R15 random-bytes the greatest fixnum is refused, over-the-cap, before any block"
  (refusal 'random-bytes 'over-the-cap 'n (greatest-fixnum))
  (lambda () (random-bytes (greatest-fixnum))))

(check "R15 random-bytes 65536 is accepted, and answers 65536 bytes"
  '(no-raise 65536)
  (lambda () (bytevector-length (random-bytes 65536))))

;; --- blake2b's refusals

(for-each
 (lambda (secret)
   (check (string-append "R15 blake2b of " (symbol->string (cdr secret))
                         ": no bytevector is refused, not-a-bytevector input, by kind alone")
     (refusal 'blake2b 'not-a-bytevector 'input (kind (cdr secret)))
     (lambda () (blake2b (car secret)))))
 secrets)

(check "R15 blake2b of 65537 bytes is refused, over-the-cap input, by kind alone"
  (refusal 'blake2b 'over-the-cap 'input (kind 'bytevector))
  (lambda () (blake2b (bytes-of 65537))))

(check "R15 blake2b of 65536 bytes is accepted, at the default size and at 64"
  (list 'no-raise (list bytes-default 64))
  (lambda ()
    (list (bytevector-length (blake2b (bytes-of 65536)))
          (bytevector-length (blake2b (bytes-of 65536) 64)))))

(for-each
 (lambda (row)
   (check (string-append "R15 blake2b size " (car row) " is refused, not-a-natural, its size shown")
     (refusal 'blake2b 'not-a-natural 'size (cadr row))
     (lambda () (blake2b abc (caddr row)))))
 (list (list "-1" -1 -1)
       (list "2.5" 2.5 2.5)
       (list "32.0, which is no exact natural" 32.0 32.0)
       (list "a symbol" 'big 'big)
       (list "a string, shown by its kind" (kind 'string) "32")
       (list "#f" #f #f)))

(check "R15 blake2b size 0 is refused, size-out-of-range"
  (refusal 'blake2b 'size-out-of-range 'size 0)
  (lambda () (blake2b abc 0)))

(check "R15 blake2b one under the least size is refused, size-out-of-range, its size shown"
  (refusal 'blake2b 'size-out-of-range 'size (beside - bytes-min))
  (lambda () (blake2b abc (- bytes-min 1))))

(check "R15 blake2b one over the greatest size is refused, size-out-of-range, its size shown"
  (refusal 'blake2b 'size-out-of-range 'size (beside + bytes-max))
  (lambda () (blake2b abc (+ bytes-max 1))))

(check "R15 blake2b size 2^70 is refused, size-out-of-range, its size shown"
  (refusal 'blake2b 'size-out-of-range 'size (expt 2 70))
  (lambda () (blake2b abc (expt 2 70))))

(check "R15 blake2b at the least size and at the greatest answers that many bytes"
  (list 'no-raise (list bytes-min bytes-max))
  (lambda ()
    (list (bytevector-length (blake2b abc bytes-min))
          (bytevector-length (blake2b abc bytes-max)))))

(for-each
 (lambda (secret)
   (check (string-append "R15 blake2b key of " (symbol->string (cdr secret))
                         ": no bytevector is refused, not-a-bytevector key, by kind alone")
     (refusal 'blake2b 'not-a-bytevector 'key (kind (cdr secret)))
     (lambda () (blake2b abc 32 (car secret)))))
 secrets)

(check "R15 blake2b with an empty key is refused, empty-key, by kind alone"
  (refusal 'blake2b 'empty-key 'key (kind 'bytevector))
  (lambda () (blake2b abc 32 (bytevector))))

(check "R15 blake2b with a key one byte under the least is refused, key-length-out-of-range"
  (refusal 'blake2b 'key-length-out-of-range 'key (kind 'bytevector))
  (lambda () (blake2b abc 32 (bytes-of (- keybytes-min 1)))))

(check "R15 blake2b with a key one byte over the greatest is refused, key-length-out-of-range"
  (refusal 'blake2b 'key-length-out-of-range 'key (kind 'bytevector))
  (lambda () (blake2b abc 32 (bytes-of (+ keybytes-max 1)))))

(check "R15 blake2b with a key of 65537 bytes is refused by the key's range, key-length-out-of-range"
  (refusal 'blake2b 'key-length-out-of-range 'key (kind 'bytevector))
  (lambda () (blake2b abc 32 (bytes-of 65537))))

(check "R15 blake2b with a key of the least length and of the greatest answers 32 bytes each"
  '(no-raise (32 32))
  (lambda ()
    (list (bytevector-length (blake2b abc 32 (bytes-of keybytes-min)))
          (bytevector-length (blake2b abc 32 (bytes-of keybytes-max))))))

;; The order: a call with two mistakes shows the first one only.

(check "R15 blake2b order: a bad input, size and key are refused at the input's type"
  (refusal 'blake2b 'not-a-bytevector 'input (kind 'symbol))
  (lambda () (blake2b 'hunter2 'big 'oops)))

(check "R15 blake2b order: an input over the cap and a bad size are refused at the input's cap"
  (refusal 'blake2b 'over-the-cap 'input (kind 'bytevector))
  (lambda () (blake2b (bytes-of 65537) 'big 'oops)))

(check "R15 blake2b order: a size that is no natural and a key that is no bytevector are refused at the size's type"
  (refusal 'blake2b 'not-a-natural 'size 'big)
  (lambda () (blake2b abc 'big 'oops)))

(check "R15 blake2b order: a size out of range and a key that is no bytevector are refused at the size's range"
  (refusal 'blake2b 'size-out-of-range 'size 0)
  (lambda () (blake2b abc 0 'oops)))

(check "R15 blake2b order: a key that is no bytevector is refused at the key's type, before its length"
  (refusal 'blake2b 'not-a-bytevector 'key (kind 'symbol))
  (lambda () (blake2b abc 32 'oops)))

(check "R15 blake2b order: an empty key is refused as empty, before its length is checked"
  (refusal 'blake2b 'empty-key 'key (kind 'bytevector))
  (lambda () (blake2b abc 32 (bytevector))))

;; --- constant-time-bytevector=?'s refusals

(for-each
 (lambda (secret)
   (check (string-append "R15 constant-time-bytevector=? a of " (symbol->string (cdr secret))
                         ": no bytevector is refused, not-a-bytevector a, by kind alone")
     (refusal 'constant-time-bytevector=? 'not-a-bytevector 'a (kind (cdr secret)))
     (lambda () (constant-time-bytevector=? (car secret) abc)))
   (check (string-append "R15 constant-time-bytevector=? b of " (symbol->string (cdr secret))
                         ": no bytevector is refused, not-a-bytevector b, by kind alone")
     (refusal 'constant-time-bytevector=? 'not-a-bytevector 'b (kind (cdr secret)))
     (lambda () (constant-time-bytevector=? abc (car secret)))))
 secrets)

(check "R15 constant-time-bytevector=? a of 65537 bytes is refused, over-the-cap a, though b is short"
  (refusal 'constant-time-bytevector=? 'over-the-cap 'a (kind 'bytevector))
  (lambda () (constant-time-bytevector=? (bytes-of 65537) (bytes-of 1))))

(check "R15 constant-time-bytevector=? b of 65537 bytes is refused, over-the-cap b, though a is short: the cap comes before the lengths"
  (refusal 'constant-time-bytevector=? 'over-the-cap 'b (kind 'bytevector))
  (lambda () (constant-time-bytevector=? (bytes-of 1) (bytes-of 65537))))

(check "R15 constant-time-bytevector=? a and b of 65537 bytes each are refused at a"
  (refusal 'constant-time-bytevector=? 'over-the-cap 'a (kind 'bytevector))
  (lambda () (constant-time-bytevector=? (bytes-of 65537) (bytes-of 65537))))

(check "R15 constant-time-bytevector=? a and b of 65536 bytes each are accepted: equal answers #t"
  '(no-raise #t)
  (lambda () (constant-time-bytevector=? (bytes-of 65536) (bytes-of 65536))))

(check "R15 constant-time-bytevector=? order: a bad a and a bad b are refused at a's type"
  (refusal 'constant-time-bytevector=? 'not-a-bytevector 'a (kind 'symbol))
  (lambda () (constant-time-bytevector=? 'hunter2 'oops)))

(check "R15 constant-time-bytevector=? order: a bad a and an over-long b are refused at a's type, before b's cap"
  (refusal 'constant-time-bytevector=? 'not-a-bytevector 'a (kind 'symbol))
  (lambda () (constant-time-bytevector=? 'hunter2 (bytes-of 65537))))

(check "R15 constant-time-bytevector=? order: an over-long a and a bad b are refused at a's cap, before b's type"
  (refusal 'constant-time-bytevector=? 'over-the-cap 'a (kind 'bytevector))
  (lambda () (constant-time-bytevector=? (bytes-of 65537) 'oops)))

(check "R15 constant-time-bytevector=? order: a good a and a bad b are refused at b's type"
  (refusal 'constant-time-bytevector=? 'not-a-bytevector 'b (kind 'symbol))
  (lambda () (constant-time-bytevector=? abc 'oops)))

;; --- R16: no secret in a refusal

;; The refusal rows above assert each secret parameter's irritants whole, as
;; (kind K): a value shown by shown-value, a symbol or a number as itself,
;; would differ from them. This row holds the same, over every refusal at
;; once, and that no refusal's condition holds the secret anywhere, message
;; included, by printing each and searching for the secret's text.

;; occurs-in? : String String -> Boolean
(define (occurs-in? needle text)
  (let ((n (string-length text)) (m (string-length needle)))
    (let loop ((i 0))
      (cond ((> (+ i m) n) #f)
            ((string=? (substring text i (+ i m)) needle) #t)
            (else (loop (+ i 1)))))))

(define secret-calls
  (list (cons "blake2b input" (lambda (s) (blake2b s)))
        (cons "blake2b key" (lambda (s) (blake2b abc 32 s)))
        (cons "constant-time-bytevector=? a" (lambda (s) (constant-time-bytevector=? s abc)))
        (cons "constant-time-bytevector=? b" (lambda (s) (constant-time-bytevector=? abc s)))))

(for-each
 (lambda (call)
   (test-equal (string-append "R16 " (car call)
                              ": a symbol, a number and a list of characters are each refused, and the refusal's whole text names none of them")
     '((refused refused refused) (clean clean clean))
     (let* ((vals (list 'hunter2 4242424242 '(#\q #\z #\w)))
            (needles (list '("hunter2") '("4242424242") '("#\\q" "(q z w)")))
            (conditions (map (lambda (value)
                               (guard (e (#t e)) ((cdr call) value) 'no-raise))
                             vals)))
       (list (map (lambda (c) (if (assertion-violation? c) 'refused (list 'not-refused c)))
                  conditions)
             (map (lambda (c needle)
                    (if (and (condition? c)
                         (not (exists (lambda (n) (occurs-in? n (describe c))) needle)))
                    'clean
                    'leaks))
                  conditions needles)))))
 secret-calls)

;; --- the cap and the exports ---------------------------------------------------------------------

(test-equal "input-cap is 65536"
  65536
  input-cap)

(check "S5 libsodium's greatest hash size and greatest key length are each at most the input cap: the output and the key are capped only through those bounds, which no verb compares with input-cap"
  '(no-raise (#t #t))
  (lambda () (list (<= bytes-max input-cap) (<= keybytes-max input-cap))))

(define (sorted-exports lib)
  (guard (e (#t (list 'unreadable (describe e))))
    (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
               (library-exports lib))))

(test-equal "(chez-sodium private byte-verbs) exports exactly the three verbs"
  '(blake2b constant-time-bytevector=? random-bytes)
  (sorted-exports verbs-lib))

(test-equal "(chez-sodium private cap) exports exactly input-cap"
  '(input-cap)
  (sorted-exports cap-lib))

;; --- R18: under an engine ------------------------------------------------------------------------
;; An engine spends no ticks inside a critical section, so no expiry falls in
;; one, and an expiry before it is resumed harmlessly. Each row runs a job at
;; every fuel from 1 until the first fuel at which it completes without
;; expiring, and asserts the outcome at each, never the count of expiries.
;; Both libraries were reached at the top of this suite, before the first
;; engine.

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

;; shape-outcome : Any -> Any
(define (shape-outcome outcome)
  (if (and (pair? outcome) (eq? (car outcome) 'raised))
      (list 'raised (let ((e (cadr outcome))) (if (condition? e) (describe e) e)))
      outcome))

;; sweep : (-> Any) (Any -> Boolean) -> Any
;; JOB at each fuel from 1: every outcome must satisfy RIGHT? and leave every
;; count zero. (every-fuel-right reached-a-completing-fuel) when a fuel
;; completes with no expiry; otherwise (wrong-at-fuel N OUTCOME COUNTS), or
;; never-completed past 5,000.
(define (sweep job right?)
  (let loop ((fuel 1))
    (if (> fuel 5000)
        'never-completed
        (let* ((run (run-in-engine fuel job))
               (counts (native-counts)))
          (cond ((not (and (right? (car run)) (equal? counts zero-counts)))
                 (list 'wrong-at-fuel fuel (shape-outcome (car run)) counts))
                ((= (cadr run) 0) '(every-fuel-right reached-a-completing-fuel))
                (else (loop (+ fuel 1))))))))

(define sweep-right '(every-fuel-right reached-a-completing-fuel))

(test-equal "R18 random-bytes 32 under an engine at every fuel from 1 until it completes: each run answers 32 bytes, raises nothing, and leaves every count zero"
  sweep-right
  (sweep (lambda () (random-bytes 32))
         (lambda (outcome)
           (and (pair? outcome) (eq? (car outcome) 'done) (bytevector? (cadr outcome))
                (= (bytevector-length (cadr outcome)) 32)))))

(test-equal "R18 random-bytes 0 under an engine at every fuel: each run answers #vu8()"
  sweep-right
  (sweep (lambda () (random-bytes 0))
         (lambda (outcome) (equal? outcome '(done #vu8())))))

(test-equal "R18 blake2b of \"abc\" at size 32 under an engine at every fuel: each run answers BLAKE2b-256's bddd813c...d52319, raises nothing, and leaves every count zero"
  sweep-right
  (sweep (lambda () (blake2b abc 32))
         (lambda (outcome)
           (and (pair? outcome) (eq? (car outcome) 'done) (bytevector? (cadr outcome))
                (equal? (bytes->hex (cadr outcome))
                        "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")))))

(test-equal "R18 blake2b of \"abc\" at size 32 keyed by 16 bytes under an engine at every fuel: each run answers 6a0e5434...4701da"
  sweep-right
  (sweep (lambda () (blake2b abc 32 (counting 16 1)))
         (lambda (outcome)
           (and (pair? outcome) (eq? (car outcome) 'done) (bytevector? (cadr outcome))
                (equal? (bytes->hex (cadr outcome))
                        "6a0e54342c7a2cccd02d678e5513f8a643a3b46b7a45db70a985c19f744701da")))))

(test-equal "R18 constant-time-bytevector=? of equal operands under an engine at every fuel: each run answers #t"
  sweep-right
  (sweep (lambda () (constant-time-bytevector=? (counting 32 1) (counting 32 1)))
         (lambda (outcome) (equal? outcome '(done #t)))))

(test-equal "R18 constant-time-bytevector=? of operands that differ under an engine at every fuel: each run answers #f"
  sweep-right
  (sweep (lambda () (constant-time-bytevector=? (counting 32 1) (counting 32 2)))
         (lambda (outcome) (equal? outcome '(done #f)))))

(test-equal "R18 constant-time-bytevector=? of operands of other lengths under an engine at every fuel: each run answers #f"
  sweep-right
  (sweep (lambda () (constant-time-bytevector=? (counting 32 1) (counting 31 1)))
         (lambda (outcome) (equal? outcome '(done #f)))))

;; --- S: the verbs' bodies, read as data ----------------------------------------------------------
;; A verb that refused a mistake or raised inside its section behaves exactly
;; as one that does it outside: call-in-section raises again, after the
;; section, whatever its thunk raised, so the handler runs at depth 1, every
;; count is zero and the decoy's log is empty. Only the text can tell. So
;; byte-verbs.sls is read as data, forms and never comments.

(define verbs-source "src/chez-sodium/private/byte-verbs.sls")
(define cap-source "src/chez-sodium/private/cap.sls")

;; read-library : String -> (U (List Any ...) (List 'unreadable Any))
;; The library form at PATH, as a list.
(define (read-library path)
  (guard (e (#t (list 'unreadable (describe e))))
    (let ((form (call-with-port
                 (open-file-input-port path (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (if (and (list? form) (> (length form) 4) (eq? (car form) 'library))
          form
          (list 'unreadable 'not-a-library-form)))))

(define verbs-form (read-library verbs-source))
(define cap-form (read-library cap-source))

(define (library-read? form) (not (eq? (car form) 'unreadable)))

;; library-imports : Any -> (U (Listof Any) (List 'unreadable Any))
;; The import specs of a library form, each as written.
(define (library-imports form)
  (if (and (library-read? form) (list? (cadddr form)) (eq? (car (cadddr form)) 'import))
      (cdr (cadddr form))
      (list 'unreadable 'no-import-clause)))

;; library-body : Any -> (Listof Any)
(define (library-body form)
  (if (library-read? form) (cddddr form) '()))

;; definition-form : Symbol -> Any
;; The top-level (define NAME EXPR) or (define (NAME . ARGS) BODY ...) of NAME
;; in the verbs' library, or no-definition.
(define (definition-form name)
  (let loop ((forms (library-body verbs-form)))
    (cond ((null? forms) 'no-definition)
          ((let ((form (car forms)))
             (and (pair? form) (eq? (car form) 'define) (pair? (cdr form))
                  (or (eq? (cadr form) name)
                      (and (pair? (cadr form)) (eq? (car (cadr form)) name)))))
           (car forms))
          (else (loop (cdr forms))))))

;; tokens : Any -> (Listof Any)
;; The symbols of X, in reading order, a dotted tail and a vector included.
(define (tokens x)
  (cond ((symbol? x) (list x))
        ((pair? x) (append (tokens (car x)) (tokens (cdr x))))
        ((vector? x) (tokens (vector->list x)))
        (else '())))

;; headed : Symbol Any -> (Listof Any)
;; Every list headed by HEAD anywhere in X, in reading order, elements only.
(define (headed head x)
  (cond ((not (pair? x)) '())
        (else
         (let loop ((rest x) (found (if (eq? (car x) head) (list x) '())))
           (if (pair? rest)
               (loop (cdr rest) (append found (headed head (car rest))))
               found)))))

(define verb-names '(random-bytes blake2b constant-time-bytevector=?))

(define (count-of symbol list)
  (let loop ((rest list) (n 0))
    (cond ((null? rest) n)
          ((eq? (car rest) symbol) (loop (cdr rest) (+ n 1)))
          (else (loop (cdr rest) n)))))

(test-equal "S1 each verb's definition holds exactly one call-in-section, as a symbol anywhere in it"
  '((random-bytes 1) (blake2b 1) (constant-time-bytevector=? 1))
  (map (lambda (name) (list name (count-of 'call-in-section (tokens (definition-form name)))))
       verb-names))

(test-equal "S1 the library's whole body holds three call-in-section symbols, one in each verb: no helper holds a section of its own"
  3
  (count-of 'call-in-section (tokens (library-body verbs-form))))

;; around-section : Symbol Symbol -> (List Natural Natural)
;; How many times TOKEN occurs in NAME's definition before its first
;; call-in-section, in reading order, and how many after.
(define (around-section name token)
  (let loop ((rest (tokens (definition-form name))) (before 0) (after 0) (seen-section #f))
    (cond ((null? rest) (list before after))
          ((eq? (car rest) 'call-in-section) (loop (cdr rest) before after #t))
          ((eq? (car rest) token)
           (if seen-section
               (loop (cdr rest) before (+ after 1) seen-section)
               (loop (cdr rest) (+ before 1) after seen-section)))
          (else (loop (cdr rest) before after seen-section)))))

(test-equal "S2 every refusal is before the section, every raise after it: in each verb, the assertion-violation, refuse-secret and raise-sodium-failed forms, counted before and after its call-in-section"
  '((random-bytes (assertion-violation 2 0) (refuse-secret 0 0) (raise-sodium-failed 0 0))
    (blake2b (assertion-violation 2 0) (refuse-secret 5 0) (raise-sodium-failed 0 1))
    (constant-time-bytevector=? (assertion-violation 0 0) (refuse-secret 4 0)
                                (raise-sodium-failed 0 0)))
  (map (lambda (name)
         (cons name
               (map (lambda (token) (cons token (around-section name token)))
                    '(assertion-violation refuse-secret raise-sodium-failed))))
       verb-names))

;; section-tokens : Symbol -> (Listof Symbol)
;; Every symbol inside call-in-section's argument in NAME's definition, in
;; reading order.
(define (section-tokens name)
  (append-map tokens (map cdr (headed 'call-in-section (definition-form name)))))

(test-equal "S2 no lambda in a verb's definition lies outside its call-in-section argument, but case-lambda's clauses: a check cannot be written there and called inside"
  '((random-bytes 0) (blake2b 0) (constant-time-bytevector=? 0))
  (map (lambda (name)
         (list name (- (count-of 'lambda (tokens (definition-form name)))
                       (count-of 'lambda (section-tokens name)))))
       verb-names))

;; What runs inside a section is whatever it names. Each verb's whole list is
;; written here, so a helper called there, a let-bound lambda or a top-level
;; procedure, raiser or not, adds its name and fails the row. The names are
;; the verb's own variables, syntax, native's bindings and the block helpers.
(test-equal "S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called there, and no raise"
  '((random-bytes lambda call-with-block quote random-bytes n leave-unwritten lambda out
                  randombytes-buf out n foreign-bytes out n)
    (blake2b lambda call-with-bytes quote blake2b input lambda in
             call-with-bytes quote blake2b key-bytes lambda key-block
             call-with-block quote blake2b size leave-unwritten lambda out
             let code crypto-generichash out size in bytevector-length input
             key-block bytevector-length key-bytes
             if eqv? code cons quote hash foreign-bytes out size cons quote failed code)
    (constant-time-bytevector=? lambda call-with-bytes quote constant-time-bytevector=? a lambda a-block
                                call-with-bytes quote constant-time-bytevector=? b lambda b-block
                                sodium-memcmp a-block b-block bytevector-length a))
  (map (lambda (name) (cons name (section-tokens name))) verb-names))

(test-equal "S4 byte-verbs' import clauses, whole: require-threaded first, then (rnrs), native, conditions and cap, and nothing from (chezscheme)"
  '((chez-sodium private require-threaded)
    (rnrs)
    (chez-sodium private native)
    (chez-sodium private conditions)
    (chez-sodium private cap))
  (library-imports verbs-form))

(test-equal "S4 cap's import clauses, whole: require-threaded first, then (rnrs)"
  '((chez-sodium private require-threaded) (rnrs))
  (library-imports cap-form))

(test-equal "S4 the verbs' library exports the three verbs, as written"
  '(export random-bytes blake2b constant-time-bytevector=?)
  (if (library-read? verbs-form) (caddr verbs-form) 'unreadable))

(test-equal "S4 cap's library exports input-cap alone, and defines it as 65536"
  '((export input-cap) ((define input-cap 65536)))
  (list (if (library-read? cap-form) (caddr cap-form) 'unreadable)
        (filter (lambda (form) (and (pair? form) (eq? (car form) 'define)))
                (library-body cap-form))))

;; source-files : String -> (Listof String)
;; Every file under DIR, recursively, sorted.
(define (source-files dir)
  (list-sort string<?
             (append-map
              (lambda (name)
                (let ((path (string-append dir "/" name)))
                  (if (file-directory? path) (source-files path) (list path))))
              (directory-list dir))))

(define (file-text path)
  (call-with-port
   (open-file-input-port path (file-options) (buffer-mode block)
                         (make-transcoder (utf-8-codec)))
   get-string-all))

(test-equal "S5 input-cap is written in each verb's definition as many times as it checks a length: random-bytes 1, blake2b 1, the compare 2"
  '((random-bytes 1) (blake2b 1) (constant-time-bytevector=? 2))
  (map (lambda (name) (list name (count-of 'input-cap (tokens (definition-form name)))))
       verb-names))

(test-equal "S5 the text 65536 occurs under src/ in cap.sls alone"
  '("src/chez-sodium/private/cap.sls")
  (guard (e (#t (list 'unreadable (describe e))))
    (filter (lambda (path) (occurs-in? "65536" (file-text path)))
            (source-files "src"))))

;; --- the end -------------------------------------------------------------------------------------

(test-equal "every count is zero after every row"
  zero-counts
  (native-counts))

(test-end "byte-verbs")

(exit (suite-exit-status runner))
