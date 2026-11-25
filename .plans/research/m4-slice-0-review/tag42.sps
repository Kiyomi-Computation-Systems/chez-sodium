#!r6rs
;;; test-native-codes' hand-written moderate string, its tag cut to 42
;;; characters, then its 42nd character swapped. A tag of 42 base64
;;; characters is 31 bytes and 4 spare bits: libsodium decodes it when those
;;; bits are zero. So is "a tag of 42 is -1" a rule of length, or of this
;;; one string's last character? Each row: the 42nd character, its 4 low
;;; bits, and password-needs-rehash? at 'moderate (#f only when libsodium
;;; answers 0 and the shape check passes).
(import (rnrs) (chez-sodium))

(define alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
(define salt22 "QUJDREVGR0hJSktMTU5PUA")
(define tag43 "YWRnam1wc3Z5fH+ChYiLjpGUl5qdoKOmqayvsrW4u74")
(define (moderate tag)
  (string-append "$argon2id$v=19$m=262144,t=3,p=1$" salt22 "$" tag))
(define (index c)
  (let loop ((i 0)) (if (char=? (string-ref alphabet i) c) i (loop (+ i 1)))))

(write (list 'intact (password-needs-rehash? (moderate tag43) 'moderate)))
(newline)
(for-each
 (lambda (c)
   (let ((tag (string-append (substring tag43 0 41) (string c))))
     (write (list 'tag-42-ending c 'low-bits (bitwise-and (index c) 15)
                  'needs-rehash (password-needs-rehash? (moderate tag) 'moderate)))
     (newline)))
 (list #\7 #\g #\w #\A #\Q #\h))
;; The salt: 22 characters is 16 bytes. 20 is 15 bytes and 16 is 12, with no
;; spare bits; 21 leaves one character over, which never decodes.
(for-each
 (lambda (n)
   (write (list 'salt-characters n 'needs-rehash
                (password-needs-rehash?
                 (string-append "$argon2id$v=19$m=262144,t=3,p=1$" (substring salt22 0 n) "$" tag43)
                 'moderate)))
   (newline))
 '(22 21 20 16))
