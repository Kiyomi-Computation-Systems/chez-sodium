#!r6rs
;;; Fixture for tests/test-check-seam.sps: (chez-sodium private extra), a second library in this file. Rule (h) reads it as defined under the directory, but Chez looks for it at chez-sodium/private/extra.sls.
(library (chez-sodium private a)
  (export a)
  (import (rnrs))
  (define a 1))
(library (chez-sodium private extra) (export extra) (import (rnrs)) (define extra 1))
