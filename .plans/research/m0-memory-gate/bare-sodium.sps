#!r6rs
;;; A bare FFI call into libsodium, for Valgrind: loads the library named by
;;; CHEZ_SODIUM_LIBRARY, binds sodium_init and sodium_version_string with
;;; foreign-procedure, and calls both.
(import (rnrs)
        (only (chezscheme) load-shared-object foreign-procedure getenv
              foreign-ref))

(load-shared-object (getenv "CHEZ_SODIUM_LIBRARY"))

(define sodium-init (foreign-procedure "sodium_init" () int))
(define sodium-version-string (foreign-procedure "sodium_version_string" () uptr))

(define (c-string address)
  (let loop ((i 0) (acc '()))
    (let ((b (foreign-ref 'unsigned-8 address i)))
      (if (= b 0)
          (list->string (reverse acc))
          (loop (+ i 1) (cons (integer->char b) acc))))))

(display "sodium_init: ") (display (sodium-init)) (newline)
(display "sodium_version_string: ") (display (c-string (sodium-version-string))) (newline)
(exit 0)
