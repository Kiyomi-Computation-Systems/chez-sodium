#!r6rs
;;; tests/fixtures/raising/chez-sodium/private/native.sls: a stand-in
;;; (chez-sodium private native) whose loaded-libsodium raises a plain
;;; error, not a refusal, for tests/test-library-loading-preflight.sps only.
;;; Run with --libdirs tests/fixtures/raising:src, it shadows src/'s native,
;;; so the refusal probe and the preflight meet a raise that is a bug, and
;;; must report it as one: never as a refusal.
;;;
;;; It loads nothing and binds no foreign procedure. Its one export is the
;;; one the probe and the preflight reference.
(library (chez-sodium private native)
  (export loaded-libsodium)
  (import (rnrs))

  ;; loaded-libsodium : -> Nothing
  (define (loaded-libsodium)
    (error 'loaded-libsodium "the raising fixture raises a plain error, not a refusal")))
