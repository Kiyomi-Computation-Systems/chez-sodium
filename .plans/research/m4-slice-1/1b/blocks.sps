;;; build/m4s1-1b/blocks.sps: builder 1b's own check of its pages' blocks.
;;; Run from the repository root, in the container:
;;;   scheme --libdirs src --program build/m4s1-1b/blocks.sps OUTDIR
;;; - every fenced block names scheme, scheme run, sh or text;
;;; - every Scheme block reads; no fragment holds a ";; =>" line;
;;; - each scheme run block's body, as (let () BODY) in (rnrs) and
;;;   (chez-sodium), is equal? to its ";; =>" datum;
;;; - README.org's one Scheme block equals, line for line, some run block;
;;; - each whole program is written to OUTDIR/NAME.sps, with
;;;   OUTDIR/NAME.expected when a text block follows it before the next
;;;   Scheme block, and OUTDIR/NAME.guarded when it holds a guard clause
;;;   (sodium-library-unavailable? V).
(import (chezscheme))

(define pages '("docs/quickstart.md" "docs/passwords.md" "docs/tokens.md"
                "docs/finding-libsodium.md"))
(define outdir (cadr (command-line)))
(define failures 0)
(define (fail . xs)
  (set! failures (+ failures 1))
  (display "FAIL: ") (for-each display xs) (newline))
(define (ok . xs) (display "ok: ") (for-each display xs) (newline))

(define (file-lines path)
  (call-with-input-file path
    (lambda (p)
      (let loop ((acc '()))
        (let ((l (get-line p)))
          (if (eof-object? l) (reverse acc) (loop (cons l acc))))))))

(define (trim s)
  (let* ((n (string-length s))
         (a (let f ((i 0)) (if (and (< i n) (memv (string-ref s i) '(#\space #\tab))) (f (+ i 1)) i)))
         (b (let f ((i n)) (if (and (> i a) (memv (string-ref s (- i 1)) '(#\space #\tab))) (f (- i 1)) i))))
    (substring s a b)))
(define (starts? s p) (and (>= (string-length s) (string-length p)) (string=? (substring s 0 (string-length p)) p)))
(define (search s pat)
  (let ((n (string-length s)) (m (string-length pat)))
    (let loop ((i 0)) (cond ((> (+ i m) n) #f) ((string=? (substring s i (+ i m)) pat) i) (else (loop (+ i 1)))))))

;; blocks : (Listof String) -> (Listof (List Natural String (Listof String)))
;; Each fenced block: its opening line number, its info string, its lines.
(define (blocks lines)
  (let loop ((ls lines) (n 1) (acc '()))
    (cond ((null? ls) (reverse acc))
          ((starts? (trim (car ls)) "```")
           (let ((info (trim (substring (trim (car ls)) 3 (string-length (trim (car ls)))))))
             (let body ((rest (cdr ls)) (k (+ n 1)) (got '()))
               (cond ((null? rest) (fail "unclosed block at line " n) (reverse acc))
                     ((string=? (trim (car rest)) "```")
                      (loop (cdr rest) (+ k 1) (cons (list n info (reverse got)) acc)))
                     (else (body (cdr rest) (+ k 1) (cons (car rest) got)))))))
          (else (loop (cdr ls) (+ n 1) acc)))))

(define (joined lines) (apply string-append (map (lambda (l) (string-append l "\n")) lines)))

(define (read-all text)
  (let ((p (open-input-string text)))
    (let loop ((acc '()))
      (let ((d (read p)))
        (if (eof-object? d) (reverse acc) (loop (cons d acc)))))))

(define (guarded? x)
  (and (pair? x)
       (or (and (eq? (car x) 'guard) (pair? (cdr x)) (pair? (cadr x))
                (exists (lambda (clause)
                          (and (pair? clause) (pair? (car clause))
                               (eq? (caar clause) 'sodium-library-unavailable?)
                               (pair? (cdar clause))
                               (eq? (cadar clause) (caadr x))))
                        (cdadr x)))
           (and (list? x) (exists guarded? x)))))

(define env (environment '(rnrs) '(chez-sodium)))
(define run-blocks '())

(for-each
 (lambda (page)
   (let* ((bs (blocks (file-lines page)))
          (base (path-root (path-last page))))
     (let loop ((bs bs) (k 0))
       (unless (null? bs)
         (let* ((b (car bs)) (line (car b)) (info (cadr b)) (ls (caddr b))
                (where (string-append page ":" (number->string line))))
           (cond
            ((not (member info '("scheme" "scheme run" "sh" "text")))
             (fail where " block kind " info))
            ((string=? info "scheme")
             (let ((data (guard (e (#t (fail where " does not read: " (condition-message e)) #f))
                           (read-all (joined ls)))))
               (when (exists (lambda (l) (starts? (trim l) ";; =>")) ls)
                 (fail where " a fragment holds ;; =>"))
               (when (and data (pair? data) (pair? (car data)) (eq? (caar data) 'import))
                 (let ((name (string-append outdir "/" base "-" (number->string k))))
                   (with-output-to-file (string-append name ".sps")
                     (lambda () (display (joined ls))) 'replace)
                   (when (exists guarded? data)
                     (with-output-to-file (string-append name ".guarded")
                       (lambda () (display where)) 'replace))
                   ;; the text block before the next Scheme block, if any
                   (let find ((rest (cdr bs)))
                     (cond ((null? rest) (ok where " whole program, no text block"))
                           ((starts? (cadr (car rest)) "scheme")
                            (ok where " whole program, no text block before the next Scheme block"))
                           ((string=? (cadr (car rest)) "text")
                            (with-output-to-file (string-append name ".expected")
                              (lambda () (display (joined (caddr (car rest))))) 'replace)
                            (ok where " whole program, text block at line " (car (car rest))))
                           (else (find (cdr rest)))))))
               (when data (ok where " reads"))))
            ((string=? info "scheme run")
             (set! run-blocks (cons ls run-blocks))
             (let* ((nonblank (filter (lambda (l) (not (string=? (trim l) ""))) ls))
                    (last-line (and (pair? nonblank) (list-ref nonblank (- (length nonblank) 1))))
                    (arrows (filter (lambda (l) (starts? (trim l) ";; =>")) ls)))
               (if (not (and last-line (starts? (trim last-line) ";; => ") (= (length arrows) 1)))
                   (fail where " run block's last line is not its one ;; =>")
                   (let* ((datum-text (substring (trim last-line) 6 (string-length (trim last-line))))
                          (stated (read-all datum-text))
                          (body-lines (let drop ((l (reverse ls)))
                                        (if (starts? (trim (car l)) ";; =>") (reverse (cdr l)) (drop (cdr l)))))
                          (body (read-all (joined body-lines)))
                          (got (guard (e (#t (list 'raised (if (message-condition? e) (condition-message e) e)
                                                   (if (irritants-condition? e) (condition-irritants e) '()))))
                                 (eval `(let () ,@body) env))))
                     (if (and (= (length stated) 1) (equal? got (car stated)))
                         (ok where " run block gives " (car stated))
                         (fail where " run block gave " got ", stated " stated))))))
            (else (ok where " " info " block"))))
         (loop (cdr bs) (+ k 1))))))
 pages)

;; README.org's Scheme blocks: each the twin of some run block.
(let* ((ls (file-lines "README.org"))
       (srcs (let loop ((ls ls) (acc '()))
               (cond ((null? ls) (reverse acc))
                     ((string=? (trim (car ls)) "#+begin_src scheme")
                      (let body ((rest (cdr ls)) (got '()))
                        (if (string=? (trim (car rest)) "#+end_src")
                            (loop (cdr rest) (cons (reverse got) acc))
                            (body (cdr rest) (cons (car rest) got)))))
                     (else (loop (cdr ls) acc))))))
  (if (null? srcs) (fail "README.org has no Scheme block"))
  (for-each (lambda (src)
              (if (member src run-blocks)
                  (ok "README.org's Scheme block is a run block's twin: " (car src))
                  (fail "README.org's Scheme block has no twin: " src)))
            srcs))

(display "library: ") (write (eval (quote (sodium-version)) env)) (newline)
(display "failures: ") (display failures) (newline)
(exit (if (= failures 0) 0 1))
