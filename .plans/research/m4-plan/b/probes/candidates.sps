#!r6rs
;;; Discovery's candidate lists, from (chez-sodium private discovery)'s pure
;;; procedure, for each world and machine: what a page's table must say.
;;; The Guix list is asked with GUIX_ENVIRONMENT, GUIX_PROFILE and HOME set
;;; to stand-ins, so each path reads as a page writes it.
(import (rnrs) (chez-sodium private discovery))

(define (stand-in name)
  (cond ((string=? name "GUIX_ENVIRONMENT") "$GUIX_ENVIRONMENT")
        ((string=? name "GUIX_PROFILE") "$GUIX_PROFILE")
        ((string=? name "HOME") "~")
        (else #f)))
;; libsodium-candidates takes absolute paths only, so stand in with
;; absolute markers and print them back as the page would write them.
(define (absolute-stand-in name)
  (cond ((string=? name "GUIX_ENVIRONMENT") "/@GUIX_ENVIRONMENT")
        ((string=? name "GUIX_PROFILE") "/@GUIX_PROFILE")
        ((string=? name "HOME") "/@HOME")
        (else #f)))

(define (show x) (write x) (newline))

(show (list 'sources libsodium-sources))
(for-each
 (lambda (machine)
   (show (list 'fhs machine (libsodium-candidates 'fhs machine absolute-stand-in)))
   (show (list 'guix machine (libsodium-candidates 'guix machine absolute-stand-in))))
 '(ta6le tarm64le))
(show (list 'not-linux 'ta6osx (libsodium-candidates 'fhs 'ta6osx absolute-stand-in)))
(show (list 'world-of-no-maps (libsodium-world #f)))
