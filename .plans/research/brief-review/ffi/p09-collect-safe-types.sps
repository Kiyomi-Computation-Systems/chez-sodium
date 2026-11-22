#!r6rs
;; Probe: which argument types Chez 10.4.0 accepts in a __collect_safe
;; foreign-procedure, against randombytes_buf's entry.
;; Usage: scheme --script p09-collect-safe-types.sps /path/libsodium.so.23
(import (chezscheme))
(load-shared-object (cadr (command-line)))
(define-syntax try
  (syntax-rules ()
    ((_ form) (guard (e (#t (list 'refused (condition-message e)))) (eval 'form) 'accepted))))
(printf "u8* : ~s\n" (try (foreign-procedure __collect_safe "randombytes_buf" (u8* size_t) void)))
(printf "string : ~s\n" (try (foreign-procedure __collect_safe "randombytes_buf" (string size_t) void)))
(printf "utf-8 : ~s\n" (try (foreign-procedure __collect_safe "randombytes_buf" (utf-8 size_t) void)))
(printf "scheme-object : ~s\n" (try (foreign-procedure __collect_safe "randombytes_buf" (scheme-object size_t) void)))
(printf "uptr size_t : ~s\n" (try (foreign-procedure __collect_safe "randombytes_buf" (uptr size_t) void)))
