#!r6rs
;; Probe: does (exit) inside a dynamic-wind run its after thunk? If not, a
;; verb's wipe is skipped by an exit from inside its extent (a handler that
;; exits, another library's code in PROC).
;; Usage: scheme --script p17-exit-unwind.sps
(import (chezscheme))
(dynamic-wind
  (lambda () (display "before\n"))
  (lambda () (exit 0))
  (lambda () (display "after thunk ran\n")))
