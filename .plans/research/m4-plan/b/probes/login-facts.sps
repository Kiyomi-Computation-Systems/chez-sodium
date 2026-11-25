#!r6rs
;;; The login facts M4's documents owe, each as one line:
;;;
;;;   nfc/nfd       a password is never normalised: "é" as U+00E9 and as
;;;                 e + U+0301 do not verify against each other
;;;   stored        a stored hash with a stray character: what verify and
;;;                 needs-rehash answer
;;;   over-cap      a password over the cap given to password-verify
;;;   custom        custom limits, with needs-rehash given them and not
;;;                 given them
;;;   opaque        what a Password-limits looks like to a caller
(import (rnrs) (chez-sodium))

(define (show label value) (write (list label value)) (newline))

(define (outcome thunk)
  (guard (e ((assertion-violation? e)
             (list 'raised (condition-who e) (condition-irritants e)))
            (#t (list 'raised-other e)))
    (list 'answered (thunk))))

(define least (make-password-limits 1 8))
(define pw "correct horse")

;; NFC against NFD
(let* ((nfc "caf\xE9;")            ; é as one code point
       (nfd "cafe\x301;")          ; e then a combining acute accent
       (h-nfc (password-hash nfc least))
       (h-nfd (password-hash nfd least)))
  (show 'nfc-length-chars (list (string-length nfc) (string-length nfd)))
  (show 'nfc-utf8-bytes (list (bytevector-length (string->utf8 nfc)) (bytevector-length (string->utf8 nfd))))
  (show 'nfc-hash-verifies-nfc (password-verify h-nfc nfc))
  (show 'nfc-hash-verifies-nfd (password-verify h-nfc nfd))
  (show 'nfd-hash-verifies-nfd (password-verify h-nfd nfd))
  (show 'nfd-hash-verifies-nfc (password-verify h-nfd nfc)))

;; a stored hash, exactly and with a stray character
(let ((h (password-hash pw least)))
  (for-each
   (lambda (case)
     (let ((stored ((cdr case) h)))
       (show (list 'stored (car case))
             (list 'verify (password-verify stored pw)
                   'needs-rehash (password-needs-rehash? stored least)))))
   (list (cons 'exact (lambda (h) h))
         (cons 'trailing-space (lambda (h) (string-append h " ")))
         (cons 'trailing-newline (lambda (h) (string-append h "\n")))
         (cons 'trailing-crlf (lambda (h) (string-append h "\r\n")))
         (cons 'leading-space (lambda (h) (string-append " " h)))
         (cons 'trailing-x (lambda (h) (string-append h "x")))
         (cons 'trailing-nul-junk (lambda (h) (string-append h "\x0;junk")))
         (cons 'last-char-dropped (lambda (h) (substring h 0 (- (string-length h) 1)))))))

;; a password over the cap, given to password-verify
(let ((h (password-hash pw least)))
  (show 'over-cap-ascii (outcome (lambda () (password-verify h (make-string 65537 #\a)))))
  (show 'at-cap-ascii (outcome (lambda () (password-verify h (make-string 65536 #\a)))))
  (show 'over-cap-two-byte-chars (outcome (lambda () (password-verify h (make-string 32769 #\xE9)))))
  (show 'at-cap-two-byte-chars (outcome (lambda () (password-verify h (make-string 32768 #\xE9)))))
  (show 'over-cap-with-unreadable-hash (outcome (lambda () (password-verify "" (make-string 65537 #\a)))))
  (show 'not-a-string-password (outcome (lambda () (password-verify h 'x)))))

;; custom limits, with needs-rehash given them and not
(let* ((mine (make-password-limits 3 19456))
       (h (password-hash pw mine)))
  (show 'custom-hash-verifies (password-verify h pw))
  (show 'custom-needs-rehash-given-them (password-needs-rehash? h mine))
  (show 'custom-needs-rehash-given-equal-new-record (password-needs-rehash? h (make-password-limits 3 19456)))
  (show 'custom-needs-rehash-default (password-needs-rehash? h))
  (show 'custom-needs-rehash-interactive (password-needs-rehash? h 'interactive))
  (show 'custom-needs-rehash-other-ops (password-needs-rehash? h (make-password-limits 2 19456)))
  (show 'custom-needs-rehash-other-memory (password-needs-rehash? h (make-password-limits 3 19457))))
(let ((h (password-hash pw)))
  (show 'default-hash-needs-rehash-given-custom-equal (password-needs-rehash? h (make-password-limits 2 65536)))
  (show 'default-hash-needs-rehash-default (password-needs-rehash? h)))

;; what a Password-limits looks like
(let ((l (make-password-limits 2 16)))
  (show 'limits-record? (record? l))
  (show 'limits-equal-records (equal? (make-password-limits 2 16) (make-password-limits 2 16)))
  (show 'limits-written (call-with-string-output-port (lambda (p) (write l p)))))
