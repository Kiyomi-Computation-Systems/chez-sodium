#!r6rs
;; Item 4: the 14 size and limit functions bound () size_t, strprefix () uptr.
;; Usage: scheme --program consts.sps LIBRARY
(import (chezscheme))
(define path (cadr (command-line)))
(load-shared-object path)
(define (c-string a)
  (let loop ((i 0) (acc '()))
    (let ((b (foreign-ref 'unsigned-8 a i)))
      (if (= b 0) (list->string (reverse acc)) (loop (+ i 1) (cons (integer->char b) acc))))))
(printf "library ~a, version ~a\n" path (c-string ((foreign-procedure "sodium_version_string" () uptr))))
(define names
  '("crypto_pwhash_strbytes"
    "crypto_pwhash_passwd_min" "crypto_pwhash_passwd_max"
    "crypto_pwhash_opslimit_min" "crypto_pwhash_opslimit_max" "crypto_pwhash_opslimit_interactive"
    "crypto_pwhash_opslimit_moderate" "crypto_pwhash_opslimit_sensitive"
    "crypto_pwhash_memlimit_min" "crypto_pwhash_memlimit_max" "crypto_pwhash_memlimit_interactive"
    "crypto_pwhash_memlimit_moderate" "crypto_pwhash_memlimit_sensitive"))
(define vals '())
(for-each (lambda (n)
            (let ((v ((eval `(foreign-procedure ,n () size_t)))))
              (printf "~a ~a\n" n v) (set! vals (cons (cons n v) vals))))
          names)
(printf "crypto_pwhash_strprefix ~s\n" (c-string ((foreign-procedure "crypto_pwhash_strprefix" () uptr))))
(define (v n) (cdr (assoc n vals)))
(define (kib n) (let ((x (v n)))
  (printf "~a: multiple of 1024 ~a, /1024 = ~a\n" n (zero? (mod x 1024)) (div x 1024))))
(for-each kib '("crypto_pwhash_memlimit_min" "crypto_pwhash_memlimit_max" "crypto_pwhash_memlimit_interactive"
                "crypto_pwhash_memlimit_moderate" "crypto_pwhash_memlimit_sensitive"))
(printf "opslimit_max fits unsigned 32: ~a\n" (<= (v "crypto_pwhash_opslimit_max") (- (expt 2 32) 1)))
(printf "memlimit_max/1024 fits unsigned 32: ~a (~a, 2^32-1 = ~a)\n"
        (<= (div (v "crypto_pwhash_memlimit_max") 1024) (- (expt 2 32) 1))
        (div (v "crypto_pwhash_memlimit_max") 1024) (- (expt 2 32) 1))
