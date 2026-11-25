#!r6rs
;; Probe: chez-sqlite3's test-reference readers, copied verbatim (its lines
;; 74-123 and 235-284), run on chez-sodium's public library: the exports as
;; Chez lists them, each one's kind, and the signature comments as that
;; suite reads them.
(import (rnrs) (rnrs eval)
        (only (chezscheme) library-exports printf))
(define (describe e) (if (message-condition? e) (condition-message e) e))
;; --- reading text ----------------------------------------------------------------

;; slurp : String -> String
;; The file's text, read as UTF-8.
(define (slurp path)
  (call-with-port
   (open-file-input-port path (file-options) (buffer-mode block)
                         (make-transcoder (utf-8-codec)))
   (lambda (port)
     (let ((text (get-string-all port)))
       (if (eof-object? text) "" text)))))

;; text-lines : String -> (Listof String)
;; The text split at each newline, a newline that ends it ending its last.
(define (text-lines s)
  (let loop ((cs (string->list s)) (line '()) (out '()))
    (cond ((null? cs)
           (reverse (if (null? line) out (cons (list->string (reverse line)) out))))
          ((char=? (car cs) #\newline)
           (loop (cdr cs) '() (cons (list->string (reverse line)) out)))
          (else (loop (cdr cs) (cons (car cs) line) out)))))

;; blank? : Char -> Boolean
(define (blank? c) (or (char=? c #\space) (char=? c #\tab)))

;; trim : String -> String
(define (trim s)
  (let* ((n (string-length s))
         (i (let loop ((i 0)) (if (and (< i n) (blank? (string-ref s i))) (loop (+ i 1)) i)))
         (j (let loop ((j n)) (if (and (> j i) (blank? (string-ref s (- j 1)))) (loop (- j 1)) j))))
    (substring s i j)))

;; starts? : String String -> Boolean
(define (starts? s prefix)
  (and (>= (string-length s) (string-length prefix))
       (string=? (substring s 0 (string-length prefix)) prefix)))

;; run : String Natural Char -> Natural
;; How many of C begin at I.
(define (run s i c)
  (let loop ((j i))
    (if (and (< j (string-length s)) (char=? (string-ref s j) c)) (loop (+ j 1)) (- j i))))

;; words : String -> (Listof String)
(define (words s)
  (let loop ((cs (string->list s)) (w '()) (out '()))
    (define (flush) (if (null? w) out (cons (list->string (reverse w)) out)))
    (cond ((null? cs) (reverse (flush)))
          ((blank? (car cs)) (loop (cdr cs) '() (flush)))
          (else (loop (cdr cs) (cons (car cs) w) out)))))
;; The names the library exports, as Chez's library-exports lists them,
;; sorted; the library is first imported into an environment, so Chez has
;; it. Or (raised WHAT) for a raise.
(define (exports-of library)
  (guard (e (#t (list 'raised (describe e))))
    (environment library)
    (list-sort string<? (map symbol->string (library-exports library)))))

;; kind-in : Environment String -> (U 'syntax 'procedure 'value (List 'raised String))
;; What NAME is, as Chez evaluates it in ENV: syntax, when evaluating it is
;; a syntax violation; a procedure; a value; or (raised WHAT) for any other
;; raise.
(define (kind-in env name)
  (guard (e ((syntax-violation? e) 'syntax)
            (#t (list 'raised (describe e))))
    (let ((v (eval (string->symbol name) env)))
      (if (procedure? v) 'procedure 'value))))

;; has-arrow? : String -> Boolean
;; Whether the type holds ->.
(define (has-arrow? type)
  (let loop ((i 0))
    (cond ((> (+ i 2) (string-length type)) #f)
          ((string=? (substring type i (+ i 2)) "->") #t)
          (else (loop (+ i 1))))))

;; line-type : String String -> (U String #f)
;; The TYPE of a line "NAME : TYPE" for this NAME, else #f.
(define (line-type name line)
  (let ((lead (string-append name " : ")))
    (and (starts? line lead)
         (substring line (string-length lead) (string-length line)))))

;; signature-comments : String -> (Listof (Pair String String))
;; Every line of the source's text, up to its import clause, that is a comment
;; ";; NAME : TYPE" (any indent), as (NAME . "NAME : TYPE"). NAME holds no space.
(define (signature-comments text)
  (let* ((lines (let take ((ls (text-lines text)) (out '()))
                  (if (or (null? ls) (starts? (trim (car ls)) "(import"))
                      (reverse out)
                      (take (cdr ls) (cons (trim (car ls)) out)))))
         (comments (map (lambda (l) (substring l 3 (string-length l)))
                        (filter (lambda (l) (starts? l ";; ")) lines))))
    (apply append
           (map (lambda (c)
                  (let ((ws (words c)))
                    (if (and (pair? ws) (pair? (cdr ws)) (string=? (cadr ws) ":"))
                        (list (cons (car ws) c))
                        '())))
                comments))))
(define text (slurp "src/chez-sodium.sls"))
(define exports (exports-of '(chez-sodium)))
(define env (environment '(chez-sodium)))
(define comments (signature-comments text))
(printf "exports ~a\n" (length exports))
(for-each
 (lambda (name)
   (let ((cs (filter (lambda (c) (string=? (car c) name)) comments)))
     (printf "~a | ~a | ~a | ~s\n" name (kind-in env name) (length cs)
             (if (pair? cs) (cdar cs) 'none))))
 exports)
(printf "comments ~a, for no export: ~s\n" (length comments)
        (filter (lambda (c) (not (member (car c) exports))) comments))
(for-each
 (lambda (c)
   (let ((type (line-type (car c) (cdr c))))
     (when (and type (let loop ((i 0)) (cond ((>= i (string-length type)) #f)
                                              ((char=? (string-ref type i) #\;) #t)
                                              (else (loop (+ i 1))))))
       (printf "trailing annotation: ~s\n" (cdr c)))))
 comments)
