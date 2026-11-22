#!r6rs
;; Probe: what the 1.0.18 library's version functions and sodium_init answer.
;; Usage: scheme --script p01-version.sps /path/to/libsodium.so.23
(import (chezscheme))
(define path (cadr (command-line)))
(load-shared-object path)
(define major (foreign-procedure "sodium_library_version_major" () int))
(define minor (foreign-procedure "sodium_library_version_minor" () int))
(define minimal (foreign-procedure "sodium_library_minimal" () int))
(define vstr (foreign-procedure "sodium_version_string" () string))
(define init (foreign-procedure "sodium_init" () int))
(printf "path ~a\n" path)
(printf "version_string ~s major ~s minor ~s minimal ~s\n" (vstr) (major) (minor) (minimal))
(let* ((a (init)) (b (init)))
  (printf "sodium_init first ~s second ~s\n" a b))
