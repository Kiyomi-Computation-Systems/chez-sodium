#!r6rs
;;; A hash string password-hash never makes: argon2id at m=8,t=1,p=1 with a
;;; 64-byte tag, as another argon2 library can make one. It is built here
;;; with libsodium's raw crypto_pwhash, bound by this probe alone, and encoded
;;; by hand. Does chez-sodium verify it, and does password-needs-rehash? call
;;; it current at its own limits? A 32-byte tag built the same way is the
;;; control: it is what password-hash makes.
(import (chezscheme) (chez-sodium))

(load-shared-object (getenv "CHEZ_SODIUM_LIBRARY"))
;; int crypto_pwhash(out, outlen, passwd, passwdlen, salt, opslimit, memlimit, alg)
(define crypto-pwhash
  (foreign-procedure "crypto_pwhash" (u8* unsigned-64 u8* unsigned-64 u8* unsigned-64 size_t int) int))

(define alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
(define (base64-no-padding bv)
  (let ((n (bytevector-length bv)))
    (let loop ((i 0) (out '()))
      (if (>= i n)
          (list->string (reverse out))
          (let* ((b0 (bytevector-u8-ref bv i))
                 (b1 (if (< (+ i 1) n) (bytevector-u8-ref bv (+ i 1)) 0))
                 (b2 (if (< (+ i 2) n) (bytevector-u8-ref bv (+ i 2)) 0))
                 (w (+ (* b0 65536) (* b1 256) b2))
                 (chars (list (string-ref alphabet (bitwise-and (bitwise-arithmetic-shift-right w 18) 63))
                              (string-ref alphabet (bitwise-and (bitwise-arithmetic-shift-right w 12) 63))
                              (string-ref alphabet (bitwise-and (bitwise-arithmetic-shift-right w 6) 63))
                              (string-ref alphabet (bitwise-and w 63))))
                 (keep (cond ((>= (+ i 3) n) (+ 1 (- n i))) (else 4))))
            (loop (+ i 3) (append (reverse (list-head chars (min 4 keep))) out)))))))

(define password "correct horse")
(define salt (make-bytevector 16 42))

(define (made-with tag-bytes)
  (let ((out (make-bytevector tag-bytes 0))
        (pw (string->utf8 password)))
    (let ((code (crypto-pwhash out tag-bytes pw (bytevector-length pw) salt 1 8192 2)))
      (string-append "$argon2id$v=19$m=8,t=1,p=1$" (base64-no-padding salt) "$" (base64-no-padding out)))))

(define limits (make-password-limits 1 8))
(for-each
 (lambda (tag-bytes)
   (let ((h (made-with tag-bytes)))
     (write (list 'tag-bytes tag-bytes
                  'length (string-length h)
                  'verify-right (password-verify h password)
                  'verify-wrong (password-verify h "battery staple")
                  'needs-rehash-at-its-limits (password-needs-rehash? h limits)))
     (newline)))
 '(32 16 64))
(let ((real (password-hash password limits)))
  (write (list 'password-hash-makes-length (string-length real)))
  (newline))
