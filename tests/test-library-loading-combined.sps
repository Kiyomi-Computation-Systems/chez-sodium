#!r6rs
;;; One of the seven suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds the decoy's
;;; builds combined with its behaviours: the kept refusal and the kept load,
;;; with the marker, values that are no switch, the wipe seen in the
;;; decoy's log, what every switch answers, and the log's overflow.
;;; tests/test-library-loading-decoys.sps holds each switch alone.
;;;
;;; The wipe rows read the decoy's log, which is the same when the wipe
;;; writes a block already freed: only the memory gate fails that here, with
;;; Valgrind's invalid write. tests/test-wipe.sps holds it in a plain run
;;; (ADR-0008).
;;;
;;; Under the memory gate each child runs under a Valgrind of its own, so
;;; the rows are split among seven suites, each running at most 14 children,
;;; to keep each well under MEMORY_TIMEOUT (ADR-0011); (library-loading)
;;; holds what all seven use.
;;;
;;; Native loads libsodium in its library body, once per process, and Chez
;;; runs that body before a program's own, so a refusal cannot be caught in
;;; this process, nor a second library tried in it. Every case therefore runs
;;; a probe in a fresh Chez, through `env`, and reads back what it printed,
;;; as data, whole: exit status, every line, and stderr.
;;;
;;; Each child that reaches native code prints its counts, and every row
;;; requires them zero (ADR-0011). Each runs through gated-command, so under
;;; make test-memory the gate's own Valgrind runs it, with a log of its own
;;; that the gate reads. Every child here says whether it ran under Valgrind
;;; (memcheck's preload in /proc/self/maps), and a row requires yes exactly
;;; when the gate asked. A child that escaped the gate fails its row
;;; (ADR-0011).
;;;
;;; This process itself never loads libsodium, and requires as much at its
;;; end. Each expected value is one the code under test cannot produce by
;;; failing, and none is #f: SRFI-64 makes #f of a raise in the actual
;;; expression. Anything that can raise is computed under a guard with a
;;; sentinel. Effects run in order, through let*, named lets and for-each,
;;; never map.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (library-loading)
        (only (chezscheme) file-directory? foreign-entry?))

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

(test-begin "library-loading-combined")

;; The Makefile exports CHEZ, so this suite spawns the Chez that runs it.
;; Without it nothing below can run: fail, never skip.
(test-equal "CHEZ names the Chez to spawn"
  'set
  (if (set? chez) 'set 'unset))

(unless (set? chez)
  (exit 1))

;; --- the scratch directory and the floors ----------------------------------------------

;; scratch : (U String #f)
;; A fresh directory for the decoys. This suite is flat top-level forms, so
;; (chez-sodium-testing) removes the directory when the process ends; the
;; last forms remove it earlier, and the tests below require that.
(define scratch
  (guard (e (#t #f))
    (make-process-temp-directory)))

(test-equal "mktemp -d made a scratch directory"
  'made
  (if (and (absolute? scratch) (file-directory? scratch)) 'made 'not-made))

(unless (and (absolute? scratch) (file-directory? scratch))
  (exit 1))

(define (in-scratch name) (string-append scratch "/" name))

(define floor-values (read-floor-values))

(test-equal "packaging/floors.sexp gives the decoys their versions: the floor, and the version one patch below it"
  'read
  (if (and (= (length floor-values) 2) (string? (car floor-values))) 'read floor-values))

(unless (string? (car floor-values))
  (exit 1))

(define floor-version (car floor-values))
(define below-version (cadr floor-values))

;; builds : (Listof (Pairof String (Listof String)))
;; The builds this suite's rows use.
(define builds (decoy-builds (quote ("control" "marked"))))

(define (so-of build) (in-scratch (string-append build ".so")))

;; compiled : (Listof (Pairof String Any))
;; Every build, compiled once, in order.
(define compiled (compile-decoys so-of floor-values builds))

(define (compiled-status build) (decoy-status compiled build))

;; decoy-row : String (U String #f) (Listof String) String (String -> Expected) -> Void
;; (library-loading)'s decoy-row-in, on this suite's builds.
(define (decoy-row build switch args description expected)
  (decoy-row-in so-of compiled-status build switch args description expected))

(define control-report (report floor-version 10 3 0))
(define (control-calls) (loaded-calls "control"))

;; --- the kept refusal and the kept load ----------------------------------------------------
;; A refusal is kept. Below the floor, then CHEZ_SODIUM_LIBRARY names the
;; marked build, and the probe references loaded-libsodium twice more. Both
;; raise the first refusal again: nothing is loaded or called a second time,
;; and the second library never enters the process (ADR-0002).
(let ((first (so-of "control")) (second (so-of "marked")))
  (test-equal "a refusal is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new"
    (list 0 0
          (outcome 1 (refused-lines 'below-floor first 'override below-version '() (list first))
                   (list (cons 'then-override second)) (list (cons 'marker 'absent))
                   (apply log-of "below-floor" version-calls)))
    (list (compiled-status "control") (compiled-status "marked")
          (probe-with (cons (override first) (switch-args "below-floor"))
                      (list "--then-override" second "--marker" "decoy_marker")))))

;; A load is kept too: loaded, then the override names the marked build.
;; Nothing is loaded again: the later references answer the same record, the
;; log shows one load, and the marked build never enters the process.
(let ((first (so-of "control")) (second (so-of "marked")))
  (test-equal "a load is kept: CHEZ_SODIUM_LIBRARY changed between references loads nothing new"
    (list 0 0
          (outcome 0 (loaded-lines first 'override control-report)
                   (list (cons 'then-override second)) (list (cons 'marker 'absent))
                   (control-calls)))
    (list (compiled-status "control") (compiled-status "marked")
          (probe-with (cons (override first) (switch-args #f))
                      (list "--then-override" second "--marker" "decoy_marker")))))

;; The marker's control: loaded, the marked build's marker is seen.
(decoy-row "marked" #f '("--marker" "decoy_marker")
  "a build with DECOY_MARKER, once loaded, shows its marker to foreign-entry?"
  (lambda (so) (outcome 0 (loaded-lines so 'override control-report) '()
                        (list (cons 'marker 'present)) (control-calls))))

;; --- values that are no switch --------------------------------------------------------------
;; Only an exact value is a switch: a near miss, and an empty value, behave as
;; the control, and the log shows what the decoy read.
(define (no-switch value)
  (lambda (so)
    (loaded so 'override control-report
            (append (list (string-append "decoy(?" value ")")) version-calls (list init-call) size-calls))))

(decoy-row "control" "Below-floor" '()
  "a value that is no switch behaves as the control, and the log names it"
  (no-switch "Below-floor"))

(decoy-row "control" "below-floorX" '()
  "a value that only begins with a switch, below-floorX, is no switch: the control, and the log names it"
  (no-switch "below-floorX"))

(decoy-row "control" "" '()
  "an empty value is no switch either"
  (no-switch ""))

;; --- the wipe, seen from C ------------------------------------------------------------------
;; The probe makes a block of N bytes through call-with-bytes, inside
;; call-in-section, and frees it. The decoy's log then holds the wipe: one
;; sodium_memzero call over the block's size, after the load's calls. An empty
;; bytevector gets a block of one byte, which is wiped too (ADR-0008).
(define (wiped n)
  (lambda (so)
    (list 0
          (append (loaded-lines so 'override control-report)
                  (list once (cons 'wipe 'ok) no-native-objects valgrind-line
                        (cons 'calls (join (append (control-calls)
                                                   (list (string-append "sodium_memzero(p," (number->string n) ")")))))))
          "")))

(let ((so (so-of "control")))
  (test-equal "a block of 5 bytes is wiped by one sodium_memzero call over its 5 bytes"
    (cons 0 ((wiped 5) so))
    (cons (compiled-status "control")
          (probe-with (cons (override so) (switch-args #f)) '("--wipe" "5")))))

(let ((so (so-of "control")))
  (test-equal "an empty bytevector's block of one byte is wiped by one call over 1 byte"
    (cons 0 ((wiped 1) so))
    (cons (compiled-status "control")
          (probe-with (cons (override so) (switch-args #f)) '("--wipe" "0")))))

;; --- what each switch answers, and the log's overflow ------------------------------------
;; The probe's --drive mode loads the decoy itself and binds the verbs' eight
;; entry points with foreign-procedure of its own: the five size functions,
;; randombytes_buf, crypto_generichash and sodium_memcmp. It calls each on
;; blocks it makes with foreign-alloc and prints every answer and every
;; output block, whole. One child per switch: the control, and each of the
;; four others. Each decoy's log, whole, shows every call that was made.
;;
;; The blocks: randombytes_buf is asked for 9 bytes of a block of 10, and
;; crypto_generichash for 7 of a block of 8, each block 11 hex before the
;; call. A5 over exactly the length, and the byte after it still 11, shows
;; both ends. sodium_memcmp is called on equal blocks, on blocks that
;; differ, at length 0 on blocks that differ, and with a NULL operand, first
;; and second, at length 4.

;; written : Natural -> Bytevector
;; A block of N+1 bytes after a call that wrote A5 over N of them, from a
;; block of 11s.
(define (written n)
  (let ((bytes (make-bytevector (+ n 1) #xA5)))
    (bytevector-u8-set! bytes n #x11)
    bytes))

(define drive-calls
  '("randombytes_buf(p,9)" "crypto_generichash(p,7,p,3,p,2)"
    "sodium_memcmp(p,p,4)" "sodium_memcmp(p,p,4)" "sodium_memcmp(p,p,0)"
    "sodium_memcmp(NULL,p,4)" "sodium_memcmp(p,NULL,4)"))

;; The log's end once a thousand more sodium_init calls have filled it, and
;; what one more does: nothing.
(define overflow-lines
  (list (cons 'head "decoy(control)")
        (cons 'tail "sodium_init() sodium_init() overflow")
        (cons 'unmoved 'yes)
        (cons 'overflows 1)
        (cons 'fits 'yes)))

;; driven : (U String #f) (Listof Natural) Integer (Listof Integer) Boolean -> Expected
;; The probe's whole answer under SWITCH: the five SIZES, the answer HASH of
;; crypto_generichash, the five answers MEMCMPS of sodium_memcmp, then the
;; decoy's log, and the overflow's lines when OVERFLOW?.
(define (driven switch sizes hash memcmps overflow?)
  (list 0
        (append (list (cons 'sizes sizes)
                      (cons 'randombytes (written 9))
                      (list 'generichash hash (written 7))
                      (cons 'memcmp memcmps)
                      (cons 'calls (join (append (list (read-switch (or switch "control")))
                                                 size-calls drive-calls))))
                (if overflow? overflow-lines '())
                (list no-native-objects valgrind-line))
        ""))

;; drive-row : String (U String #f) (Listof Natural) Integer (Listof Integer) Boolean -> Void
(define (drive-row description switch sizes hash memcmps overflow?)
  (let ((so (so-of "control")))
    (test-equal description
      (cons 0 (driven switch sizes hash memcmps overflow?))
      (cons (compiled-status "control")
            (probe-with (cons (override so) (switch-args switch))
                        (append '("--drive" "yes") (if overflow? '("--overflow" "yes") '())))))))

(drive-row "the control, called directly: the sizes 32, 16, 64, 16 and 64, A5 over exactly the length, 0, and 0, -1, 0, -1, -1; then a full log ends in one overflow entry and takes nothing more"
  #f control-sizes 0 '(0 -1 0 -1 -1) #t)

(drive-row "sizes-other, called directly: the sizes 33, 8, 80, 9 and 81, and every other answer the control's"
  "sizes-other" other-sizes 0 '(0 -1 0 -1 -1) #f)

(drive-row "generichash-fails, called directly: crypto_generichash answers -1 and still writes A5 over its length"
  "generichash-fails" control-sizes -1 '(0 -1 0 -1 -1) #f)

(drive-row "generichash-other, called directly: crypto_generichash answers 1 and writes A5 over its length"
  "generichash-other" control-sizes 1 '(0 -1 0 -1 -1) #f)

(drive-row "memcmp-other, called directly: equal blocks answer 1, differing ones -1, and length 0 and a NULL operand answer 0 and -1 as ever"
  "memcmp-other" control-sizes 0 '(1 -1 0 -1 -1) #f)

;; --- this process ----------------------------------------------------------------------------

(test-equal "this suite's own process never loaded a libsodium, nor a decoy"
  '(not-loaded not-loaded)
  (list (if (foreign-entry? "sodium_version_string") 'loaded 'not-loaded)
        (if (foreign-entry? "decoy_calls") 'loaded 'not-loaded)))

(test-equal "the scratch directory is removed"
  '(done removed)
  (let* ((removal (guard (e (#t (list 'raised (describe e))))
                    (remove-temp-directory scratch)
                    'done))
         (left (if (file-directory? scratch) 'left 'removed)))
    (list removal left)))

(test-end "library-loading-combined")

(exit (suite-exit-status runner))
