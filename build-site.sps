#!r6rs
;;; The imperative shell: read docs/*.md, render, write HTML.
;;;
;;;   make site
;;; or directly, from the repository root:
;;;   CHEZSCHEMELIBDIRS=.:build/akku/chez-cmark-gfm/src scheme --program build-site.sps
;;;
;;; SITE_REF pins the ../-escape rewrite in (site links) to a git ref for the
;;; GitHub blob URLs it produces (default "main"). SITE_OUT overrides the
;;; output directory (default "build/site"), which must exist.
(import (rnrs) (only (chezscheme) getenv) (site io) (site render)
        (only (site links) valid-ref?))

(define ref (or (getenv "SITE_REF") "main"))
(define out (or (getenv "SITE_OUT") "build/site"))

;; The ref goes into every repository URL the site writes. Refuse one that is
;; not one or more of A-Z a-z 0-9 . _ / -, or that begins with -, before
;; anything is written.
(unless (valid-ref? ref)
  (display "build-site: SITE_REF is not one or more of A-Z a-z 0-9 . _ / - not beginning with -" (current-error-port))
  (newline (current-error-port))
  (exit 1))

(let ((result (render-site (read-site-inputs) ref)))
  (write-site result out)
  (display "site: wrote ") (display (length (site-result-pages result)))
  (display " pages to ") (display out) (newline))
