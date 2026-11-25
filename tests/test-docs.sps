#!r6rs
;;; The docs' rules, held for README.org and every docs/*.md page:
;;;
;;; - every block names its language: scheme, sh or text (an Org block a src
;;;   block of one of them, or a quote block), and a fence or #+end_ closes
;;;   it;
;;; - every Scheme block is a fragment, each datum of which Chez's read
;;;   reads, or a runnable example (below). A Scheme block that says
;;;   anything else fails, by its page and line;
;;; - every relative link names a file or directory of the checkout, and its
;;;   #anchor, when it has one, names a heading of that Markdown page by
;;;   GitHub's rule. A link with an anchor into a page that is not Markdown,
;;;   README.org among them, and an Org link to a place on its own page,
;;;   fail: nothing here could check them. No link points into .plans/, and
;;;   no page says so;
;;; - README.org links every page of docs/, so none is orphaned;
;;; - README.org holds a Scheme block, and each of its Scheme blocks is the
;;;   twin of a runnable example (below) of a page of docs/: its lines are,
;;;   line for line, all of that block's lines, its ";; =>" line included. So
;;;   the README's example runs, through its twin. A block with no twin
;;;   fails, by its #+begin_src line; so does a README with no Scheme block,
;;;   and one with a block inside another, which the Org reader would not see;
;;; - no page says ADR- or TODO, "not yet" or any other "yet", "unreleased",
;;;   "slice", "printable ASCII", a path in .plans, or a date written
;;;   YYYY-MM-DD, in any case; nor holds a finding id: a capital letter, then
;;;   capitals and digits, then -F and digits, as in M3S2-F4 or L-F7;
;;; - every code span of a page's prose that is one name, its chars a to z,
;;;   digits, -, !, ? and =, beginning sodium-, chez-sodium-, password-,
;;;   make-password-, random-, blake2b or constant-time-, is an export of
;;;   (chez-sodium). So is every such name in README.org's Org verbatim
;;;   =x= or code ~x~ span, as Org's rule reads one within a line, and every
;;;   such symbol, at any depth and quoted too, in the data of a Markdown
;;;   Scheme fragment. A page writes BLAKE2b-512 and the like outside code;
;;; - every Markdown Scheme fragment whose first datum, as Chez's read reads
;;;   the block's text, is a list headed import is a whole program: read
;;;   skips a #!r6rs and comments before it. It runs as written, a program of
;;;   its own in a fresh Chez with a reader's library path, src alone,
;;;   through gated-command, from a fresh directory of its own, src named by
;;;   its absolute path: it exits 0 with nothing on stderr; when a text block
;;;   follows it on its page before the next Scheme block, whatever lies
;;;   between, it prints the first such block's lines, line for line. Some
;;;   whole program has one. None prints a password hash;
;;; - a guarded program is a whole program that holds a guard with a clause
;;;   (sodium-library-unavailable? V), V the guard's variable. It prints
;;;   (sodium-version) as the suite reads it, as write writes it, and a
;;;   newline, and runs again with CHEZ_SODIUM_LIBRARY naming a file that is
;;;   not there, exits 0 with nothing on stderr, and prints exactly
;;;   (refused load-failed "PATH"), PATH that file, as write writes it, and a
;;;   newline.
;;;   It has no text block before the next Scheme block of its page, since
;;;   the version it prints differs by lane;
;;; - no whole program names a (chez-sodium private ...) library: no list
;;;   of its data, at any depth, begins chez-sodium private, so neither its
;;;   import form, a second import in its body, an environment nor a quoted
;;;   name reaches one. The reader's library path finds those too;
;;; - docs/finding-libsodium.md's tables are the code's. The reasons table's
;;;   first column, each cell one code span, is the library's list of
;;;   refusal reasons, in its order. The discovery table's two rows are
;;;   discovery's worlds, in order, Guix and other Linux: the first row's
;;;   first cell holds Guix, the second's begins Other Linux. A row's second
;;;   cell names its files and its directories, `FILE`, then `FILE` in `DIR`,
;;;   `DIR`, ...: the code spans before the word " in " are the file names,
;;;   in order, those after it the directories, in order, and the paths are,
;;;   directory by directory, each file in order, DIR/FILE. Each row's paths
;;;   and sources are compared with the candidates discovery's own procedure
;;;   gives for its world on x86_64 and on arm64; the sources are its third
;;;   cell's code spans. The code span before " for `CHEZ_SODIUM_LIBRARY`"
;;;   in the prose is the source an override gets; with the table's, they are
;;;   discovery's sources, each once;
;;; - every word of a page, a run of letters, digits and _, in a block or
;;;   not, that holds CHEZ_ is CHEZ_SODIUM_LIBRARY; and every
;;;   CHEZ_SODIUM_LIBRARY= of a line that sets it, one at the line's start
;;;   or after a blank, as export X=, env X= and X=... before a command do,
;;;   gives it a value, up to a blank, that begins with /. One after any
;;;   other char, as Org's verbatim =CHEZ_SODIUM_LIBRARY= is, sets nothing;
;;; - every page of docs/ has one level-1 heading, and it is the page's
;;;   first line;
;;; - docs/reference.md's reasons are the code's. Its glossary's Reason line,
;;;   the quoted words of the text block line that begins Reason and of the
;;;   indented lines after it, and its reasons table's first column, are the
;;;   library's refusal reasons, in its order. Each - `REASON`: bullet of a
;;;   verb's entry names a reason that verb raises, which a probe of the
;;;   verb's own mistakes shows, but for two the probe cannot reach, held to
;;;   a quoted symbol of password-verbs.sls; and names each reason the verb
;;;   raises. The order the page promises is the probes': an entry's probed
;;;   reasons, each at its first place, are the probes' reasons in the order
;;;   the code checks them; a reason no probe reaches is held by presence
;;;   alone. The detail entry's bullets are the library's reasons, each once,
;;;   in any order. The glossary's Limits line is the source's Limits line
;;;   of src/chez-sodium.sls, read as text: the quoted presets in order, then
;;;   Password-limits.
;;;
;;; THE RUNNABLE CONVENTION. A Markdown Scheme block whose info string is
;;; exactly the one word run, written ```scheme run, is run: the tests
;;; evaluate it. Neither GitHub nor the site shows the info string, so what a
;;; reader sees is its last line, ";; =>", which no Markdown fragment may
;;; hold. Its last non-blank line is a comment that
;;; states its result, ";; => DATUM", and no other line of the block starts
;;; that way. Everything above that line is the body, one or more data
;;; evaluated as the body of (let () ...) in an environment of (rnrs) and
;;; (chez-sodium); its last value, as Chez's read reads DATUM, must be
;;; equal? to the stated one. A body that raises fails, with what it raised.
;;; The runs leave the block count at zero, so a block that makes a native
;;; block frees it. A block that has no ";; =>" line, or has two, or
;;; whose line is not last, or whose DATUM is not one datum, fails; so does
;;; an info string of any other words after scheme, and an Org Scheme block
;;; with any: the convention is Markdown's.
;;;
;;; The pages are read as CommonMark is: a fenced block opens on a line of up
;;; to three spaces, then three or more backticks or tildes and an info
;;; string, and closes only on a fence of its own character, at least as
;;; long, and nothing after; one no fence closes runs to the page's end. Its
;;; links are each inline link, [text](target), of its prose, outside code;
;;; its headings, its ATX headings outside blocks. A reference-style link is
;;; out of reach: write inline ones. An Org page's blocks run from
;;; #+begin_NAME to #+end_NAME; its links are [[target]] and [[target][text]]
;;; outside blocks. A heading's anchor, by GitHub's rule: its text, a link
;;; read as its text, inline code's marks and * dropped, in lower case, every
;;; char but a letter, a digit, _, a space or a - dropped, each space made a
;;; -; a second heading of one anchor takes -1, a third -2.
;;;
;;; A pipe table is a run of prose lines that begin, past up to three
;;; spaces, with |, its second line a delimiter row; a cell is the text
;;; between two |s, trimmed, a \| kept as |. A table whose lines do not
;;; begin with | is out of reach. A span written right after another as
;;; (`ALT` on M) takes that one's place on the machine M, arm64 or x86_64,
;;; and names nothing on any other. Discovery is asked in an environment
;;; where GUIX_ENVIRONMENT, GUIX_PROFILE and HOME each name a stand-in
;;; directory and nothing else is set, so a path under one reads as the page
;;; writes it: $GUIX_ENVIRONMENT, $GUIX_PROFILE, and ~ for HOME.
;;;
;;; Out of its reach, with no oracle but a reader's reading: prose that says
;;; something wrong, and a stated result that is wrong in a way equal? cannot
;;; see. (The signatures are tests/test-reference.sps's.) Every reader and
;;; rule is held on texts of the suite's own before it reads a page. Each
;;; computation that can raise runs under a guard that answers what was
;;; raised, since SRFI-64 turns a raise in the actual expression into #f; no
;;; expected value is #f. The suite runs from the repository root, with src
;;; and tests on Chez's library path.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (chez-sodium-testing)
        (chez-sodium private counters)
        (only (chez-sodium private conditions) sodium-library-unavailable-reasons)
        (only (chez-sodium private discovery)
              choose-libsodium libsodium-candidates libsodium-sources)
        (only (chezscheme) current-directory directory-list getenv))


;; SRFI-64 sets no exit status. This suite's last line turns the runner's
;; counts into one.
(define runner (test-runner-simple))
(test-runner-current runner)
(test-begin "docs")

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

;; --- reading text ----------------------------------------------------------------

;; slurp : String -> String
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

;; joined : (Listof String) -> String
;; The lines, each ended by a newline.
(define (joined lines)
  (apply string-append (map (lambda (l) (string-append l "\n")) lines)))

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

;; ends? : String String -> Boolean
(define (ends? s suffix)
  (let ((n (string-length s)) (k (string-length suffix)))
    (and (>= n k) (string=? (substring s (- n k) n) suffix))))

;; search : String String Natural -> (U Natural #f)
;; Where PAT next begins in S, from I.
(define (search s pat i)
  (let ((n (string-length s)) (k (string-length pat)))
    (let loop ((i i))
      (cond ((> (+ i k) n) #f)
            ((string=? (substring s i (+ i k)) pat) i)
            (else (loop (+ i 1)))))))

;; run : String Natural Char -> Natural
;; How many of C begin at I.
(define (run s i c)
  (let loop ((j i))
    (if (and (< j (string-length s)) (char=? (string-ref s j) c)) (loop (+ j 1)) (- j i))))

;; split : String Char -> (Listof String)
(define (split s c)
  (let loop ((cs (string->list s)) (piece '()) (out '()))
    (cond ((null? cs) (reverse (cons (list->string (reverse piece)) out)))
          ((char=? (car cs) c) (loop (cdr cs) '() (cons (list->string (reverse piece)) out)))
          (else (loop (cdr cs) (cons (car cs) piece) out)))))

;; words : String -> (Listof String)
(define (words s)
  (filter (lambda (w) (not (string=? w "")))
          (split (list->string (map (lambda (c) (if (blank? c) #\space c)) (string->list s)))
                 #\space)))

;; ascii-downcase : String -> String
(define (ascii-downcase s)
  (list->string (map (lambda (c) (if (and (char<=? #\A c) (char<=? c #\Z))
                                     (integer->char (+ (char->integer c) 32))
                                     c))
                     (string->list s))))

;; datums : String -> (U (Listof Any) (List 'unreadable))
;; Every datum Chez's read reads from the text.
(define (datums text)
  (guard (e (#t (list 'unreadable)))
    (let ((p (open-string-input-port text)))
      (let loop ((out '()))
        (let ((d (read p)))
          (if (eof-object? d) (reverse out) (loop (cons d out))))))))

;; shown : Datum -> String
(define (shown d)
  (call-with-string-output-port (lambda (p) (write d p))))

;; numbered : (Listof String) -> (Listof (Pair Natural String))
;; Each line with its number, from 1.
(define (numbered lines)
  (let loop ((ls lines) (n 1) (out '()))
    (if (null? ls) (reverse out) (loop (cdr ls) (+ n 1) (cons (cons n (car ls)) out)))))

;; --- Markdown: blocks, prose, headings and links -------------------------------------

;; A block of a page: its line, its language, the words of its info string
;; after the language, its lines, and whether a fence closes it.
(define-record-type block (fields line language info lines closed?))

;; fence : String -> (U (List Char Natural Natural String) #f)
;; The line as a fence that opens a block: its character, how many, its
;; indent, and its info string, trimmed. A backtick fence's info holds no
;; backtick.
(define (fence line)
  (let ((indent (run line 0 #\space)) (n (string-length line)))
    (and (<= indent 3) (< indent n)
         (let ((c (string-ref line indent)))
           (and (memv c '(#\` #\~))
                (let* ((k (run line indent c))
                       (info (trim (substring line (+ indent k) n))))
                  (and (>= k 3)
                       (not (and (char=? c #\`) (memv #\` (string->list info))))
                       (list c k indent info))))))))

;; closes? : String (List Char Natural Natural String) -> Boolean
(define (closes? line open)
  (let ((indent (run line 0 #\space)))
    (and (<= indent 3)
         (let ((k (run line indent (car open))))
           (and (>= k (cadr open))
                (string=? (trim (substring line (+ indent k) (string-length line))) ""))))))

;; unindent : String Natural -> String
(define (unindent line n)
  (let ((k (min n (run line 0 #\space)))) (substring line k (string-length line))))

;; heading-of : String -> (U (Pair Natural String) #f)
(define (heading-of line)
  (let* ((indent (run line 0 #\space)) (n (string-length line)))
    (and (<= indent 3)
         (let ((k (run line indent #\#)))
           (and (<= 1 k 6)
                (or (= (+ indent k) n) (blank? (string-ref line (+ indent k))))
                (cons k (trim (substring line (+ indent k) n))))))))

;; make-block-of : (List Char Natural Natural String) Natural (Listof String) Boolean -> Block
(define (make-block-of open line lines closed?)
  (let ((ws (words (cadddr open))))
    (make-block line (if (null? ws) "" (ascii-downcase (car ws))) (if (null? ws) '() (cdr ws))
                lines closed?)))

;; markdown : String -> (List (Listof Block) (Listof String) (Listof (Pair Natural String)))
;; The page's fenced blocks, in order; its prose, every other line, a blank
;; line for each of a block's, so the prose keeps the page's line numbers;
;; and its headings, each with its text, outside blocks.
(define (markdown text)
  (let loop ((ls (text-lines text)) (n 1) (open #f) (start 0) (body '())
             (blocks '()) (prose '()) (heads '()))
    (cond ((null? ls)
           (list (reverse (if open (cons (make-block-of open start (reverse body) #f) blocks) blocks))
                 (reverse prose) (reverse heads)))
          (open
           (if (closes? (car ls) open)
               (loop (cdr ls) (+ n 1) #f 0 '()
                     (cons (make-block-of open start (reverse body) #t) blocks) (cons "" prose) heads)
               (loop (cdr ls) (+ n 1) open start (cons (unindent (car ls) (caddr open)) body)
                     blocks (cons "" prose) heads)))
          ((fence (car ls))
           => (lambda (f) (loop (cdr ls) (+ n 1) f n '() blocks (cons "" prose) heads)))
          (else
           (loop (cdr ls) (+ n 1) #f 0 '() blocks (cons (car ls) prose)
                 (let ((h (heading-of (car ls)))) (if h (cons h heads) heads)))))))

;; h1-lines : (Listof String) -> (Listof Natural)
;; The line of each level-1 heading of a Markdown page's prose, as markdown
;; reads its headings, in order.
(define (h1-lines prose)
  (map car (filter (lambda (l) (let ((h (heading-of (cdr l)))) (and h (= (car h) 1))))
                   (numbered prose))))

;; code-ranges : String -> (Listof (Pair Natural Natural))
;; Where each `code` span of the text begins and ends: a run of backticks
;; opens one, and the next run of exactly as many closes it; a run that none
;; closes is text, and so is a backtick after a backslash.
(define (code-ranges text)
  (let ((n (string-length text)))
    (define (closer i k)
      (cond ((>= i n) #f)
            ((char=? (string-ref text i) #\`)
             (let ((m (run text i #\`))) (if (= m k) i (closer (+ i m) k))))
            (else (closer (+ i 1) k))))
    (let loop ((i 0) (out '()))
      (cond ((>= i n) (reverse out))
            ((and (char=? (string-ref text i) #\\) (< (+ i 1) n)) (loop (+ i 2) out))
            ((char=? (string-ref text i) #\`)
             (let* ((k (run text i #\`)) (j (closer (+ i k) k)))
               (if j (loop (+ j k) (cons (cons i (+ j k)) out)) (loop (+ i k) out))))
            (else (loop (+ i 1) out))))))

;; code-spans : String -> (Listof String)
;; The text of each code span, its backticks off and its blanks trimmed.
(define (code-spans text)
  (map (lambda (r)
         (let* ((s (substring text (car r) (cdr r)))
                (k (run s 0 #\`)))
           (trim (substring s k (- (string-length s) k)))))
       (code-ranges text)))

;; without-code : String -> String
;; The text with each code span made spaces, its line ends kept.
(define (without-code text)
  (let ((ranges (code-ranges text)))
    (let loop ((cs (string->list text)) (i 0) (out '()))
      (if (null? cs)
          (list->string (reverse out))
          (loop (cdr cs) (+ i 1)
                (cons (if (and (not (char=? (car cs) #\newline))
                               (exists (lambda (r) (and (<= (car r) i) (< i (cdr r)))) ranges))
                          #\space
                          (car cs))
                      out))))))

;; markdown-links : (Listof String) -> (Listof String)
;; The target of each inline link and image of the prose, [text](target),
;; outside code: what follows "](" up to a blank, a line's end or the ")"
;; that ends it, without angle brackets around it.
(define (markdown-links prose)
  (let ((s (without-code (joined prose))))
    (let loop ((i 0) (out '()))
      (let ((j (search s "](" i)))
        (if (not j)
            (reverse out)
            (let end ((k (+ j 2)))
              (if (or (>= k (string-length s)) (memv (string-ref s k) '(#\) #\space #\tab #\newline)))
                  (let ((t (substring s (+ j 2) k)))
                    (loop k (cons (if (and (starts? t "<") (ends? t ">"))
                                      (substring t 1 (- (string-length t) 1))
                                      t)
                                  out)))
                  (end (+ k 1)))))))))

;; --- Org: blocks and links ------------------------------------------------------------

;; org-keyword : String String -> (U String #f)
;; The rest of the line after KEYWORD, when the line, past its blanks,
;; begins with it in any case.
(define (org-keyword line keyword)
  (let ((s (trim line)))
    (and (starts? (ascii-downcase s) keyword) (substring s (string-length keyword) (string-length s)))))

;; org : String -> (List (Listof Block) (Listof String))
;; The page's blocks, and its prose, every line outside a block, a blank
;; line for a block's, with its #+begin_ and #+end_ lines. A src block's
;; language is the first word after #+begin_src, "" for none; any other
;; block's is # and its NAME.
(define (org text)
  (let loop ((ls (text-lines text)) (n 1) (open #f) (start 0) (body '()) (blocks '()) (prose '()))
    (define (finish closed?)
      (let ((ws (cadr open)))
        (cons (if (string=? (car open) "src")
                  (make-block start (if (null? ws) "" (ascii-downcase (car ws)))
                              (if (null? ws) '() (cdr ws)) (reverse body) closed?)
                  (make-block start (string-append "#" (car open)) ws (reverse body) closed?))
              blocks)))
    (cond ((null? ls) (list (reverse (if open (finish #f) blocks)) (reverse prose)))
          (open
           (let ((end (org-keyword (car ls) "#+end_")))
             (if (and end (string=? (ascii-downcase (trim end)) (car open)))
                 (loop (cdr ls) (+ n 1) #f 0 '() (finish #t) (cons "" prose))
                 (loop (cdr ls) (+ n 1) open start (cons (car ls) body) blocks (cons "" prose)))))
          ((org-keyword (car ls) "#+begin_")
           => (lambda (rest)
                (let ((ws (words rest)))
                  (if (null? ws)
                      (loop (cdr ls) (+ n 1) #f 0 '() blocks (cons (car ls) prose))
                      (loop (cdr ls) (+ n 1) (list (ascii-downcase (car ws)) (cdr ws)) n '() blocks
                            (cons "" prose))))))
          (else (loop (cdr ls) (+ n 1) #f 0 '() blocks (cons (car ls) prose))))))

;; org-links : (Listof String) -> (Listof String)
;; The target of each [[target]] and [[target][text]] link of the prose.
(define (org-links prose)
  (let ((s (joined prose)))
    (let loop ((i 0) (out '()))
      (let ((j (search s "[[" i)))
        (if (not j)
            (reverse out)
            (let end ((k (+ j 2)))
              (cond ((>= k (string-length s)) (reverse out))
                    ((char=? (string-ref s k) #\]) (loop k (cons (substring s (+ j 2) k) out)))
                    (else (end (+ k 1))))))))))

;; --- anchors ---------------------------------------------------------------------------

;; heading-text : String -> String
;; A heading's text as it reads: each link [t](u) as t, code's marks and *
;; dropped.
(define (heading-text s)
  (let loop ((cs (string->list s)) (out '()))
    (cond ((null? cs) (list->string (reverse out)))
          ((and (char=? (car cs) #\]) (pair? (cdr cs)) (char=? (cadr cs) #\())
           (let skip ((rest (cddr cs)))
             (cond ((null? rest) (loop rest out))
                   ((char=? (car rest) #\)) (loop (cdr rest) out))
                   (else (skip (cdr rest))))))
          ((memv (car cs) '(#\[ #\` #\*)) (loop (cdr cs) out))
          (else (loop (cdr cs) (cons (car cs) out))))))

;; slug : String -> String
;; GitHub's rule for one heading's text, before duplicates.
(define (slug text)
  (list->string
   (map (lambda (c) (if (char=? c #\space) #\- c))
        (filter (lambda (c) (or (char-alphabetic? c) (char-numeric? c) (memv c '(#\_ #\- #\space))))
                (string->list (ascii-downcase (heading-text text)))))))

;; anchors : (Listof String) -> (Listof String)
;; The anchor of each heading text, in order: a second of one slug takes -1,
;; a third -2.
(define (anchors texts)
  (let loop ((rest texts) (seen '()) (out '()))
    (if (null? rest)
        (reverse out)
        (let* ((s (slug (car rest)))
               (n (length (filter (lambda (x) (string=? x s)) seen))))
          (loop (cdr rest) (cons s seen)
                (cons (if (= n 0) s (string-append s "-" (number->string n))) out))))))

;; --- links, resolved -------------------------------------------------------------------

;; scheme-like? : String -> Boolean
;; The target begins with a URI scheme and a colon, as https: or mailto: does.
(define (scheme-like? target)
  (let ((colon (search target ":" 0)))
    (and colon (> colon 0)
         (char-alphabetic? (string-ref target 0))
         (for-all (lambda (c) (or (char-alphabetic? c) (char-numeric? c) (memv c '(#\+ #\- #\.))))
                  (string->list (substring target 0 colon))))))

;; cut : String Char -> (Pair String (U String #f))
;; The text before the first C, and what follows it, or #f.
(define (cut s c)
  (let ((k (search s (string c) 0)))
    (if k (cons (substring s 0 k) (substring s (+ k 1) (string-length s))) (cons s #f))))

;; link-parts : String Boolean -> (U (List String (U String #f)) (List 'own-page) #f)
;; A link's file and its anchor, when it names one of the checkout: its
;; ?query dropped, and for an Org link a file: before it and a ::search
;; after it. #f for a link with a scheme; (own-page) for a place on its own
;; page, # or, for Org, * ; a link of no file at all is that too.
(define (link-parts target org?)
  (let* ((t (if (and org? (starts? target "file:")) (substring target 5 (string-length target)) target))
         (t (if org? (car (let ((k (search t "::" 0))) (cons (if k (substring t 0 k) t) #f))) t))
         (parts (cut t #\#))
         (file (car (cut (car parts) #\?))))
    (cond ((and (not org?) (scheme-like? file)) #f)
          ((and org? (scheme-like? file)) #f)
          ((or (string=? file "") (and org? (starts? target "*"))) (list 'own-page))
          (else (list file (cdr parts))))))

;; resolve : String String -> (U String #f)
;; PATH, relative to the directory DIR of the checkout ("" for its root), as
;; a path from the root, its . and empty segments dropped, each .. taking
;; off the segment before; #f when it climbs out of the root, or is
;; absolute. The root itself is "".
(define (resolve dir path)
  (and (not (starts? path "/"))
       (let loop ((segments (append (if (string=? dir "") '() (split dir #\/)) (split path #\/)))
                  (out '()))
         (cond ((null? segments)
                (if (null? out)
                    ""
                    (fold-left (lambda (acc s) (if (string=? acc "") s (string-append acc "/" s)))
                               "" (reverse out))))
               ((member (car segments) '("" ".")) (loop (cdr segments) out))
               ((string=? (car segments) "..") (and (pair? out) (loop (cdr segments) (cdr out))))
               (else (loop (cdr segments) (cons (car segments) out)))))))

;; dir-of : String -> String
(define (dir-of path)
  (let ((parts (split path #\/)))
    (if (null? (cdr parts))
        ""
        (fold-left (lambda (acc s) (if (string=? acc "") s (string-append acc "/" s)))
                   "" (reverse (cdr (reverse parts)))))))

;; into-plans? : String -> Boolean
(define (into-plans? path) (or (string=? path ".plans") (starts? path ".plans/")))

;; link-problem : String String Boolean (String -> Boolean) (String -> (U (Listof String) #f))
;;                -> (U Symbol #f)
;; Why TARGET, a link of the page PAGE, is no good, or #f. EXISTS? says a
;; path of the checkout is there; ANCHORS-OF answers a Markdown page's
;; anchors, #f when it cannot be read.
(define (link-problem page target org? exists? anchors-of)
  (let ((parts (link-parts target org?)))
    (cond ((not parts) #f)
          ((eq? (car parts) 'own-page)
           (if (and (not org?) (starts? target "#"))
               (let ((frag (substring target 1 (string-length target))))
                 (if (or (string=? frag "") (member frag (or (anchors-of page) '()))) #f 'no-such-anchor))
               'own-page-link-unchecked))
          (else
           (let ((path (resolve (dir-of page) (car parts))))
             (cond ((not path) 'outside-the-checkout)
                   ((into-plans? path) 'into-plans)
                   ((not (exists? (if (string=? path "") "." path))) 'no-such-file)
                   ((not (cadr parts)) #f)
                   ((not (ends? path ".md")) 'anchor-into-a-page-that-is-not-markdown)
                   ((string=? (cadr parts) "") #f)
                   ((member (cadr parts) (or (anchors-of path) '())) #f)
                   (else 'no-such-anchor)))))))

;; --- what a Scheme block says -----------------------------------------------------------

;; scheme-mark : Block Boolean -> (U 'fragment 'run 'unknown)
;; What the info of a Scheme block says it is: nothing, a fragment; the one
;; word run in Markdown, a runnable example; else unknown.
(define (scheme-mark b org?)
  (let ((info (block-info b)))
    (cond ((null? info) 'fragment)
          ((and (not org?) (equal? info '("run"))) 'run)
          (else 'unknown))))

;; parse-run : (Listof String) -> (U (List 'ok (Listof Any) Any) (List 'bad Symbol))
;; The body's data and the stated result's datum of a runnable block, or why
;; the block is no runnable example.
(define (parse-run lines)
  (let* ((marks (filter (lambda (l) (starts? (trim l) ";; =>")) lines))
         (nonblank (filter (lambda (l) (not (string=? (trim l) ""))) lines)))
    (cond ((null? marks) '(bad no-result-line))
          ((> (length marks) 1) '(bad two-result-lines))
          ((not (equal? (car (reverse nonblank)) (car marks))) '(bad result-line-not-last))
          (else
           (let* ((mark (trim (car marks)))
                  (stated (datums (substring mark 5 (string-length mark))))
                  (body (datums (joined (filter (lambda (l) (not (string=? l (car marks)))) lines)))))
             (cond ((or (equal? stated '(unreadable)) (not (= (length stated) 1))) '(bad result-is-not-one-datum))
                   ((or (equal? body '(unreadable)) (null? body)) '(bad body-is-not-data))
                   (else (list 'ok body (car stated)))))))))

;; check-run : (Listof String) Environment -> (U 'ok (List 'bad Symbol) (List 'wrong-result Any Any))
;; A runnable block's lines run in ENV: ok when its value is equal? to the
;; stated one; else why not, with what was stated and what happened.
(define (check-run lines env)
  (let ((parsed (parse-run lines)))
    (if (eq? (car parsed) 'bad)
        parsed
        (let ((outcome (guard (e (#t (list 'raised (describe e))))
                         (list 'value (eval (cons 'let (cons '() (cadr parsed))) env)))))
          (if (equal? outcome (list 'value (caddr parsed)))
              'ok
              (list 'wrong-result (caddr parsed) outcome))))))

;; --- the README's twin ----------------------------------------------------------------------

;; twin-problems : String String (Listof String) -> (Listof (Listof Any))
;; What keeps the README NAME, of Org text ORG-TEXT, from its twins in the
;; Markdown pages of texts MD-TEXTS: (NAME no-scheme-block) when it holds no
;; Scheme block; else (NAME LINE no-twin) for each Scheme block, by the line
;; of its #+begin_src, whose lines are not, line for line, all the lines of
;; one runnable block of a page.
(define (twin-problems name org-text md-texts)
  (let ((blocks (filter (lambda (b) (string=? (block-language b) "scheme")) (car (org org-text))))
        (runnable (apply append
                         (map (lambda (t)
                                (filter (lambda (b) (and (string=? (block-language b) "scheme")
                                                         (eq? (scheme-mark b #f) 'run)))
                                        (car (markdown t))))
                              md-texts))))
    (if (null? blocks)
        (list (list name 'no-scheme-block))
        (apply append
               (map (lambda (b)
                      (if (exists (lambda (r) (equal? (block-lines b) (block-lines r))) runnable)
                          '()
                          (list (list name (block-line b) 'no-twin))))
                    blocks)))))

;; --- prose rules ----------------------------------------------------------------------------

;; digit? : Char -> Boolean
(define (digit? c) (and (char<=? #\0 c) (char<=? c #\9)))

;; dated? : String -> Boolean
;; Whether the text holds four digits, -, two digits, -, two digits.
(define (dated? s)
  (let ((n (string-length s)))
    (let loop ((i 0))
      (and (<= (+ i 10) n)
           (or (let ((w (substring s i (+ i 10))))
                 (and (for-all digit? (string->list (substring w 0 4)))
                      (char=? (string-ref w 4) #\-)
                      (for-all digit? (string->list (substring w 5 7)))
                      (char=? (string-ref w 7) #\-)
                      (for-all digit? (string->list (substring w 8 10)))))
               (loop (+ i 1)))))))

;; upper? : Char -> Boolean
(define (upper? c) (and (char<=? #\A c) (char<=? c #\Z)))

;; finding-id? : String -> Boolean
;; Whether the text holds a finding id: a capital letter, then capitals and
;; digits, then -F and one or more digits, as M3S2-F4, M4S0-F7 and L-F7.
(define (finding-id? s)
  (let ((n (string-length s)))
    (let loop ((i 1))
      (and (< (+ i 2) n)
           (or (and (char=? (string-ref s i) #\-)
                    (char=? (string-ref s (+ i 1)) #\F)
                    (digit? (string-ref s (+ i 2)))
                    (let back ((j (- i 1)) (capital #f))
                      (if (and (>= j 0) (or (upper? (string-ref s j)) (digit? (string-ref s j))))
                          (back (- j 1) (or capital (upper? (string-ref s j))))
                          capital)))
               (loop (+ i 1)))))))

;; forbidden : String -> (Listof String)
;; Which of the banned phrases the text says, in any case, a line's end
;; between two words read as a space; and whether it holds a finding id, which
;; is read as written.
(define (forbidden text)
  (let ((flat (ascii-downcase (list->string (map (lambda (c) (if (char=? c #\newline) #\space c))
                                                 (string->list text))))))
    (append (filter (lambda (p) (search flat p 0))
                    '("adr-" "todo" "not yet" " yet" "unreleased" "slice" ".plans" "printable ascii"))
            (if (finding-id? text) '("a finding id") '())
            (if (dated? flat) '("a date") '()))))

;; name-prefixes : (Listof String)
;; What a name of (chez-sodium) begins with: every export does.
(define name-prefixes
  '("sodium-" "chez-sodium-" "password-" "make-password-" "random-" "blake2b" "constant-time-"))

;; name-like? : String -> Boolean
;; A code span that is one name of this library's kind: it begins with a
;; prefix, and holds only a to z, digits, -, !, ? and =.
(define (name-like? s)
  (and (exists (lambda (prefix) (starts? s prefix)) name-prefixes)
       (for-all (lambda (c) (or (and (char<=? #\a c) (char<=? c #\z)) (digit? c)
                                (memv c '(#\- #\! #\? #\=))))
                (string->list s))))

;; unknown-names : (Listof String) (Listof String) -> (Listof String)
;; The name-like code spans that are no export, sorted, each once.
(define (unknown-names spans exports)
  (let loop ((rest spans) (out '()))
    (cond ((null? rest) (list-sort string<? out))
          ((and (name-like? (car rest)) (not (member (car rest) exports)) (not (member (car rest) out)))
           (loop (cdr rest) (cons (car rest) out)))
          (else (loop (cdr rest) out)))))

;; org-post : (Listof Char)
;; What may follow a closing = or ~ of an Org span, besides a blank or a line's end.
(define org-post '(#\- #\. #\, #\; #\: #\! #\? #\' #\) #\} #\[ #\" #\\))

;; org-spans : String -> (Listof String)
;; The text of each verbatim =x= and code ~x~ span of one line of Org text,
;; as Org's rule reads one: its marker begins the line or follows a blank or
;; one of -({'" and is followed by a char that is no blank; it closes at the
;; next marker of its own kind that follows a char that is no blank and is
;; followed by the line's end, a blank or a char of org-post. A span never
;; crosses a line.
(define (org-spans line)
  (let ((n (string-length line)))
    (let loop ((i 0) (out '()))
      (cond ((>= i n) (reverse out))
            ((and (memv (string-ref line i) '(#\= #\~))
                  (or (= i 0)
                      (blank? (string-ref line (- i 1)))
                      (memv (string-ref line (- i 1)) '(#\- #\( #\{ #\' #\")))
                  (< (+ i 1) n)
                  (not (blank? (string-ref line (+ i 1)))))
             (let close ((j (+ i 2)))
               (cond ((>= j n) (loop (+ i 1) out))
                     ((and (char=? (string-ref line j) (string-ref line i))
                           (not (blank? (string-ref line (- j 1))))
                           (or (= (+ j 1) n)
                               (blank? (string-ref line (+ j 1)))
                               (memv (string-ref line (+ j 1)) org-post)))
                      (loop (+ j 1) (cons (substring line (+ i 1) j) out)))
                     (else (close (+ j 1))))))
            (else (loop (+ i 1) out))))))

;; datum-symbols : Any -> (Listof String)
;; The name of each symbol among the datum's elements, at any depth, a
;; vector's, a quoted datum's and a dotted tail's among them, in order.
(define (datum-symbols x)
  (cond ((symbol? x) (list (symbol->string x)))
        ((pair? x) (append (datum-symbols (car x)) (datum-symbols (cdr x))))
        ((vector? x) (apply append (map datum-symbols (vector->list x))))
        (else '())))

;; --- the readers, on texts of the suite's own --------------------------------------------------

(define sample-md
  (string-append
   "# Top `x`\n"
   "See [a](a.md#top-x) and `[no](code.md)`, ![i](<b.png>).\n"
   "```scheme run\n[no](block.md)\n# not a heading\n```\n"
   "## Top x\n"
   "[two](u#top-x-1) [mail](mailto:a@b)\n"
   "~~~sh\nls\n"))

(define sample-parsed (markdown sample-md))

(test-equal "markdown: each block with its line, language, info, lines and whether a fence closes it"
  '((3 "scheme" ("run") ("[no](block.md)" "# not a heading") #t)
    (9 "sh" () ("ls") #f))
  (map (lambda (b) (list (block-line b) (block-language b) (block-info b) (block-lines b) (block-closed? b)))
       (car sample-parsed)))

(test-equal "markdown: a block's lines are blank prose, so the prose keeps its line numbers"
  '("# Top `x`" "See [a](a.md#top-x) and `[no](code.md)`, ![i](<b.png>)." "" "" "" ""
    "## Top x" "[two](u#top-x-1) [mail](mailto:a@b)" "" "")
  (cadr sample-parsed))

(test-equal "markdown: the headings outside blocks, with level and text"
  '((1 . "Top `x`") (2 . "Top x"))
  (caddr sample-parsed))

(test-equal "h1-lines: each level-1 heading's line, a bare # and one indented three spaces among them; not one in a block, a level-2, a #word, one indented four, or seven #s"
  '((1) (2 8 10))
  (list (h1-lines (cadr sample-parsed))
        (h1-lines (cadr (markdown (string-append
                                   "Intro\n# Two\n```\n# in a block\n```\n#NoSpace\n    # four spaces\n"
                                   "   # three spaces\n## level two\n#\n####### seven\n"))))))

(test-equal "markdown-links: inline links and images outside code, an angle-bracketed target as written within them"
  '("a.md#top-x" "b.png" "u#top-x-1" "mailto:a@b")
  (markdown-links (cadr sample-parsed)))

(test-equal "code-spans: the text of each, a double-backtick span holding a backtick whole"
  '("a" "b ` c")
  (code-spans "x `a` y ``b ` c`` z `open"))

(test-equal "anchors: a heading's slug, its code and * and link marks dropped, a repeat taking -1 and -2"
  '("top-x" "top-x-1" "top-x-2" "ab_c" "see-here")
  (anchors '("Top `x`" "Top x" "Top *x*" "A.b_c!" "See [here](x.md)")))

(test-equal "link-parts: a scheme is no file; a fragment-only link is its own page; a ?query is dropped; Org's file: and ::search too"
  (list #f '(own-page) '("a.md" "top") '("b/c.md" #f) '("d.org" #f) '(own-page) #f)
  (list (link-parts "https://x.y/z" #f) (link-parts "#top" #f) (link-parts "a.md?q=1#top" #f)
        (link-parts "b/c.md" #f) (link-parts "file:d.org::*Head" #t) (link-parts "*Head" #t)
        (link-parts "mailto:a@b" #f)))

(test-equal "resolve: against the page's directory, . and .. applied, a climb out of the root and an absolute path refused"
  '("docs/b.md" "a.md" "" #f #f)
  (list (resolve "docs" "./b.md") (resolve "docs" "../a.md") (resolve "docs" "..")
        (resolve "docs" "../../a") (resolve "docs" "/etc")))

(test-equal "dir-of: a page's directory, \"\" for the root"
  '("docs" "" "a/b")
  (list (dir-of "docs/r.md") (dir-of "README.org") (dir-of "a/b/c.md")))

;; link-problem on a stand-in checkout: docs/r.md with anchors (top), a.md
(define stand-in-files '("." "docs" "docs/r.md" "a.md" "x.txt" ".plans/x.md" "README.org"))
(define (stand-in-exists? p) (and (member p stand-in-files) #t))
(define (stand-in-anchors p) (if (string=? p "docs/r.md") '("top") #f))

(test-equal "link-problem: each way a link fails, and each that does not"
  '(#f #f #f #f #f no-such-file no-such-anchor no-such-anchor into-plans outside-the-checkout
    no-such-anchor anchor-into-a-page-that-is-not-markdown #f)
  (map (lambda (t) (link-problem "docs/r.md" t #f stand-in-exists? stand-in-anchors))
       '("../a.md" "r.md#top" "#top" "https://x" ".." "nope.md" "r.md#nope" "#nope"
         "../.plans/x.md" "../../x" "../a.md#top" "../x.txt#top" "r.md#")))

(test-equal "link-problem: a link to README.org is fine without an anchor, from a page of docs/ and from a page at the root; an anchor on it, whatever it says, is refused"
  '(#f #f anchor-into-a-page-that-is-not-markdown anchor-into-a-page-that-is-not-markdown no-such-file)
  (list (link-problem "docs/r.md" "../README.org" #f stand-in-exists? stand-in-anchors)
        (link-problem "a.md" "README.org" #f stand-in-exists? stand-in-anchors)
        (link-problem "docs/r.md" "../README.org#requirements" #f stand-in-exists? stand-in-anchors)
        (link-problem "a.md" "README.org#" #f stand-in-exists? stand-in-anchors)
        (link-problem "docs/r.md" "README.org" #f stand-in-exists? stand-in-anchors)))

(test-equal "link-problem: Org's own-page links cannot be checked, and a missing file is named"
  '(own-page-link-unchecked own-page-link-unchecked no-such-file #f)
  (list (link-problem "README.org" "*Head" #t stand-in-exists? stand-in-anchors)
        (link-problem "README.org" "#id" #t stand-in-exists? stand-in-anchors)
        (link-problem "README.org" "docs/none.md" #t stand-in-exists? stand-in-anchors)
        (link-problem "README.org" "file:docs/r.md::x" #t stand-in-exists? stand-in-anchors)))

(test-equal "link-problem: an own-page # link of a page whose anchors are unknown fails, and a lone # is fine"
  '(no-such-anchor #f)
  (list (link-problem "docs/zz.md" "#top" #f stand-in-exists? stand-in-anchors)
        (link-problem "docs/r.md" "#" #f stand-in-exists? stand-in-anchors)))

(define sample-org
  (string-append
   "* Head\n"
   "A [[docs/r.md][ref]] and [[file:x.org::*H]] and [[https://z]].\n"
   "#+begin_src scheme :run\n[[not-a-link]]\n#+end_src\n"
   "#+BEGIN_QUOTE\nq\n#+END_QUOTE\n"
   "#+begin_src sh\nls\n"))

(define sample-org-parsed (org sample-org))

(test-equal "org: each block with its line, language, info, lines and whether #+end_ closes it"
  '((3 "scheme" (":run") ("[[not-a-link]]") #t)
    (6 "#quote" () ("q") #t)
    (9 "sh" () ("ls") #f))
  (map (lambda (b) (list (block-line b) (block-language b) (block-info b) (block-lines b) (block-closed? b)))
       (car sample-org-parsed)))

(test-equal "org-links: [[target]] and [[target][text]] outside blocks"
  '("docs/r.md" "file:x.org::*H" "https://z")
  (org-links (cadr sample-org-parsed)))

(test-equal "scheme-mark: nothing is a fragment; run alone is runnable in Markdown, never in Org; anything else unknown"
  '(fragment run unknown unknown unknown)
  (let ((b (lambda (info) (make-block 1 "scheme" info '() #t))))
    (list (scheme-mark (b '()) #f) (scheme-mark (b '("run")) #f) (scheme-mark (b '("run")) #t)
          (scheme-mark (b '("run" "x")) #f) (scheme-mark (b '("example=a.sps")) #f))))

(define rnrs-env (environment '(rnrs)))

(test-equal "check-run: a result that is the stated one passes; a different one, a raise, and each shape that is no example fail, named"
  '(ok
    (wrong-result 4 (value 3))
    (wrong-result 1 (raised "r"))
    (bad no-result-line)
    (bad two-result-lines)
    (bad result-line-not-last)
    (bad result-is-not-one-datum)
    (bad result-is-not-one-datum)
    (bad body-is-not-data)
    ok)
  (let ((go (lambda (lines)
              (let ((r (check-run lines rnrs-env)))
                (if (and (pair? r) (eq? (car r) 'wrong-result) (pair? (caddr r)) (eq? (car (caddr r)) 'raised))
                    (list 'wrong-result (cadr r) (list 'raised "r"))
                    r)))))
    (list (go '("(+ 1 2)" ";; => 3"))
          (go '("(+ 1 2)" ";; => 4"))
          (go '("(raise 'x)" ";; => 1"))
          (go '("(+ 1 2)"))
          (go '(";; => 1" ";; => 1"))
          (go '(";; => 3" "(+ 1 2)"))
          (go '("(+ 1 2)" ";; => 3 4"))
          (go '("(+ 1 2)" ";; =>"))
          (go '(";; => 3"))
          (go '("(define x 1)" "(list x x)" "" ";; => (1 1)" "")))))

(test-equal "forbidden: each banned phrase, in any case across a line's end, a finding id and a date; a yet without its not"
  '(("adr-" "todo" "not yet" " yet" "slice" ".plans" "printable ascii" "a finding id" "a date") ()
    (" yet") ("unreleased") ("printable ascii") ("printable ascii") () ("a finding id"))
  (list (forbidden "see ADR-0001, TODO: Not\nyet, a Slice of .plans/x on 2026-11-14, printable ASCII, M4S0-F7")
        (forbidden "Nothing to see: 2026-1-14 or 20261114.")
        (forbidden "The rest is not here\nYet.")
        (forbidden "Unreleased")
        (forbidden "A Printable\nASCII hash")
        (forbidden "printable ascii")
        (forbidden "Printable text, and ASCII.")
        (forbidden "L-F7")))

(test-equal "finding-id?: a capital, then capitals and digits, then -F and digits, as M3S2-F4, M4S0-F7 and L-F7, at the text's start, middle and end, with more digits, or in a longer word; not F4, -F4, a lowercase id, no digit, a digit-only start, a space, or another letter after -"
  '(yes yes yes yes yes yes yes yes yes no no no no no no no no no no)
  (map (lambda (s) (if (finding-id? s) 'yes 'no))
       '("M3S2-F4" "M4S0-F7" "L-F7" "A-F1" "see (L-F7)." "x M3S2-F10 y" "XM3-F1" "end A-F1" "1a B2-F3"
         "F4" "-F4" "m3s2-f4" "M3S2-F" "M3S2-FX" "12-F3" "M3S2 F4" "M3S2- F4" "A-G4" "")))

(test-equal "unknown-names: only the name-like spans that are no export, sorted, each once"
  '("chez-sodium-nope" "sodium-nope")
  (unknown-names '("sodium-nope" "sodium-ok" "chez-sodium-nope" "sodium-nope" "sodium-x y" "Sodium-Q"
                   "(sodium-nope)" "open-database")
                 '("sodium-ok" "open-database")))

(define sample-exports '("sodium-version" "chez-sodium-error?" "password-hash" "make-password-limits"
                         "random-bytes" "blake2b" "constant-time-bytevector=?" "password-needs-rehash?"))

(test-equal "unknown-names: a typo of an export, under each prefix, the first char, the middle or the last, is named; each export itself is not"
  '("blake2bb" "chez-sodium-eror?" "constant-time-bytevector?" "make-password-limit"
    "password-hashes" "random-byte" "sodium-versio")
  (unknown-names '("sodium-versio" "chez-sodium-eror?" "password-hashes" "make-password-limit"
                   "random-byte" "blake2bb" "constant-time-bytevector?"
                   "sodium-version" "chez-sodium-error?" "password-hash" "make-password-limits"
                   "random-bytes" "blake2b" "constant-time-bytevector=?")
                 sample-exports))

(test-equal "unknown-names: each prefix is held by itself: one span under each, a typo of its name, is named, and no other prefix's span is"
  (list-sort string<? (map (lambda (p) (string-append p "zz")) name-prefixes))
  (unknown-names (map (lambda (p) (string-append p "zz")) name-prefixes) sample-exports))

(test-equal "name-like?: each of a to z, a digit, -, !, ? and = is a char of a name; a capital, a space, a ., a _, a ( and a / are not; a prefix alone is a name, and a name of no prefix is not"
  '(yes yes yes yes yes yes yes no no no no no no no no no no)
  (map (lambda (s) (if (name-like? s) 'yes 'no))
       '("sodium-az" "sodium-09" "sodium--" "sodium-!" "sodium-?" "sodium-=" "sodium-"
         "sodium-A" "sodium- x" "sodium-a.b" "sodium-a_b" "(sodium-a)" "sodium-a/b"
         "blake2" "Sodium-a" "ransom-a" "constant-tim")))

(test-equal "org-spans: =x= and ~y~, at the line's start, after a blank, a ( and a quote, closed before a blank, a line's end and each char of org-post; a ~ span may hold ="
  '(("x" "y") ("a" "b" "c") ("a") ("p") ("q") ("r") ("s") ("t") ("u") ("v") ("w") ("x") ("constant-time-bytevector=?") ("y"))
  (map org-spans
       '("a =x= b ~y~ c" "=a= start, (=b=), ~c~." "-=a=" "(=p=" "'=q='" "=r=-" "=s=;" "=t=:" "=u=!" "=v=?" "=w=)" "=x=\\"
         "~constant-time-bytevector=?~" "CHEZ_SODIUM_LIBRARY=/x and =y=")))

(test-equal "org-spans: none from a marker inside a word, one followed or preceded by a blank, an unclosed one, a closer after a blank or before a letter, the other marker, or an empty span; two kinds on a line are each read"
  '(() () () () () () () () ("a" "b") ("p"))
  (map org-spans
       '("x=a=b" "a = b = c" "=a =" "=a" "~a" "=a~ b~" "=a=b" "==" "=a= ~b~ ~" "~a= =p=")))

(test-equal "org-spans, held to the exports: an Org span that is a typo of an export, under each prefix, is named; each export, and a span of no prefix, is not"
  '("blake2bb" "chez-sodium-eror?" "constant-time-bytevector?" "make-password-limit" "password-hashes"
    "random-byte" "sodium-versio")
  (unknown-names (apply append
                        (map org-spans
                             '("=sodium-versio= and ~chez-sodium-eror?~" "see =password-hashes=, ~make-password-limit~."
                               "(=random-byte=) ~blake2bb~ =constant-time-bytevector?= =x-y=" "=sodium-version= ~password-hash~"
                               "~constant-time-bytevector=?~ and =random-bytes= =blake2b=")))
                 sample-exports))

(test-equal "datum-symbols: each symbol of the data at any depth, a vector's, a quoted one's, a dotted tail's, in order; no string, comment or number"
  '("define" "f" "password-verfy" "x" "quote" "password-hashes" "vector" "random-byte" "a" "sodium-nope" "b" "y")
  (datum-symbols (datums "(define (f) (password-verfy x '(password-hashes))) #(vector random-byte) (a . sodium-nope) ;; z-nope\n\"s-nope\" 12 (b y)")))

(test-equal "unknown-names, on the symbols of a fragment's data: a typo of an export, bare, quoted, in a vector or a dotted tail, is named; an export, a name of no prefix, a string and a comment are not"
  '("blake2bb" "chez-sodium-x" "password-hashh" "password-verfy" "random-byte" "sodium-nope")
  (unknown-names
   (datum-symbols
    (datums (string-append "#!r6rs (define (log-in! h p) (cond ((password-verfy h p) (when x 'password-hashh))))\n"
                           "#(random-byte) (a . sodium-nope) \"password-nope\" ;; sodium-comment\n"
                           "'chez-sodium-x '(blake2bb) (password-hash p) (sodium-version) 'not-found")))
   sample-exports))

(test-equal "name-like?: BLAKE2b-512 and the like, written outside a code span, are no span; a span of one is no name"
  '(no no)
  (map (lambda (s) (if (name-like? s) 'yes 'no)) '("BLAKE2b-512" "blake2")))

;; twin-problems on texts of the suite's own: a page whose runnable block is
;; TWIN, beside a fragment of other lines, and READMEs whose Scheme blocks
;; differ from it in one way each. A README's first block opens on line 5.

(define twin '("(define x 2)" "(* x 21)" ";; => 42"))

;; fenced : String (Listof String) -> String
;; A Markdown block of LINES whose fence's info string is INFO.
(define (fenced info lines) (string-append "```" info "\n" (joined lines) "```\n"))

;; org-src : String (Listof String) -> String
;; An Org block of LINES opened by #+begin_src LANGUAGE.
(define (org-src language lines)
  (string-append "#+begin_src " language "\n" (joined lines) "#+end_src\n"))

;; readme-of : String ... -> String
;; A README of a heading and a paragraph, then PARTS.
(define (readme-of . parts) (apply string-append "* Title\n\nProse.\n\n" parts))

(define twin-page
  (string-append "# Page\n\nProse.\n\n" (fenced "scheme run" twin) "\n" (fenced "scheme" '("(display 1)"))))

;; changed-at : String Natural -> String
;; S with its char at I made another.
(define (changed-at s i)
  (string-append (substring s 0 i)
                 (if (char=? (string-ref s i) #\x) "y" "x")
                 (substring s (+ i 1) (string-length s))))

;; one-char-off : (Listof (Listof String))
;; TWIN with one char changed, at the start and at the end of each line in
;; turn, the ;; => line's among them.
(define one-char-off
  (apply append
         (map (lambda (k)
                (let ((line (list-ref twin k)))
                  (map (lambda (i)
                         (let loop ((j 0) (ls twin) (out '()))
                           (if (null? ls)
                               (reverse out)
                               (loop (+ j 1) (cdr ls) (cons (if (= j k) (changed-at line i) (car ls)) out)))))
                       (list 0 (- (string-length line) 1)))))
              '(0 1 2))))

(test-equal "twin-problems: a README whose one Scheme block is a page's runnable block, line for line, has its twin"
  '()
  (twin-problems "R" (readme-of (org-src "scheme" twin)) (list twin-page)))

(test-equal "twin-problems: one char off, at the start or the end of any of its lines, the ;; => line's too, and the block has no twin, named by its line"
  (map (lambda (x) '(("R" 5 no-twin))) one-char-off)
  (map (lambda (lines) (twin-problems "R" (readme-of (org-src "scheme" lines)) (list twin-page)))
       one-char-off))

(test-equal "twin-problems: a twin is all of a runnable block's lines, as written: its body alone, a line added before or after, two lines swapped, each line indented, have none"
  '((("R" 5 no-twin)) (("R" 5 no-twin)) (("R" 5 no-twin)) (("R" 5 no-twin)) (("R" 5 no-twin)))
  (map (lambda (lines) (twin-problems "R" (readme-of (org-src "scheme" lines)) (list twin-page)))
       (list '("(define x 2)" "(* x 21)")
             (cons "" twin)
             (append twin '(""))
             '("(* x 21)" "(define x 2)" ";; => 42")
             (map (lambda (l) (string-append "  " l)) twin))))

(test-equal "twin-problems: a README with no Scheme block is named: prose that says scheme, an sh block, a quote, an example, and an empty README"
  '((("R" no-scheme-block)) (("R" no-scheme-block)))
  (list (twin-problems "R"
                       (readme-of "Some scheme here.\n\n" (org-src "sh" '("ls"))
                                  "#+begin_quote\n(* 2 21)\n#+end_quote\n"
                                  "#+begin_example\n(* 2 21)\n#+end_example\n")
                       (list twin-page))
        (twin-problems "R" "" (list twin-page))))

(test-equal "twin-problems: two Scheme blocks, each held: the second without a twin, the first, and both, each named by its line, in order"
  '((("R" 10 no-twin)) (("R" 5 no-twin)) (("R" 5 no-twin) ("R" 10 no-twin)))
  (list (twin-problems "R" (readme-of (org-src "scheme" twin) (org-src "scheme" '("(* 2 21)")))
                       (list twin-page))
        (twin-problems "R" (readme-of (org-src "scheme" '("(* 2 21)")) "\n\n" (org-src "scheme" twin))
                       (list twin-page))
        (twin-problems "R" (readme-of (org-src "scheme" '("(* 2 21)")) "\n\n" (org-src "scheme" '("1")))
                       (list twin-page))))

(test-equal "twin-problems: the same lines in a block not marked run are no twin: plain scheme, scheme run with another word, scheme example, sh, text, and no language"
  (map (lambda (info) '(("R" 5 no-twin))) '("scheme" "scheme run x" "scheme example" "sh" "text" ""))
  (map (lambda (info)
         (twin-problems "R" (readme-of (org-src "scheme" twin))
                        (list (string-append "# Page\n\n" (fenced info twin)))))
       '("scheme" "scheme run x" "scheme example" "sh" "text" "")))

(test-equal "twin-problems: the twin may be in any page, among other runnable blocks; with no page there is none"
  '(() () (("R" 5 no-twin)))
  (list (twin-problems "R" (readme-of (org-src "scheme" twin))
                       (list "# Other\n" twin-page))
        (twin-problems "R" (readme-of (org-src "scheme" twin))
                       (list (string-append (fenced "scheme run" '("1" ";; => 1")) twin-page)))
        (twin-problems "R" (readme-of (org-src "scheme" twin)) '())))

(test-equal "twin-problems: the twin is found at each place, first, between and last among a page's runnable blocks, and in the first, middle and last of three pages"
  '(() () () () () ())
  (let ((readme (readme-of (org-src "scheme" twin)))
        (mine (string-append (fenced "scheme run" twin) "\n"))
        (other (lambda (k)
                 (string-append (fenced "scheme run" (list (number->string k)
                                                          (string-append ";; => " (number->string k))))
                                "\n")))
        (page (lambda parts (apply string-append "# Page\n\n" parts))))
    (list (twin-problems "R" readme (list (page mine (other 1) (other 2))))
          (twin-problems "R" readme (list (page (other 1) mine (other 2))))
          (twin-problems "R" readme (list (page (other 1) (other 2) mine)))
          (twin-problems "R" readme (list (page mine) (page (other 1)) (page (other 2))))
          (twin-problems "R" readme (list (page (other 1)) (page mine) (page (other 2))))
          (twin-problems "R" readme (list (page (other 1)) (page (other 2)) (page mine))))))

;; nested-blocks : String -> (Listof Natural)
;; The line of each block of the Org text ORG-TEXT that holds a #+begin_
;; line, in any case. org reads no block inside another, so a Scheme block
;; inside a quote would escape every block rule, the twin's among them.
(define (nested-blocks org-text)
  (map block-line
       (filter (lambda (b) (exists (lambda (l) (org-keyword l "#+begin_")) (block-lines b)))
               (car (org org-text)))))

(test-equal "nested-blocks: a quote holding a Scheme block, and an example holding one in capitals, are named by their lines; a quote of prose, and a src block beside a quote, are not"
  '((5) (5) () ())
  (list (nested-blocks (readme-of "#+begin_quote\n" (org-src "scheme" twin) "#+end_quote\n"))
        (nested-blocks (readme-of "#+begin_example\n#+BEGIN_SRC scheme\n(* 2 21)\n#+END_SRC\n#+end_example\n"))
        (nested-blocks (readme-of "#+begin_quote\nA quote of prose.\n#+end_quote\n"))
        (nested-blocks (readme-of (org-src "scheme" twin) "\n#+begin_quote\nProse.\n#+end_quote\n"))))

;; --- whole programs -------------------------------------------------------------------------------

;; first-datum : String -> (U (List Any) 'none 'unreadable)
;; The first datum Chez's read reads from the text, in a list; none when it
;; holds none, unreadable when read raises.
(define (first-datum text)
  (guard (e (#t 'unreadable))
    (let ((d (read (open-string-input-port text))))
      (if (eof-object? d) 'none (list d)))))

;; whole-program? : Block Boolean -> Boolean
;; A Markdown Scheme fragment whose first datum, as Chez's read reads the
;; block's text, is a list headed import: a program a reader saves and runs
;; whole. read skips a #!r6rs and comments before it.
(define (whole-program? b org?)
  (and (not org?)
       (string=? (block-language b) "scheme")
       (eq? (scheme-mark b org?) 'fragment)
       (let ((d (first-datum (joined (block-lines b)))))
         (and (pair? d) (pair? (car d)) (eq? (caar d) 'import)))))

;; text-after : Block (Listof Block) -> (U (Listof String) #f)
;; The lines of the first text block after B among its page's BLOCKS,
;; whatever lies between, when it comes before the next Scheme block; #f
;; when a Scheme block, or the page's end, comes first.
(define (text-after b blocks)
  (let ((rest (memq b blocks)))
    (and rest
         (let loop ((rest (cdr rest)))
           (cond ((null? rest) #f)
                 ((string=? (block-language (car rest)) "text") (block-lines (car rest)))
                 ((string=? (block-language (car rest)) "scheme") #f)
                 (else (loop (cdr rest))))))))

;; guards-unavailable? : Any -> Boolean
;; Whether X holds, at any depth, a guard with a clause whose test is
;; (sodium-library-unavailable? V), V the guard's own variable.
(define (guards-unavailable? x)
  (cond ((pair? x)
         (or (and (eq? (car x) 'guard)
                  (pair? (cdr x)) (list? (cadr x)) (pair? (cadr x)) (symbol? (car (cadr x)))
                  (exists (lambda (clause)
                            (and (pair? clause)
                                 (equal? (car clause)
                                         (list 'sodium-library-unavailable? (car (cadr x))))))
                          (cdr (cadr x))))
             (guards-unavailable? (car x))
             (guards-unavailable? (cdr x))))
        ((vector? x) (guards-unavailable? (vector->list x)))
        (else #f)))

;; refusal-text : String -> String
;; What a guarded program prints when CHEZ_SODIUM_LIBRARY names the file PATH
;; and it is not there: the datum (refused load-failed PATH), as write writes
;; it, and a newline.
(define (refusal-text path)
  (string-append "(refused load-failed " (shown path) ")\n"))

(test-equal "whole-program?: a Markdown fragment whose first datum, as read reads it, is a list headed import: past blanks, a #!r6rs, a line comment, a block comment and a datum comment, in brackets, with a datum after; not one whose import comes later, a quoted import, an imports, unreadable text, a runnable block, an Org block, another language, or an empty block"
  '(#t #t #t #t #t #t #t #t no no no no no no no no no no)
  (let ((b (lambda (lang info lines) (make-block 1 lang info lines #t)))
        (yes-or-no (lambda (x) (if x #t 'no))))
    (list (yes-or-no (whole-program? (b "scheme" '() '("(import (rnrs))" "(display 1)")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("" "  (import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("#!r6rs" "(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '(";; app.sps" "(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("#| app.sps" "|# (import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("#;(display 1)" "(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("[import (rnrs)]")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("#!r6rs ;; x" "" "(import (rnrs)) (display 1)")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("(display 1)" "(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("'(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("(imports (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("(library (x) (export) (import (rnrs)))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("(import (rnrs)")) #f))
          (yes-or-no (whole-program? (b "scheme" '("run") '("(import (rnrs))" ";; => 1")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("(import (rnrs))")) #t))
          (yes-or-no (whole-program? (b "text" '() '("(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "sh" '() '("(import (rnrs))")) #f))
          (yes-or-no (whole-program? (b "scheme" '() '("" "")) #f)))))

(test-equal "text-after: the first text block's lines after it, right after, with prose between, past an sh block or two, the first of two; none when a Scheme block comes first, a runnable one or a fragment, or none follows"
  '(("out 1") ("out 2") ("late") ("two sh") none none ("after fragment") none)
  (let* ((page (markdown (string-append
                          (fenced "scheme" '("(import (rnrs))")) (fenced "text" '("out 1"))
                          (fenced "scheme" '("(import (rnrs))")) "\nIt prints:\n\n" (fenced "text" '("out 2"))
                          (fenced "scheme" '("(import (rnrs))")) (fenced "sh" '("ls")) "\nThen:\n\n"
                          (fenced "text" '("late"))
                          (fenced "scheme" '("(import (rnrs))")) (fenced "sh" '("ls")) (fenced "sh" '("pwd"))
                          (fenced "text" '("two sh")) (fenced "text" '("second"))
                          (fenced "scheme" '("(import (rnrs))")) (fenced "scheme run" '("1" ";; => 1"))
                          (fenced "text" '("after run"))
                          (fenced "scheme" '("(import (rnrs))"))
                          (fenced "scheme" '("(display 1)")) (fenced "text" '("after fragment"))
                          (fenced "scheme" '("(import (rnrs))")) (fenced "sh" '("ls")))))
         (bs (car page)))
    (map (lambda (b) (or (text-after b bs) 'none))
         (filter (lambda (b) (eq? (scheme-mark b #f) 'fragment))
                 (filter (lambda (b) (string=? (block-language b) "scheme")) bs)))))

(test-equal "guards-unavailable?: a guard clause (sodium-library-unavailable? V) on its own variable, at any depth, among other clauses; not one on another variable, another predicate, or the name outside a guard"
  '(yes yes no no no)
  (map (lambda (text) (if (guards-unavailable? (datums text)) 'yes 'no))
       '("(import (rnrs)) (write (guard (e ((sodium-library-unavailable? e) 'no)) 1))"
         "(define (f) (let () (vector (guard (c ((string? c) 1) ((sodium-library-unavailable? c) 2)) 3))))"
         "(guard (e ((sodium-library-unavailable? x) 'no)) 1)"
         "(guard (e ((sodium-failed? e) 'no)) 1)"
         "(list sodium-library-unavailable? (sodium-library-unavailable? e))")))

(test-equal "refusal-text: the datum as write writes it, its path a string with its quotes and backslashes escaped, and a newline"
  '("(refused load-failed \"/a b\")\n" "(refused load-failed \"/a\\\"b\\\\c\")\n")
  (list (refusal-text "/a b") (refusal-text "/a\"b\\c")))

;; --- the private libraries a whole program names ----------------------------------------------

;; elements : Any -> (Listof Any)
;; The elements of a list, and the tail of an improper one as the last.
(define (elements x)
  (cond ((pair? x) (cons (car x) (elements (cdr x))))
        ((null? x) '())
        (else (list x))))

;; private-names : Any -> (Listof (Listof Symbol))
;; The name of each private library X names: each list among X's elements,
;; at any depth, a vector's among them, whose first two elements are
;; chez-sodium and private, as its symbols, a version after them dropped.
;; Never a list's tail, which is no element. However a program reaches the
;; library, by its import form, a second import in its body, an
;; environment or a quoted name, it names it. In the order met, each once.
(define (private-names x)
  (let walk ((x x) (found '()))
    (cond ((vector? x) (fold-left (lambda (acc e) (walk e acc)) found (vector->list x)))
          ((pair? x)
           (let ((found (if (and (pair? (cdr x)) (eq? (car x) 'chez-sodium) (eq? (cadr x) 'private))
                            (let ((name (filter symbol? (elements x))))
                              (if (member name found) found (append found (list name))))
                            found)))
             (fold-left (lambda (acc e) (walk e acc)) found (elements x))))
          (else found))))

(test-equal "private-names: a private library named plainly, with a version, through only, except, prefix, rename, for and library, two in turn, the bare prefix, a second import in the body, an environment, a quoted name and one in a vector, each once in its order; not chez-sodium, chez-sodium-testing, private chez-sodium, chez-sodium privates, private as an identifier, the two symbols quoted apart, a list's tail, or a string"
  '(((chez-sodium private utf8))
    ((chez-sodium private native))
    ((chez-sodium private counters))
    ((chez-sodium private memory))
    ((chez-sodium private open))
    ((chez-sodium private values))
    ((chez-sodium private script))
    ((chez-sodium private interrupt))
    ((chez-sodium private a) (chez-sodium private b))
    ((chez-sodium private))
    ((chez-sodium private utf8))
    ((chez-sodium private native))
    ((chez-sodium private open))
    ((chez-sodium private memory))
    ((chez-sodium private a))
    () () () () () () ())
  (map (lambda (text) (private-names (datums text)))
       '("(import (rnrs) (chez-sodium private utf8))"
         "(import (chez-sodium private native (1 0)) (chez-sodium))"
         "(import (only (chez-sodium private counters) native-counts))"
         "(import (except (chez-sodium private memory) x))"
         "(import (prefix (chez-sodium private open) o:))"
         "(import (rename (chez-sodium private values) (a b)))"
         "(import (for (chez-sodium private script) run expand))"
         "(import (library (chez-sodium private interrupt)))"
         "(import (prefix (only (chez-sodium private a) x) p:) (rnrs) (for (except (chez-sodium private b) y) run))"
         "(import (chez-sodium private))"
         "(import (rnrs) (only (chezscheme) import)) (display 1) (import (chez-sodium private utf8))"
         "(import (rnrs) (rnrs eval)) (eval 'x (environment '(rnrs) '(chez-sodium private native)))"
         "(import (rnrs)) (define lib '(chez-sodium private open))"
         "(import (rnrs)) (define libs '#((chez-sodium private memory)))"
         "(import (chez-sodium private a)) (import (chez-sodium private a))"
         "(import (rnrs) (rnrs eval) (chez-sodium))"
         "(import (chez-sodium-testing))"
         "(import (private chez-sodium) (chez-sodium privates x))"
         "(import (only (chez-sodium) private))"
         "(import (rnrs)) (f 'chez-sodium 'private)"
         "(import (rnrs)) (g chez-sodium private x)"
         "(import (rnrs)) (display \"(chez-sodium private utf8)\")")))

;; --- pipe tables and their cells ------------------------------------------------------------------

;; pipe-cells : String -> (Listof String)
;; The cells of a table line: the text between its |s, each trimmed, a |
;; after a backslash kept as |, the empty text before a leading | and after
;; a trailing one dropped.
(define (pipe-cells line)
  (let* ((s (trim line))
         (pieces (let loop ((cs (string->list s)) (piece '()) (out '()))
                   (cond ((null? cs) (reverse (cons (list->string (reverse piece)) out)))
                         ((and (char=? (car cs) #\\) (pair? (cdr cs)) (char=? (cadr cs) #\|))
                          (loop (cddr cs) (cons #\| piece) out))
                         ((char=? (car cs) #\|)
                          (loop (cdr cs) '() (cons (list->string (reverse piece)) out)))
                         (else (loop (cdr cs) (cons (car cs) piece) out)))))
         (pieces (if (starts? s "|") (cdr pieces) pieces))
         (pieces (if (and (pair? pieces) (ends? s "|") (not (ends? s "\\|")))
                     (reverse (cdr (reverse pieces)))
                     pieces)))
    (map trim pieces)))

;; delimiter-row? : (Listof String) -> Boolean
;; Cells each of one or more -, with a : at either end or both.
(define (delimiter-row? cells)
  (and (pair? cells)
       (for-all (lambda (c)
                  (let* ((c (if (starts? c ":") (substring c 1 (string-length c)) c))
                         (c (if (ends? c ":") (substring c 0 (- (string-length c) 1)) c)))
                    (and (> (string-length c) 0)
                         (for-all (lambda (ch) (char=? ch #\-)) (string->list c)))))
                cells)))

;; table-line? : String -> Boolean
(define (table-line? line)
  (let ((indent (run line 0 #\space)))
    (and (<= indent 3) (< indent (string-length line)) (char=? (string-ref line indent) #\|))))

;; tables : (Listof String) -> (Listof (List Natural (Listof String) (Listof (Listof String))))
;; Each pipe table of the prose: the number of its first line, its header's
;; cells, and each later row's cells, in order. A run of table lines whose
;; second is no delimiter row is no table.
(define (tables prose)
  (let loop ((ls prose) (n 1) (out '()))
    (cond ((null? ls) (reverse out))
          ((table-line? (car ls))
           (let collect ((rest ls) (k n) (taken '()))
             (if (and (pair? rest) (table-line? (car rest)))
                 (collect (cdr rest) (+ k 1) (cons (car rest) taken))
                 (let ((lines (reverse taken)))
                   (loop rest k
                         (if (and (pair? (cdr lines)) (delimiter-row? (pipe-cells (cadr lines))))
                             (cons (list n (pipe-cells (car lines)) (map pipe-cells (cddr lines))) out)
                             out))))))
          (else (loop (cdr ls) (+ n 1) out)))))

;; cell-span : String -> (U String (List 'not-one-code-span String))
;; The text of a cell that is one code span, whole; else why not, with it.
(define (cell-span cell)
  (let ((ranges (code-ranges cell)))
    (if (and (= (length ranges) 1) (= (caar ranges) 0) (= (cdar ranges) (string-length cell)))
        (car (code-spans cell))
        (list 'not-one-code-span cell))))

;; spans-at : String -> (Listof (List Natural Natural String))
;; Each code span of the text: where it begins, where it ends, its text.
(define (spans-at text)
  (map (lambda (r s) (list (car r) (cdr r) s)) (code-ranges text) (code-spans text)))

;; alternative-word : String (List Natural Natural String) -> (U String #f)
;; M, when the span of TEXT is written (`ALT` on M), M a word; else #f.
(define (alternative-word text span)
  (let ((s (car span)) (e (cadr span)) (n (string-length text)))
    (and (> s 0) (char=? (string-ref text (- s 1)) #\()
         (starts? (substring text e n) " on ")
         (let ((close (search text ")" (+ e 4))))
           (and close
                (let ((w (substring text (+ e 4) close)))
                  (and (> (string-length w) 0) (not (exists blank? (string->list w))) w)))))))

;; spans-on-at : String String -> (Listof (List Natural String))
;; The code spans of CELL on the machine MACHINE: each that is no
;; alternative, in order, in its place an alternative for MACHINE written
;; right after it, when there is one; each with where its own span begins.
(define (spans-on-at cell machine)
  (let loop ((rest (spans-at cell)) (out '()))
    (cond ((null? rest) (reverse out))
          ((alternative-word cell (car rest)) (loop (cdr rest) out))
          (else
           (let* ((alternatives (let take ((r (cdr rest)) (acc '()))
                                  (if (and (pair? r) (alternative-word cell (car r)))
                                      (take (cdr r) (cons (car r) acc))
                                      (reverse acc))))
                  (mine (find (lambda (a) (string=? (alternative-word cell a) machine)) alternatives)))
             (loop (cdr rest) (cons (list (car (car rest)) (caddr (or mine (car rest)))) out)))))))

;; looks-in : String String -> (U (Listof String) (List 'unreadable String))
;; The paths a where-it-looks cell names on MACHINE, in order. With no " in "
;; outside its code spans: none for no span, the one for one, else
;; unreadable. With one, the spans before it are the file names and those
;; after it the directories, and the paths are, directory by directory, each
;; file in order, DIR/FILE; no file or no directory is unreadable.
(define (looks-in cell machine)
  (let* ((spans (spans-on-at cell machine))
         (in (search (without-code cell) " in " 0)))
    (cond ((not in)
           (cond ((null? spans) '())
                 ((null? (cdr spans)) (map cadr spans))
                 (else (list 'unreadable cell))))
          (else
           (let ((files (map cadr (filter (lambda (s) (< (car s) in)) spans)))
                 (dirs (map cadr (filter (lambda (s) (> (car s) in)) spans))))
             (if (or (null? files) (null? dirs))
                 (list 'unreadable cell)
                 (apply append
                        (map (lambda (dir) (map (lambda (file) (string-append dir "/" file)) files))
                             dirs))))))))

;; spans-before : String String -> (Listof String)
;; The text of each code span of TEXT that AFTER follows, a line's end in
;; TEXT read as a space.
(define (spans-before text after)
  (let ((flat (list->string (map (lambda (c) (if (char=? c #\newline) #\space c)) (string->list text)))))
    (map caddr (filter (lambda (s) (starts? (substring flat (cadr s) (string-length flat)) after))
                       (spans-at flat)))))

;; distinct : (Listof String) -> (Listof String)
;; Each string once, at its first place.
(define (distinct xs)
  (let loop ((rest xs) (out '()))
    (cond ((null? rest) (reverse out))
          ((member (car rest) out) (loop (cdr rest) out))
          (else (loop (cdr rest) (cons (car rest) out))))))

;; stand-in-getenv : String -> (U String #f)
;; An environment in which GUIX_ENVIRONMENT, GUIX_PROFILE and HOME each name
;; a directory of its own, /@NAME, and nothing else is set.
(define (stand-in-getenv name)
  (and (member name '("GUIX_ENVIRONMENT" "GUIX_PROFILE" "HOME")) (string-append "/@" name)))

;; as-written : String -> String
;; A path under a stand-in's directory as the page writes it: /@HOME as ~,
;; any other /@NAME as $NAME; any other path as it is.
(define (as-written path)
  (let* ((slash (and (starts? path "/@") (or (search path "/" 2) (string-length path))))
         (name (and slash (substring path 2 slash))))
    (if (and name (not (string=? name "")))
        (string-append (if (string=? name "HOME") "~" (string-append "$" name))
                       (substring path slash (string-length path)))
        path)))

;; label-names? : String (List (U 'holds 'begins) String) -> Boolean
;; Whether a row's first cell names its world by RULE: (holds S), S
;; anywhere in it; (begins S), S at its start.
(define (label-names? cell rule)
  (if (eq? (car rule) 'begins)
      (starts? cell (cadr rule))
      (and (search cell (cadr rule) 0) #t)))

(define sample-tables
  '("Prose."
    "| A | B |"
    "|---|:-:|"
    "| `x` | y \\| z |"
    "|  | last |"
    ""
    "| not | a table |"
    "| no | delimiter |"
    ""
    "   | C |"
    "   |---|"
    "    | four spaces, no table line |"))

(test-equal "tables: each run of | lines whose second is a delimiter row, by its first line, its header and its rows; a run with no delimiter row is none, and four spaces end one"
  '((2 ("A" "B") (("`x`" "y | z") ("" "last")))
    (10 ("C") ()))
  (tables sample-tables))

(test-equal "pipe-cells: no outer |s, outer |s, a lone |, an escaped | at the end, and an empty cell"
  '(("a" "b") ("a") () ("a |") ("a" "" "b"))
  (map pipe-cells '("a | b" "| a |" "|" "| a \\|" "| a || b |")))

(test-equal "delimiter-row?: -, :-, -:, :-: cells; not an empty cell, a :, text, or no cell"
  '(yes no no no no)
  (map (lambda (cells) (if (delimiter-row? cells) 'yes 'no))
       '(("---" ":--" "--:" ":-:") ("---" "") (":") ("-a-") ())))

(test-equal "cell-span: a cell that is one code span, whole, single or double backticks; text beside it, two spans, none, and an empty cell are not"
  '("below-floor" "a ` b" (not-one-code-span "`a` b") (not-one-code-span "`a` `b`")
    (not-one-code-span "a") (not-one-code-span ""))
  (map cell-span '("`below-floor`" "``a ` b``" "`a` b" "`a` `b`" "a" "")))

(test-equal "looks-in: each file in each directory, directory by directory, the files in order; an alternative (`ALT` on M) in its span's place on M, in a file's or a directory's, first, between or last, and nothing elsewhere; one for another machine ignored; one path alone; none; and no file, no directory, or more spans with no in, unreadable"
  '(("/a/f" "/a/g" "/b/f" "/b/g" "/c/f" "/c/g")
    ("/a/f" "/a/g" "/b/f" "/b/g" "/c/f" "/c/g")
    ("/x/f" "/x/g" "/b/f" "/b/g" "/c/f" "/c/g")
    ("/a/f" "/a/g" "/b/f" "/b/g")
    ("/a/f" "/a/g" "/y/f" "/y/g" "/c/f" "/c/g")
    ("/a/f" "/a/g" "/b/f" "/b/g" "/z/f" "/z/g")
    ("/a/f" "/a/g" "/b/f" "/b/g" "/c/f" "/c/g")
    ("/a/h" "/a/g" "/b/h" "/b/g")
    ("/a/f")
    ("/p/lib.dylib")
    ()
    (unreadable "`f` or `/a`")
    (unreadable "`f`, `g` in")
    ("/a/f")
    ("/a/f" "/x/f"))
  (list (looks-in "`f`, then `g` in `/a`, `/b`, then `/c`" "x86_64")
        (looks-in "`f`, then `g` in `/a`, `/b`, then `/c`" "arm64")
        (looks-in "`f`, then `g` in `/a` (`/x` on arm64), `/b`, then `/c`" "arm64")
        (looks-in "`f`, then `g` in `/a` (`/x` on arm64), then `/b`" "x86_64")
        (looks-in "`f`, then `g` in `/a`, `/b` (`/y` on arm64), then `/c`" "arm64")
        (looks-in "`f`, then `g` in `/a`, `/b`, then `/c` (`/z` on arm64)" "arm64")
        (looks-in "`f`, then `g` in `/a`, `/b` (`/y` on riscv64), then `/c`" "arm64")
        (looks-in "`f` (`h` on arm64), then `g` in `/a`, then `/b`" "arm64")
        (looks-in "`f` in `/a`" "x86_64")
        (looks-in "Apple's `/p/lib.dylib`" "arm64")
        (looks-in "nothing" "x86_64")
        (looks-in "`f` or `/a`" "x86_64")
        (looks-in "`f`, `g` in" "x86_64")
        (looks-in "`f` in `/a` (`/b` on arm64)" "x86_64")
        (looks-in "`f` in `/a`, `/x` on arm64)" "x86_64")))

(test-equal "looks-in: the word in inside a code span is no split"
  '(unreadable "`a in b`, `c`")
  (looks-in "`a in b`, `c`" "x86_64"))

(test-equal "spans-before: each code span that the text follows, across a line's end; not one another text follows"
  '("override" "z")
  (spans-before "and `override` for\n`CHEZ_SODIUM_LIBRARY`, `x` for `Y`, `z` for `CHEZ_SODIUM_LIBRARY`"
                " for `CHEZ_SODIUM_LIBRARY`"))

(test-equal "distinct: each once, at its first place"
  '("a" "b" "c")
  (distinct '("a" "b" "a" "c" "b")))

(test-equal "label-names?: holds finds its word at the cell's start, middle and end, and the whole cell; begins only at the start; neither in another case, nor in an empty cell"
  '(yes yes yes yes yes no no no no no)
  (map (lambda (c) (if (label-names? (car c) (cadr c)) 'yes 'no))
       '(("Guix's C library" (holds "Guix")) ("Linux, on Guix's C" (holds "Guix")) ("Linux on Guix" (holds "Guix"))
         ("Mac" (holds "Mac")) ("Other Linux systems" (begins "Other Linux"))
         ("Linux, other" (begins "Other Linux")) ("Not any other" (begins "Any other"))
         ("macOS" (holds "Mac")) ("" (holds "Mac")) ("Not Other Linux" (begins "Other Linux")))))

(test-equal "as-written: a stand-in's directory as $NAME, HOME's as ~, alone or before more; any other path unchanged"
  '("$GUIX_PROFILE/lib/x" "~/.guix-home/profile/lib/x" "~" "/usr/lib/x" "/@")
  (map as-written '("/@GUIX_PROFILE/lib/x" "/@HOME/.guix-home/profile/lib/x" "/@HOME" "/usr/lib/x" "/@")))

;; --- the variable's name, and its value ------------------------------------------------------------

;; word-char? : Char -> Boolean
(define (word-char? c)
  (or (and (char<=? #\a c) (char<=? c #\z)) (and (char<=? #\A c) (char<=? c #\Z)) (digit? c) (char=? c #\_)))

;; chez-words : String -> (Listof String)
;; Each word of the text, a run of letters, digits and _, that holds CHEZ_,
;; in order.
(define (chez-words s)
  (let ((n (string-length s)))
    (let loop ((i 0) (out '()))
      (cond ((>= i n) (reverse out))
            ((word-char? (string-ref s i))
             (let* ((j (let end ((j i)) (if (and (< j n) (word-char? (string-ref s j))) (end (+ j 1)) j)))
                    (w (substring s i j)))
               (loop j (if (search w "CHEZ_" 0) (cons w out) out))))
            (else (loop (+ i 1) out))))))

;; assignment-values : String -> (Listof String)
;; What follows each CHEZ_SODIUM_LIBRARY= of the line that sets the
;; variable, up to a blank or the line's end: one at the line's start or
;; after a blank, as export X=, env X= and X=... before a command are. One
;; after any other char, as Org's verbatim =CHEZ_SODIUM_LIBRARY= is, sets
;; nothing.
(define (assignment-values line)
  (let ((pat "CHEZ_SODIUM_LIBRARY="))
    (let loop ((i 0) (out '()))
      (let ((j (search line pat i)))
        (if (not j)
            (reverse out)
            (let* ((start (+ j (string-length pat)))
                   (end (let e ((k start))
                          (if (and (< k (string-length line)) (not (blank? (string-ref line k)))) (e (+ k 1)) k))))
              (loop end (if (or (= j 0) (blank? (string-ref line (- j 1))))
                            (cons (substring line start end) out)
                            out))))))))

(test-equal "chez-words: each word that holds CHEZ_, at the text's start and end, after $, = or a backtick, before =, ' or a backtick, a letter before it or after; not CHEZ alone, CHEZSCHEME, or chez_"
  '("CHEZ_A" "CHEZ_SODIUM_LIBRARY" "CHEZ_B_2" "CHEZ_C" "XCHEZ_D" "CHEZ_Ee" "CHEZ_F")
  (chez-words "CHEZ_A, $CHEZ_SODIUM_LIBRARY=/x =CHEZ_B_2= `CHEZ_C`'s XCHEZ_D CHEZ_Ee CHEZ CHEZSCHEME chez_x CHEZ_F"))

(test-equal "chez-words: a word that holds CHEZ_, set at each place in a text, is found there alone"
  (let loop ((i 0) (out '())) (if (> i 6) out (loop (+ i 1) (cons '("CHEZ_Q") out))))
  (let ((s "a-b, c"))
    (let loop ((i 0) (out '()))
      (if (> i (string-length s))
          out
          (loop (+ i 1)
                (cons (chez-words (string-append (substring s 0 i) " CHEZ_Q " (substring s i (string-length s))))
                      out))))))

(test-equal "assignment-values: each value up to a blank, after export, indented, an empty one, two on a line, at the line's start before a command, past blanks or a tab, after env; none after =, as Org's verbatim is, a backtick, a $, a letter or a quote, nor without its ="
  '(("/a/b") ("rel") ("") ("/a;" "b") ("/x") ("lib.so") ("t") ("/e") () () () () () ())
  (map assignment-values
       '("export CHEZ_SODIUM_LIBRARY=/a/b" "  export CHEZ_SODIUM_LIBRARY=rel x" "export CHEZ_SODIUM_LIBRARY="
         "export CHEZ_SODIUM_LIBRARY=/a; export CHEZ_SODIUM_LIBRARY=b"
         "CHEZ_SODIUM_LIBRARY=/x scheme --program app.sps" "  CHEZ_SODIUM_LIBRARY=lib.so scheme"
         "\tCHEZ_SODIUM_LIBRARY=t" "env CHEZ_SODIUM_LIBRARY=/e scheme"
         "=CHEZ_SODIUM_LIBRARY= names it" "`CHEZ_SODIUM_LIBRARY=x`" "$CHEZ_SODIUM_LIBRARY=x"
         "XCHEZ_SODIUM_LIBRARY=x" "'CHEZ_SODIUM_LIBRARY=x'" "set CHEZ_SODIUM_LIBRARY x")))

(test-equal "assignment-values: one after a blank, set at each place in a text, is found there alone; one after =, at each place, is not"
  (let loop ((i 0) (out '())) (if (> i 5) out (loop (+ i 1) (cons '(("v") ()) out))))
  (let ((s "a=b c"))
    (let loop ((i 0) (out '()))
      (if (> i (string-length s))
          out
          (loop (+ i 1)
                (cons (list (assignment-values (string-append (substring s 0 i) " CHEZ_SODIUM_LIBRARY=v "
                                                              (substring s i (string-length s))))
                            (assignment-values (string-append (substring s 0 i) "=CHEZ_SODIUM_LIBRARY=v "
                                                              (substring s i (string-length s)))))
                      out))))))

;; --- the pages ----------------------------------------------------------------------------------

;; read-page : String -> (U String (List 'unreadable String))
(define (read-page path) (guard (e (#t (list 'unreadable (describe e)))) (slurp path)))

;; docs-pages : (Listof String)
;; docs/*.md, sorted.
(define docs-pages
  (guard (e (#t (list "docs/unreadable")))
    (map (lambda (f) (string-append "docs/" f))
         (list-sort string<? (filter (lambda (f) (ends? f ".md")) (directory-list "docs"))))))

(define pages (cons "README.org" docs-pages))

(define (org-page? p) (ends? p ".org"))

;; page-texts : (Listof (Pair String (U String (List 'unreadable String))))
(define page-texts (map (lambda (p) (cons p (read-page p))) pages))

(define (text-of p) (cdr (assoc p page-texts)))

;; parsed : String -> (U (List Blocks Prose Headings) #f)
;; A page's reading: Markdown's three lists; Org's two, and no headings.
(define (parsed p)
  (let ((t (text-of p)))
    (and (string? t)
         (if (org-page? p)
             (let ((r (org t))) (list (car r) (cadr r) '()))
             (markdown t)))))

(define (blocks-of p) (let ((r (parsed p))) (if r (car r) '())))
(define (prose-of p) (let ((r (parsed p))) (if r (cadr r) '())))

;; anchors-of : String -> (U (Listof String) #f)
(define (anchors-of p)
  (let ((r (and (assoc p page-texts) (parsed p))))
    (and r (not (org-page? p)) (anchors (map cdr (caddr r))))))

;; checkout-exists? : String -> Boolean
(define (checkout-exists? p) (file-exists? p))

(test-equal "every page is read: README.org and the pages of docs/, and docs/ has the reference and the finding page"
  '(() #t #t)
  (list (map car (filter (lambda (p) (not (string? (cdr p)))) page-texts))
        (and (member "docs/reference.md" pages) #t)
        (and (member "docs/finding-libsodium.md" pages) #t)))

;; --- the blocks -----------------------------------------------------------------------------------

(define allowed-languages '("scheme" "sh" "text"))
(define (allowed-language? b org?)
  (or (member (block-language b) allowed-languages)
      (and org? (string=? (block-language b) "#quote"))))

(test-equal "every block names its language, scheme, sh or text (Org: or a quote), and is closed, by page and line"
  '()
  (apply append
         (map (lambda (p)
                (apply append
                       (map (lambda (b)
                              (append (if (allowed-language? b (org-page? p)) '()
                                          (list (list p (block-line b) 'language (block-language b))))
                                      (if (block-closed? b) '() (list (list p (block-line b) 'unclosed)))))
                            (blocks-of p))))
              pages)))

(define (scheme-blocks p)
  (filter (lambda (b) (string=? (block-language b) "scheme")) (blocks-of p)))

(test-equal "every Scheme block is a fragment or runnable, by page and line"
  '()
  (apply append
         (map (lambda (p)
                (map (lambda (b) (list p (block-line b) 'unknown-mark (block-info b)))
                     (filter (lambda (b) (eq? (scheme-mark b (org-page? p)) 'unknown))
                             (scheme-blocks p))))
              pages)))

(test-equal "no Markdown fragment holds a \";; =>\" line, the mark of a block the tests run, by page and line"
  '()
  (apply append
         (map (lambda (p)
                (map (lambda (b) (list p (block-line b) 'unrun-result))
                     (filter (lambda (b)
                               (and (not (org-page? p))
                                    (eq? (scheme-mark b #f) 'fragment)
                                    (exists (lambda (l) (starts? (trim l) ";; =>")) (block-lines b))))
                             (scheme-blocks p))))
              pages)))

(test-equal "every fragment's text is data Chez reads, and holds a datum, by page and line"
  '()
  (apply append
         (map (lambda (p)
                (map (lambda (b) (list p (block-line b) 'fragment-unreadable))
                     (filter (lambda (b)
                               (and (eq? (scheme-mark b (org-page? p)) 'fragment)
                                    (let ((d (datums (joined (block-lines b)))))
                                      (or (equal? d '(unreadable)) (null? d)))))
                             (scheme-blocks p))))
              pages)))

;; --- the runnable examples ------------------------------------------------------------------------

(define run-env (guard (e (#t #f)) (environment '(rnrs) '(chez-sodium))))

(define zero-counts '((block . 0)))

;; each-in-order : (A -> B) (Listof A) -> (Listof B)
;; F applied to each item, first to last, and the answers in that order. An
;; example's run has effects, so it never goes through map, which calls its
;; procedure in no fixed order.
(define (each-in-order f items)
  (let loop ((rest items) (out '()))
    (if (null? rest)
        (reverse out)
        (let ((answer (f (car rest))))
          (loop (cdr rest) (cons answer out))))))

;; run-counted : (Listof String) (U Environment #f) -> (List Any Any)
;; What check-run says of the lines in ENV, and the native counts when it was
;; done; no-environment for #f.
(define (run-counted lines env)
  (let* ((result (if env (check-run lines env) '(bad no-environment)))
         (counts (native-counts)))
    (list result counts)))

;; A body that makes a native block and does not free it, and one that does.
(define leak-env (environment '(rnrs) '(chez-sodium private counters)))

(test-equal "run-counted: a body that leaves a native block live is seen in the counts, and a body that frees what it made is not; the counts after are as they were, so the rows below see their own"
  '((ok ((block . 1))) (ok ((block . 0))) ((block . 0)))
  (let* ((leaked (run-counted '("(count-up! 'block)" "1" ";; => 1") leak-env))
         (freed (begin (count-down! 'block)
                       (run-counted '("(count-up! 'block)" "(count-down! 'block)" "1" ";; => 1") leak-env))))
    (list leaked freed (native-counts))))

(test-equal "the runnable environment is (rnrs) and (chez-sodium): a body may use random-bytes and u8-list->bytevector; it may not use bytevector, which (rnrs) has not, nor an import form, nor a name of (chez-sodium private ...)"
  '(ok ok (wrong-result 1 (raised #t)) (wrong-result 1 (raised #t)) (wrong-result 1 (raised #t)))
  (map (lambda (lines)
         (let ((r (check-run lines run-env)))
           (if (and (pair? r) (eq? (car r) 'wrong-result) (pair? (caddr r)) (eq? (car (caddr r)) 'raised))
               (list 'wrong-result (cadr r) (list 'raised #t))
               r)))
       '(("(bytevector-length (random-bytes 3))" ";; => 3")
         ("(bytevector-u8-ref (u8-list->bytevector '(7)) 0)" ";; => 7")
         ("(bytevector 1)" ";; => 1")
         ("(import (rnrs))" "1" ";; => 1")
         ("(native-counts)" ";; => 1"))))

;; runs : (Listof (List String Natural Any Any))
;; Each runnable block of every Markdown page: its page, its line, what
;; check-run said, and the native counts when it was done.
(define runs
  (apply append
         (each-in-order
          (lambda (p)
            (each-in-order
             (lambda (b)
               (let ((counted (run-counted (block-lines b) run-env)))
                 (list p (block-line b) (car counted) (cadr counted))))
             (filter (lambda (b) (eq? (scheme-mark b (org-page? p)) 'run))
                     (scheme-blocks p))))
          pages)))

(test-equal "the docs have runnable examples at all"
  'some
  (if (null? runs) 'none 'some))

(for-each
 (lambda (r)
   (test-equal (string-append (car r) ":" (number->string (cadr r))
                              ": the runnable example gives the result it states")
     'ok
     (caddr r))
   (test-equal (string-append (car r) ":" (number->string (cadr r))
                              ": it leaves no native block live")
     zero-counts
     (cadddr r)))
 runs)

;; --- the README's example, through its twin ---------------------------------------------------------

;; text-or-empty : String -> String
(define (text-or-empty p) (let ((t (text-of p))) (if (string? t) t "")))

(test-equal "README.org holds a Scheme block, and each is, line for line, all of a runnable block of a page of docs/: the blocks that are not, by line"
  '()
  (twin-problems "README.org" (text-or-empty "README.org") (map text-or-empty docs-pages)))

(test-equal "README.org holds no block inside another, where a Scheme block would escape the block rules: the outer blocks' lines"
  '()
  (nested-blocks (text-or-empty "README.org")))

;; --- the links --------------------------------------------------------------------------------------

;; links-of : String -> (Listof String)
(define (links-of p)
  (if (org-page? p) (org-links (prose-of p)) (markdown-links (prose-of p))))

(test-equal "every relative link resolves to a file or directory of the checkout, its anchor to a heading, none into .plans/, by page and target"
  '()
  (apply append
         (map (lambda (p)
                (apply append
                       (map (lambda (t)
                              (let ((why (link-problem p t (org-page? p) checkout-exists? anchors-of)))
                                (if why (list (list p t why)) '())))
                            (links-of p))))
              pages)))

;; every file a page links, resolved from the root
(define (linked-files p)
  (apply append
         (map (lambda (t)
                (let ((parts (link-parts t (org-page? p))))
                  (if (and parts (not (eq? (car parts) 'own-page)))
                      (let ((path (resolve (dir-of p) (car parts)))) (if path (list path) '()))
                      '())))
              (links-of p))))

(test-equal "README.org links every page of docs/: the pages it leaves out"
  '()
  (filter (lambda (d) (not (member d (linked-files "README.org")))) docs-pages))

;; --- the headings -------------------------------------------------------------------------------------

(test-equal "every page of docs/ has one level-1 heading, and it is the page's first line: the others, by page and the lines of their level-1 headings"
  '()
  (apply append
         (map (lambda (p)
                (let ((lines (h1-lines (prose-of p))))
                  (if (equal? lines '(1)) '() (list (list p lines)))))
              docs-pages)))

;; --- the prose ----------------------------------------------------------------------------------------

(test-equal "no page says a banned phrase, by page"
  '()
  (apply append
         (map (lambda (p)
                (let ((found (forbidden (let ((t (text-of p))) (if (string? t) t "")))))
                  (if (null? found) '() (list (cons p found)))))
              pages)))

(define export-strings
  (guard (e (#t '("unreadable")))
    (let ((data (call-with-port
                 (open-file-input-port "src/chez-sodium.sls" (file-options) (buffer-mode block)
                                       (make-transcoder (utf-8-codec)))
                 read)))
      (map symbol->string (cdr (find (lambda (c) (and (pair? c) (eq? (car c) 'export))) (cddr data)))))))

;; prose-spans : String -> (Listof String)
;; The code spans of a page's prose: Org's =x= and ~x~ for an Org page, Markdown's
;; `x` for any other.
(define (prose-spans p)
  (if (org-page? p)
      (apply append (map org-spans (prose-of p)))
      (code-spans (joined (prose-of p)))))

(test-equal "every code span of the prose that is one name of a prefix of the library is an export of (chez-sodium), by page: README.org's Org spans =x= and ~x~ too"
  '()
  (apply append
         (map (lambda (p)
                (let ((bad (unknown-names (prose-spans p) export-strings)))
                  (map (lambda (n) (list p n)) bad)))
              pages)))

(test-equal "every symbol of a Markdown Scheme fragment's data, quoted ones too, that is one name of a prefix of the library is an export of (chez-sodium), by page, line and name"
  '()
  (apply append
         (map (lambda (p)
                (apply append
                       (map (lambda (b)
                              (map (lambda (n) (list p (block-line b) n))
                                   (unknown-names (datum-symbols (datums (joined (block-lines b))))
                                                  export-strings)))
                            (filter (lambda (b) (eq? (scheme-mark b #f) 'fragment))
                                    (if (org-page? p) '() (scheme-blocks p))))))
              pages)))

;; --- the variable's name, and its value, on the pages ----------------------------------------------

;; page-lines : String -> (Listof (Pair Natural String))
;; Every line of the page, in a block or not, with its number.
(define (page-lines p) (numbered (text-lines (text-or-empty p))))

(test-equal "the pages name CHEZ_SODIUM_LIBRARY, and set it: the rules below hold words that are there"
  '(some some)
  (let ((all (apply append (map page-lines pages))))
    (list (if (exists (lambda (l) (pair? (chez-words (cdr l)))) all) 'some 'none)
          (if (exists (lambda (l) (pair? (assignment-values (cdr l)))) all) 'some 'none))))

(test-equal "every word of a page that holds CHEZ_, in a block or not, is CHEZ_SODIUM_LIBRARY: the others, by page and line"
  '()
  (apply append
         (map (lambda (p)
                (apply append
                       (map (lambda (l)
                              (map (lambda (w) (list p (car l) w))
                                   (filter (lambda (w) (not (string=? w "CHEZ_SODIUM_LIBRARY")))
                                           (chez-words (cdr l)))))
                            (page-lines p))))
              pages)))

(test-equal "every CHEZ_SODIUM_LIBRARY= of a page that sets it, at a line's start or after a blank, in a block or not, gives it a value that begins with /: the others, by page and line"
  '()
  (apply append
         (map (lambda (p)
                (apply append
                       (map (lambda (l)
                              (map (lambda (v) (list p (car l) v))
                                   (filter (lambda (v) (not (starts? v "/"))) (assignment-values (cdr l)))))
                            (page-lines p))))
              pages)))

;; --- finding-libsodium.md's tables, held to the code --------------------------------------------------

(define finding-page "docs/finding-libsodium.md")

;; The page's prose, none when the page is not among the pages read, so
;; each row below fails by its name.
(define finding-prose (guard (e (#t '())) (prose-of finding-page)))

(define finding-tables (tables finding-prose))

;; table-headed : (Listof Table) String -> (U (List Natural (Listof String) (Listof (Listof String))) (List 'tables Natural))
;; The one table of TABLES whose header's first cell is HEAD; else how many
;; there are.
(define (table-headed tables head)
  (let ((found (filter (lambda (t) (and (pair? (cadr t)) (string=? (car (cadr t)) head))) tables)))
    (if (= (length found) 1) (car found) (list 'tables (length found)))))

;; rows-of : (U Table (List 'tables Natural)) -> (U (Listof (Listof String)) (List 'tables Natural))
(define (rows-of t) (if (symbol? (car t)) t (caddr t)))

;; no-table? : Any -> Boolean
;; Whether ROWS is table-headed's answer that no one table has its header.
(define (no-table? rows) (and (pair? rows) (eq? (car rows) 'tables)))

(define library-reasons
  (guard (e (#t (list 'raised (describe e))))
    (map symbol->string sodium-library-unavailable-reasons)))

;; reasons-column : (Listof Table) -> (U (Listof (U String Any)) (List 'tables Natural))
;; The first column of the one table headed Reason, each cell one code span's
;; text; else why not.
(define (reasons-column tables)
  (let ((rows (rows-of (table-headed tables "Reason"))))
    (if (no-table? rows)
        rows
        (map (lambda (row) (if (pair? row) (cell-span (car row)) (list 'no-cell row))) rows))))

(test-equal "reasons-column: the first column of the one table headed Reason, each cell's code span; a cell that is no one span, a second table headed Reason and none are named"
  '(("a" "b") ("a" (not-one-code-span "b `c`")) (tables 2) (tables 0))
  (let ((table (lambda (head . cells)
                 (append (list "Prose." (string-append "| " head " | Meaning |") "|---|---|")
                         (map (lambda (c) (string-append "| " c " | x |")) cells)
                         (list "")))))
    (list (reasons-column (tables (table "Reason" "`a`" "`b`")))
          (reasons-column (tables (table "Reason" "`a`" "b `c`")))
          (reasons-column (tables (append (table "Reason" "`a`") (table "Reason" "`b`"))))
          (reasons-column (tables (table "System" "`a`"))))))

(test-equal "finding-libsodium.md: the reasons table's first column is the library's refusal reasons, in its order, each cell one code span"
  library-reasons
  (reasons-column finding-tables))

;; discovery-worlds : (Listof (List String (U 'guix 'fhs #f) (Listof (Pair Symbol String))
;;                                   (List (U 'holds 'begins) String)))
;; Discovery's worlds, in the table's order: each one's name, the world
;; libsodium-candidates takes, the machine types it is read on, each with
;; the word a row's (`ALT` on WORD) names it by, and how its row's first
;; cell names it, as label-names? reads a rule.
(define discovery-worlds
  '(("Guix" guix ((ta6le . "x86_64") (tarm64le . "arm64")) (holds "Guix"))
    ("other Linux" fhs ((ta6le . "x86_64") (tarm64le . "arm64")) (begins "Other Linux"))))

;; world-indices : (Listof Natural)
;; Each world's place in the table, from 0.
(define world-indices
  (let loop ((k (- (length discovery-worlds) 1)) (out '())) (if (< k 0) out (loop (- k 1) (cons k out)))))

;; discovery-says : (U 'guix 'fhs #f) Symbol -> (U (List (Listof String) (Listof String)) (List 'raised String))
;; Discovery's candidates for WORLD on MACHINE-TYPE, with the stand-in
;; environment: their paths as the page writes them, and their sources,
;; each once, in order.
(define (discovery-says world machine-type)
  (guard (e (#t (list 'raised (describe e))))
    (let ((cs (libsodium-candidates world machine-type stand-in-getenv)))
      (list (map (lambda (c) (as-written (car c))) cs)
            (distinct (map (lambda (c) (symbol->string (cdr c))) cs))))))

;; row-says : (Listof String) String -> (U (List (Listof String) (Listof String)) (List 'cells (Listof String)))
;; A discovery row read on MACHINE: the paths its second cell names, and its
;; third cell's code spans.
(define (row-says cells machine)
  (if (= (length cells) 3)
      (list (looks-in (cadr cells) machine) (code-spans (caddr cells)))
      (list 'cells cells)))

;; row-agrees? : String (U 'guix 'fhs) -> Boolean
;; Whether the table row of ROW-TEXT names, on x86_64 and on arm64, the paths
;; and the sources discovery gives for WORLD.
(define (row-agrees? row-text world)
  (let ((w (find (lambda (w) (eq? (cadr w) world)) discovery-worlds)))
    (equal? (map (lambda (m) (discovery-says world (car m))) (caddr w))
            (map (lambda (m) (row-says (pipe-cells row-text) (cdr m))) (caddr w)))))

(define guix-row
  (string-append "| Guix | `libsodium.so.26`, then `libsodium.so.23` in `$GUIX_ENVIRONMENT/lib`, "
                 "`$GUIX_PROFILE/lib`, `~/.guix-home/profile/lib`, `~/.guix-profile/lib`, "
                 "then `/run/current-system/profile/lib` | `guix-environment`, `guix-profile`, "
                 "`guix-home`, `guix-user-profile`, `guix-system` |"))

(define linux-row
  (string-append "| Other Linux | `libsodium.so.26`, then `libsodium.so.23` in `/usr/local/lib`, "
                 "`/usr/lib/x86_64-linux-gnu` (`/usr/lib/aarch64-linux-gnu` on arm64), `/usr/lib64`, "
                 "then `/usr/lib` | `system` |"))

;; replaced : String String String -> String
;; TEXT with its one PATTERN made REPLACEMENT.
(define (replaced text pattern replacement)
  (let ((i (search text pattern 0)))
    (if i
        (string-append (substring text 0 i) replacement
                       (substring text (+ i (string-length pattern)) (string-length text)))
        (assertion-violation 'replaced "no such text" pattern))))

(test-equal "row-agrees?: a Guix row and an other-Linux row written as the finding page writes them agree with discovery's candidates, path for path and source for source, on both machines"
  '(#t #t)
  (list (row-agrees? guix-row 'guix) (row-agrees? linux-row 'fhs)))

(test-equal "row-agrees?: a Guix row with two directories swapped, the files swapped, a directory typo'd, a directory left out, a source swapped, a source left out or one added, a file left out, or the other world's row, disagrees"
  '(#f #f #f #f #f #f #f #f #f #f #f)
  (list (row-agrees? (replaced guix-row "`$GUIX_PROFILE/lib`, `~/.guix-home/profile/lib`"
                               "`~/.guix-home/profile/lib`, `$GUIX_PROFILE/lib`")
                     'guix)
        (row-agrees? (replaced guix-row "`libsodium.so.26`, then `libsodium.so.23` in"
                               "`libsodium.so.23`, then `libsodium.so.26` in")
                     'guix)
        (row-agrees? (replaced guix-row "~/.guix-home/profile/lib" "~/.guix-home/profile/lib64") 'guix)
        (row-agrees? (replaced guix-row "`$GUIX_PROFILE/lib`, " "") 'guix)
        (row-agrees? (replaced guix-row "`guix-environment`, `guix-profile`"
                               "`guix-profile`, `guix-environment`")
                     'guix)
        (row-agrees? (replaced guix-row ", `guix-system` |" " |") 'guix)
        (row-agrees? (replaced guix-row "`guix-system` |" "`guix-system`, `system` |") 'guix)
        (row-agrees? (replaced guix-row "`libsodium.so.26`, then " "") 'guix)
        (row-agrees? linux-row 'guix)
        (row-agrees? guix-row 'fhs)
        (row-agrees? (replaced linux-row " (`/usr/lib/aarch64-linux-gnu` on arm64)" "") 'fhs)))

(test-equal "row-agrees?: an other-Linux row with the arm64 alternative changed, a directory out of order, a source other than system, or no alternative on the one directory, disagrees; one with the arm64 alternative as discovery has it agrees"
  '(#f #f #f #f #t)
  (list (row-agrees? (replaced linux-row "aarch64-linux-gnu" "arm64-linux-gnu") 'fhs)
        (row-agrees? (replaced (replaced linux-row "`/usr/lib64`" "`/usr/lib`") ", then `/usr/lib` |" ", then `/usr/lib64` |")
                     'fhs)
        (row-agrees? (replaced linux-row "`system`" "`guix-system`") 'fhs)
        (row-agrees? (replaced linux-row "`/usr/lib/x86_64-linux-gnu` (`/usr/lib/aarch64-linux-gnu` on arm64)"
                               "`/usr/lib/x86_64-linux-gnu`")
                     'fhs)
        (row-agrees? linux-row 'fhs)))

(define discovery-rows (rows-of (table-headed finding-tables "System")))

(test-equal "finding-libsodium.md: the discovery table has a row for each of discovery's worlds, and no other"
  (length discovery-worlds)
  (if (no-table? discovery-rows) discovery-rows (length discovery-rows)))

(for-each
 (lambda (w k)
   (test-equal (string-append "finding-libsodium.md: the discovery table's row " (number->string (+ k 1))
                              ", for " (car w) ", names discovery's candidates, by the paths it writes, and their sources, in order, on x86_64 and on arm64")
     (map (lambda (m) (discovery-says (cadr w) (car m))) (caddr w))
     (if (and (not (no-table? discovery-rows)) (> (length discovery-rows) k))
         (map (lambda (m) (row-says (list-ref discovery-rows k) (cdr m))) (caddr w))
         'no-row)))
 discovery-worlds
 world-indices)

(for-each
 (lambda (w k)
   (let ((rule (cadddr w)))
     (test-equal (string-append "finding-libsodium.md: the discovery table's row " (number->string (+ k 1))
                                ", for " (car w) ", names its world in its first cell, which "
                                (if (eq? (car rule) 'begins) "begins " "holds ") (cadr rule))
       'names-its-world
       (if (and (not (no-table? discovery-rows)) (> (length discovery-rows) k)
                (pair? (list-ref discovery-rows k)))
           (let ((cell (car (list-ref discovery-rows k))))
             (if (label-names? cell rule) 'names-its-world (list 'first-cell cell)))
           'no-row))))
 discovery-worlds
 world-indices)

;; override-source : (U String (List 'raised String))
;; The source discovery gives a path CHEZ_SODIUM_LIBRARY names.
(define override-source
  (guard (e (#t (list 'raised (describe e))))
    (call-with-values
     (lambda () (choose-libsodium (lambda (name) (and (string=? name "CHEZ_SODIUM_LIBRARY") "/@override/lib.so"))
                                   'ta6le #f (lambda (path) #f)))
     (lambda (path source) (symbol->string source)))))

(define prose-override-sources
  (spans-before (joined finding-prose) " for `CHEZ_SODIUM_LIBRARY`"))

(test-equal "finding-libsodium.md: its prose names the source an override gets, in the one code span before \" for `CHEZ_SODIUM_LIBRARY`\""
  (list override-source)
  prose-override-sources)

(test-equal "finding-libsodium.md: the discovery table's sources and the prose's override source are discovery's sources, each once"
  (guard (e (#t (list 'raised (describe e))))
    (list-sort string<? (map symbol->string libsodium-sources)))
  (list-sort string<?
             (append (if (no-table? discovery-rows)
                         (list (shown discovery-rows))
                         (apply append (map (lambda (row) (if (= (length row) 3) (code-spans (caddr row)) '()))
                                            discovery-rows)))
                     prose-override-sources)))


;; --- reference.md's reasons, held to the code -------------------------------------------------------

(define reference-page "docs/reference.md")

;; Empty when the page is not among the pages read, so each row below fails
;; by its name.
(define reference-prose (guard (e (#t '())) (prose-of reference-page)))
(define reference-blocks (guard (e (#t '())) (blocks-of reference-page)))

;; glossary-reasons : (Listof Block) -> (U (Listof String) 'no-reason-line)
;; The words that begin with ' on the line of a text block that begins
;; Reason and a blank, and on the lines after it that begin with a blank,
;; their ' dropped; no-reason-line when no text block has one.
(define (glossary-reasons blocks)
  (let ((lines (apply append (map block-lines (filter (lambda (b) (string=? (block-language b) "text")) blocks)))))
    (let find ((ls lines))
      (cond ((null? ls) 'no-reason-line)
            ((and (starts? (car ls) "Reason") (> (string-length (car ls)) 6) (blank? (string-ref (car ls) 6)))
             (let take ((rest (cdr ls)) (taken (list (car ls))))
               (if (and (pair? rest) (> (string-length (car rest)) 0) (blank? (string-ref (car rest) 0)))
                   (take (cdr rest) (cons (car rest) taken))
                   (apply append
                          (map (lambda (l)
                                 (map (lambda (w) (substring w 1 (string-length w)))
                                      (filter (lambda (w) (starts? w "'")) (words l))))
                               (reverse taken))))))
            (else (find (cdr ls)))))))

(test-equal "glossary-reasons: the quoted words of the Reason line and the indented lines after it; not a line after a flush or a blank one, nor a word without its quote, nor Reasons, an indented Reason or a Reason alone"
  '(("a" "b" "c" "d") ("a") no-reason-line no-reason-line no-reason-line no-reason-line)
  (let ((go (lambda lines (glossary-reasons (list (make-block 1 "text" '() lines #t))))))
    (list (go "Natural   x" "Reason    one of 'a 'b" "          'c" "          'd" "Other     'z")
          (go "Reason    one of 'a b" "" "  'z")
          (go "Reasons   one of 'a")
          (go "  Reason  one of 'a")
          (go "Reason")
          (glossary-reasons (list (make-block 1 "sh" '() '("Reason  one of 'a") #t))))))

(test-equal "reference.md: its glossary's Reason line is the library's refusal reasons, in its order"
  library-reasons
  (glossary-reasons reference-blocks))

(test-equal "reference.md: its reasons table's first column is the library's refusal reasons, in its order, each cell one code span"
  library-reasons
  (reasons-column (tables reference-prose)))

;; entries : (Listof String) -> (Listof (Pair String (Listof String)))
;; Each ### `NAME` entry of a Markdown page's prose, as NAME and the REASON of
;; each of its lines that begins - `REASON`: with REASON of a to z, digits
;; and -, in order. An entry ends at the next heading of level 3 or less.
(define (entries prose)
  (let loop ((ls prose) (current #f) (out '()))
    (define (close) (if current (cons (cons (car current) (reverse (cdr current))) out) out))
    (if (null? ls)
        (reverse (close))
        (let ((h (heading-of (car ls))))
          (cond ((and h (<= (car h) 3))
                 (loop (cdr ls)
                       (and (= (car h) 3)
                            (starts? (cdr h) "`") (ends? (cdr h) "`")
                            (list (substring (cdr h) 1 (- (string-length (cdr h)) 1))))
                       (close)))
                ((and current (bullet-reason (car ls)))
                 => (lambda (r) (loop (cdr ls) (cons (car current) (cons r (cdr current))) out)))
                (else (loop (cdr ls) current out)))))))

;; bullet-reason : String -> (U String #f)
;; REASON, for a line that begins - `REASON`: with REASON of a to z, digits and -.
(define (bullet-reason line)
  (and (starts? line "- `")
       (let ((close (search line "`:" 3)))
         (and close (> close 3)
              (let ((r (substring line 3 close)))
                (and (for-all (lambda (c) (or (and (char<=? #\a c) (char<=? c #\z)) (digit? c) (char=? c #\-)))
                              (string->list r))
                     r))))))

;; The reasons each verb of the reference raises: those a probe of its own
;; mistakes gives, and these two, which no probe reaches: a password that
;; cannot be too long once the cap holds, and a change another thread makes
;; mid-call. They are held to a symbol the library quotes.
(define unprobed-reasons
  '(("password-hash" "length-out-of-range" "changed-during-call")
    ("password-verify" "length-out-of-range" "changed-during-call")))

;; Each verb's mistakes, as expressions the probe evaluates in run-env. Each
;; is refused before any hash is made or any call reaches libsodium.
(define reason-probes
  '(("random-bytes" "(random-bytes \"32\")" "(random-bytes 65537)")
    ("blake2b" "(blake2b \"x\")" "(blake2b (make-bytevector 65537 0))" "(blake2b (make-bytevector 1 0) #f)"
     "(blake2b (make-bytevector 1 0) 15)" "(blake2b (make-bytevector 1 0) 32 #f)"
     "(blake2b (make-bytevector 1 0) 32 (make-bytevector 0 0))"
     "(blake2b (make-bytevector 1 0) 32 (make-bytevector 15 1))")
    ("constant-time-bytevector=?" "(constant-time-bytevector=? 1 2)"
     "(constant-time-bytevector=? (make-bytevector 65537 0) (make-bytevector 1 0))")
    ("password-hash" "(password-hash 1)" "(password-hash (make-string 65537 #\\a))" "(password-hash \"pw\" 'fast)")
    ("password-verify" "(password-verify 1 \"x\")" "(password-verify \"x\" #f)"
     "(password-verify \"x\" (make-string 65537 #\\a))")
    ("password-needs-rehash?" "(password-needs-rehash? 1)" "(password-needs-rehash? \"x\" 'bogus)")
    ("make-password-limits" "(make-password-limits 1.0 8)" "(make-password-limits 0 8)"
     "(make-password-limits 1 64.0)" "(make-password-limits 1 7)")))

;; reason-of : String -> (U String (List 'other String))
;; The reason, the first irritant, of the refusal the expression raises in
;; run-env; else what happened.
(define (reason-of expression)
  (guard (e ((and (assertion-violation? e) (irritants-condition? e)
                  (pair? (condition-irritants e)) (symbol? (car (condition-irritants e))))
             (symbol->string (car (condition-irritants e))))
            (#t (list 'other (describe e))))
    (eval (car (datums expression)) run-env)
    (list 'other "nothing raised")))

(define probed-reasons
  (map (lambda (entry) (cons (car entry) (map reason-of (cdr entry)))) reason-probes))

;; raised-by : String -> (Listof String)
;; The reasons the verb raises: its probed ones, each once, and its unprobed ones.
(define (raised-by verb)
  (let ((probed (assoc verb probed-reasons)) (extra (assoc verb unprobed-reasons)))
    (distinct (append (if probed (filter string? (cdr probed)) '()) (if extra (cdr extra) '())))))

;; quoted-symbols : Any -> (Listof String)
;; The name of each symbol of each quoted datum of the data, at any depth.
(define (quoted-symbols x)
  (cond ((and (pair? x) (eq? (car x) 'quote) (pair? (cdr x))) (datum-symbols (cadr x)))
        ((pair? x) (append (quoted-symbols (car x)) (quoted-symbols (cdr x))))
        ((vector? x) (apply append (map quoted-symbols (vector->list x))))
        (else '())))

(define library-quoted
  (guard (e (#t '()))
    (quoted-symbols
     (call-with-port
      (open-file-input-port "src/chez-sodium/private/password-verbs.sls" (file-options) (buffer-mode block)
                            (make-transcoder (utf-8-codec)))
      read))))

;; entry-problems : (Listof Entry) (Listof String) (String -> (Listof String)) -> (Listof (List String Any))
;; Each reason an entry of a verb among VERBS names that RAISED-OF does not
;; give for the verb, as (VERB REASON); an entry that has reasons and is no
;; verb's, the detail entry apart, as (NAME no-such-verb).
(define (entry-problems entries verbs raised-of)
  (apply append
         (map (lambda (e)
                (cond ((member (car e) verbs)
                       (map (lambda (r) (list (car e) r))
                            (filter (lambda (r) (not (member r (raised-of (car e))))) (cdr e))))
                      ((or (null? (cdr e)) (string=? (car e) "sodium-library-unavailable-detail")) '())
                      (else (list (list (car e) 'no-such-verb)))))
              entries)))

(define sample-reference
  (list "# R" "### `v`" "Refuses:" "" "- `a`: x." "- `b`: y." "  - `zz`: nested." "- Not `c`: text." "- `d e`: no."
        "### `w`" "- `a`: x." "## Other" "- `a`: after the level 2." "### `x`" "- `q`: x." "#### `y`" "- `r`: deeper."
        "### no code" "- `s`: x." "### `empty`"))

(test-equal "entries: each ### `NAME` entry's bullets of the form - `REASON`:, in order, to the next heading of level 3 or less; not a nested bullet, a bullet that begins with other text or a REASON with a blank in it, one under a heading of another level or without a name in code; an entry with none is an empty one"
  '(("v" "a" "b") ("w" "a") ("x" "q" "r") ("empty"))
  (entries sample-reference))

(test-equal "entry-problems: a reason a verb does not raise, named by verb; an entry that is no verb's, named; the detail entry and an entry with no reasons, not"
  '(("v" "b") ("x" no-such-verb))
  (entry-problems (entries sample-reference) '("v" "w")
                  (lambda (verb) (if (string=? verb "v") '("a") '("a" "b")))))

(test-equal "entry-problems: a verb's entry that names each reason it raises, in any order and more than once, is no problem"
  '()
  (entry-problems '(("v" "b" "a" "b")) '("v") (lambda (verb) '("a" "b" "c"))))

(test-equal "quoted-symbols: the symbols of each quoted datum, at any depth, a vector's among them; no unquoted one, string or comment"
  '("a" "b" "c" "d")
  (quoted-symbols (datums "(f 'a x \"y\") (g '(b (c))) #(h 'd) ;; 'z\n(i j)")))

(test-equal "the probes of each verb's mistakes each raise a refusal, whose reason is a string: those that do not, by verb"
  '()
  (apply append
         (map (lambda (entry)
                (let ((bad (filter (lambda (r) (not (string? r))) (cdr entry))))
                  (if (null? bad) '() (list (cons (car entry) bad)))))
              probed-reasons)))

(test-equal "a probe reaches each reason the verb has that the reference's entry names, but for the unprobed ones: each verb's reasons the probes give, in order, once each"
  '(("random-bytes" "not-a-natural" "over-the-cap")
    ("blake2b" "not-a-bytevector" "over-the-cap" "not-a-natural" "size-out-of-range" "empty-key" "key-length-out-of-range")
    ("constant-time-bytevector=?" "not-a-bytevector" "over-the-cap")
    ("password-hash" "not-a-string" "over-the-cap" "not-password-limits")
    ("password-verify" "not-a-string" "over-the-cap")
    ("password-needs-rehash?" "not-a-string" "not-password-limits")
    ("make-password-limits" "not-a-natural" "ops-out-of-range" "memory-out-of-range"))
  (map (lambda (entry) (cons (car entry) (distinct (filter string? (cdr entry))))) probed-reasons))

(test-equal "the reasons no probe reaches are symbols password-verbs.sls quotes"
  '()
  (filter (lambda (r) (not (member r library-quoted)))
          (distinct (apply append (map cdr unprobed-reasons)))))

(test-equal "reference.md: each reason an entry of a verb names is one the verb raises, by verb and reason; no entry of another name has reasons but the detail entry"
  '()
  (entry-problems (entries reference-prose) (map car reason-probes) raised-by))

;; entry-gaps : (Listof Entry) (Listof String) (String -> (Listof String)) (String -> (Listof String))
;;              -> (Listof (List String Any))
;; What a verb's entry among VERBS leaves out, beside what entry-problems finds:
;; each reason RAISED-OF gives that the entry does not name, as (VERB REASON
;; missing); and, when it leaves none of the PROBED-OF reasons out, those
;; reasons in an order other than PROBED-OF's, as (VERB order). The entry's
;; order is its probed reasons, each at its first place; the reasons no probe
;; reaches are held by presence alone. An entry that has no reasons, and a
;; verb with no entry, are the rows beside this one.
(define (entry-gaps entries verbs raised-of probed-of)
  (apply append
         (map (lambda (e)
                (if (and (member (car e) verbs) (pair? (cdr e)))
                    (let* ((missing (filter (lambda (r) (not (member r (cdr e)))) (raised-of (car e))))
                           (probed (probed-of (car e)))
                           (seen (distinct (filter (lambda (r) (member r probed)) (cdr e))))
                           (probed-missing (filter (lambda (r) (not (member r seen))) probed)))
                      (append (map (lambda (r) (list (car e) r 'missing)) missing)
                              (if (and (null? probed-missing) (not (equal? seen probed)))
                                  (list (list (car e) 'order))
                                  '())))
                    '()))
              entries)))

(test-equal "entry-gaps: a reason a verb raises that its entry leaves out, by verb; probed reasons out of the probes' order, once each, but not when one is left out; an entry with no reasons, one that is no verb's and an extra reason, not"
  '(("v" "c" missing) ("w" order) ("y" "q" missing))
  (entry-gaps '(("v" "a" "b") ("w" "b" "a" "b" "c" "x") ("u" "a") ("e") ("z" "a") ("y" "a" "b"))
              '("v" "w" "e" "y")
              (lambda (verb) (cond ((string=? verb "y") '("a" "b" "q")) (else '("a" "b" "c"))))
              (lambda (verb) '("a" "b" "c"))))

(test-equal "entry-gaps: a verb's entry that names each reason it raises, the probed ones in order, repeated or with the unprobed one between, is no gap"
  '()
  (entry-gaps '(("v" "a" "a" "q" "b" "c")) '("v")
              (lambda (verb) '("a" "b" "c" "q")) (lambda (verb) '("a" "b" "c"))))

(test-equal "reference.md: each verb's entry names each reason the verb raises, and its probed ones in the probes' order, which is the order the code checks"
  '()
  (entry-gaps (entries reference-prose) (map car reason-probes) raised-by
              (lambda (verb) (let ((p (assoc verb probed-reasons)))
                               (if p (distinct (filter string? (cdr p))) '())))))

;; limits-of-line : String -> (Listof String)
;; The names of the quoted words of a Limits line up to its first ), each
;; without its ' and its trailing ,, and Password-limits, last, when the line holds it.
(define (limits-of-line line)
  (let ((strip (lambda (w)
                 (let loop ((n (string-length w)))
                   (if (and (> n 0) (memv (string-ref w (- n 1)) '(#\, #\))))
                       (loop (- n 1))
                       (substring w 0 n))))))
    (append (map (lambda (w) (substring (strip w) 1 (string-length (strip w))))
                 (filter (lambda (w) (starts? w "'"))
                         (words (let ((close (search line ")" 0)))
                                  (if close (substring line 0 close) line)))))
            (if (search line "Password-limits" 0) '("Password-limits") '()))))

;; limits-line-of : (Listof String) (String -> Boolean) -> (U (Listof String) 'no-limits-line)
;; limits-of-line of the first line the predicate holds; else no-limits-line.
(define (limits-line-of lines pred)
  (let ((l (find pred lines)))
    (if l (limits-of-line l) 'no-limits-line)))

(define (glossary-limits-line? l)
  (and (starts? l "Limits") (> (string-length l) 6) (blank? (string-ref l 6))))

(define (source-limits-line? l) (starts? (trim l) ";;   Limits = "))

(test-equal "limits-of-line and limits-line-of: the presets of a Limits line, in order, with Password-limits last; the first line the predicate holds, else none"
  '(("interactive" "moderate" "sensitive" "Password-limits") ("interactive" "moderate" "Password-limits")
    ("interactive") no-limits-line)
  (list (limits-of-line "Limits   'interactive, 'moderate, 'sensitive or a Password-limits")
        (limits-of-line ";;   Limits = (U 'interactive 'moderate Password-limits), by default 'interactive")
        (limits-line-of '("Natural x" "Limits 'interactive" "Limits 'z") glossary-limits-line?)
        (limits-line-of '("Limitsx 'a" "Limits") glossary-limits-line?)))

(test-equal "limits rows: the glossary's Limits line and the source's hold the same presets, in order, as text; a line with one preset less is no match"
  '(#t #f)
  (let ((g (limits-of-line "Limits  'interactive, 'moderate, 'sensitive or a Password-limits")))
    (list (equal? g (limits-of-line ";;   Limits = (U 'interactive 'moderate 'sensitive Password-limits), by default 'interactive"))
          (equal? g (limits-of-line ";;   Limits = (U 'interactive 'moderate Password-limits), by default 'interactive")))))

(define source-lines (guard (e (#t '())) (text-lines (slurp "src/chez-sodium.sls"))))

(test-equal "reference.md: its glossary's Limits line is the source's Limits line, in text: the presets in order, then Password-limits"
  (limits-line-of source-lines source-limits-line?)
  (limits-line-of (apply append (map block-lines (filter (lambda (b) (string=? (block-language b) "text")) reference-blocks)))
                  glossary-limits-line?))

(test-equal "reference.md: each verb has an entry that names a reason: the verbs without"
  '()
  (let ((named (map car (filter (lambda (e) (pair? (cdr e))) (entries reference-prose)))))
    (filter (lambda (v) (not (member v named))) (map car reason-probes))))

(test-equal "reference.md: the detail entry's bullets are the library's refusal reasons, each once, in any order"
  (guard (e (#t (list 'raised (describe e)))) (list-sort string<? library-reasons))
  (let ((e (assoc "sodium-library-unavailable-detail" (entries reference-prose))))
    (if e (list-sort string<? (cdr e)) 'no-detail-entry)))

;; --- whole programs, and the guarded one -----------------------------------------------------------

;; whole-programs-of : String Boolean String
;;                     -> (Listof (List String Block (U (Listof String) #f) Boolean))
;; Each whole program of the page PAGE, of text TEXT: its page, its block, the
;; lines of the text block after it or #f, and whether it holds a guard on
;; sodium-library-unavailable?.
(define (whole-programs-of page org? text)
  (let ((bs (car (if org? (org text) (markdown text)))))
    (map (lambda (b)
           (list page b (text-after b bs) (guards-unavailable? (datums (joined (block-lines b))))))
         (filter (lambda (b) (whole-program? b org?)) bs))))

;; guarded-text-problems : (Listof WholeProgram) -> (Listof (List String Natural Symbol))
;; Each guarded program that has a text block before the next Scheme block of
;; its page, by its page and line: the version it prints differs by lane, so
;; no text block can hold it.
(define (guarded-text-problems programs)
  (map (lambda (w) (list (car w) (block-line (cadr w)) 'guarded-has-a-text-block))
       (filter (lambda (w) (and (cadddr w) (caddr w))) programs)))

;; hash-shown? : String -> Boolean
;; Whether the text holds a password hash, which begins $argon2.
(define (hash-shown? text) (and (search text "$argon2" 0) #t))

(define sample-programs-page
  (string-append
   "# Page\n\n"
   (fenced "scheme" '("(import (rnrs))" "(display 1)")) (fenced "text" '("1"))
   (fenced "scheme" '("(import (rnrs) (chez-sodium))"
                      "(guard (e ((sodium-library-unavailable? e) (display 2))) (display 3))"))
   (fenced "text" '("3"))
   (fenced "scheme" '("(import (rnrs) (chez-sodium))"
                      "(guard (c ((sodium-library-unavailable? c) (display 2))) (display 3))"))
   "\nIt prints the version.\n\n" (fenced "sh" '("ls"))
   (fenced "scheme" '("(display 4)"))
   (fenced "text" '("4"))
   (fenced "scheme" '("(import (rnrs) (chez-sodium))"
                      "(guard (c ((sodium-library-unavailable? c) (display 2))) (display 3))"))
   (fenced "scheme run" '("1" ";; => 1"))
   (fenced "text" '("after a run"))))

(define sample-programs (whole-programs-of "docs/p.md" #f sample-programs-page))

(test-equal "whole-programs-of: each whole program, by page, its text block or #f, and whether it guards sodium-library-unavailable?; a fragment with no import and a runnable block are none"
  '(("docs/p.md" 3 ("1") #f) ("docs/p.md" 10 ("3") #t) ("docs/p.md" 17 #f #t) ("docs/p.md" 33 #f #t))
  (map (lambda (w) (list (car w) (block-line (cadr w)) (caddr w) (cadddr w))) sample-programs))

(test-equal "guarded-text-problems: a guarded program followed by a text block is named by its page and line; one with prose and an sh block before the next Scheme block, or a Scheme block first, and an unguarded one with a text block, are not"
  '(("docs/p.md" 10 guarded-has-a-text-block))
  (guarded-text-problems sample-programs))

(test-equal "guarded-text-problems: a guarded program, last on its page, with a text block at the page's end, is named; with none, it is not"
  '(1 0)
  (map (lambda (text) (length (guarded-text-problems (whole-programs-of "docs/q.md" #f text))))
       (list (string-append "# Q\n\n" (fenced "scheme" '("(import (rnrs))" "(guard (e ((sodium-library-unavailable? e) 1)) 2)"))
                            (fenced "text" '("x")))
             (string-append "# Q\n\n" (fenced "scheme" '("(import (rnrs))" "(guard (e ((sodium-library-unavailable? e) 1)) 2)"))))))

(test-equal "hash-shown?: a text that holds a hash's $argon2 start, anywhere, is shown; a #t, an empty text and a near miss are not"
  '(#t #t #f #f #f)
  (map hash-shown? '("$argon2id$v=19$m=65536" "x\n$argon2i\n" "#t\n" "" "$argon3")))

;; --- the children ------------------------------------------------------------------------------------

;; chez : (U String #f)
;; CHEZ as the environment has it, made absolute from the suite's directory
;; when it is a relative path, since each program runs from a directory of
;; its own. A bare name is left for the shell's PATH.
(define chez
  (let ((c (getenv "CHEZ")))
    (if (and c (not (starts? c "/")) (search c "/" 0))
        (string-append (current-directory) "/" c)
        c)))

;; The file the override names in the rows below, which is not there.
(define missing-library "/no/such/directory/libsodium.so.26")

;; write-text : String String -> Void
(define (write-text path text)
  (call-with-port
   (open-file-output-port path (file-options no-fail) (buffer-mode block)
                          (make-transcoder (utf-8-codec)))
   (lambda (p) (put-string p text))))

;; The library path a reader gives: the quick start's --libdirs names the
;; clone's src and nothing else, so a program that imports anything more
;; fails for the reader, and must fail here. It is the checkout's src by its
;; absolute path, since each program runs in a directory of its own.
(define reader-libdirs (string-append (current-directory) "/src"))

;; The file each program is written to, in its directory.
(define program-name "child.sps")

;; run-in : String (U String #f) String -> (List Integer String String)
;; PROGRAM run in a fresh Chez with a reader's library path, through
;; gated-command, from the directory DIR, with CHEZ_SODIUM_LIBRARY set to
;; OVERRIDE, or as the environment has it for #f; and the status, stdout and
;; stderr it gave. A cd that fails exits 125.
(define (run-in dir override program)
  (capture-command
   (append (list "/bin/sh" "-c" "cd \"$1\" || exit 125; shift; exec \"$@\"" "sh" dir)
           (if override
               (list "env" (string-append "CHEZ_SODIUM_LIBRARY=" override))
               '())
           (gated-command getenv (list chez "--libdirs" reader-libdirs "--program" program)))))

;; program-session : (U String #f) String
;;                   -> (U (List (List Integer String String) (Listof String)) (List 'raised String))
;; TEXT, as written, run as a program from a fresh directory of its own, as
;; run-in runs it, and what it gave; and the files it left in that directory,
;; but its own, sorted. The directory is removed after.
(define (program-session override text)
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (base)
       (let ((program (string-append base "/" program-name)))
         (write-text program text)
         (let* ((run (run-in base override program))
                (left (list-sort string<?
                                 (filter (lambda (f) (not (string=? f program-name)))
                                         (directory-list base)))))
           (list run left)))))))

;; program-run : (U String #f) String -> (U (List Integer String String) (List 'raised String))
;; TEXT, as written, run once as program-session runs it; and the status,
;; stdout and stderr it gave.
(define (program-run override text)
  (let ((session (program-session override text)))
    (if (eq? (car session) 'raised) session (car session))))

;; Prints whether this process runs under memcheck: its preload is in /proc/self/maps.
(define valgrind-printer
  (string-append
   "(write (cons 'valgrind\n"
   "            (guard (e (#t 'no-maps))\n"
   "              (let ((maps (call-with-port\n"
   "                           (open-file-input-port \"/proc/self/maps\" (file-options) (buffer-mode block)\n"
   "                                                 (make-transcoder (utf-8-codec)))\n"
   "                           get-string-all))\n"
   "                    (needle \"vgpreload_memcheck\"))\n"
   "                (let loop ((i 0))\n"
   "                  (cond ((> (+ i (string-length needle)) (string-length maps)) 'no)\n"
   "                        ((string=? (substring maps i (+ i (string-length needle))) needle) 'yes)\n"
   "                        (else (loop (+ i 1)))))))))\n"
   "(newline)\n"))

;; The last line a child prints: yes exactly when the gate asked.
(define valgrind-line
  (string-append "(valgrind . "
                 (cond ((getenv "CHEZ_SODIUM_GATE_CHILD") "yes")
                       ((file-exists? "/proc/self/maps") "no")
                       (else "no-maps"))
                 ")\n"))

;; The file the program in the first row below writes, by a relative path.
(define relative-file "written-by-a-docs-program.txt")

(test-equal "a program runs from a directory of its own, in a fresh Chez, through gated-command, with the override it is given: the file it writes by a relative path is left there and not in the checkout, it prints the override and, last, whether Valgrind ran it exactly when the gate asked, and exits 0 with nothing on stderr"
  (list (list 0 (string-append "\"" missing-library "\"\n" valgrind-line) "")
        (list relative-file)
        'not-in-the-checkout)
  (let* ((session (program-session
                   missing-library
                   (string-append "(import (rnrs) (only (chezscheme) getenv))\n"
                                  "(call-with-output-file \"" relative-file "\" (lambda (p) (display \"x\" p)))\n"
                                  "(write (getenv \"CHEZ_SODIUM_LIBRARY\"))\n(newline)\n"
                                  valgrind-printer)))
         (in-checkout (file-exists? relative-file)))
    (when in-checkout (guard (e (#t #f)) (delete-file relative-file)))
    (if (eq? (car session) 'raised)
        session
        (list (car session) (cadr session) (if in-checkout 'in-the-checkout 'not-in-the-checkout)))))

(test-equal "a program that exits 3 after a line on stderr is seen as it is: its status, and the stderr, whole"
  '(3 "oops\n")
  (let ((r (program-run #f (string-append "(import (rnrs))\n"
                                          "(put-string (current-error-port) \"oops\\n\")\n"
                                          "(flush-output-port (current-error-port))\n(exit 3)\n"))))
    (if (integer? (car r)) (list (car r) (caddr r)) r)))

(test-equal "src is alone on a program's library path: a program that imports (floors), a library of tests/ that needs nothing but Chez, fails, and prints nothing"
  '(failed "")
  (let ((r (program-run #f "(import (rnrs) (floors))\n(display \"ran\")\n")))
    (if (integer? (car r)) (list (if (zero? (car r)) 'ran 'failed) (cadr r)) r)))

;; --- the whole programs, run as written ----------------------------------------------------------
;; Each runs through program-run, so under make test-memory the gate's own
;; Valgrind runs it, and reads its log; Valgrind writes to that log, not to
;; the program's stdout or stderr. A whole program prints no valgrind line of
;; its own: the row above, whose child runs through the same program-run,
;; prints one, and fails when the gate asked and it says no.

;; whole-programs : (Listof (List String Block (U (Listof String) #f) Boolean))
(define whole-programs
  (apply append
         (map (lambda (p) (whole-programs-of p (org-page? p) (text-or-empty p))) pages)))

;; program-runs : (Listof (List String Natural (U (Listof String) #f) Run (U Run #f)))
;; Each whole program's page, line and text block's lines; what it gave run
;; as the environment has the library; and, for a guarded one, what it gave
;; with the library missing.
(define program-runs
  (each-in-order
   (lambda (w)
     (let* ((text (joined (block-lines (cadr w))))
            (answer (program-run #f text))
            (missing (and (cadddr w) (program-run missing-library text))))
       (list (car w) (block-line (cadr w)) (caddr w) answer missing)))
   whole-programs))

(test-equal "no guarded program has a text block before the next Scheme block of its page: those that do, by page and line"
  '()
  (guarded-text-problems whole-programs))

(test-equal "no whole program names a (chez-sodium private ...) library, which a reader's library path finds too, in any of its data: those that do, by page and line, with the libraries"
  '()
  (apply append
         (map (lambda (w)
                (let ((names (private-names (datums (joined (block-lines (cadr w)))))))
                  (if (null? names) '() (list (list (car w) (block-line (cadr w)) names)))))
              whole-programs)))

;; status-and-stderr, stdout-of : Run -> ...
;; What a row asserts of a run's answer, or the answer when the run raised.
(define (ran? r) (integer? (car r)))
(define (status-and-stderr r) (if (ran? r) (list (car r) (caddr r)) r))
(define (stdout-of r) (if (ran? r) (cadr r) r))

;; loaded-line : (U String (List 'raised String))
;; What the suite reads itself of the library it loaded, as a guarded program
;; prints it with the library there: its version, written, and a newline.
(define loaded-line
  (guard (e (#t (list 'raised (describe e))))
    (string-append (shown (eval '(sodium-version) run-env)) "\n")))

(test-equal "the docs hold whole programs, and one of them guards sodium-library-unavailable?"
  '(some some)
  (list (if (null? whole-programs) 'none 'some)
        (if (exists cadddr whole-programs) 'some 'none)))

(test-equal "a whole program of the docs has a text block after it that holds what it prints"
  'some
  (if (exists caddr whole-programs) 'some 'none))

(for-each
 (lambda (r)
   (let ((name (string-append (car r) ":" (number->string (cadr r)) ": the whole program, run as written, ")))
     (test-equal (string-append name "exits 0 with nothing on stderr")
       '(0 "")
       (status-and-stderr (list-ref r 3)))
     (test-equal (string-append name "prints no password hash")
       'none-shown
       (let ((out (stdout-of (list-ref r 3))))
         (cond ((not (string? out)) out)
               ((hash-shown? out) 'a-hash-is-shown)
               (else 'none-shown))))
     (when (caddr r)
       (test-equal (string-append name "prints the text block after it, line for line")
         (joined (caddr r))
         (stdout-of (list-ref r 3))))
     (when (list-ref r 4)
       (test-equal (string-append name "with the library there, prints the version the suite reads itself, written, and a newline")
         loaded-line
         (stdout-of (list-ref r 3)))
       (test-equal (string-append name "with CHEZ_SODIUM_LIBRARY naming a missing file, exits 0 with nothing on stderr and prints exactly (refused load-failed PATH), as write writes it, and a newline")
         (list 0 (refusal-text missing-library) "")
         (list-ref r 4)))))
 program-runs)

(test-end "docs")

;; SRFI-64 sets no exit status; this is the shared form.
(exit (suite-exit-status runner))
