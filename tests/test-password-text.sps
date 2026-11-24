#!r6rs
;;; The suite for (chez-sodium private password-text): utf8-length,
;;; readable-hash-string? and current-hash-shape?. It loads no libsodium: its
;;; last row holds that.
;;;
;;;   U    utf8-length at each width's edges, on "", on a mixed string and on
;;;        a long one, each against string->utf8's length
;;;   R    readable-hash-string?: a real hash, each edge of the printable
;;;        range, U+0000, 0x80 and above, the empty string, both sides of
;;;        input-cap
;;;   H    current-hash-shape?: each part present, missing or altered
;;;   S    password-text.sls read as data: no copying primitive, string-append
;;;        only for a message, the import clause and the exports whole
(import (rnrs)
        (only (chezscheme) foreign-entry?)
        (srfi :64)
        (chez-sodium-testing)
        (chez-sodium private password-text)
        (chez-sodium private cap))

;; SRFI-64 sets no exit status. This suite's last line turns the runner's
;; counts into one.
(define runner (test-runner-simple))
(test-runner-current runner)

;; The simple runner names a failing test but not its values. Print both.
(let ((simple-end (test-runner-on-test-end runner)))
  (test-runner-on-test-end! runner
    (lambda (r)
      (simple-end r)
      (when (memq (test-result-kind r) '(fail xpass))
        (display "  expected: ")
        (write (test-result-ref r 'expected-value))
        (newline)
        (display "  actual:   ")
        (write (test-result-ref r 'actual-value))
        (newline)))))

(test-begin "password-text")

;; --- helpers ---------------------------------------------------------------------------------

;; chars : Natural ... -> String
(define (chars . codes) (list->string (map integer->char codes)))

;; utf8-n : String -> Natural
;; The reference length, from the encoder: the suite may use it, the library may not.
(define (utf8-n s) (bytevector-length (string->utf8 s)))

;; width : Natural -> Natural
(define (width code) (utf8-length (chars code)))

;; iota-list : Natural -> (Listof Natural)
(define (iota-list n)
  (let loop ((i (- n 1)) (acc '()))
    (if (< i 0) acc (loop (- i 1) (cons i acc)))))

;; repeat : Natural Char -> String
(define (repeat n c) (make-string n c))

;; The real hashes, from libsodium's own answers.
(define id-hash "$argon2id$v=19$m=8,t=1,p=1$G3l+79ke+VolO5DJeBf7Ew$f4PPEPgEJa+vZURqklKvZaKsC2LE9213fLd/rFWTJNc")
(define i-hash "$argon2i$v=19$m=8,t=3,p=1$M7piIWNtEXiEBDILqW0joQ$YvJYnNYtgmsRVSqwuv5bVM30pd8Gomfs5DL4FSDZfCA")
(define long-hash "$argon2id$v=19$m=8,t=1,p=1$EyYDv0QsQbeigj9AAWd4og$2h21FCkx8IoVDEl4/mLnPx/13x3VOsaGEEcSznsHWANOIbT5yNoNpmiSmo3WFrwrB8CHtsaXS9cT0QGGUfFzow")
(define id-prefix "$argon2id$")
(define i-prefix "$argon2i$")

;; --- U: utf8-length --------------------------------------------------------------------------

(for-each
 (lambda (row)
   (test-equal (string-append "U width of U+" (number->string (car row) 16))
     (cdr row) (width (car row))))
 '((#x0 . 1) (#x7F . 1) (#x80 . 2) (#x7FF . 2) (#x800 . 3) (#xFFFF . 3)
   (#x10000 . 4) (#x10FFFF . 4)))

(test-equal "U the empty string is 0" 0 (utf8-length ""))
(test-equal "U \"pässwörd€\" is 13" 13 (utf8-length "pässwörd€"))
(test-equal "U \"pässwörd€\" agrees with the encoder" (utf8-n "pässwörd€") (utf8-length "pässwörd€"))

(let ((long (apply string-append
                   (map (lambda (i)
                          (chars (+ #x41 (mod i 20)) #xE9 (+ #x800 i) (+ #x10000 i) #x20))
                        (iota-list 3000)))))
  (test-equal "U a long mixed string agrees with the encoder" (utf8-n long) (utf8-length long)))

;; --- R: readable-hash-string? ----------------------------------------------------------------

;; r-answer, h-answer : (-> Boolean) -> (U (List 'answered Boolean) (List 'raised))
;; What the call answers, or 'raised: SRFI-64 would read a raise as #f.
(define (r-answer thunk) (guard (e (#t (list 'raised))) (list 'answered (thunk))))
(define h-answer r-answer)

(test-equal "R a real hash is readable" (list 'answered #t) (r-answer (lambda () (readable-hash-string? id-hash))))
(test-equal "R the 136-character hash is readable" (list 'answered #t) (r-answer (lambda () (readable-hash-string? long-hash))))
(test-equal "R U+0020 is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (chars #x20)))))
(test-equal "R U+0021 is accepted" (list 'answered #t) (r-answer (lambda () (readable-hash-string? (chars #x21)))))
(test-equal "R U+007E is accepted" (list 'answered #t) (r-answer (lambda () (readable-hash-string? (chars #x7E)))))
(test-equal "R U+007F is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (chars #x7F)))))
(test-equal "R U+0020 inside a hash is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (string-append id-hash " ")))))
(test-equal "R U+0000 at the end is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (string-append id-hash (chars 0))))))
(test-equal "R U+0000 at the start is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (string-append (chars 0) id-hash)))))
(test-equal "R U+0000 in the middle is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (string-append "$arg" (chars 0) "on2id$")))))
(test-equal "R U+0080 is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (string-append id-hash (chars #x80))))))
(test-equal "R U+00E9 is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (string-append "a" (chars #xE9))))))
(test-equal "R U+20AC is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (chars #x20AC)))))
(test-equal "R the empty string is refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? ""))))
(test-equal "R input-cap characters are accepted" (list 'answered #t) (r-answer (lambda () (readable-hash-string? (repeat input-cap #\a)))))
(test-equal "R input-cap + 1 characters are refused" (list 'answered #f) (r-answer (lambda () (readable-hash-string? (repeat (+ input-cap 1) #\a)))))

;; --- H: current-hash-shape? ------------------------------------------------------------------

;; id-with : String -> String
;; An argon2id hash around the parameter text PARAMS.
(define (id-with params) (string-append id-prefix params "$c2FsdHNhbHQ$dGFndGFn"))

(test-equal "H an argon2id hash against the argon2id prefix" (list 'answered #t) (h-answer (lambda () (current-hash-shape? id-hash id-prefix))))
(test-equal "H an argon2id hash against the argon2i prefix" (list 'answered #f) (h-answer (lambda () (current-hash-shape? id-hash i-prefix))))
(test-equal "H an argon2i hash against the argon2i prefix" (list 'answered #t) (h-answer (lambda () (current-hash-shape? i-hash i-prefix))))
(test-equal "H an argon2i hash against the argon2id prefix" (list 'answered #f) (h-answer (lambda () (current-hash-shape? i-hash id-prefix))))
(test-equal "H the 136-character hash" (list 'answered #t) (h-answer (lambda () (current-hash-shape? long-hash id-prefix))))
(test-equal "H a #f prefix" (list 'answered #f) (h-answer (lambda () (current-hash-shape? id-hash #f))))
(test-equal "H a #f prefix is not an empty one: a hash that is only the parameters" (list 'answered #f) (h-answer (lambda () (current-hash-shape? "v=19$m=8,t=1,p=1$x" #f))))
(test-equal "H p=4" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,t=1,p=4") id-prefix))))
(test-equal "H p=2" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,t=1,p=2") id-prefix))))
(test-equal "H p=10" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,t=1,p=10") id-prefix))))
(test-equal "H the generated shape holds" (list 'answered #t) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,t=1,p=1") id-prefix))))
(test-equal "H no v=" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "m=8,t=1,p=1") id-prefix))))
(test-equal "H v= with no digits" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=$m=8,t=1,p=1") id-prefix))))
(test-equal "H v= with a letter" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=1x$m=8,t=1,p=1") id-prefix))))
(test-equal "H m= with a letter" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=x,t=1,p=1") id-prefix))))
(test-equal "H m= with no digits" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=,t=1,p=1") id-prefix))))
(test-equal "H m= missing" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$,t=1,p=1") id-prefix))))
(test-equal "H t= missing" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,p=1") id-prefix))))
(test-equal "H t= with no digits" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,t=,p=1") id-prefix))))
(test-equal "H p= missing" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19$m=8,t=1") id-prefix))))
(test-equal "H a comma where $ stands before m" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (id-with "v=19,m=8,t=1,p=1") id-prefix))))
(test-equal "H ,p=1 with nothing after $" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (string-append id-prefix "v=19$m=8,t=1,p=1$") id-prefix))))
(test-equal "H ,p=1 with no $" (list 'answered #f) (h-answer (lambda () (current-hash-shape? (string-append id-prefix "v=19$m=8,t=1,p=1") id-prefix))))
(test-equal "H one character after ,p=1$" (list 'answered #t) (h-answer (lambda () (current-hash-shape? (string-append id-prefix "v=19$m=8,t=1,p=1$x") id-prefix))))
(test-equal "H the prefix only" (list 'answered #f) (h-answer (lambda () (current-hash-shape? id-prefix id-prefix))))
(test-equal "H the empty hash" (list 'answered #f) (h-answer (lambda () (current-hash-shape? "" id-prefix))))
(test-equal "H a hash shorter than the prefix" (list 'answered #f) (h-answer (lambda () (current-hash-shape? "$argon2" id-prefix))))
(for-each
 (lambda (row)
   (test-equal (string-append "H ends mid-shape: " (car row))
     '(answered #f) (h-answer (lambda () (current-hash-shape? (cdr row) id-prefix)))))
 '(("empty" . "")
   ("after v=19" . "$argon2id$v=19")
   ("after m=8" . "$argon2id$v=19$m=8")
   ("after t=1" . "$argon2id$v=19$m=8,t=1")
   ("after v=" . "$argon2id$v=")
   ("after m=" . "$argon2id$v=19$m=")))

(test-equal "H an empty prefix does not stand for any prefix" (list 'answered #f) (h-answer (lambda () (current-hash-shape? id-hash ""))))

;; --- S: the source read as data --------------------------------------------------------------

(define source-path "src/chez-sodium/private/password-text.sls")

;; read-library : String -> (U (List Any ...) (List 'unreadable Any))
(define (read-library path)
  (guard (e (#t (list 'unreadable 'could-not-read)))
    (let ((form (call-with-port
                 (open-file-input-port path (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (if (and (list? form) (> (length form) 4) (eq? (car form) 'library))
          form
          (list 'unreadable 'not-a-library-form)))))

(define form (read-library source-path))
(define read? (not (eq? (car form) 'unreadable)))
(define body (if read? (cddddr form) '()))

;; tokens : Any -> (Listof Symbol)
(define (tokens x)
  (cond ((symbol? x) (list x))
        ((pair? x) (append (tokens (car x)) (tokens (cdr x))))
        ((vector? x) (tokens (vector->list x)))
        (else '())))

(define forbidden
  '(string->utf8 utf8->string string->list list->string substring string-copy
    string->bytevector bytevector-copy make-string string string-set! string-fill!
    string-copy! string-normalize-nfc string-normalize-nfd string-normalize-nfkc
    string-normalize-nfkd string-upcase string-downcase string-foldcase string-titlecase
    string->symbol open-string-output-port call-with-string-output-port put-string
    write display))

;; offending : (Listof Symbol)
;; The forbidden symbols in the body, in reading order; the list (unreadable) when the file is unread.
(define offending
  (if read?
      (filter (lambda (t) (memq t forbidden)) (tokens body))
      '(unreadable)))

(test-equal "S the library holds no copying or encoding primitive" '() offending)

;; message-definition? : Any -> Boolean
;; A top-level definition of a name ending in -message, bound to a value that is
;; not a procedure: no parameters, no lambda, no case-lambda.
(define (message-definition? f)
  (and (pair? f) (eq? (car f) 'define) (pair? (cdr f)) (symbol? (cadr f))
       (not (memq 'lambda (tokens f))) (not (memq 'case-lambda (tokens f)))
       (let ((name (symbol->string (cadr f))))
         (and (>= (string-length name) 8)
              (string=? "-message" (list->string
                                    (list-tail (string->list name) (- (string-length name) 8))))))))

(test-equal "S string-append appears only in a top-level -message definition"
  '()
  (if read?
      (filter (lambda (f) (and (memq 'string-append (tokens f)) (not (message-definition? f))))
              body)
      '(unreadable)))

;; sorted-symbols : (Listof Symbol) -> (Listof Symbol)
;; The distinct symbols, sorted by name.
(define (sorted-symbols syms)
  (let loop ((sorted (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
                                syms))
             (acc '()))
    (cond ((null? sorted) (reverse acc))
          ((and (pair? acc) (eq? (car acc) (car sorted))) (loop (cdr sorted) acc))
          (else (loop (cdr sorted) (cons (car sorted) acc))))))

(test-equal "S every symbol the body references, distinct and sorted, whole"
  '(+ < <= = > >= and c char->integer char<=? char=? char>=? cond current-hash-shape?
    define digit? digits else end hash i if input-cap j k lambda let lit literal loop m n or
    prefix readable-hash-string? step str string-length string-ref then total utf8-length)
  (if read? (sorted-symbols (tokens body)) '(unreadable)))

(test-equal "S the import clause, whole: require-threaded first, then (rnrs), then cap"
  '((chez-sodium private require-threaded) (rnrs) (chez-sodium private cap))
  (if (and read? (list? (cadddr form)) (eq? (car (cadddr form)) 'import))
      (cdr (cadddr form))
      '(unreadable)))

(test-equal "S the exports, whole"
  '(utf8-length readable-hash-string? current-hash-shape?)
  (if (and read? (pair? (caddr form)) (eq? (car (caddr form)) 'export))
      (cdr (caddr form))
      '(unreadable)))

;; The three functions are pure, so calling them loads no libsodium.
(test-equal "no libsodium is loaded after calling all three"
  '(answered #f)
  (guard (e (#t (list 'raised)))
    (utf8-length "a")
    (readable-hash-string? "a")
    (current-hash-shape? "a" id-prefix)
    (list 'answered (foreign-entry? "sodium_init"))))

(test-end "password-text")

;; Anything after this line never runs.
(exit (suite-exit-status runner))
