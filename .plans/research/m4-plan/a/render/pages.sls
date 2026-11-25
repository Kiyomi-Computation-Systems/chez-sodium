#!r6rs
;; PURE. Imports no library that loads a shared object.
;; Probe copy of chez-sqlite3's site/pages.sls, its list cut to two stub pages.
(library (site pages)
  (export pages page-file-name)
  (import (rnrs))
  (define pages
    '(("quickstart.md" . "Quick start")
      ("reference.md" . "Reference")))
  (define (page-file-name name)
    (if (string=? name (car (car pages)))
        "index.html"
        (string-append (substring name 0 (- (string-length name) 3)) ".html"))))
