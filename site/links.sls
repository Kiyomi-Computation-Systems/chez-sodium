#!r6rs
;; PURE. Imports no library that loads a shared object.
(library (site links)
  (export rewrite-links repo-blob valid-ref? release-tag-version release-like-ref?)
  (import (rnrs) (only (site pages) page-file-name))

  ;; repo-blob : String
  ;; Where a ../ escape points: this repository's files on GitHub, at the
  ;; ref the site is built for. tests/check-site.sps checks each such target
  ;; exists in the checkout.
  (define repo-blob
    "https://github.com/Kiyomi-Computation-Systems/chez-sodium/blob/")

  ;; valid-ref? : String -> Boolean
  ;; Whether REF may go into every repository URL the site writes: one or more
  ;; of A-Z a-z 0-9 . _ / -, and not beginning with -.
  (define (valid-ref? ref)
    (and (> (string-length ref) 0)
         (not (char=? (string-ref ref 0) #\-))
         (let loop ((cs (string->list ref)))
           (or (null? cs)
               (let ((c (car cs)))
                 (and (or (char<=? #\a c #\z) (char<=? #\A c #\Z)
                          (char<=? #\0 c #\9) (memv c '(#\. #\_ #\/ #\-)))
                      (loop (cdr cs))))))))

  ;; release-tag-version : String -> (U String #f)
  ;; For a release tag, "v" and three naturals joined by dots, its version
  ;; without the "v"; #f for any other ref.
  (define (release-tag-version ref)
    (and (> (string-length ref) 1)
         (char=? (string-ref ref 0) #\v)
         (let ((v (substring ref 1 (string-length ref))))
           (let loop ((cs (string->list v)) (digits 0) (dots 0))
             (cond ((null? cs) (and (= dots 2) (> digits 0) v))
                   ((char<=? #\0 (car cs) #\9) (loop (cdr cs) (+ digits 1) dots))
                   ((and (char=? (car cs) #\.) (> digits 0) (< dots 2))
                    (loop (cdr cs) 0 (+ dots 1)))
                   (else #f))))))

  ;; release-like-ref? : String -> Boolean
  ;; Whether REF begins with "v" and a digit, as a release tag does, whether or
  ;; not it is exactly "v" and three naturals.
  (define (release-like-ref? ref)
    (and (> (string-length ref) 1)
         (char=? (string-ref ref 0) #\v)
         (char<=? #\0 (string-ref ref 1) #\9)))

  (define (prefix? pre s)
    (and (>= (string-length s) (string-length pre))
         (string=? pre (substring s 0 (string-length pre)))))
  (define (suffix? suf s)
    (let ((ls (string-length s)) (lf (string-length suf)))
      (and (>= ls lf) (string=? suf (substring s (- ls lf) ls)))))

  ;; -> (values path anchor-or-#f); anchor includes its leading '#'.
  (define (split-anchor target)
    (let loop ((i 0))
      (cond ((= i (string-length target)) (values target #f))
            ((char=? (string-ref target i) #\#)
             (values (substring target 0 i) (substring target i (string-length target))))
            (else (loop (+ i 1))))))

  (define (registry-has? registry page slug)
    (cond ((assoc page registry) => (lambda (kv) (and (member slug (cdr kv)) #t)))
          (else #f)))

  ;; "./page.md" names the same page as "page.md".
  (define (strip-dot-slash path)
    (if (prefix? "./" path) (substring path 2 (string-length path)) path))

  ;; Rewrite one href/src target. Returns (values new-target dangling?).
  (define (rewrite-target target page registry ref)
    (cond
      ((prefix? "http://" target) (values target #f))
      ((prefix? "https://" target) (values target #f))
      ((prefix? "#" target)                              ; same-page anchor
       (values target
               (not (registry-has? registry page (substring target 1 (string-length target))))))
      ((prefix? "../" target)                            ; escape -> GitHub blob
       (values (string-append repo-blob ref "/" (substring target 3 (string-length target))) #f))
      (else
       (let-values (((path anchor) (split-anchor target)))
         (if (suffix? ".md" path)
             (let* ((target-page (strip-dot-slash path))
                    (slug (and anchor (substring anchor 1 (string-length anchor)))))
               ;; The page's own file name: a link to the home page is
               ;; written as index.html, the name the home page is written to.
               (values (string-append (page-file-name target-page) (or anchor ""))
                       ;; With an anchor, registry-has? asks for the page
                       ;; and its slug at once; without one, the page alone.
                       (not (if slug
                                (registry-has? registry target-page slug)
                                (assoc target-page registry)))))
             (values target #f))))))          ; unrecognised: leave, don't dangle

  ;; rewrite-links : SXML Registry String String
  ;;                 -> (Values SXML (Listof (Pairof String String)))
  ;;   where Registry = (Listof (Pairof String (Listof String)))
  ;; Rewrite href/src targets across the SXML tree rooted at `body`, given
  ;; the site-wide id `registry` (a list of (page . (slug ...))), the
  ;; `page` this body belongs to (attached to any dangler it produces), and
  ;; the release `ref` used to pin ../ escapes to a GitHub blob URL.
  ;; Returns (values new-body danglers); danglers is a list of
  ;; (page . original-target) in document order.
  ;;
  ;; Only href/src attribute VALUES are ever rewritten, and only on (a) and
  ;; (img) elements -- walk-node gates on the tag before attr-map ever runs,
  ;; so an href/src carried by any other element passes through unchanged by
  ;; construction, not by coincidence of what the doc body happens to emit.
  ;; Everything else -- every string, every non-href/src attribute -- passes
  ;; through `eq?`-at-the-leaf untouched. That is what keeps a "javascript:"
  ;; URL sitting as text inside (pre (code "...")) safe: it is a string
  ;; child, never an attribute value, so it is never a candidate for
  ;; rewriting in the first place -- there is no text-scanning pass that
  ;; could mistake it for a link.
  (define (rewrite-links body registry page ref)
    (let ((danglers '()))

      ;; attr = (name value). Rewrite it if name is href/src; else pass
      ;; through unchanged.
      (define (attr-map attr)
        (if (and (memq (car attr) '(href src)) (pair? (cdr attr)) (string? (cadr attr)))
            (let-values (((new dangling?) (rewrite-target (cadr attr) page registry ref)))
              (when dangling? (set! danglers (cons (cons page (cadr attr)) danglers)))
              (list (car attr) new))
            attr))

      ;; R6RS leaves `map`'s application order unspecified, and attr-map has
      ;; a `set!` side effect (recording danglers) -- so a plain (map
      ;; attr-map attrs) could accumulate danglers out of document order.
      ;; Recurse explicitly left to right instead, as (site transform) does for
      ;; its own `set!`-during-walk accumulator: the
      ;; `let` forces and binds the head's result -- side effect included --
      ;; before the recursive call for the tail is ever evaluated.
      (define (walk-attrs attrs)
        (if (null? attrs)
            '()
            (let ((head (attr-map (car attrs))))
              (cons head (walk-attrs (cdr attrs))))))

      ;; Same reasoning, for an element's children.
      (define (walk-children nodes)
        (if (null? nodes)
            '()
            (let ((head (walk-node (car nodes))))
              (cons head (walk-children (cdr nodes))))))

      ;; A leading (^ ...) in an element's tail is its attribute list. Only
      ;; (a) and (img) elements ever carry href/src, so the rewrite is gated
      ;; on the tag itself: walk-attrs runs for those two tags, and every
      ;; other tag's attribute list passes through unchanged. Either way we
      ;; still recurse into the remaining children. Strings (and any other
      ;; non-pair leaf) come back unchanged.
      (define (walk-node node)
        (if (pair? node)
            (let ((tag (car node)) (rest (cdr node)))
              (if (and (pair? rest) (pair? (car rest)) (eq? (caar rest) '^))
                  (cons tag (cons (cons '^ (if (memq tag '(a img))
                                                (walk-attrs (cdar rest))
                                                (cdar rest)))
                                  (walk-children (cdr rest))))
                  (cons tag (walk-children rest))))
            node))

      (let ((out (walk-node body)))
        (values out (reverse danglers))))))
