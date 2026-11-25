#!r6rs
;; Probe: the site's slug rule on a reference heading for each export of
;; (chez-sodium), one slugger for the page, as transform-body numbers repeats.
(import (rnrs) (site slug))
(define names
  '("sodium-version" "random-bytes" "blake2b" "constant-time-bytevector=?"
    "password-hash" "password-verify" "password-needs-rehash?" "make-password-limits"
    "chez-sodium-error?" "sodium-library-unavailable?" "sodium-library-unavailable-reason"
    "sodium-library-unavailable-path" "sodium-library-unavailable-source"
    "sodium-library-unavailable-detail" "sodium-library-unavailable-candidates"
    "sodium-failed?" "sodium-failed-function" "sodium-failed-code"))
(define slug (make-slugger))
(for-each (lambda (n) (put-string (current-output-port) (string-append n " -> " (slug n) "\n"))) names)
