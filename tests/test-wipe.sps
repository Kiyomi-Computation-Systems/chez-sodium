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
;;; A mutant that drops the wipe, shortens it by one byte, or moves it into a
;;; wrapper of PROC leaves some or all of the rows at 2.
(import (rnrs)
        (srfi :64)
        (only (chezscheme) getenv)
        (chez-sodium-testing)
        (only (libsodium-oracle) c-compiler))

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
   ";; The interposer is preloaded already: loading it by path reaches its two functions.\n"
   "(define interposer (cadr (command-line)))\n"
   "(load-shared-object interposer)\n"
   "(define watch-set (foreign-procedure \"watch_set\" (uptr size_t) void))\n"
   "(define watch-verdict (foreign-procedure \"watch_verdict\" () int))\n"
   "(define (fill-a n)\n"
   "  (lambda (b) (let loop ((i 0)) (when (< i n) (foreign-set! 'unsigned-8 b i #x41) (loop (+ i 1))))))\n"
   ";; named: PROC that names its block, N bytes of it, to the interposer.\n"
   "(define (named n) (lambda (b) (watch-set b n) 'ran))\n"
   ";; A row: the interposer cleared first, THUNK run under a catch-all guard,\n"
   ";; then the verdict read once the call has ended.\n"
   "(define (row name thunk)\n"
   "  (watch-set 0 0)\n"
   "  (guard (e (#t #f)) (thunk))\n"
   "  (list name (watch-verdict)))\n"
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
   "              (watch-set 0 0)\n"
   "              ((fill-a 32) b)\n"
   "              (watch-set b 32)\n"
   "              (let ((verdict (watch-verdict)))\n"
   "                (free-foreign-block! b (lambda (address size) #f))\n"
   "                (list 'control-never-freed verdict))))\n"
   "         (m (dead-block-row)))\n"
   "    (list a b c d e f g h i j k m)))\n"
   "(for-each (lambda (r) (write r) (newline)) results)\n"
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

;; run-wipe-child : -> (U (List Integer String String) (List 'raised String))
;; The interposer compiled and the child run, as (STATUS STDOUT STDERR), or
;; (compile EVIDENCE) when the compile failed, or (raised TEXT).
(define (run-wipe-child)
  (guard (e (#t (list 'raised (describe e))))
    (call-with-temp-directory
     (lambda (dir)
       (let* ((so (string-append dir "/libfreewatch.so"))
              (program (string-append dir "/wipe-child.sps"))
              (compiled (capture-command
                         (append (c-compiler getenv)
                                 (list "-Wall" "-Werror" "-shared" "-fPIC" "-o" so
                                       "tests/free-watch.c" "-ldl")))))
         (if (not (= (car compiled) 0))
             (list 'compile compiled)
             (begin
               (write-file program child-program)
               ;; GNU env reads -u only before its first assignment.
               (capture-command
                (list "env" "-u" "CHEZ_SODIUM_GATE_CHILD" (string-append "LD_PRELOAD=" so)
                      (getenv "CHEZ") "--libdirs" "src:tests:build/scheme-libs"
                      "--program" program so)))))))))

(test-begin "wipe")

;; The child runs once. Its line for the dead block is judged apart from the
;; rest: where malloc does not hand back the block just freed, that row says
;; no-reuse and is skipped by name, never passed.
(define child-run (run-wipe-child))

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

(test-end "wipe")

(exit (suite-exit-status runner))
