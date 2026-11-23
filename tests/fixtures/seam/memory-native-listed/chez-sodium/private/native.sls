#!r6rs
;;; Fixture for tests/test-check-seam.sps
(library (chez-sodium private native)
  (export bind)
  (import (chez-sodium private require-threaded) (except (rnrs) dynamic-wind) (only (chezscheme) critical-section display-condition dynamic-wind foreign-entry foreign-entry? foreign-procedure foreign-ref foreign-set! format format-condition? getenv load-shared-object machine-type make-mutex with-mutex))
  (define bind 1))
