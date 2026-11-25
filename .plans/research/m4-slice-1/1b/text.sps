;;; build/m4s1-1b/text.sps: builder 1b's own check of its pages' text.
;;; Run from the repository root (or a copy holding docs/ and README.org):
;;;   scheme --libdirs SRC:SITE --program build/m4s1-1b/text.sps
;;; - every prose code span of one name with a watched prefix is an export;
;;; - every relative link names a file, and an anchor into a .md page names
;;;   one of its headings by GitHub's rule; README.org's [[file:X]] exist;
;;; - each page's first line is its one H1, "# " and its label;
;;; - finding-libsodium.md's reasons table is the reasons, in order, and its
;;;   discovery table names libsodium-candidates' paths and sources for guix
;;;   and fhs on ta6le and tarm64le, with stand-in GUIX_ENVIRONMENT,
;;;   GUIX_PROFILE and HOME; the one span before " for `CHEZ_SODIUM_LIBRARY`"
;;;   is override, and with the rows' they are libsodium-sources, in order;
;;; - README.org's Documentation list is (site pages)' list.
(import (chezscheme)
        (only (chez-sodium private discovery) libsodium-candidates libsodium-sources)
        (only (chez-sodium private conditions) sodium-library-unavailable-reasons)
        (only (site pages) pages))

(define pages-md '(("docs/quickstart.md" . "Quick start") ("docs/passwords.md" . "Passwords")
                   ("docs/tokens.md" . "Tokens") ("docs/finding-libsodium.md" . "Finding libsodium")))
(define failures 0)
(define (fail . xs) (set! failures (+ failures 1)) (display "FAIL: ") (for-each display xs) (newline))
(define (ok . xs) (display "ok: ") (for-each display xs) (newline))

(define (file-lines path)
  (call-with-input-file path
    (lambda (p) (let loop ((acc '())) (let ((l (get-line p))) (if (eof-object? l) (reverse acc) (loop (cons l acc))))))))
(define (trim s)
  (let* ((n (string-length s))
         (a (let f ((i 0)) (if (and (< i n) (memv (string-ref s i) '(#\space #\tab))) (f (+ i 1)) i)))
         (b (let f ((i n)) (if (and (> i a) (memv (string-ref s (- i 1)) '(#\space #\tab))) (f (- i 1)) i))))
    (substring s a b)))
(define (starts? s p) (and (>= (string-length s) (string-length p)) (string=? (substring s 0 (string-length p)) p)))
(define (search s pat i)
  (let ((n (string-length s)) (m (string-length pat)))
    (let loop ((i i)) (cond ((> (+ i m) n) #f) ((string=? (substring s i (+ i m)) pat) i) (else (loop (+ i 1)))))))
(define (joined ls) (apply string-append (map (lambda (l) (string-append l "\n")) ls)))
(define (flat s) (list->string (map (lambda (c) (if (char=? c #\newline) #\space c)) (string->list s))))

;; prose-lines : (Listof String) -> (Listof String)
;; The lines outside fenced blocks.
(define (prose-lines lines)
  (let loop ((ls lines) (in? #f) (acc '()))
    (cond ((null? ls) (reverse acc))
          ((starts? (trim (car ls)) "```") (loop (cdr ls) (not in?) acc))
          (in? (loop (cdr ls) #t acc))
          (else (loop (cdr ls) #f (cons (car ls) acc))))))

;; spans : String -> (Listof (List Natural Natural String))
;; Each single-backtick code span: its start, its end past the close, its text.
(define (spans text)
  (let loop ((i 0) (acc '()))
    (let ((a (search text "`" i)))
      (if (not a) (reverse acc)
          (let ((b (search text "`" (+ a 1))))
            (if (not b) (reverse acc)
                (loop (+ b 1) (cons (list a (+ b 1) (substring text (+ a 1) b)) acc))))))))

(define exports (begin (environment '(chez-sodium)) (map symbol->string (library-exports '(chez-sodium)))))
(define prefixes '("sodium-" "chez-sodium-" "password-" "make-password-" "random-" "blake2b" "constant-time-"))
(define (name-char? c) (or (char<=? #\a c #\z) (char<=? #\0 c #\9) (memv c '(#\- #\! #\? #\=))))
(define (watched? s)
  (and (> (string-length s) 0) (for-all name-char? (string->list s))
       (exists (lambda (p) (starts? s p)) prefixes)))

;; GitHub's anchor for a heading's text.
(define (slug text)
  (let* ((no-links (let loop ((s text))      ; [x](y) -> x
                     (let ((a (search s "](" 0)))
                       (if (not a) s
                           (let ((open (let f ((i a)) (if (char=? (string-ref s i) #\[) i (f (- i 1)))))
                                 (close (search s ")" a)))
                             (loop (string-append (substring s 0 open) (substring s (+ open 1) a)
                                                  (substring s (+ close 1) (string-length s)))))))))
         (kept (filter (lambda (c) (or (char-alphabetic? c) (char-numeric? c) (memv c '(#\_ #\space #\-))))
                       (string->list (string-downcase no-links)))))
    (list->string (map (lambda (c) (if (char=? c #\space) #\- c)) kept))))
(define (anchors path)
  (let loop ((ls (prose-lines (file-lines path))) (seen '()))
    (cond ((null? ls) (reverse seen))
          ((starts? (car ls) "#")
           (let* ((text (trim (let f ((s (car ls))) (if (starts? s "#") (f (substring s 1 (string-length s))) s))))
                  (base (slug text))
                  (n (length (filter (lambda (x) (equal? (car x) base)) seen))))
             (loop (cdr ls) (cons (cons base (if (= n 0) base (string-append base "-" (number->string n)))) seen))))
          (else (loop (cdr ls) seen)))))

(for-each
 (lambda (pg)
   (let* ((page (car pg)) (label (cdr pg)) (lines (file-lines page)) (prose (prose-lines lines))
          (text (flat (joined prose))))
     ;; H1
     (let ((h1s (filter (lambda (l) (and (starts? l "# ") #t)) prose)))
       (if (and (string=? (car lines) (string-append "# " label)) (= (length h1s) 1))
           (ok page " one H1, its first line: " (car lines))
           (fail page " H1s " h1s)))
     ;; export spans
     (for-each (lambda (s)
                 (let ((t (caddr s)))
                   (when (watched? t)
                     (if (member t exports) #t (fail page " span `" t "` is no export")))))
               (spans text))
     (ok page " watched spans: "
         (let ((ws (filter watched? (map caddr (spans text)))))
           (list-sort string<? (let d ((l ws) (o '())) (cond ((null? l) o) ((member (car l) o) (d (cdr l) o)) (else (d (cdr l) (cons (car l) o))))))))
     ;; links, outside code spans
     (let ((no-code (let ((s (string-copy text)))
                      (for-each (lambda (sp)
                                  (do ((i (car sp) (+ i 1))) ((= i (cadr sp)))
                                    (string-set! s i #\space)))
                                (spans text))
                      s)))
       (let loop ((i 0))
         (let ((a (search no-code "](" i)))
           (when a
             (let* ((b (search no-code ")" a)) (target (substring no-code (+ a 2) b)))
               (cond ((or (starts? target "http://") (starts? target "https://")) #t)
                     (else
                      (let* ((h (search target "#" 0))
                             (file (if h (substring target 0 h) target))
                             (anchor (and h (substring target (+ h 1) (string-length target))))
                             (path (if (string=? file "") page (string-append "docs/" file))))
                        (cond ((starts? file "../.plans") (fail page " links into .plans: " target))
                              ((not (file-exists? path)) (fail page " links to a missing file: " target))
                              ((and anchor (not (starts? path "docs/"))) (fail page " anchors into a non-Markdown page: " target))
                              ((and anchor (not (member anchor (map cdr (anchors path)))))
                               (fail page " anchor not a heading: " target))
                              (else (ok page " link " target))))))
               (loop (+ b 1)))))))))
 pages-md)

;; README.org: every [[file:X]] names a file; the Documentation list is (site pages)'.
(let* ((lines (file-lines "README.org")) (text (joined lines)))
  (let loop ((i 0))
    (let ((a (search text "[[file:" i)))
      (when a
        (let* ((b (search text "]" a)) (target (substring text (+ a 7) b)))
          (if (file-exists? target) (ok "README.org link " target)
              (display (string-append "note: README.org links " target ", which is not in the tree\n")))
          (loop (+ b 1))))))
  (let* ((tail (cdr (member "** Documentation" lines)))
         (section (let f ((ls tail)) (if (or (null? ls) (starts? (car ls) "*")) '() (cons (car ls) (f (cdr ls))))))
         (listed (let f ((ls section))
                   (cond ((null? ls) '())
                         ((search (car ls) "[[file:docs/" 0)
                          => (lambda (a)
                               (let* ((s (car ls)) (b (search s "][" a)) (c (search s "]]" b)))
                                 (cons (cons (substring s (+ a 12) b) (substring s (+ b 2) c)) (f (cdr ls))))))
                         (else (f (cdr ls)))))))
    (if (equal? listed pages) (ok "README.org's Documentation list is (site pages)': " listed)
        (fail "README.org's Documentation list " listed " vs " pages))))

;; finding-libsodium.md's tables.
(define finding (joined (prose-lines (file-lines "docs/finding-libsodium.md"))))
(define (table-rows header)
  (let loop ((ls (prose-lines (file-lines "docs/finding-libsodium.md"))))
    (cond ((null? ls) (fail "no table headed " header) '())
          ((starts? (car ls) (string-append "| " header " |"))
           (let rows ((ls (cddr ls)) (acc '()))
             (if (or (null? ls) (not (starts? (car ls) "|"))) (reverse acc)
                 (rows (cdr ls)
                       (cons (let cells ((s (car ls)) (i 1) (acc '()))
                               (let ((j (search s "|" i)))
                                 (if (not j) (reverse acc)
                                     (cells s (+ j 1) (cons (trim (substring s i j)) acc)))))
                             acc)))))
          (else (loop (cdr ls))))))

(let ((first-col (map (lambda (row) (let ((ss (spans (car row))))
                                      (if (and (= (length ss) 1) (= (car (car ss)) 0) (= (cadr (car ss)) (string-length (car row))))
                                          (string->symbol (caddr (car ss))) (list 'not-one-span (car row)))))
                      (table-rows "Reason"))))
  (if (equal? first-col sodium-library-unavailable-reasons)
      (ok "reasons table: " first-col)
      (fail "reasons table " first-col " vs " sodium-library-unavailable-reasons)))

(define (stand-in name) (and (member name '("GUIX_ENVIRONMENT" "GUIX_PROFILE" "HOME")) (string-append "/@" name)))
(define (as-written path)
  (cond ((starts? path "/@HOME") (string-append "~" (substring path 6 (string-length path))))
        ((starts? path "/@GUIX_ENVIRONMENT") (string-append "$GUIX_ENVIRONMENT" (substring path 18 (string-length path))))
        ((starts? path "/@GUIX_PROFILE") (string-append "$GUIX_PROFILE" (substring path 14 (string-length path))))
        (else path)))
;; The paths a "where it looks" cell names on MACHINE (x86_64 or arm64).
(define (looks-in cell machine)
  (let* ((ss (spans cell))
         (alt-of (lambda (s) ; the machine word when S is written (`X` on M)
                   (and (> (car s) 1) (char=? (string-ref cell (- (car s) 1)) #\()
                        (let ((on (search cell " on " (cadr s))) (close (search cell ")" (cadr s))))
                          (and on close (= on (cadr s)) (substring cell (+ on 4) close))))))
         (chosen (let loop ((ss ss) (acc '()))
                   (cond ((null? ss) (reverse acc))
                         ((alt-of (car ss)) (loop (cdr ss) acc))
                         ((and (pair? (cdr ss)) (alt-of (cadr ss)))
                          (loop (cddr ss) (cons (if (string=? (alt-of (cadr ss)) machine) (cadr ss) (car ss)) acc)))
                         (else (loop (cdr ss) (cons (car ss) acc))))))
         (in-at (search cell " in " 0))
         (files (filter (lambda (s) (< (car s) in-at)) chosen))
         (dirs (filter (lambda (s) (> (car s) in-at)) chosen)))
    (unless (= (cadr (list-ref files (- (length files) 1))) in-at)
      (fail "the last file span is not right before \" in \": " cell))
    (apply append (map (lambda (d) (map (lambda (f) (string-append (caddr d) "/" (caddr f))) files)) dirs))))

(let ((rows (table-rows "System")))
  (if (not (= (length rows) 2)) (fail "discovery rows: " (length rows)))
  (for-each
   (lambda (row world label-ok?)
     (if (label-ok? (car row)) (ok "row label: " (car row)) (fail "row label " (car row)))
     (for-each
      (lambda (mt machine)
        (let ((want (map (lambda (c) (as-written (car c))) (libsodium-candidates world mt stand-in)))
              (got (looks-in (cadr row) machine)))
          (if (equal? want got) (ok world " on " mt ": " got) (fail world " on " mt ": page " got " code " want))))
      '(ta6le tarm64le) '("x86_64" "arm64"))
     (let ((want (let d ((l (map (lambda (c) (symbol->string (cdr c))) (libsodium-candidates world 'ta6le stand-in))) (o '()))
                   (cond ((null? l) (reverse o)) ((member (car l) o) (d (cdr l) o)) (else (d (cdr l) (cons (car l) o))))))
           (got (map caddr (spans (caddr row)))))
       (if (equal? want got) (ok world " sources: " got) (fail world " sources page " got " code " want))))
   rows
   '(guix fhs)
   (list (lambda (c) (and (search c "Guix" 0) #t)) (lambda (c) (starts? c "Other Linux"))))
  (let* ((ftext (flat finding))
         (before (map caddr (filter (lambda (s) (starts? (substring ftext (cadr s) (string-length ftext))
                                                         " for `CHEZ_SODIUM_LIBRARY`"))
                                    (spans ftext))))
         (all (append before (apply append (map (lambda (r) (map caddr (spans (caddr r)))) rows)))))
    (if (equal? before '("override")) (ok "the override's span: " before) (fail "override spans " before))
    (if (equal? (map string->symbol all) libsodium-sources) (ok "sources, each once, in order: " all)
        (fail "sources " all " vs " libsodium-sources))))

(display "failures: ") (display failures) (newline)
(exit (if (= failures 0) 0 1))
