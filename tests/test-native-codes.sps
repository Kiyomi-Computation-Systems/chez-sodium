#!r6rs
;;; The return codes of the verbs' three entry points, through native's raw
;;; bindings on blocks from native's call-with-block, against the library
;;; this suite loads (CHEZ_SODIUM_LIBRARY when set, else discovery's):
;;; crypto_generichash, sodium_memcmp and randombytes_buf. Every code the brief states is
;;; confirmed here by a row against the real library before any verb relies
;;; on it.
;;;
;;;   crypto_generichash  outlen 0 and 65 answer -1; 1, 15, 16, 32 and 64
;;;                  answer 0 and write BLAKE2b of "abc" at that size.
;;;                  keylen 65 answers -1; 0, 1, 15, 16 and 64 answer 0 and
;;;                  write the keyed hash. inlen 0 on a one-byte block
;;;                  answers 0. Every -1 leaves out as it was. With keylen 0
;;;                  the key block's bytes are never read: two blocks of
;;;                  different bytes give the unkeyed hash
;;;   sodium_memcmp  equal blocks answer 0; a difference in the first byte,
;;;                  in the last, and in every byte, each both ways round,
;;;                  answers -1; a length of 0 answers 0 on blocks that differ
;;;   randombytes_buf  size 0 leaves a block as it was; size 16 writes 16
;;;                  bytes and no more
;;;
;;; The expected hashes are Python's hashlib.blake2b over the same inputs,
;;; written here as hex. Every computation that can raise runs under a guard
;;; with a sentinel of its own, and no expected value is #f for something that
;;; can raise. The suite ends with every count zero.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (only (chezscheme) foreign-ref foreign-set! void)
        (chez-sodium-testing)
        (chez-sodium private counters))

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

;; --- native, reached through eval, once, before any row ----------------------------------------

(define native-load
  (guard (e (#t (list 'raised (describe e))))
    (eval '(loaded-libsodium) (environment '(chez-sodium private native)))
    'loaded))

(define (native-procedure name)
  (guard (e (#t (lambda args
                  (error name "(chez-sodium private native) could not be reached" (describe e)))))
    (eval name (environment '(chez-sodium private native)))))

(define call-with-block (native-procedure 'call-with-block))
(define crypto-generichash (native-procedure 'crypto-generichash))
(define sodium-memcmp (native-procedure 'sodium-memcmp))
(define randombytes-buf (native-procedure 'randombytes-buf))

;; --- helpers -----------------------------------------------------------------------------------

;; make-list-of : Natural Any -> (Listof Any)
(define (make-list-of n x) (if (= n 0) '() (cons x (make-list-of (- n 1) x))))

;; peek : Natural Natural -> (Listof Natural)
(define (peek address n)
  (let loop ((i (- n 1)) (found '()))
    (if (< i 0) found (loop (- i 1) (cons (foreign-ref 'unsigned-8 address i) found)))))

;; poke! : Natural (Listof Natural) -> Void
(define (poke! address bytes)
  (let loop ((i 0) (bytes bytes))
    (unless (null? bytes)
      (foreign-set! 'unsigned-8 address i (car bytes))
      (loop (+ i 1) (cdr bytes)))))

;; with-bytes : (Listof Natural) (Natural -> Any) -> Any
;; PROC's answer, given the address of a block holding BYTES (a block of one
;; byte, 0, for none: no pointer is ever NULL), from native's call-with-block.
(define (with-bytes bytes proc)
  (call-with-block 'test-native-codes (max 1 (length bytes))
                   (lambda (address) (poke! address (if (null? bytes) '(0) bytes)))
                   proc))

;; hex->bytes : String -> (Listof Natural)
(define (hex->bytes hex)
  (let loop ((i 0) (found '()))
    (if (>= i (string-length hex))
        (reverse found)
        (loop (+ i 2) (cons (string->number (substring hex i (+ i 2)) 16) found)))))

;; iota-from-1 : Natural -> (Listof Natural)
;; (1 2 ... N), the key's bytes.
(define (iota-from-1 n)
  (let loop ((i n) (found '()))
    (if (= i 0) found (loop (- i 1) (cons i found)))))

;; guarded : (-> Any) -> Any
;; THUNK's answer, or (raised TEXT).
(define (guarded thunk)
  (guard (e (#t (list 'raised (describe e))))
    (thunk)))

(define fill #xCC)
(define out-size 80)

;; hash : Natural (Listof Natural) Natural (Listof Natural) Natural
;;        -> (List Integer (Listof Natural))
;; crypto_generichash into an 80-byte block filled with CC: the code, and the
;; block read back whole. INBYTES and KEYBYTES are the bytes of the blocks;
;; INLEN and KEYLEN what is passed.
(define (hash outlen inbytes inlen keybytes keylen)
  (call-with-block 'test-native-codes out-size
                   (lambda (out) (poke! out (make-list-of out-size fill)))
                   (lambda (out)
                     (with-bytes inbytes
                       (lambda (in)
                         (with-bytes keybytes
                           (lambda (key)
                             (let ((code (crypto-generichash out outlen in inlen key keylen)))
                               (list code (peek out out-size))))))))))

;; take : (Listof Any) Natural -> (Listof Any)
(define (take xs n) (if (= n 0) '() (cons (car xs) (take (cdr xs) (- n 1)))))

;; padded : (Listof Natural) -> (Listof Natural)
;; BYTES, then the fill, to the out block's 80: what a hash of that size
;; leaves in the block.
(define (padded bytes)
  (append bytes (make-list-of (- out-size (length bytes)) fill)))

(define abc '(#x61 #x62 #x63))
(define untouched (list -1 (make-list-of out-size fill)))

(define abc-at
  '((1 . "6b")
    (15 . "cb322ea749b92c9a46ca598e516025")
    (16 . "cf4ab791c62b8d2b2109c90275287816")
    (32 . "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319")
    (64 . "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923")))

(define keyed-abc-at-32
  '((1 . "3cd0fce8793ea08ce5da55ad90cd85c7a971618d2b40f424a7019b91cf9e4d4f")
    (15 . "6a4be4a022ceb34bad08e88ec3061909013342df57aed789c12d2392d8a941e1")
    (16 . "6a0e54342c7a2cccd02d678e5513f8a643a3b46b7a45db70a985c19f744701da")
    (64 . "d342184a15d79ed16db1f56034d3aab4472fcdff6e7aa3226bc95a86876124f0")))

(define empty-at-32 "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8")

(define zero-counts '((block . 0)))

(test-begin "native-codes")

(test-equal "(chez-sodium private native) loads, reached through eval"
  'loaded
  native-load)

;; --- crypto_generichash ------------------------------------------------------------------------

(test-equal "crypto_generichash: outlen 0 and 65 answer -1, and out is left as it was, the 80 bytes read whole (the call's code and block)"
  (list untouched untouched)
  (guarded (lambda ()
             (let* ((zero (hash 0 abc 3 '(0) 0))
                    (over (hash 65 abc 3 '(0) 0)))
               (list zero over)))))

(test-equal "crypto_generichash: outlen 1, 15, 16, 32 and 64 answer 0 and write BLAKE2b of abc at that size, and nothing past it (each call's code and block)"
  (map (lambda (entry) (list 0 (padded (hex->bytes (cdr entry))))) abc-at)
  (guarded (lambda ()
             (let loop ((entries abc-at) (found '()))
               (if (null? entries)
                   (reverse found)
                   (loop (cdr entries)
                         (cons (hash (car (car entries)) abc 3 '(0) 0) found)))))))

(test-equal "crypto_generichash: keylen 65 and 128 answer -1, and out is left as it was (each call's code and block)"
  (list untouched untouched)
  (guarded (lambda ()
             (let* ((at-65 (hash 32 abc 3 (iota-from-1 65) 65))
                    (at-128 (hash 32 abc 3 (iota-from-1 128) 128)))
               (list at-65 at-128)))))

(test-equal "crypto_generichash: keylen 1, 15, 16 and 64 answer 0 and write the keyed hash at size 32 (each call's code and block)"
  (map (lambda (entry) (list 0 (padded (hex->bytes (cdr entry))))) keyed-abc-at-32)
  (guarded (lambda ()
             (let loop ((entries keyed-abc-at-32) (found '()))
               (if (null? entries)
                   (reverse found)
                   (loop (cdr entries)
                         (cons (hash 32 abc 3 (iota-from-1 (car (car entries)))
                                     (car (car entries)))
                               found)))))))

(test-equal "crypto_generichash: keylen 0 answers 0 and writes the unkeyed hash, whatever the key block holds: two key blocks of different bytes give the same (each call's code and block)"
  (let ((unkeyed (list 0 (padded (hex->bytes (cdr (assv 32 abc-at)))))))
    (list unkeyed unkeyed))
  (guarded (lambda ()
             (let* ((a (hash 32 abc 3 '(#x11) 0))
                    (b (hash 32 abc 3 '(#xEE) 0)))
               (list a b)))))

(test-equal "crypto_generichash: inlen 0 on a one-byte block answers 0 and writes the hash of nothing at size 32 (the call's code and block)"
  (list 0 (padded (hex->bytes empty-at-32)))
  (guarded (lambda () (hash 32 '(#x61) 0 '(0) 0))))

;; --- sodium_memcmp ---------------------------------------------------------------------------

;; compare : (Listof Natural) (Listof Natural) Natural -> Integer
;; sodium_memcmp over blocks holding A and B, LEN bytes.
(define (compare a b len)
  (with-bytes a
    (lambda (x)
      (with-bytes b
        (lambda (y) (sodium-memcmp x y len))))))

(define eight '(1 2 3 4 5 6 7 8))
(define eight-first '(9 2 3 4 5 6 7 8))
(define eight-last '(1 2 3 4 5 6 7 9))
(define eight-every '(9 8 7 6 5 4 3 2))

(test-equal "sodium_memcmp: equal blocks answer 0; a difference in the first byte, the last byte and every byte answers -1, each both ways round (the seven calls' codes, in order)"
  '(0 -1 -1 -1 -1 -1 -1)
  (guarded (lambda ()
             (let* ((equal (compare eight eight 8))
                    (first-ab (compare eight eight-first 8))
                    (first-ba (compare eight-first eight 8))
                    (last-ab (compare eight eight-last 8))
                    (last-ba (compare eight-last eight 8))
                    (every-ab (compare eight eight-every 8))
                    (every-ba (compare eight-every eight 8)))
               (list equal first-ab first-ba last-ab last-ba every-ab every-ba)))))

(test-equal "sodium_memcmp: a length of 0 on two blocks that differ answers 0 (the call's code)"
  0
  (guarded (lambda () (compare '(1) '(2) 0))))

(test-equal "sodium_memcmp: a length short of the difference answers 0, and one covering it -1 (the two calls' codes)"
  '(0 -1)
  (guarded (lambda ()
             (let* ((short (compare eight eight-last 7))
                    (whole (compare eight eight-last 8)))
               (list short whole)))))

;; --- randombytes_buf ---------------------------------------------------------------------------

(test-equal "randombytes_buf: size 0 leaves a one-byte block as it was (the call's answer and the block)"
  (list (void) '(#xCC))
  (guarded (lambda ()
             (call-with-block 'test-native-codes 1
                              (lambda (b) (poke! b '(#xCC)))
                              (lambda (b)
                                (let ((answer (randombytes-buf b 0)))
                                  (list answer (peek b 1))))))))

(test-equal "randombytes_buf: size 16 writes the block, so its 16 bytes are not all one value (the fill, a zero wipe, a constant), and the four bytes after it are as they were (the call's answer, the first 16 bytes' verdict and the last 4)"
  (list (void) 'written '(#xCC #xCC #xCC #xCC))
  (guarded (lambda ()
             (call-with-block 'test-native-codes 20
                              (lambda (b) (poke! b (make-list-of 20 #xCC)))
                              (lambda (b)
                                (let* ((answer (randombytes-buf b 16))
                                       (bytes (peek b 20))
                                       (head (take bytes 16))
                                       (tail (list-tail bytes 16)))
                                  (list answer
                                        (if (for-all (lambda (x) (= x (car head))) head) 'unwritten 'written)
                                        tail)))))))

(test-equal "every count is zero at the end"
  zero-counts
  (native-counts))

(test-end "native-codes")

(exit (suite-exit-status runner))
