#!r6rs
;;; The suite for (chez-sodium private memory): counted foreign blocks
;;; (ADR-0011), and the wipe fused with the free (ADR-0008). A block is
;;; malloc'd memory, counted as a block in (chez-sodium private counters)
;;; while it lives, and kept in a table of live blocks, so that freeing any
;;; other address raises before free runs, and before the wipe does.
;;;
;;; Memory never loads libsodium, so this suite imports it, as it imports the
;;; counters. The writers' rows at the end reach native through eval, under a
;;; guard, so a native that will not load fails them by name. The wipe is a
;;; procedure memory is given: every row here hands it the suite's own stub,
;;; which logs its calls, so what memory passes it, when it calls it and what
;;; it does when the stub raises are all read directly.
;;; A refusal names a size or an address by shown-value: a number as itself,
;;; never a secret (ADR-0006).
;;;
;;; The dead-address row runs a child Chez: a free that ran anyway would make
;;; glibc abort, and a child's abort fails that row by name, not the whole
;;; suite with SIGABRT. It reaches malloc and free only: it never loads
;;; libsodium. It runs through gated-command, so under make test-memory the
;;; gate's own Valgrind runs it, with a log of its own (ADR-0011). It prints
;;; its counts and how many times its wipe ran, and this suite asserts both;
;;; then whether it ran under memcheck, which this suite requires to be yes
;;; exactly when the gate asked, so a child that escaped the gate fails its
;;; row.
;;;
;;; The wipe row that reads the block (W8) passes in any run: it is the gate
;;; that sees a wipe that runs after the free, as an invalid read.
;;;
;;; Every refusal is raised after the critical section that decided it,
;;; never inside one: a with-exception-handler handler of it runs at depth 1,
;;; with interrupts enabled (disable-interrupts answers 1 outside any
;;; section). A row per site: the free of what is no live block, the free
;;; whose count-down finds the count at zero, made so by a count-down! this
;;; suite makes first, a wipe that raises, and a malloc that fails, asked for
;;; the greatest fixnum of bytes, which no address space holds.
;;;
;;; A test that raises a count on purpose lowers it again under dynamic-wind,
;;; and this suite exits through suite-exit-status, which fails it if any
;;; count is left. Each expected value is one the code under test cannot
;;; produce by failing: SRFI-64 makes #f of a raise in the actual expression,
;;; so none is #f, and each refusal is compared, who and irritants,
;;; against a no-raise sentinel.
(import (rnrs)
        (rnrs eval)
        (srfi :64)
        (only (chezscheme) foreign-ref foreign-set! getenv library-exports disable-interrupts
              enable-interrupts)
        (chez-sodium-testing)
        (chez-sodium private counters)
        (chez-sodium private memory))

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

;; raised : (-> Any) -> Any
;; What THUNK raised: (assertion-violation WHO IRRITANTS), (other TEXT)
;; for any other raise, or (no-raise VALUE).
(define (raised thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (message-condition? e)
                  (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (list 'no-raise (thunk))))

;; A refusal is compared by its kind, who and irritants, never its message
;; text (ADR-0006).

(define zero-counts '((block . 0)))

;; counts-with : (Listof (Pairof Symbol Integer)) -> (Listof (Pairof Symbol Integer))
;; zero-counts, with each kind in CHANGES at its count.
(define (counts-with changes)
  (map (lambda (entry) (cond ((assq (car entry) changes) => (lambda (c) c)) (else entry)))
       zero-counts))

;; poke! : Natural (Listof Natural) -> Void
(define (poke! address bytes)
  (let loop ((i 0) (bytes bytes))
    (unless (null? bytes)
      (foreign-set! 'unsigned-8 address i (car bytes))
      (loop (+ i 1) (cdr bytes)))))

;; peek : Natural Natural -> (Listof Natural)
(define (peek address n)
  (let loop ((i (- n 1)) (found '()))
    (if (< i 0) found (loop (- i 1) (cons (foreign-ref 'unsigned-8 address i) found)))))

;; iota-from : Natural Natural -> (Listof Natural)
(define (iota-from start n)
  (if (= n 0) '() (cons start (iota-from (+ start 1) (- n 1)))))

;; no-wipe : Natural Natural -> #f
;; A wipe that does nothing: the suite's blocks need none.
(define (no-wipe address size) #f)

;; with-block : Natural (Natural -> Any) -> Any
;; PROC's answer, given a counted block of SIZE bytes, freed after.
(define (with-block size proc)
  (let ((block (foreign-block size)))
    (dynamic-wind
      (lambda () #f)
      (lambda () (proc block))
      (lambda () (free-foreign-block! block no-wipe)))))

;; logging-wipe : -> (Values Procedure (-> (Listof Any)))
;; A wipe that records each call as (ADDRESS SIZE COUNTS), COUNTS being the
;; native counts at the call, and the procedure that reads the log, oldest
;; first.
(define (logging-wipe)
  (let ((log '()))
    (values (lambda (address size)
              (set! log (cons (list address size (native-counts)) log))
              #f)
            (lambda () (reverse log)))))

(define (sorted-names names)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) names))

(test-begin "blocks")

;; No back door to the table: the library exports exactly these, written out.
(test-equal "(chez-sodium private memory) exports exactly foreign-block and free-foreign-block!"
  (sorted-names '(foreign-block free-foreign-block!))
  (sorted-names (library-exports '(chez-sodium private memory))))

(test-equal "foreign-block: an address, counted as a block while it lives; free-foreign-block! frees it, and the count is zero after"
  (list 'address (counts-with '((block . 1))) zero-counts)
  (let* ((block (foreign-block 16))
         (inside (native-counts)))
    (free-foreign-block! block no-wipe)
    (list (if (and (integer? block) (exact? block) (> block 0)) 'address block)
          inside (native-counts))))

(test-equal "a block is writable over its whole size"
  (iota-from 1 16)
  (with-block 16 (lambda (block) (poke! block (iota-from 1 16)) (peek block 16))))

(test-equal "foreign-block refuses a size that is no positive exact integer: 0, -1, 1.5, 8.0, and \"8\" named by its kind, counting nothing"
  (list (list 'assertion-violation 'foreign-block '(0))
        (list 'assertion-violation 'foreign-block '(-1))
        (list 'assertion-violation 'foreign-block '(1.5))
        (list 'assertion-violation 'foreign-block '(8.0))
        (list 'assertion-violation 'foreign-block '((kind string)))
        zero-counts)
  (let* ((a (raised (lambda () (foreign-block 0))))
         (b (raised (lambda () (foreign-block -1))))
         (c (raised (lambda () (foreign-block 1.5))))
         (d (raised (lambda () (foreign-block 8.0))))
         (e (raised (lambda () (foreign-block "8")))))
    (list a b c d e (native-counts))))

;; The live table holds every block, not the last one alone: two live at
;; once, each freed, in the order they were made, then a third after.
(test-equal "two blocks live at once are both counted, and each frees, the first made first; a block of 1 byte is one too"
  (list (counts-with '((block . 2))) (counts-with '((block . 1))) zero-counts
        (counts-with '((block . 1))) zero-counts)
  (let* ((first (foreign-block 8))
         (second (foreign-block 8))
         (both (native-counts))
         (one-left (begin (free-foreign-block! first no-wipe) (native-counts)))
         (none (begin (free-foreign-block! second no-wipe) (native-counts)))
         (tiny (foreign-block 1))
         (tiny-live (native-counts)))
    (free-foreign-block! tiny no-wipe)
    (list both one-left none tiny-live (native-counts))))

(test-equal "free-foreign-block! refuses what is no address at all, a symbol as itself and a string by its kind, and counts nothing"
  (list (list 'assertion-violation 'free-foreign-block! '(x))
        (list 'assertion-violation 'free-foreign-block! '((kind string)))
        zero-counts)
  (let* ((a (raised (lambda () (free-foreign-block! 'x no-wipe))))
         (b (raised (lambda () (free-foreign-block! "4096" no-wipe)))))
    (list a b (native-counts))))

;; --- the wipe, fused with the free (ADR-0008) -----------------------------------

;; W1: one call, with the address and the size the block was made with, while
;; the block is still counted: the wipe runs before the count-down, so a wipe
;; that read the block would find it live.
(test-equal "W1 free-foreign-block! calls its wipe once, with the block's address and size, while the block is still counted; the count falls after"
  (list 1 'the-block 24 (counts-with '((block . 1))) zero-counts)
  (let-values (((wipe log) (logging-wipe)))
    (let* ((block (foreign-block 24)))
      (free-foreign-block! block wipe)
      (let ((calls (log)))
        (list (length calls)
              (if (and (pair? calls) (eqv? (car (car calls)) block)) 'the-block (car calls))
              (cadr (car calls))
              (caddr (car calls))
              (native-counts))))))

;; W2: the size comes from the table. The caller never passes one, so a wipe
;; handed a size of the caller's, or a fixed one, could not be told from this
;; by one size alone: three, none a word's multiple but 4096.
(test-equal "W2 the size the wipe gets is the one foreign-block recorded: 1, 7 and 4096 each arrive as made"
  '(1 7 4096)
  (let-values (((wipe log) (logging-wipe)))
    (for-each (lambda (size)
                (let ((block (foreign-block size)))
                  (free-foreign-block! block wipe)))
              '(1 7 4096))
    (map cadr (log))))

;; W3: a dead address is refused before the wipe: the block may be freed
;; already, and a wipe over it is a write to freed memory.
(test-equal "W3 a freed address and one never allocated are refused with the wipe never called, and nothing is counted"
  (list (list 'assertion-violation 'free-foreign-block! 'the-address)
        (list 'assertion-violation 'free-foreign-block! '(4096))
        '()
        zero-counts)
  (let-values (((wipe log) (logging-wipe)))
    (let* ((block (foreign-block 16))
           (freed (begin (free-foreign-block! block no-wipe) block))
           (a (raised (lambda () (free-foreign-block! freed wipe))))
           (b (raised (lambda () (free-foreign-block! 4096 wipe)))))
      (list (if (equal? a (list 'assertion-violation 'free-foreign-block! (list freed)))
                (list 'assertion-violation 'free-foreign-block! 'the-address)
                a)
            b
            (log)
            (native-counts)))))

;; W4: a wipe that is no procedure is refused before anything is touched: the
;; block stays live and counted, and the row frees it after.
(test-equal "W4 a wipe that is no procedure is refused by shown-value, and the block stays live and counted until freed properly"
  (list (list 'assertion-violation 'free-foreign-block! '(x))
        (list 'assertion-violation 'free-foreign-block! '(#f))
        (list 'assertion-violation 'free-foreign-block! '((kind string)))
        (counts-with '((block . 1)))
        zero-counts)
  (let* ((block (foreign-block 8))
         (a (raised (lambda () (free-foreign-block! block 'x))))
         (b (raised (lambda () (free-foreign-block! block #f))))
         (c (raised (lambda () (free-foreign-block! block "w"))))
         (still (native-counts)))
    (free-foreign-block! block no-wipe)
    (list a b c still (native-counts))))

;; interrupt-depth : -> Positive-Integer
;; How many critical sections this thread is inside, plus one: what
;; disable-interrupts answers, put back at once. 1 outside any section.
(define (interrupt-depth)
  (let ((n (disable-interrupts)))
    (enable-interrupts)
    n))

;; depth-and-object : (-> Any) -> (U (List 'raised-at-depth Symbol Any) (List 'no-raise Any))
;; The depth a with-exception-handler handler runs at for the first thing
;; THUNK raises, as depth-N, and the object itself.
(define (depth-and-object thunk)
  (call/cc
   (lambda (k)
     (with-exception-handler
      (lambda (c)
        (let ((depth (interrupt-depth)))
          (k (list 'raised-at-depth
                   (string->symbol (string-append "depth-" (number->string depth)))
                   c))))
      (lambda () (list 'no-raise (thunk)))))))

;; shape-of : Any -> Any
;; A raised object by kind, who and irritants when it is an assertion violation.
(define (shape-of e)
  (if (and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
      (list 'assertion-violation (condition-who e) (condition-irritants e))
      (list 'other (describe e))))

;; W5: a wipe that raises is caught inside the section, the block is freed
;; and counted down all the same, and the raise reaches a handler once the
;; section has ended, as the very object the wipe raised.
(test-equal "W5 a wipe that raises: its object reaches a handler at depth 1, itself, the block is freed and counted down, and a second free is refused as not live"
  (list 'depth-1 'same-object zero-counts 'not-live)
  (let* ((boom (list 'boom))
         (block (foreign-block 8))
         (r (depth-and-object
             (lambda () (free-foreign-block! block (lambda (address size) (raise boom))))))
         (counts (native-counts))
         (again (raised (lambda () (free-foreign-block! block no-wipe)))))
    (list (cadr r)
          (if (and (eq? (car r) 'raised-at-depth) (eq? (caddr r) boom)) 'same-object r)
          counts
          (if (equal? again (list 'assertion-violation 'free-foreign-block! (list block)))
              'not-live
              again))))

;; W6: the wipe's failure came first, so it is the one raised. The count was
;; taken away by this suite beforehand, so count-down! finds zero, which is a
;; double free; two failures, and the first is told.
(test-equal "W6 a wipe that raises, over a block whose count was taken away, raises the wipe's object, not the double free"
  (list 'depth-1 'wipes-object zero-counts)
  (let* ((boom (list 'boom))
         (block (foreign-block 8))
         (taken (count-down! 'block))
         (r (depth-and-object
             (lambda () (free-foreign-block! block (lambda (address size) (raise boom)))))))
    (list (cadr r)
          (if (and (eq? (car r) 'raised-at-depth) (eq? (caddr r) boom)) 'wipes-object r)
          (native-counts))))

;; W8: a wipe that reads every byte of the block sees it live, and holds what
;; was written. Run under make test-memory, a wipe that ran after the free
;; would read freed memory, and Valgrind would fail this suite.
(test-equal "W8 a wipe that reads the whole block finds it live, holding what was written"
  (iota-from 1 40)
  (let* ((block (foreign-block 40))
         (seen #f))
    (poke! block (iota-from 1 40))
    (free-foreign-block! block (lambda (address size) (set! seen (peek address size)) #f))
    seen))

;; W9: a wipe that frees its own block. Chez's mutexes are recursive, so the
;; second free gets in; it finds the block no longer live and is refused, and
;; that refusal is the wipe's failure, raised after the section. If the table
;; entry outlived the wipe, the second free would free the block, the first
;; would free it again, and glibc would abort the process.
(test-equal "W9 a wipe that calls free-foreign-block! on its own address is refused as not live, with no double free: the refusal reaches a handler at depth 1, and every count is zero after"
  (list (list 'depth-1 (list 'assertion-violation 'free-foreign-block! 'its-own-address))
        zero-counts)
  (let* ((block (foreign-block 16))
         (r (depth-and-object
             (lambda () (free-foreign-block! block (lambda (address size)
                                                      (free-foreign-block! address no-wipe)))))))
    (list (if (eq? (car r) 'raised-at-depth)
              (list (cadr r)
                    (let ((e (caddr r)))
                      (if (and (assertion-violation? e) (who-condition? e)
                               (equal? (list (condition-who e) (condition-irritants e))
                                       (list 'free-foreign-block! (list block))))
                          (list 'assertion-violation 'free-foreign-block! 'its-own-address)
                          (shape-of e))))
              r)
          (native-counts))))

;; A dead address: freed already or never one of memory's. Freeing either
;; would make glibc abort the process, or worse, so the refusal must come
;; before free runs. A child Chez does it, so that free running anyway
;; fails this test by name, not the whole suite with SIGABRT. The child
;; prints its counts and how many times its wipe ran: once, for the block
;; that was live, and for neither dead address (W7).
(define dead-address-program
  (string-append
   "(import (rnrs) (chez-sodium private memory) (chez-sodium private counters))\n"
   "(define wipe-calls 0)\n"
   "(define (wipe address size) (set! wipe-calls (+ wipe-calls 1)) #f)\n"
   "(define block (foreign-block 16))\n"
   "(free-foreign-block! block wipe)\n"
   "(define (try thunk)\n"
   "  (guard (e ((and (assertion-violation? e) (who-condition? e) (message-condition? e)\n"
   "                  (irritants-condition? e))\n"
   "             (list (condition-who e)\n"
   "                   (if (equal? (condition-irritants e) (list block)) 'that-block (condition-irritants e)))))\n"
   "    (thunk)\n"
   "    'no-raise))\n"
   "(let* ((again (try (lambda () (free-foreign-block! block wipe))))\n"
   "       (never (try (lambda () (free-foreign-block! 4096 wipe)))))\n"
   "  (write (list again never (native-counts) (cons 'wipe-calls wipe-calls)))\n"
   "  (newline))\n"
   ";; Whether this process runs under memcheck: its preload is in /proc/self/maps.\n"
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

;; Under make test-memory the child runs under the gate's own Valgrind, and
;; says so; anywhere else it does not.
(define valgrind-line
  (string-append "(valgrind . "
                 (cond ((getenv "CHEZ_SODIUM_GATE_CHILD") "yes")
                       ((file-exists? "/proc/self/maps") "no")
                       (else "no-maps"))
                 ")\n"))

(test-equal "W7 free-foreign-block! refuses a dead address, freed already or never allocated, before free and before the wipe: in a child Chez, whose wipe ran once, for the live block, and whose counts are all zero"
  (list 0
        (string-append
         "((free-foreign-block! that-block) (free-foreign-block! (4096)) "
         "((block . 0)) (wipe-calls . 1))\n"
         valgrind-line)
        "")
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (dir)
       (let ((program (string-append dir "/dead-address.sps")))
         (call-with-port (open-file-output-port program (file-options) (buffer-mode block)
                                                (make-transcoder (utf-8-codec)))
           (lambda (p) (put-string p dead-address-program)))
         (capture-command (gated-command getenv
                                         (list (getenv "CHEZ") "--libdirs" "src:tests:build/scheme-libs"
                                               "--program" program))))))))

;; --- raised after the section ------------------------------------------------

;; handler-depth : (-> Any) -> (U (List 'raised-at-depth Symbol Any) (List 'no-raise Any))
;; The depth a with-exception-handler handler runs at for the first thing
;; THUNK raises, read before anything else, as depth-N, and what it raised:
;; an assertion violation by its who, as a symbol, and its irritants, else
;; (other TEXT). The handler escapes, so nothing returns into the raise.
(define (handler-depth thunk)
  (call/cc
   (lambda (k)
     (with-exception-handler
      (lambda (c)
        (let* ((depth (interrupt-depth))
               (what (if (and (assertion-violation? c) (who-condition? c) (irritants-condition? c))
                         (list 'assertion-violation
                               (let ((who (condition-who c)))
                                 (if (string? who) (string->symbol who) who))
                               (condition-irritants c))
                         (list 'other (describe c)))))
          (k (list 'raised-at-depth
                   (string->symbol (string-append "depth-" (number->string depth)))
                   what))))
      (lambda () (list 'no-raise (thunk)))))))

(test-equal "free-foreign-block! refuses what is no live block after its critical section: a handler of it runs at depth 1, and nothing is counted"
  (list (list 'raised-at-depth 'depth-1 (list 'assertion-violation 'free-foreign-block! '(x)))
        zero-counts)
  (let ((r (handler-depth (lambda () (free-foreign-block! 'x no-wipe)))))
    (list r (native-counts))))

;; The block's count is taken away by this suite first, so the free's
;; count-down finds it at zero: a double free, which count-down! refuses
;; once the block is freed. A free that did not run is a leak, which the
;; gate's Valgrind sees: no second free is tried here, since one that ran
;; anyway would abort this process (the dead-address row's child).
(test-equal "free-foreign-block! raises its count-down's double free after its critical section: a handler of it runs at depth 1, and the count stays at zero"
  (list (list 'raised-at-depth 'depth-1 (list 'assertion-violation 'count-down! '(double-free block)))
        zero-counts)
  (let* ((block (foreign-block 8))
         (taken (count-down! 'block))
         (r (handler-depth (lambda () (free-foreign-block! block no-wipe)))))
    (list r (native-counts))))

;; foreign-alloc refuses a malloc that answers NULL with an assertion
;; violation of its own, whose who is the string "foreign-alloc" on Chez
;; 10.4.0, and its irritant the system's text for ENOMEM, which this row
;; does not read.
(test-equal "foreign-block raises a failed malloc after its critical section: asked for the greatest fixnum of bytes, a handler of foreign-alloc's refusal runs at depth 1, and nothing is counted"
  (list (list 'raised-at-depth 'depth-1 'foreign-alloc) zero-counts)
  (let ((r (handler-depth (lambda () (foreign-block (greatest-fixnum))))))
    (list (if (and (eq? (car r) 'raised-at-depth) (eq? (car (caddr r)) 'assertion-violation))
              (list (car r) (cadr r) (cadr (caddr r)))
              r)
          (native-counts))))

;; --- the writers: call-with-c-string, call-with-utf8 and foreign-ascii-string ---------------------
;;
;; Reached through eval, under a guard, as test-native reaches native: a
;; native that will not load fails these rows by name. Each row reads what the
;; writer wrote from inside PROC, with foreign-ref, and compares it with a
;; list written here from string->utf8, which only a test may use. A byte
;; written past the block, and a block whose terminating 0 was never written,
;; are seen by the memory gate's Valgrind, as an invalid write and as a read
;; of an uninitialised byte: a plain run reuses a wiped chunk that reads 0.

(define (native-procedure name)
  (guard (e (#t (lambda args
                  (error name "(chez-sodium private native) could not be reached" (describe e)))))
    (eval name (environment '(chez-sodium private native)))))

(define call-with-c-string (native-procedure 'call-with-c-string))
(define call-with-utf8 (native-procedure 'call-with-utf8))
(define foreign-ascii-string (native-procedure 'foreign-ascii-string))

;; make-list-of : Natural Any -> (Listof Any)
(define (make-list-of n x) (if (= n 0) '() (cons x (make-list-of (- n 1) x))))

;; guarded : (-> Any) -> Any
(define (guarded thunk)
  (guard (e (#t (list 'raised (describe e))))
    (thunk)))

;; raised-shape : (-> Any) -> Any
;; (refused WHO IRRITANTS) for an assertion violation, (other TEXT) for any
;; other raise, (no-raise VALUE) when THUNK answers.
(define (raised-shape thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'refused (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (list 'no-raise (thunk))))

;; utf8-written : String Natural -> Any
;; call-with-utf8's (ran ADDRESS-POSITIVE BYTES BLOCKS-LIVE) for STRING counted
;; as N: BYTES being max(1,N) bytes read back inside PROC; or
;; (changed PROC-CALLS) when CHANGED answered.
(define (utf8-written string n)
  (let ((proc-calls 0))
    (let ((answer (call-with-utf8 'writer string n
                    (lambda (address)
                      (set! proc-calls (+ proc-calls 1))
                      (list 'ran (positive? address) (peek address (max 1 n))
                            (cdr (assq 'block (native-counts)))))
                    (lambda () (list 'changed proc-calls)))))
      answer)))

(define widths-string "a\x7F;\x80;\x7FF;\x800;\xFFFF;\x10000;\x10FFFF;")

(test-equal "call-with-utf8 writes the UTF-8 of each string into a block of (max 1 N), read back inside PROC with the block's address above 0 and one block live: \"\" as the one byte 0, \"a\", \"a\" NUL \"b\", \"pässwörd€\" and a string of each width's edges 7F, 80, 7FF, 800, FFFF, 10000 and 10FFFF"
  (map (lambda (s)
         (list 'ran #t (let ((b (bytevector->u8-list (string->utf8 s)))) (if (null? b) '(0) b)) 1))
       (list "" "a" "a\x0;b" "p\x00E4;ssw\x00F6;rd\x20AC;" widths-string))
  (guarded (lambda ()
             (map (lambda (s) (utf8-written s (bytevector-length (string->utf8 s))))
                  (list "" "a" "a\x0;b" "p\x00E4;ssw\x00F6;rd\x20AC;" widths-string)))))

(test-equal "call-with-utf8 frees its block after PROC: none counted once it returns, and the same for a string answered as changed"
  (list zero-counts zero-counts)
  (guarded (lambda ()
             (call-with-utf8 'writer "p\x00E4;ssw\x00F6;rd\x20AC;" 13 (lambda (a) #f) (lambda () #f))
             (let ((after-ran (native-counts)))
               (call-with-utf8 'writer "p\x00E4;ssw\x00F6;rd\x20AC;" 12 (lambda (a) #f) (lambda () #f))
               (list after-ran (native-counts))))))

(test-equal "call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count: \"pässwörd€\" (13 bytes) at 14 and 12, each width's string at its count +1 and -1, \"a\" at 0, and \"\" at 1"
  (append (make-list-of 14 '(changed 0)) '((changed 0) (changed 0)))
  (guarded (lambda ()
             (let ((strings (list "p\x00E4;ssw\x00F6;rd\x20AC;" "a" "\x7FF;" "\x800;" "\xFFFF;" "\x10000;" "\x10FFFF;")))
               (append
                (apply append
                       (map (lambda (s)
                              (let ((n (bytevector-length (string->utf8 s))))
                                (list (utf8-written s (+ n 1)) (utf8-written s (- n 1)))))
                            strings))
                (list (utf8-written "a" 0) (utf8-written "" 1)))))))

(test-equal "call-with-utf8 never writes past N: a four-byte character that does not fit the last 3 of N bytes answers CHANGED, a three-byte one the last 2, and a two-byte one the last 1, with PROC never called"
  '((changed 0) (changed 0) (changed 0))
  (guarded (lambda ()
             (list (utf8-written "a\x10000;" 4) (utf8-written "a\x800;" 3) (utf8-written "a\x7FF;" 2)))))

(test-equal "call-with-utf8 answers PROC's value whatever it is: #f, 0, '() and a string are each the answer, and CHANGED's answer is its own value, unwrapped"
  '(#f 0 () "text" changed-value)
  (guarded (lambda ()
             (list (call-with-utf8 'writer "a" 1 (lambda (a) #f) (lambda () 'no))
                   (call-with-utf8 'writer "a" 1 (lambda (a) 0) (lambda () 'no))
                   (call-with-utf8 'writer "a" 1 (lambda (a) '()) (lambda () 'no))
                   (call-with-utf8 'writer "a" 1 (lambda (a) "text") (lambda () 'no))
                   (call-with-utf8 'writer "a" 2 (lambda (a) 'ran) (lambda () 'changed-value))))))

;; c-string-written : String -> Any
;; call-with-c-string's (ran ADDRESS-POSITIVE BYTES BLOCKS-LIVE), BYTES the
;; N+1 bytes read back inside PROC; or (changed PROC-CALLS).
(define (c-string-written string)
  (let ((proc-calls 0))
    (call-with-c-string 'writer string
      (lambda (address)
        (set! proc-calls (+ proc-calls 1))
        (list 'ran (positive? address) (peek address (+ (string-length string) 1))
              (cdr (assq 'block (native-counts)))))
      (lambda () (list 'changed proc-calls)))))

(define hash-text "$argon2id$v=19$m=8,t=1,p=1$YNFZTNc7WUJq/v9Atwru5g$OTen/d9lhPgaQexgFJCgC9qQeduKiC0KIvPZlLCNRDE")

(test-equal "call-with-c-string writes each character as one byte and then a 0, in a block of N+1 read back inside PROC with one block live: \"\" as the one byte 0, \"!~\" at the range's edges, \"pw\", and a 93-character hash string whole, its 0 the 94th byte"
  (map (lambda (s) (list 'ran #t (append (bytevector->u8-list (string->utf8 s)) '(0)) 1))
       (list "" "!~" "pw" hash-text))
  (guarded (lambda () (map c-string-written (list "" "!~" "pw" hash-text)))))

(test-equal "call-with-c-string answers CHANGED's value and never calls PROC for a character outside U+0021 to U+007E, first, in the middle or last: a space, U+007F, U+00E9, U+0000 and U+20AC"
  (make-list-of 15 '(changed 0))
  (guarded (lambda ()
             (apply append
                    (map (lambda (c)
                           (let ((c (string c)))
                             (list (c-string-written (string-append c "ab"))
                                   (c-string-written (string-append "a" c "b"))
                                   (c-string-written (string-append "ab" c)))))
                         (list #\space #\x7F #\xE9 #\x0 #\x20AC))))))

(test-equal "call-with-c-string frees its block, and answers PROC's value or CHANGED's: none counted after a run and after a changed string; #f from PROC is the answer"
  (list zero-counts zero-counts #f 'changed-value)
  (guarded (lambda ()
             (let* ((ran (call-with-c-string 'writer "pw" (lambda (a) #f) (lambda () 'no)))
                    (after-ran (native-counts))
                    (changed (call-with-c-string 'writer "p w" (lambda (a) 'no) (lambda () 'changed-value)))
                    (after-changed (native-counts)))
               (list after-ran after-changed ran changed)))))

;; The writers' own refusals, each before any block: who and irritants whole,
;; and no block counted after. A string is a secret: a refusal of one names
;; its kind alone.

(define (refused-writers)
  (let ((proc (lambda (a) 'ran)) (changed (lambda () 'changed)))
    (list
     (raised-shape (lambda () (call-with-c-string 42 "pw" proc changed)))
     (raised-shape (lambda () (call-with-c-string 'w #vu8(1 2) proc changed)))
     (raised-shape (lambda () (call-with-c-string 'w 'secret-symbol proc changed)))
     (raised-shape (lambda () (call-with-c-string 'w '(#\a #\b) proc changed)))
     (raised-shape (lambda () (call-with-c-string 'w "pw" 42 changed)))
     (raised-shape (lambda () (call-with-c-string 'w "pw" proc 'no)))
     (raised-shape (lambda () (call-with-utf8 42 "pw" 2 proc changed)))
     (raised-shape (lambda () (call-with-utf8 'w #vu8(1 2) 2 proc changed)))
     (raised-shape (lambda () (call-with-utf8 'w 12345 2 proc changed)))
     (raised-shape (lambda () (call-with-utf8 'w "pw" -1 proc changed)))
     (raised-shape (lambda () (call-with-utf8 'w "pw" 1.5 proc changed)))
     (raised-shape (lambda () (call-with-utf8 'w "pw" "2" proc changed)))
     (raised-shape (lambda () (call-with-utf8 'w "pw" 2 'no changed)))
     (raised-shape (lambda () (call-with-utf8 'w "pw" 2 proc 7))))))

(test-equal "the writers refuse before any block: a who that is no symbol, from the helper; a string that is no string by its kind alone; an N that is no exact natural, a PROC and a CHANGED that are no procedure, from WHO by shown-value; no block counted after"
  (list '((refused call-with-c-string (42))
          (refused w (not-a-string string (kind bytevector)))
          (refused w (not-a-string string (kind symbol)))
          (refused w (not-a-string string (kind list)))
          (refused w (42))
          (refused w (no))
          (refused call-with-utf8 (42))
          (refused w (not-a-string string (kind bytevector)))
          (refused w (not-a-string string (kind number)))
          (refused w (-1))
          (refused w (1.5))
          (refused w ((kind string)))
          (refused w (no))
          (refused w (7)))
        zero-counts)
  (guarded (lambda () (let ((r (refused-writers))) (list r (native-counts))))))

;; holds-part? : Any -> Boolean
;; Whether X holds, at any depth, a piece of the secrets the row below hands the
;; writers: the symbol topsecret, the characters t, o and p, the numbers 116,
;; 111 and 112, or a string with one of those characters. It looks in every
;; pair, every vector, and every string's characters.
(define (holds-part? x)
  (cond ((pair? x) (or (holds-part? (car x)) (holds-part? (cdr x))))
        ((vector? x) (holds-part? (vector->list x)))
        ((string? x) (holds-part? (string->list x)))
        ((symbol? x) (eq? x 'topsecret))
        ((char? x) (and (memv x '(#\t #\o #\p)) #t))
        ((number? x) (and (memv x '(116 111 112)) #t))
        (else #f)))

(test-equal "a refusal of a secret string holds no part of it, at any depth: the irritants of a symbol, a list of characters and a bytevector hold their kind alone, whatever they contain"
  'clean
  (guarded (lambda ()
             (let ((shown (map (lambda (r) (if (and (pair? r) (eq? (car r) 'refused)) (caddr r) r))
                               (list (raised-shape (lambda () (call-with-utf8 'w 'topsecret 1 (lambda (a) 1) (lambda () 2))))
                                     (raised-shape (lambda () (call-with-c-string 'w 'topsecret (lambda (a) 1) (lambda () 2))))
                                     (raised-shape (lambda () (call-with-c-string 'w '(#\t #\o #\p) (lambda (a) 1) (lambda () 2))))
                                     (raised-shape (lambda () (call-with-c-string 'w #vu8(116 111 112) (lambda (a) 1) (lambda () 2))))))))
               (if (exists holds-part? shown) shown 'clean)))))

;; The order of the writers' checks: the who first, then the string, the N, PROC and CHANGED
;; (call-with-c-string has no N: who, string, PROC, CHANGED).
(test-equal "the writers check in order: a bad who before a bad string, a bad string before a bad N, a bad N before a bad PROC, a bad PROC before a bad CHANGED"
  '((refused call-with-utf8 (42))
    (refused w (not-a-string string (kind number)))
    (refused w (-1))
    (refused w (no-proc)))
  (guarded (lambda ()
             (list (raised-shape (lambda () (call-with-utf8 42 7 -1 'p 'c)))
                   (raised-shape (lambda () (call-with-utf8 'w 7 -1 'p 'c)))
                   (raised-shape (lambda () (call-with-utf8 'w "x" -1 'no-proc 'c)))
                   (raised-shape (lambda () (call-with-utf8 'w "x" 1 'no-proc 'c)))))))

(test-equal "call-with-c-string checks in order: a bad who before a bad string, a bad string before a bad PROC, a bad PROC before a bad CHANGED"
  '((refused call-with-c-string (42))
    (refused w (not-a-string string (kind number)))
    (refused w (no-proc))
    (refused w (no-changed)))
  (guarded (lambda ()
             (list (raised-shape (lambda () (call-with-c-string 42 7 'p 'c)))
                   (raised-shape (lambda () (call-with-c-string 'w 7 'no-proc 'c)))
                   (raised-shape (lambda () (call-with-c-string 'w "x" 'no-proc 'no-changed)))
                   (raised-shape (lambda () (call-with-c-string 'w "x" (lambda (a) 1) 'no-changed)))))))

;; foreign-ascii-string.

;; with-bytes-block : (Listof Natural) (Natural -> Any) -> Any
;; PROC's answer, given a block holding BYTES, freed after.
(define (with-bytes-block bytes proc)
  (with-block (max 1 (length bytes))
    (lambda (block) (poke! block bytes) (proc block))))

(test-equal "foreign-ascii-string reads the bytes before the first 0 within N as characters: \"abc\" from 61 62 63 00 with N 4 and with N 8 over bytes after the 0; \"\" from a 0 first; the byte 7F as U+007F"
  '("abc" "abc" "" "a\x7F;")
  (guarded (lambda ()
             (list (with-bytes-block '(#x61 #x62 #x63 0) (lambda (b) (foreign-ascii-string b 4)))
                   (with-bytes-block '(#x61 #x62 #x63 0 #x78 #x79 #x7A #x7B)
                     (lambda (b) (foreign-ascii-string b 8)))
                   (with-bytes-block '(0 #x61) (lambda (b) (foreign-ascii-string b 2)))
                   (with-bytes-block '(#x61 #x7F 0) (lambda (b) (foreign-ascii-string b 3)))))))

(test-equal "foreign-ascii-string answers #f, compared as the symbol false, when no 0 lies within N: 61 62 63 with N 3, a 0 at index 3 with N 3, and N 0; and when a byte before the 0 is 0x80 or more: 80, and 61 C3 A9 00"
  '(false false false false false)
  (guarded (lambda ()
             (let ((f (lambda (v) (if (eq? v #f) 'false v))))
               (list (f (with-bytes-block '(#x61 #x62 #x63 #x64) (lambda (b) (foreign-ascii-string b 3))))
                     (f (with-bytes-block '(#x61 #x62 #x63 0) (lambda (b) (foreign-ascii-string b 3))))
                     (f (with-bytes-block '(0) (lambda (b) (foreign-ascii-string b 0))))
                     (f (with-bytes-block '(#x80 0) (lambda (b) (foreign-ascii-string b 2))))
                     (f (with-bytes-block '(#x61 #xC3 #xA9 0) (lambda (b) (foreign-ascii-string b 4)))))))))

(test-equal "foreign-ascii-string reads a 93-character hash string out of a 128-byte block that holds A5 after its 0, whole"
  (list hash-text)
  (guarded (lambda ()
             (list (with-block 128
                     (lambda (b)
                       (poke! b (append (bytevector->u8-list (string->utf8 hash-text))
                                        (list 0)
                                        (make-list-of (- 128 (string-length hash-text) 1) #xA5)))
                       (foreign-ascii-string b 128)))))))

(test-equal "foreign-ascii-string refuses an address and a count that are no exact naturals, and NULL with bytes to read, from itself"
  '((refused foreign-ascii-string (address (kind string)))
    (refused foreign-ascii-string (count -1))
    (refused foreign-ascii-string (null-address 3)))
  (guarded (lambda ()
             (list (raised-shape (lambda () (foreign-ascii-string "x" 1)))
                   (raised-shape (lambda () (foreign-ascii-string 8 -1)))
                   (raised-shape (lambda () (foreign-ascii-string 0 3)))))))

(test-equal "every count is zero at the end"
  zero-counts
  (native-counts))

(test-end "blocks")

(exit (suite-exit-status runner))
