#!r6rs
;;; Fixture for tests/test-check-seam.sps: a for over an only over (chezscheme), exporting its name.
(library (chez-sodium private f)
  (export threaded?)
  (import (rnrs) (for (only (chezscheme) threaded?) run)))
