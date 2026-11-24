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
;;;   crypto_pwhash_str  at the minimum limits: 0, a string of 93 characters,
;;;                  and all 128 bytes of out written; -1 for an opslimit
;;;                  of 0, 2^32 and 2^64-1 and a memlimit of 0, one under the
;;;                  minimum, one over the maximum and 2^64-1, each leaving
;;;                  out all zeros; the empty password on a one-byte block: 0;
;;;                  a memlimit floored to whole KiB
;;;   crypto_pwhash_str_verify  right 0, wrong -1; garbage, none, trailing
;;;                  junk and leading space -1; the hash then a NUL and
;;;                  junk 0, since C reads to the first NUL; a password with
;;;                  a NUL, the empty one and a non-ASCII one, by their bytes;
;;;                  a 136-character hash 0, wrong -1
;;;   crypto_pwhash_str_needs_rehash  the limits compared in whole KiB;
;;;                  garbage, any string of 128 characters or more, and ops
;;;                  2^32 and over -1; an argon2i string at ops 3: 0; p=4 or
;;;                  p=2 at 64 KiB: 0 and p=4 at 8 KiB -1; a byte of 0x80 or
;;;                  more in the salt: 0 at 1.0.18, -1 at 1.0.22; the three
;;;                  presets' hand-written strings, a 3x3 table of 0 and 1;
;;;                  a salt of 21 characters or a tag of 42 -1
;;;
;;; The no-memory codes, which need a limit on the process's address space,
;;; are not here: the memory gate's Valgrind cannot run under one.
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
(define crypto-pwhash-str (native-procedure 'crypto-pwhash-str))
(define crypto-pwhash-str-verify (native-procedure 'crypto-pwhash-str-verify))
(define crypto-pwhash-str-needs-rehash (native-procedure 'crypto-pwhash-str-needs-rehash))
(define loaded-libsodium (native-procedure 'loaded-libsodium))
;; The constants are numbers, fetched the same way: a failed fetch answers a
;; procedure, which no row expects.
(define strbytes (native-procedure 'pwhash-strbytes))
(define ops-min (native-procedure 'pwhash-opslimit-min))
(define ops-interactive (native-procedure 'pwhash-opslimit-interactive))
(define ops-moderate (native-procedure 'pwhash-opslimit-moderate))
(define ops-sensitive (native-procedure 'pwhash-opslimit-sensitive))
(define mem-min (native-procedure 'pwhash-memlimit-min))
(define mem-max (native-procedure 'pwhash-memlimit-max))
(define mem-interactive (native-procedure 'pwhash-memlimit-interactive))
(define mem-moderate (native-procedure 'pwhash-memlimit-moderate))
(define mem-sensitive (native-procedure 'pwhash-memlimit-sensitive))

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

;; --- the password hash ------------------------------------------------------------------------

;; version : (U String (List 'raised String))
;; The loaded library's version, from native's record.
(define version
  (guarded (lambda () (cdr (assq 'version (loaded-libsodium))))))

;; ascii : String -> (Listof Natural)
;; TEXT's UTF-8 bytes.
(define (ascii text) (bytevector->u8-list (string->utf8 text)))

;; with-cstr : (Listof Natural) (Natural -> Any) -> Any
;; PROC's answer, given the address of a block holding BYTES then a 0.
(define (with-cstr bytes proc) (with-bytes (append bytes '(0)) proc))

;; with-out : (Natural -> Any) -> Any
;; PROC's answer, given a block of strbytes bytes, each 5A.
(define (with-out proc)
  (call-with-block 'test-native-codes strbytes
                   (lambda (out) (poke! out (make-list-of strbytes #x5A)))
                   proc))

;; hash-call : (Listof Natural) Natural Natural -> (List Integer (Listof Natural))
;; crypto_pwhash_str of the password PW, its length their count: the code,
;; and the out block read back whole.
(define (hash-call pw ops mem)
  (with-out
   (lambda (out)
     (with-bytes pw
       (lambda (p)
         (let ((code (crypto-pwhash-str out p (length pw) ops mem)))
           (list code (peek out strbytes))))))))

;; before-nul : (Listof Natural) -> (Listof Natural)
(define (before-nul bytes)
  (if (or (null? bytes) (= (car bytes) 0)) '() (cons (car bytes) (before-nul (cdr bytes)))))

;; hash-string : (Listof Natural) Natural Natural -> (Listof Natural)
;; The hash string's bytes crypto_pwhash_str wrote, before its 0.
(define (hash-string pw ops mem)
  (before-nul (cadr (hash-call pw ops mem))))

;; verify : (Listof Natural) (Listof Natural) -> Integer
;; crypto_pwhash_str_verify of STR (its bytes, then a 0) against PW.
(define (verify str pw)
  (with-cstr str
    (lambda (s) (with-bytes pw (lambda (p) (crypto-pwhash-str-verify s p (length pw)))))))

;; rehash : (Listof Natural) Natural Natural -> Integer
(define (rehash str ops mem)
  (with-cstr str (lambda (s) (crypto-pwhash-str-needs-rehash s ops mem))))

;; str-replace : (Listof Natural) String String -> (Listof Natural)
;; BYTES with the first FROM turned to TO.
(define (str-replace bytes from to)
  (let ((f (ascii from)) (t (ascii to)))
    (let loop ((rest bytes) (done '()))
      (cond ((null? rest) (error 'str-replace "absent" from))
            ((and (>= (length rest) (length f)) (equal? (take rest (length f)) f))
             (append (reverse done) t (list-tail rest (length f))))
            (else (loop (cdr rest) (cons (car rest) done)))))))

;; split-dollar : (Listof Natural) -> (Listof String)
;; BYTES cut at each $, as strings.
(define (split-dollar bytes)
  (let loop ((rest bytes) (piece '()) (found '()))
    (cond ((null? rest) (reverse (cons (utf8->string (u8-list->bytevector (reverse piece))) found)))
          ((= (car rest) 36)
           (loop (cdr rest) '()
                 (cons (utf8->string (u8-list->bytevector (reverse piece))) found)))
          (else (loop (cdr rest) (cons (car rest) piece) found)))))

(define pw (ascii "pw"))
(define two-pow-32 (expt 2 32))
(define two-pow-64-1 (- (expt 2 64) 1))

;; The hash of "pw" at the minimum limits, made by the library under test.
(define pw-hash (guarded (lambda () (hash-string pw ops-min mem-min))))

;; A hash string of 136 characters: argon2id, a 64-byte tag, made by libsodium
;; at the minimum limits for "pw". strbytes is 128, so it does not fit a
;; hash string's out block, and libsodium still verifies it.
(define long-hash
  (ascii "$argon2id$v=19$m=8,t=1,p=1$EyYDv0QsQbeigj9AAWd4og$2h21FCkx8IoVDEl4/mLnPx/13x3VOsaGEEcSznsHWANOIbT5yNoNpmiSmo3WFrwrB8CHtsaXS9cT0QGGUfFzow"))

;; An argon2i string at ops 3, memory 8 KiB, made for "pw" by libsodium's own
;; crypto_pwhash_argon2i_str.
(define argon2i-hash
  (ascii "$argon2i$v=19$m=8,t=3,p=1$CnLsK+WNsgawJO1WNHy1Aw$jsPoZZueVvGjKl1UzqjOy2TYclOwPdW9LWyWchqkxbw"))

;; crypto_pwhash_str ----------------------------------------------------------------------------

(test-equal "crypto_pwhash_str at the minimum limits answers 0 and writes a string of 93 characters, then zeros to the end of out's 128 bytes, none left 5A; its fields are the prefix, v=19, m=8,t=1,p=1, a salt of 22 characters and a tag of 43 (the call's code, the string's length, the zeros and 5As after it, the fields)"
  (list 0 93 (- 128 94) 0 '("" "argon2id" "v=19" "m=8,t=1,p=1" 22 43))
  (guarded (lambda ()
             (let* ((made (hash-call pw ops-min mem-min))
                    (bytes (cadr made))
                    (string (before-nul bytes))
                    (after (list-tail bytes (+ (length string) 1)))
                    (fields (split-dollar string)))
               (list (car made) (length string)
                     (length (filter (lambda (b) (= b 0)) after))
                     (length (filter (lambda (b) (= b #x5A)) after))
                     (list (car fields) (cadr fields) (caddr fields) (cadddr fields)
                           (string-length (list-ref fields 4)) (string-length (list-ref fields 5))))))))

(test-equal "crypto_pwhash_str answers -1 and leaves all 128 bytes of out zero for an opslimit of 0, 2^32 and 2^64-1, and a memlimit of 0, one under the minimum, one over the maximum and 2^64-1 (each call's code and whether out is all zero)"
  (make-list-of 7 '(-1 #t))
  (guarded (lambda ()
             (map (lambda (limits)
                    (let ((made (hash-call pw (car limits) (cadr limits))))
                      (list (car made) (for-all (lambda (b) (= b 0)) (cadr made)))))
                  (list (list 0 mem-min) (list two-pow-32 mem-min) (list two-pow-64-1 mem-min)
                        (list ops-min 0) (list ops-min (- mem-min 1))
                        (list ops-min (+ mem-max 1)) (list ops-min two-pow-64-1))))))

(test-equal "crypto_pwhash_str of the empty password, length 0 on a one-byte block, answers 0 and writes a string that verifies the empty password 0, and not \"x\" (-1)"
  '(0 0 -1)
  (guarded (lambda ()
             (let* ((made (with-out
                           (lambda (out)
                             (with-bytes '()
                               (lambda (p)
                                 (let ((code (crypto-pwhash-str out p 0 ops-min mem-min)))
                                   (list code (before-nul (peek out strbytes)))))))))
                    (string (cadr made)))
               (list (car made) (verify string '()) (verify string (ascii "x")))))))

(test-equal "crypto_pwhash_str at ops 2 floors a memlimit of 16 KiB + 1 byte to whole KiB: the parameter field is m=16,t=2,p=1, as at 16 KiB, with a 94-character string"
  '("m=16,t=2,p=1" "m=16,t=2,p=1" 94)
  (guarded (lambda ()
             (let* ((plus (hash-string pw 2 (+ (* 16 1024) 1)))
                    (exact (hash-string pw 2 (* 16 1024))))
               (list (cadddr (split-dollar plus)) (cadddr (split-dollar exact)) (length exact))))))

;; crypto_pwhash_str_verify ---------------------------------------------------------------------

(test-equal "crypto_pwhash_str_verify: the right password 0, a wrong one -1; \"garbage\", an empty string, the hash then \"junk\", then a newline, and after a space -1; the hash then a NUL and \"junk\" 0, as C reads to the first NUL (the nine calls' codes, in order)"
  '(0 -1 -1 -1 -1 -1 -1 -1 0)
  (guarded (lambda ()
             (list (verify pw-hash pw) (verify pw-hash (ascii "pX"))
                   (verify (ascii "garbage") pw) (verify '() pw)
                   (verify (append pw-hash (ascii "junk")) pw)
                   (verify (append pw-hash '(10)) pw)
                   (verify (cons 32 pw-hash) pw)
                   (verify (ascii "$argon2id$") pw)
                   (verify (append pw-hash '(0) (ascii "junk")) pw)))))

(test-equal "crypto_pwhash_str_verify: a password of 3 bytes with a NUL, 61 00 62, verifies its own hash 0 and \"a\" -1; the empty password verifies its own 0 and \"x\" -1"
  '(0 -1 0 -1)
  (guarded (lambda ()
             (let* ((a0b (list #x61 0 #x62))
                    (ha0b (hash-string a0b ops-min mem-min))
                    (he (hash-string '() ops-min mem-min)))
               (list (verify ha0b a0b) (verify ha0b (ascii "a"))
                     (verify he '()) (verify he (ascii "x")))))))

(test-equal "crypto_pwhash_str_verify: a 136-character hash, longer than strbytes, verifies \"pw\" 0 and \"pX\" -1"
  '(136 0 -1)
  (guarded (lambda ()
             (list (length long-hash) (verify long-hash pw) (verify long-hash (ascii "pX"))))))

(test-equal "crypto_pwhash_str_verify: the bytes of a non-ASCII password against its own hash 0; its last character changed, its Latin-1 bytes and the ASCII part alone -1 (the four calls' codes)"
  '(13 0 -1 -1 -1 -1)
  (guarded (lambda ()
             (let* ((password (ascii "p\x00E4;ssw\x00F6;rd\x20AC;"))
                    (h (hash-string password ops-min mem-min)))
               (list (length password) (verify h password)
                     (verify h (ascii "p\x00E4;ssw\x00F6;rd$"))
                     (verify h '(112 #xE4 115 115 119 #xF6 114 100 #x80))
                     (verify h '(112 #xE4 115 115 119 #xF6 114 100))
                     (verify h (ascii "p\x00E4;ssw\x00F6;rd")))))))

;; crypto_pwhash_str_needs_rehash ----------------------------------------------------------------

(test-equal "crypto_pwhash_str_needs_rehash of the hash of \"pw\" at the minimum limits: the same limits 0; ops+1, memory x2 and memory -1 byte 1; memory +1023 bytes 0 and +1024 bytes 1 (the six calls' codes, in order)"
  '(0 1 1 1 0 1)
  (guarded (lambda ()
             (list (rehash pw-hash ops-min mem-min)
                   (rehash pw-hash (+ ops-min 1) mem-min)
                   (rehash pw-hash ops-min (* 2 mem-min))
                   (rehash pw-hash ops-min (- mem-min 1))
                   (rehash pw-hash ops-min (+ mem-min 1023))
                   (rehash pw-hash ops-min (+ mem-min 1024))))))

(test-equal "crypto_pwhash_str_needs_rehash: a hash made at ops 3 against ops 1 is 1, and against ops 3 0; one made at four times the minimum memory against the minimum is 1"
  '(0 1 1)
  (guarded (lambda ()
             (let ((h3 (hash-string pw 3 mem-min))
                   (h4 (hash-string pw ops-min (* 4 mem-min))))
               (list (rehash h3 3 mem-min) (rehash h3 1 mem-min) (rehash h4 ops-min mem-min))))))

(test-equal "crypto_pwhash_str_needs_rehash: \"garbage\" is -1, and so is the 136-character hash, at its own limits and at ops+1, and so is a string of exactly strbytes (128) characters: any string of strbytes characters or more is unreadable"
  '(-1 -1 -1 128 -1)
  (guarded (lambda ()
             (let ((exact (append pw-hash (make-list-of (- strbytes (length pw-hash)) #x41))))
               (list (rehash (ascii "garbage") ops-min mem-min)
                     (rehash long-hash ops-min mem-min)
                     (rehash long-hash (+ ops-min 1) mem-min)
                     (length exact)
                     (rehash exact ops-min mem-min))))))

(test-equal "crypto_pwhash_str_needs_rehash: an argon2i string at ops 3 and its own memory is 0, at ops 4 it is 1, and the prefix is not compared (the two calls' codes)"
  '(0 1)
  (guarded (lambda ()
             (list (rehash argon2i-hash 3 mem-min) (rehash argon2i-hash 4 mem-min)))))

(test-equal "crypto_pwhash_str_needs_rehash: p=2 and p=4 at 64 KiB are 0 as p=1 is, though p=4 and p=0 at 8 KiB are -1 (four lanes need 32 KiB); the argon2d prefix, no $v= and $v=16 are -1; an argon2i prefix on an argon2id hash is 0; \"$argon2id\" alone is -1"
  '(0 0 0 -1 -1 -1 -1 -1 0 -1)
  (guarded (lambda ()
             (let* ((kib64 (* 64 1024))
                    (h64 (hash-string pw ops-min kib64)))
               (list (rehash h64 ops-min kib64)
                     (rehash (str-replace h64 ",p=1$" ",p=2$") ops-min kib64)
                     (rehash (str-replace h64 ",p=1$" ",p=4$") ops-min kib64)
                     (rehash (str-replace pw-hash ",p=1$" ",p=4$") ops-min mem-min)
                     (rehash (str-replace pw-hash ",p=1$" ",p=0$") ops-min mem-min)
                     (rehash (str-replace pw-hash "$argon2id$" "$argon2d$") ops-min mem-min)
                     (rehash (str-replace pw-hash "$v=19" "") ops-min mem-min)
                     (rehash (str-replace pw-hash "$v=19" "$v=16") ops-min mem-min)
                     (rehash (str-replace pw-hash "$argon2id$" "$argon2i$") ops-min mem-min)
                     (rehash (ascii "$argon2id") ops-min mem-min))))))

(test-equal "crypto_pwhash_str_needs_rehash: the hash then a NUL and junk is 0; ops 0, memory 0 and both 0 are 1; ops 2^32 is -1; ops 2^32-1 with memlimit_max is 1; ops and memory 2^64-1 are -1"
  '(0 1 1 1 -1 1 -1)
  (guarded (lambda ()
             (list (rehash (append pw-hash '(0) (ascii "junk")) ops-min mem-min)
                   (rehash pw-hash 0 mem-min) (rehash pw-hash ops-min 0) (rehash pw-hash 0 0)
                   (rehash pw-hash two-pow-32 mem-min)
                   (rehash pw-hash (- two-pow-32 1) mem-max)
                   (rehash pw-hash two-pow-64-1 two-pow-64-1)))))

;; The first character of the salt, a byte of 0x80 or more: libsodium 1.0.18
;; takes the string as current, 1.0.22 refuses it. Verify refuses it at both.
(define salt-first-index (length (ascii "$argon2id$v=19$m=8,t=1,p=1$")))

(define (with-salt-byte bytes byte)
  (append (take bytes salt-first-index) (list byte) (list-tail bytes (+ salt-first-index 1))))

(test-equal "crypto_pwhash_str_needs_rehash: a byte of 0xC3 as the salt's first character is 0 at 1.0.18 and -1 at 1.0.22, by the version this suite loaded; verify of it is -1 at both (the two calls' codes)"
  (list (cond ((equal? version "1.0.18") 0) (else -1)) -1)
  (guarded (lambda ()
             (let ((edited (with-salt-byte pw-hash #xC3)))
               (list (rehash edited ops-min mem-min) (verify edited pw))))))

;; A tripwire, not a property of the library: it fails on any release whose
;; byte-0x80 answer nobody has measured, so that release's answer is measured
;; and recorded before it is trusted.
(test-equal "tripwire: the release this suite loaded is one whose byte-0x80 answer was measured, 1.0.18 or 1.0.22; any other release fails here until its answer is measured"
  #t
  (and (member version '("1.0.18" "1.0.22")) #t))

;; The hand-written preset strings: each at its own limits is 0 and at the
;; other two 1, a 3x3 table. A salt of 21 characters or a tag of 42 is -1.
(define salt22 "QUJDREVGR0hJSktMTU5PUA")
(define tag43 "YWRnam1wc3Z5fH+ChYiLjpGUl5qdoKOmqayvsrW4u74")

;; preset-string : Natural Natural String String -> (Listof Natural)
(define (preset-string ops mem salt tag)
  (ascii (string-append "$argon2id$v=19$m=" (number->string (div mem 1024)) ",t="
                        (number->string ops) ",p=1$" salt "$" tag)))

(test-equal "crypto_pwhash_str_needs_rehash: each hand-written preset string, with a salt of 22 characters and a tag of 43, is 0 at its own preset's limits and 1 at the other two: the rows interactive, moderate and sensitive, the columns the same"
  '((0 1 1) (1 0 1) (1 1 0))
  (guarded (lambda ()
             (let ((presets (list (list ops-interactive mem-interactive)
                                  (list ops-moderate mem-moderate)
                                  (list ops-sensitive mem-sensitive))))
               (map (lambda (row)
                      (let ((s (preset-string (car row) (cadr row) salt22 tag43)))
                        (map (lambda (column) (rehash s (car column) (cadr column))) presets)))
                    presets)))))

(test-equal "crypto_pwhash_str_needs_rehash: at the moderate limits, the intact string is 0, a salt of 21 characters -1 and a tag of 42 -1"
  '(0 -1 -1)
  (guarded (lambda ()
             (list (rehash (preset-string ops-moderate mem-moderate salt22 tag43)
                           ops-moderate mem-moderate)
                   (rehash (preset-string ops-moderate mem-moderate (substring salt22 0 21) tag43)
                           ops-moderate mem-moderate)
                   (rehash (preset-string ops-moderate mem-moderate salt22 (substring tag43 0 42))
                           ops-moderate mem-moderate)))))

(test-equal "every count is zero at the end"
  zero-counts
  (native-counts))

(test-end "native-codes")

(exit (suite-exit-status runner))
