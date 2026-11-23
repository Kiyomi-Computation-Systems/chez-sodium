#!r6rs
;; The size functions through Chez's FFI, each bound () size_t, on the library
;; named by argv[1]; plus every exported symbol of the library that mentions
;; "randombytes" or "BYTES_MAX", by foreign-entry? on candidate names.
;; Usage: scheme --program sizes.sps LIBRARY
(import (chezscheme))
(define path (cadr (command-line)))
(load-shared-object path)
(printf "path ~a\n" path)
(define (sz name) ((foreign-procedure name () size_t)))
(for-each (lambda (n) (printf "~a ~s\n" n (sz n)))
  '("crypto_generichash_bytes" "crypto_generichash_bytes_min" "crypto_generichash_bytes_max"
    "crypto_generichash_keybytes" "crypto_generichash_keybytes_min" "crypto_generichash_keybytes_max"))
(printf "foreign-entry? candidates for randombytes_BYTES_MAX:\n")
(for-each (lambda (n) (printf "  ~a ~s\n" n (foreign-entry? n)))
  '("randombytes_bytes_max" "randombytes_BYTES_MAX" "randombytes_max" "randombytes_buf_max"
    "randombytes_size_max" "randombytes_seedbytes" "randombytes_buf" "randombytes_random"
    "randombytes_uniform" "randombytes_implementation_name"))
