#!r6rs
;; What the load's entry points answer through Chez's FFI, on the library
;; CHEZ_SODIUM_LIBRARY names (or argv[1]), each as chez-sodium would bind it.
;; Usage: scheme --program ffi.sps [PATH]
(import (chezscheme))
(define path (if (pair? (cdr (command-line))) (cadr (command-line)) (getenv "CHEZ_SODIUM_LIBRARY")))
(load-shared-object path)
(define (c-string address)
  (let loop ((i 0) (acc '()))
    (let ((b (foreign-ref 'unsigned-8 address i)))
      (if (= b 0) (list->string (reverse acc)) (loop (+ i 1) (cons (integer->char b) acc))))))
(printf "path ~a\n" path)
(printf "foreign-entry?: ~s\n"
        (map (lambda (n) (cons n (foreign-entry? n)))
             '("sodium_version_string" "sodium_library_version_major" "sodium_library_version_minor"
               "sodium_init" "sodium_memzero" "sodium_memcmp" "randombytes_buf" "crypto_generichash"
               "crypto_generichash_bytes" "crypto_generichash_bytes_min" "crypto_generichash_bytes_max"
               "crypto_generichash_keybytes" "crypto_generichash_keybytes_min" "crypto_generichash_keybytes_max"
               "crypto_pwhash_str" "crypto_pwhash_str_verify" "crypto_pwhash_str_needs_rehash"
               "crypto_pwhash_strprefix" "crypto_pwhash_strbytes" "crypto_pwhash_opslimit_min"
               "crypto_pwhash_opslimit_max" "crypto_pwhash_opslimit_interactive" "crypto_pwhash_opslimit_moderate"
               "crypto_pwhash_opslimit_sensitive" "crypto_pwhash_memlimit_min" "crypto_pwhash_memlimit_max"
               "crypto_pwhash_memlimit_interactive" "crypto_pwhash_memlimit_moderate"
               "crypto_pwhash_memlimit_sensitive" "crypto_pwhash_passwd_min" "crypto_pwhash_passwd_max"
               "crypto_hash_sha256" "crypto_auth_hmacsha256_init" "crypto_auth_hmacsha256_update"
               "crypto_auth_hmacsha256_final" "crypto_auth_hmacsha256_statebytes")))
(define version-string (foreign-procedure "sodium_version_string" () uptr))
(define major (foreign-procedure "sodium_library_version_major" () int))
(define minor (foreign-procedure "sodium_library_version_minor" () int))
(define init (foreign-procedure "sodium_init" () int))
(define memzero (foreign-procedure "sodium_memzero" (uptr size_t) void))
(printf "before init: version ~s, major ~s, minor ~s\n" (c-string (version-string)) (major) (minor))
(let* ((a (init)) (b (init)))
  (printf "sodium_init: first ~s, second ~s\n" a b))
(printf "foreign-sizeof size_t ~s, unsigned-64 ~s, uptr ~s, int ~s\n"
        (foreign-sizeof 'size_t) (foreign-sizeof 'unsigned-64) (foreign-sizeof 'uptr) (foreign-sizeof 'int))
(let ((b (foreign-alloc 32)))
  (do ((i 0 (+ i 1))) ((= i 32)) (foreign-set! 'unsigned-8 b i #x41))
  (memzero b 32)
  (printf "memzero through (uptr size_t) void: ~s\n"
          (let loop ((i 0)) (cond ((= i 32) 'all-zero) ((= 0 (foreign-ref 'unsigned-8 b i)) (loop (+ i 1))) (else 'non-zero))))
  (foreign-free b))
