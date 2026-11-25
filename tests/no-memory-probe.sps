#!r6rs
;;; The child of tests/test-no-memory.sps. It runs one verb of (chez-sodium)
;;; against the library CHEZ_SODIUM_LIBRARY names, and writes what came of it:
;;;
;;;   MODE hash-interactive   password-hash at 'interactive
;;;   MODE hash-sensitive     password-hash at 'sensitive
;;;   MODE make-sensitive     password-hash at 'sensitive, the hash itself
;;;   MODE verify HASH        password-verify HASH with the password
;;;
;;; Each answer is one datum, then (counts . ALIST), the library's native
;;; counts, then (valgrind . no) or (valgrind . yes), read from
;;; /proc/self/maps. The suite starts it through the memory gate's command,
;;; under ulimit -v for the rows that need a cap (ADR-0011).
(import (rnrs)
        (chez-sodium)
        (chez-sodium private counters))

(define password "correct horse")

;; hash-prefix : String -> String
;; HASH up to and including its fourth $: the algorithm, version and
;; parameters, none of the salt or the tag.
(define (hash-prefix hash)
  (let loop ((i 0) (seen 0))
    (cond ((= i (string-length hash)) hash)
          ((and (char=? (string-ref hash i) #\$) (= seen 3)) (substring hash 0 (+ i 1)))
          ((char=? (string-ref hash i) #\$) (loop (+ i 1) (+ seen 1)))
          (else (loop (+ i 1) seen)))))

;; hashed : (U 'interactive 'sensitive) -> Datum
;; (hash ok PREFIX) or (hash raised FUNCTION CODE), or (hash raised OTHER).
(define (hashed limits)
  (guard (e ((sodium-failed? e)
             (list 'hash 'raised (sodium-failed-function e) (sodium-failed-code e)))
            (#t (list 'hash 'raised 'other)))
    (let ((h (password-hash password limits)))
      (list 'hash 'ok (hash-prefix h)))))

;; verified : String -> Datum
;; (verify ANSWER), or (verify raised).
(define (verified hash)
  (guard (e (#t (list 'verify 'raised)))
    (list 'verify (password-verify hash password))))

;; Whether this process runs under memcheck: its preload is in /proc/self/maps.
(define (valgrind-datum)
  (cons 'valgrind
        (guard (e (#t 'no-maps))
          (let ((maps (call-with-port
                       (open-file-input-port "/proc/self/maps" (file-options) (buffer-mode block)
                                             (make-transcoder (utf-8-codec)))
                       get-string-all))
                (needle "vgpreload_memcheck"))
            (let loop ((i 0))
              (cond ((> (+ i (string-length needle)) (string-length maps)) 'no)
                    ((string=? (substring maps i (+ i (string-length needle))) needle) 'yes)
                    (else (loop (+ i 1)))))))))

(define args (cdr (command-line)))
(define mode (car args))
(write
 (cond ((string=? mode "hash-interactive") (hashed 'interactive))
       ((string=? mode "hash-sensitive") (hashed 'sensitive))
       ((string=? mode "make-sensitive")
        (list 'made (password-hash password 'sensitive)))
       ((string=? mode "verify") (verified (cadr args)))
       (else (list 'unknown-mode))))
(newline)
(write (cons 'counts (native-counts)))
(newline)
(write (valgrind-datum))
(newline)
