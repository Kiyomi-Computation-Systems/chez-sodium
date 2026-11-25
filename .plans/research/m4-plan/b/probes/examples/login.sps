(import (rnrs) (chez-sodium))

;; Accounts: a table from a name to its stored hash string.
(define accounts (make-hashtable string-hash string=?))

;; The limits new hashes use. They were OWASP's least, 19 MiB and 2 passes;
;; now they are libsodium's 'interactive, 64 MiB and 2 passes.
(define old-limits (make-password-limits 2 19456))
(define current-limits 'interactive)

;; One real hash at the current limits, for names that have no account.
(define no-account-hash (password-hash "no one's password" current-limits))

(define (sign-up! name password)
  (hashtable-set! accounts name (password-hash password current-limits)))

(define (log-in name password)
  (let ((hash (hashtable-ref accounts name no-account-hash)))
    (cond ((> (string-length password) 1024) 'refused)   ; never over the cap
          ((not (password-verify hash password)) 'refused)
          ((eq? hash no-account-hash) 'refused)
          (else
           (when (password-needs-rehash? hash current-limits)
             (guard (e ((sodium-failed? e) #f))   ; keep the old hash; log in anyway
               (hashtable-set! accounts name (password-hash password current-limits))))
           'logged-in))))

;; params : String -> String
;; A hash string up to its salt: the algorithm and its limits.
(define (params hash)
  (let loop ((i 0) (seen 0))
    (cond ((char=? (string-ref hash i) #\$)
           (if (= seen 3) (substring hash 0 (+ i 1)) (loop (+ i 1) (+ seen 1))))
          (else (loop (+ i 1) seen)))))

;; Ada signed up under the old limits.
(hashtable-set! accounts "ada" (password-hash "correct horse" old-limits))
(sign-up! "bea" "battery staple")

(write
 (list (params (hashtable-ref accounts "ada" #f))
       (log-in "ada" "correct horse")
       (params (hashtable-ref accounts "ada" #f))
       (log-in "ada" "wrong horse")
       (log-in "bea" "battery staple")
       (log-in "cal" "correct horse")
       (log-in "ada" (make-string 70000 #\a))))
(newline)
