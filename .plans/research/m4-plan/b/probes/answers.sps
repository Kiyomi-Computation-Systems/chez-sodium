#!r6rs
;;; What each verb of (chez-sodium) answers on good input: the version, the
;;; sizes, known BLAKE2b vectors, each preset's parameter field, and the
;;; password round trips. Salts and tags are masked: a hash is shown up to
;;; and including its fourth $.
(import (rnrs) (chez-sodium))

(define (hex bv)
  (apply string-append
         (map (lambda (b)
                (let ((s (number->string b 16)))
                  (if (< b 16) (string-append "0" s) s)))
              (bytevector->u8-list bv))))

(define (params hash)
  (let loop ((i 0) (seen 0))
    (cond ((= i (string-length hash)) hash)
          ((and (char=? (string-ref hash i) #\$) (= seen 3)) (substring hash 0 (+ i 1)))
          ((char=? (string-ref hash i) #\$) (loop (+ i 1) (+ seen 1)))
          (else (loop (+ i 1) seen)))))

(define (show label value) (write (list label value)) (newline))

(define cheap (make-password-limits 1 8))

(show 'sodium-version (sodium-version))
(show 'sodium-version-fresh (not (eq? (sodium-version) (sodium-version))))

(let ((a (random-bytes 32)) (b (random-bytes 32)))
  (show 'random-bytes-32-length (bytevector-length a))
  (show 'random-bytes-two-differ (not (bytevector=? a b))))
(show 'random-bytes-0 (random-bytes 0))

(show 'blake2b-abc-default (hex (blake2b (string->utf8 "abc"))))
(show 'blake2b-abc-64 (hex (blake2b (string->utf8 "abc") 64)))
(show 'blake2b-empty-default (hex (blake2b (make-bytevector 0))))
(show 'blake2b-abc-16 (hex (blake2b (string->utf8 "abc") 16)))
;; RFC 7693 / BLAKE2 reference keyed known answer: key 00..3f, empty input,
;; 64 bytes: the first line of blake2b-kat.txt's keyed table.
(let ((key (u8-list->bytevector (let loop ((i 63) (acc '())) (if (< i 0) acc (loop (- i 1) (cons i acc)))))))
  (show 'blake2b-keyed-kat-empty (hex (blake2b (make-bytevector 0) 64 key))))
(show 'blake2b-key-changes-answer
      (not (bytevector=? (blake2b (string->utf8 "abc") 32 (make-bytevector 16 1))
                         (blake2b (string->utf8 "abc") 32 (make-bytevector 16 2)))))
(show 'blake2b-fresh (let ((x (string->utf8 "abc"))) (not (eq? (blake2b x) (blake2b x)))))

(show 'hash-default-params (params (password-hash "correct horse")))
(show 'hash-interactive-params (params (password-hash "correct horse" 'interactive)))
(show 'hash-moderate-params (params (password-hash "correct horse" 'moderate)))
(show 'hash-sensitive-params (params (password-hash "correct horse" 'sensitive)))
(show 'hash-custom-2-16-params (params (password-hash "correct horse" (make-password-limits 2 16))))
(show 'hash-custom-3-19456-params (params (password-hash "correct horse" (make-password-limits 2 19456))))
(let ((h (password-hash "correct horse" cheap)))
  (show 'hash-length (string-length h))
  (show 'hash-is-fresh-each-call (not (string=? h (password-hash "correct horse" cheap))))
  (show 'verify-right (password-verify h "correct horse"))
  (show 'verify-wrong (password-verify h "correct horse!"))
  (show 'verify-empty-password (password-verify h ""))
  (show 'needs-rehash-at-own-limits (password-needs-rehash? h cheap))
  (show 'needs-rehash-at-default (password-needs-rehash? h)))
(let ((h (password-hash "" cheap)))
  (show 'empty-password-round-trip (list (password-verify h "") (password-verify h "a"))))
(let ((h (password-hash "a\x0;b" cheap)))
  (show 'nul-password-round-trip (list (password-verify h "a\x0;b") (password-verify h "a"))))
(let ((h (password-hash "pässwörd 🐴" cheap)))
  (show 'non-ascii-round-trip (list (password-verify h "pässwörd 🐴") (password-verify h "pässwörd 🐎"))))
(let ((i (password-hash "correct horse" 'interactive)))
  (show 'preset-needs-rehash
        (list (password-needs-rehash? i 'interactive)
              (password-needs-rehash? i 'moderate)
              (password-needs-rehash? i 'sensitive)
              (password-needs-rehash? i))))
(show 'needs-rehash-garbage (password-needs-rehash? "garbage"))
(show 'needs-rehash-empty (password-needs-rehash? ""))
(show 'verify-garbage (password-verify "garbage" "correct horse"))
(show 'verify-empty-hash (password-verify "" "correct horse"))
