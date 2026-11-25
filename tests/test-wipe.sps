#!r6rs
;;; The suite for row 24: every block the library frees reads all zeros at the
;;; free (ADR-0008).
;;;
;;; It compiles tests/free-watch.c, an interposer of free(), and starts a
;;; child Chez with it preloaded. The child fills a block with #x41 through
;;; call-with-block and call-with-bytes, names the block from inside PROC, and
;;; reads the interposer's verdict once the call has ended: 1 when the block was
;;; freed all zero, 2 when it was freed holding a non-zero byte. One row each
;;; for a return, a raise, an escape, a byte count that is no word's multiple,
;;; a one-byte block, an empty bytevector whose one byte PROC dirties first
;;; (call-with-bytes writes it 0 itself, so a block left alone would read zero
;;; with or without the wipe), a call under call-in-section, and sodium_memzero
;;; handed to free-foreign-block! directly.
;;;
;;; One more row reads the block PROC freed itself: call-with-block's own free
;;; is refused as not live, and the next block of that size, the same chunk
;;; where malloc hands it back, must still hold what PROC left in bytes 16 to
;;; 63. A wipe over the dead block would have zeroed them, so a plain run sees
;;; what Valgrind sees as an invalid write. Where malloc does not hand the
;;; chunk back, the row is skipped by name.
;;;
;;; The witness has a standing control, with no mutant: a block freed with no
;;; wipe reads 2, and one named and never freed reads 0. So the interposer is
;;; shown able to say each of its answers in the same process, and a verdict of
;;; 1 is not one it gives whatever it sees.
;;;
;;; The child runs outside Valgrind, whose allocator bypasses the interposer
;;; (ADR-0011): it is not started through gated-command, and the gate does not
;;; see it. Its LD_PRELOAD is set to the interposer alone, never appended to:
;;; under the gate this suite's own LD_PRELOAD holds Valgrind's preloads, which
;;; the child must not carry outside Valgrind. The gate's variable is unset
;;; for it too. The child prints (valgrind . no) and (ld-preload . same) to
;;; show both, and this suite asserts the whole of its output.
;;;
;;; A second child, started the same way, runs the verbs of (chez-sodium private
;;; byte-verbs) and (chez-sodium private password-verbs) against the decoy libsodium (tests/decoy-libsodium.c), which
;;; names to the interposer each block it is handed. One row a call: the
;;; child answers the whole list of (length verdict) pairs, one per named
;;; block, in the order named, and every verdict is 1. Standing controls call
;;; native's raw bindings on blocks the child fills and frees with no wipe,
;;; and read 2. It cannot witness a block named with length 0, such as the
;;; unkeyed blake2b's key block, which reads 1 whatever happens, nor
;;; random-bytes 0, which makes no block; nor a block a verb makes and never
;;; hands to C, which the decoy never names. Those are held instead: check-seam's
;;; rule (m) and test-native's E7 keep every block in call-with-block, whose
;;; wipe the first child holds, and row S3 of tests/test-byte-verbs.sps lists
;;; every name inside each verb's section, so a block added there shows.
;;;
;;; A mutant that drops the wipe, shortens it by one byte, or moves it into a
;;; wrapper of PROC leaves some or all of the rows at 2.
(import (rnrs)
        (srfi :64)
        (only (chezscheme) getenv)
        (chez-sodium-testing)
        (only (libsodium-oracle) c-compiler)
        (only (library-loading) read-floor-values compile-decoys decoy-builds decoy-status))

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

;; child-tail : String
;; The last lines of every child: whether its LD_PRELOAD is the interposer
;; alone, whether it runs under memcheck, and the blocks left.
(define child-tail
  (string-append
   "(write (cons 'ld-preload (if (equal? (getenv \"LD_PRELOAD\") interposer) 'same (getenv \"LD_PRELOAD\"))))\n"
   "(newline)\n"
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
   "(newline)\n"
   "(write (list 'counts (native-counts)))\n"
   "(newline)\n"))

;; The child's program. It imports native, so its body is the load, run at the
;; child's start: a refusal ends the child with its message on stderr, which
;; this suite compares with the empty string.
(define child-program
  (string-append
   "(import (rnrs)\n"
   "        (only (chezscheme) foreign-procedure foreign-ref foreign-set! load-shared-object getenv)\n"
   "        (chez-sodium private counters)\n"
   "        (chez-sodium private memory)\n"
   "        (chez-sodium private native))\n"
   ";; The interposer is preloaded already: loading it by path reaches its functions.\n"
   "(define interposer (cadr (command-line)))\n"
   "(load-shared-object interposer)\n"
   "(define watch-reset (foreign-procedure \"watch_reset\" () void))\n"
   "(define watch-set (foreign-procedure \"watch_set\" (uptr size_t) void))\n"
   "(define watch-verdict (foreign-procedure \"watch_verdict\" (int) int))\n"
   "(define (fill-a n)\n"
   "  (lambda (b) (let loop ((i 0)) (when (< i n) (foreign-set! 'unsigned-8 b i #x41) (loop (+ i 1))))))\n"
   ";; named: PROC that names its block, N bytes of it, to the interposer.\n"
   "(define (named n) (lambda (b) (watch-set b n) 'ran))\n"
   ";; A row: the interposer cleared first, THUNK run under a catch-all guard,\n"
   ";; then the verdict read once the call has ended.\n"
   "(define (row name thunk)\n"
   "  (watch-reset)\n"
   "  (guard (e (#t #f)) (thunk))\n"
   "  (list name (watch-verdict 0)))\n"
   ";; The dead block row. PROC fills a 64-byte block and frees it itself, with no wipe,\n"
   ";; so call-with-block's own free is refused: the block is dead, and nothing may\n"
   ";; write to it. The next 64-byte block is the same chunk where malloc hands it back,\n"
   ";; and bytes 16 to 63 still hold #x41 (the allocator keeps its own words in the\n"
   ";; first 16). A wipe over the dead block would have zeroed them.\n"
   "(define (dead-block-row)\n"
   "  (let ((first #f))\n"
   "    (guard (e (#t #f))\n"
   "      (call-with-block 'w 64 (fill-a 64)\n"
   "        (lambda (b) (set! first b) (free-foreign-block! b (lambda (a n) #f)) 'freed)))\n"
   "    (let* ((next (foreign-block 64))\n"
   "           (same (eqv? next first))\n"
   "           (intact (let loop ((i 16))\n"
   "                     (or (= i 64)\n"
   "                         (and (= (foreign-ref 'unsigned-8 next i) #x41) (loop (+ i 1)))))))\n"
   "      (free-foreign-block! next (lambda (a n) #f))\n"
   "      (list 'dead-block-untouched (cond ((not same) 'no-reuse) (intact 'yes) (else 'touched))))))\n"
   "(define forty (make-bytevector 40 9))\n"
   "(define results\n"
   "  (let* ((a (row 'return-32 (lambda () (call-with-block 'w 32 (fill-a 32) (named 32)))))\n"
   "         (b (row 'return-33 (lambda () (call-with-block 'w 33 (fill-a 33) (named 33)))))\n"
   "         (c (row 'return-1 (lambda () (call-with-block 'w 1 (fill-a 1) (named 1)))))\n"
   "         (d (row 'raise (lambda () (call-with-block 'w 32 (fill-a 32)\n"
   "                                     (lambda (b) (watch-set b 32) (raise 'x))))))\n"
   "         (e (row 'escape (lambda () (call/cc (lambda (k)\n"
   "                                     (call-with-block 'w 32 (fill-a 32)\n"
   "                                       (lambda (b) (watch-set b 32) (k 'out))))))))\n"
   "         (f (row 'bytes-40 (lambda () (call-with-bytes 'w forty (named 40)))))\n"
   "         (g (row 'empty-bytes-dirtied\n"
   "                 (lambda () (call-with-bytes 'w #vu8()\n"
   "                              (lambda (b) (foreign-set! 'unsigned-8 b 0 #x41) (watch-set b 1) 'ran)))))\n"
   "         (h (row 'in-section (lambda () (call-in-section\n"
   "                                         (lambda () (call-with-bytes 'w forty (named 40)))))))\n"
   "         (i (row 'direct-memzero\n"
   "                 (lambda () (let ((b (foreign-block 40)))\n"
   "                              ((fill-a 40) b) (watch-set b 40)\n"
   "                              (free-foreign-block! b sodium-memzero)))))\n"
   "         ;; The controls: a block freed with no wipe, and one never freed.\n"
   "         (j (row 'control-unwiped\n"
   "                 (lambda () (let ((b (foreign-block 32)))\n"
   "                              ((fill-a 32) b) (watch-set b 32)\n"
   "                              (free-foreign-block! b (lambda (address size) #f))))))\n"
   "         (k (let ((b (foreign-block 32)))\n"
   "              (watch-reset)\n"
   "              ((fill-a 32) b)\n"
   "              (watch-set b 32)\n"
   "              (let ((verdict (watch-verdict 0)))\n"
   "                (free-foreign-block! b (lambda (address size) #f))\n"
   "                (list 'control-never-freed verdict))))\n"
   "         (m (dead-block-row)))\n"
   "    (list a b c d e f g h i j k m)))\n"
   "(for-each (lambda (r) (write r) (newline)) results)\n"
   child-tail))

;; The second child's program: the verbs against the decoy, which names each
;; block it is handed to the interposer (tests/decoy-libsodium.c). It imports
;; native and the verbs, so the load is its start, and CHEZ_SODIUM_LIBRARY
;; names the decoy. Each row clears the interposer, runs one call under a
;; catch-all guard, and answers the call's whole list of (length verdict)
;; pairs, one per named block, in the order the decoy named them. Every input,
;; key and operand holds a non-zero byte, and the decoy writes A5 over every
;; output, so no block is zero before its wipe.
;;
;; The controls call native's raw binding on blocks the child makes itself,
;; fills with #x41 and frees with no wipe: each named block reads 2, so the
;; list can say 2 where the verbs' say 1.
;;
;; What the rows cannot witness: a block named with length 0, the unkeyed
;; key's, reads 1 whatever happens, and random-bytes 0 makes no block.
(define decoy-child-program
  (string-append
   "(import (rnrs)\n"
   "        (only (chezscheme) foreign-procedure foreign-entry? foreign-set! load-shared-object getenv)\n"
   "        (chez-sodium private counters)\n"
   "        (chez-sodium private memory)\n"
   "        (chez-sodium private native)\n"
   "        (chez-sodium private byte-verbs)\n"
   "        (chez-sodium private password-verbs))\n"
   "(define interposer (cadr (command-line)))\n"
   "(load-shared-object interposer)\n"
   "(define watch-reset (foreign-procedure \"watch_reset\" () void))\n"
   "(define watch-count (foreign-procedure \"watch_count\" () int))\n"
   "(define watch-length (foreign-procedure \"watch_length\" (int) integer-64))\n"
   "(define watch-verdict (foreign-procedure \"watch_verdict\" (int) int))\n"
   ";; watched : -> (Listof (List Integer Integer))\n"
   ";; Every name since the reset, in order, as (length verdict).\n"
   "(define (watched)\n"
   "  (let loop ((i (- (watch-count) 1)) (found '()))\n"
   "    (if (< i 0)\n"
   "        found\n"
   "        (loop (- i 1) (cons (list (watch-length i) (watch-verdict i)) found)))))\n"
   ";; row : Symbol (-> Any) -> (List Symbol Symbol (Listof (List Integer Integer)))\n"
   "(define (row name thunk)\n"
   "  (watch-reset)\n"
   "  (let ((outcome (guard (e (#t 'raised)) (thunk) 'ran)))\n"
   "    (list name outcome (watched))))\n"
   "(define (filled n)\n"
   "  (let ((b (foreign-block n)))\n"
   "    (let loop ((i 0)) (when (< i n) (foreign-set! 'unsigned-8 b i #x41) (loop (+ i 1))))\n"
   "    b))\n"
   ";; freed-unwiped : Natural* -> Void\n"
   "(define (freed-unwiped . blocks)\n"
   "  (for-each (lambda (b) (free-foreign-block! b (lambda (address size) #f))) blocks))\n"
   "(define key-16 (make-bytevector 16 17))\n"
   "(define input-3 (u8-list->bytevector (list 1 2 3)))\n"
   "(define five-a (u8-list->bytevector (list 1 2 3 4 5)))\n"
   "(define five-b (u8-list->bytevector (list 1 2 3 4 5)))\n"
   ";; A password of nine UTF-8 bytes: p, a-umlaut (two bytes), s, s, w, o, r, d.\n"
   "(define password (string #\\p (integer->char 228) #\\s #\\s #\\w #\\o #\\r #\\d))\n"
   "(define password-limits (make-password-limits 1 8))\n"
   ";; The decoy's own hash string, 93 characters.\n"
   "(define control-hash\n"
   "  (string-append \"$argon2id$v=19$m=8,t=1,p=1$\" \"c2FsdHNhbHRzYWx0c2FsdA\" \"$\"\n"
   "                 \"dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGE\"))\n"
   ";; filled-string : Natural -> Natural*\n"
   ";; A block of N bytes holding #x41 and a NUL at the end: a C string of N-1 characters.\n"
   "(define (filled-string n)\n"
   "  (let ((b (filled n))) (foreign-set! 'unsigned-8 b (- n 1) 0) b))\n"
   "(define results\n"
   "  (let* ((a (row 'random-bytes-40 (lambda () (random-bytes 40))))\n"
   "         (b (row 'blake2b-keyed (lambda () (blake2b input-3 32 key-16))))\n"
   "         (c (row 'blake2b-unkeyed (lambda () (blake2b input-3))))\n"
   "         (d (row 'compare-5 (lambda () (constant-time-bytevector=? five-a five-b))))\n"
   "         (e (row 'control-randombytes-buf\n"
   "                 (lambda () (let ((x (filled 40)))\n"
   "                              (randombytes-buf x 40)\n"
   "                              (freed-unwiped x)))))\n"
   "         (f (row 'control-generichash\n"
   "                 (lambda () (let ((out (filled 32)) (in (filled 3)) (key (filled 16)))\n"
   "                              (crypto-generichash out 32 in 3 key 16)\n"
   "                              (freed-unwiped out in key)))))\n"
   "         (g (row 'control-memcmp\n"
   "                 (lambda () (let ((x (filled 5)) (y (filled 5)))\n"
   "                              (sodium-memcmp x y 5)\n"
   "                              (freed-unwiped x y)))))\n"
   "         (h (row 'password-hash (lambda () (password-hash password password-limits))))\n"
   "         (i (row 'password-verify (lambda () (password-verify control-hash password))))\n"
   "         (j (row 'password-needs-rehash (lambda () (password-needs-rehash? control-hash))))\n"
   "         (k (row 'control-pwhash-str\n"
   "                 (lambda () (let ((out (filled 128)) (pw (filled 9)))\n"
   "                              (crypto-pwhash-str out pw 9 1 8192)\n"
   "                              (freed-unwiped out pw)))))\n"
   "         (l (row 'control-pwhash-str-verify\n"
   "                 (lambda () (let ((s (filled-string 94)) (pw (filled 9)))\n"
   "                              (crypto-pwhash-str-verify s pw 9)\n"
   "                              (freed-unwiped s pw)))))\n"
   "         (m (row 'control-pwhash-str-needs-rehash\n"
   "                 (lambda () (let ((s (filled-string 94)))\n"
   "                              (crypto-pwhash-str-needs-rehash s 1 8192)\n"
   "                              (freed-unwiped s))))))\n"
   "    (list a b c d e f g h i j k l m)))\n"
   "(for-each (lambda (r) (write r) (newline)) results)\n"
   "(write (cons 'decoy (if (foreign-entry? \"decoy_calls\") 'yes 'no)))\n"
   "(newline)\n"
   child-tail))

;; decoy-expected-output : String
;; The second child's whole output. Each call's list is what the decoy named,
;; in parameter order: random-bytes' buf; blake2b's out, in and key, the
;; unkeyed key being the one-byte block call-with-bytes makes for #vu8(),
;; named with length 0; the compare's two operands. A decoy entry that left a
;; block unnamed makes its list shorter; a wipe that did nothing reads 2 where
;; each verb's reads 1; and the controls read 2 for every block they name.
(define decoy-expected-output
  (string-append
   "(random-bytes-40 ran ((40 1)))\n"
   "(blake2b-keyed ran ((32 1) (3 1) (16 1)))\n"
   "(blake2b-unkeyed ran ((32 1) (3 1) (0 1)))\n"
   "(compare-5 ran ((5 1) (5 1)))\n"
   "(control-randombytes-buf ran ((40 2)))\n"
   "(control-generichash ran ((32 2) (3 2) (16 2)))\n"
   "(control-memcmp ran ((5 2) (5 2)))\n"
   "(password-hash ran ((128 1) (9 1)))\n"
   "(password-verify ran ((94 1) (9 1)))\n"
   "(password-needs-rehash ran ((94 1)))\n"
   "(control-pwhash-str ran ((128 2) (9 2)))\n"
   "(control-pwhash-str-verify ran ((94 2) (9 2)))\n"
   "(control-pwhash-str-needs-rehash ran ((94 2)))\n"
   "(decoy . yes)\n"
   "(ld-preload . same)\n(valgrind . no)\n(counts ((block . 0)))\n"))

;; The child's whole output: one line per row, then the process's own facts.
(define expected-output
  (string-append
   "(return-32 1)\n(return-33 1)\n(return-1 1)\n(raise 1)\n(escape 1)\n"
   "(bytes-40 1)\n(empty-bytes-dirtied 1)\n(in-section 1)\n(direct-memzero 1)\n"
   "(control-unwiped 2)\n(control-never-freed 0)\n"
   "(dead-block-untouched yes)\n"
   "(ld-preload . same)\n(valgrind . no)\n(counts ((block . 0)))\n"))

;; write-file : String String -> Void
(define (write-file path text)
  (call-with-port (open-file-output-port path (file-options) (buffer-mode block)
                                         (make-transcoder (utf-8-codec)))
    (lambda (p) (put-string p text))))

;; run-wipe-children : -> (U (List Any Any) (List 'raised String))
;; The interposer and the decoy compiled, and each child run, as (HELPER DECOY),
;; each a (STATUS STDOUT STDERR); or (compile EVIDENCE) in the place of what
;; could not be built, or (raised TEXT). The decoy is the control build, at
;; the floor's versions, from the same compile the library-loading suites use.
;; Each child's LD_PRELOAD is the interposer alone, and the gate's variable is
;; unset for it: GNU env reads -u only before its first assignment.
(define (run-wipe-children)
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (dir)
       (let* ((so (string-append dir "/libfreewatch.so"))
              (decoy-so (string-append dir "/control.so"))
              (helper-program (string-append dir "/wipe-child.sps"))
              (decoy-program (string-append dir "/decoy-child.sps"))
              (floor-values (read-floor-values))
              (compiled (capture-command
                         (append (c-compiler getenv)
                                 (list "-Wall" "-Werror" "-shared" "-fPIC" "-o" so
                                       "tests/free-watch.c" "-ldl"))))
              (decoy-compiled (if (string? (car floor-values))
                                  (compile-decoys (lambda (build) decoy-so) floor-values
                                                  (decoy-builds '("control")))
                                  (list (cons "control" floor-values)))))
         (cond
           ((not (= (car compiled) 0)) (list 'compile compiled))
           ((not (eqv? (decoy-status decoy-compiled "control") 0))
            (list 'compile-decoy (decoy-status decoy-compiled "control")))
           (else
            (write-file helper-program child-program)
            (write-file decoy-program decoy-child-program)
            (let* ((run (lambda (program . env)
                          (capture-command
                           (append (list "env" "-u" "CHEZ_SODIUM_GATE_CHILD")
                                   env
                                   (list (string-append "LD_PRELOAD=" so)
                                         (getenv "CHEZ") "--libdirs" "src:tests:build/scheme-libs"
                                         "--program" program so)))))
                   (helper (run helper-program))
                   (decoy (run decoy-program (string-append "CHEZ_SODIUM_LIBRARY=" decoy-so))))
              (list helper decoy)))))))))

(test-begin "wipe")

;; The child runs once. Its line for the dead block is judged apart from the
;; rest: where malloc does not hand back the block just freed, that row says
;; no-reuse and is skipped by name, never passed.
(define children (run-wipe-children))
(define child-run
  (if (and (pair? children) (not (memq (car children) '(compile compile-decoy raised))))
      (car children)
      children))
(define decoy-run
  (if (and (pair? children) (not (memq (car children) '(compile compile-decoy raised))))
      (cadr children)
      children))

(define dead-line "(dead-block-untouched yes)\n")
(define no-reuse-line "(dead-block-untouched no-reuse)\n")

;; without-line : String String -> String
;; TEXT with the first occurrence of LINE taken out.
(define (without-line text line)
  (let ((n (string-length line)))
    (let loop ((i 0))
      (cond ((> (+ i n) (string-length text)) text)
            ((string=? (substring text i (+ i n)) line)
             (string-append (substring text 0 i) (substring text (+ i n) (string-length text))))
            (else (loop (+ i 1)))))))

;; has-line? : String String -> Boolean
(define (has-line? text line)
  (not (string=? text (without-line text line))))

(define dead-name "row 24: a block PROC freed itself is dead, and is never written: the next block of its size, the same chunk, still holds what PROC left in bytes 16 to 63")
(define (child-stdout) (if (and (pair? child-run) (integer? (car child-run))) (cadr child-run) ""))
(when (has-line? (child-stdout) no-reuse-line)
  (display "UNAVAILABLE ")
  (display dead-name)
  (display ": malloc did not hand back the block just freed")
  (newline)
  (test-skip dead-name))
(test-equal dead-name
  #t
  (has-line? (child-stdout) dead-line))

(test-equal "row 24: every block call-with-block and call-with-bytes free reads all zeros at the free, after a return, a raise, an escape, odd sizes, an empty bytevector and call-in-section; a block freed unwiped reads 2 and one never freed reads 0; the child ran outside Valgrind with the interposer alone preloaded, and counted no block"
  (list 0 (without-line expected-output dead-line) "")
  (if (and (pair? child-run) (integer? (car child-run)))
      (list (car child-run)
            (without-line (without-line (cadr child-run) no-reuse-line) dead-line)
            (caddr child-run))
      child-run))

(test-equal "row 24 for the verbs: against the decoy, which names each block it is handed, each verb's whole list of (length verdict) is one pair per block, all 1: random-bytes 40; keyed blake2b, its output, input and key; unkeyed, its key named with length 0; the compare's two operands; password-hash, its out block of 128 and its 9-byte password; password-verify, the 94-byte hash string and the password; password-needs-rehash?, the string; and each entry called through native's raw binding on blocks freed with no wipe reads 2 for every block it names; the child ran against the decoy, outside Valgrind, with the interposer alone preloaded, and counted no block"
  (list 0 decoy-expected-output "")
  decoy-run)

(test-end "wipe")

(exit (suite-exit-status runner))
