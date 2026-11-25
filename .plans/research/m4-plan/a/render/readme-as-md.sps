#!r6rs
;; Probe: README.org handed to chez-cmark-gfm as if it were Markdown.
(import (rnrs) (cmark gfm) (site serializer))
(define text
  (call-with-input-file "README.org"
    (lambda (p) (get-string-all p))))
(display (sxml->html (markdown->sxml text (default-cmark-options))))
(newline)
