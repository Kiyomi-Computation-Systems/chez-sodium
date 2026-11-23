#!r6rs
;;; What tests/preflight.sps does with no guard: (loaded-libsodium) evaluated
;;; in native's environment, so Chez's default handler prints whatever it
;;; raises. On the raising fixture, preflight must print exactly this: its
;;; guard takes a refusal alone, and leaves any other raise to the default
;;; handler (tests/test-library-loading-preflight.sps).
(import (rnrs)
        (only (chezscheme) eval environment))

(eval '(loaded-libsodium) (environment '(chez-sodium private native)))
