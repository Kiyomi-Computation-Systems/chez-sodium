#!r6rs
;;; One of the suites that load libsodium end to end, through
;;; (chez-sodium private native), tests/refusal-probe.sps and a decoy
;;; (ADR-0002, ADR-0003, ADR-0006, ADR-0011): this one holds what the decoy
;;; answers for the password hash. The probe's --password-entries mode loads
;;; native, then calls its three raw bindings on blocks from native's
;;; call-with-bytes and call-with-block, and prints each call's answer, the
;;; out block's first 0 and its counts of A5 and 11 bytes, and the log's
;;; growth. One child per switch: the control, pwhash-limits-other,
;;; pwhash-str-fails, -other, -unreadable and -empty, verify-other, and pwhash-blocks
;;; with no FIFO named. A last child reads the constants under strprefix-null.
;;;
;;; Under the memory gate each child runs under a Valgrind of its own, so
;;; the rows are split among the suites, each running at most 14 children,
;;; to keep each well under MEMORY_TIMEOUT (ADR-0011); (library-loading)
;;; holds what they all use.
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

(test-begin "library-loading-password-entries")

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
(define builds (decoy-builds '("control")))

(define (so-of build) (in-scratch (string-append build ".so")))

;; compiled : (Listof (Pairof String Any))
;; Every build, compiled once, in order.
(define compiled (compile-decoys so-of floor-values builds))

(define (compiled-status build) (decoy-status compiled build))

(define control-report (report floor-version 10 3 0))

;; --- the three raw bindings, called ------------------------------------------------------
;; The out block is strbytes bytes of 11 before the call. The decoy writes A5
;; over its own strbytes of it, then the fixed hash string and a 0: the
;; control's string is 93 characters of 128 bytes, so the first 0 is at 93 and
;; 128 - 94 = 34 bytes stay A5; under pwhash-limits-other the string is 140
;; of 160, so the first 0 is at 140 and 160 - 141 = 19 stay A5. The hash
;; string passed to verify and needs-rehash is 2 characters, and the log
;; shows its strlen, 2.

(define str-call "crypto_pwhash_str(p,p,2,1,8192)")
(define verify-call "crypto_pwhash_str_verify(p[2],p,2)")
(define rehash-call "crypto_pwhash_str_needs_rehash(p[2],3,4096)")

;; entries-lines : Integer Any Natural Natural Natural Integer -> (Listof Any)
;; The probe's three lines: crypto-pwhash-str's CODE, FIRST-0, A5 count and
;; 11 count, then crypto-pwhash-str-verify's and -needs-rehash's codes.
(define (entries-lines str-code first-0 a5 filler verify-code rehash-code)
  (list (list 'str str-code first-0 a5 filler str-call)
        (list 'verify verify-code verify-call)
        (list 'rehash rehash-code rehash-call)))

;; entries-row : String (U String #f) (Listof Any) -> Void
;; The probe's whole answer under SWITCH, with CHEZ_SODIUM_DECOY_FIFO unset.
(define (entries-row description switch lines)
  (let ((so (so-of "control")))
    (test-equal (string-append "password entries" (if switch (string-append " under \"" switch "\"") "")
                               ": " description)
      (cons 0 (verb-answer lines))
      (cons (compiled-status "control")
            (probe-with (append (list "-u" "CHEZ_SODIUM_DECOY_FIFO") (list (override so))
                                (switch-args switch))
                        '("--password-entries" "yes"))))))

(entries-row "the control: code 0 with the hash string of 93 characters in 128 bytes, verify 0 and rehash 0"
  #f (entries-lines 0 93 34 0 0 0))

(entries-row "the hash string is 140 characters in 160 bytes, so the out block read is strbytes' 160"
  "pwhash-limits-other" (entries-lines 0 140 19 0 0 0))

(entries-row "crypto_pwhash_str answers -1 and still writes its string"
  "pwhash-str-fails" (entries-lines -1 93 34 0 0 0))

(entries-row "crypto_pwhash_str answers 1 and still writes its string"
  "pwhash-str-other" (entries-lines 1 93 34 0 0 0))

(entries-row "crypto_pwhash_str answers 0 and leaves all 128 bytes A5, with no 0 in them"
  "pwhash-str-unreadable" (entries-lines 0 'none 128 0 0 0))

(entries-row "crypto_pwhash_str answers 0 and leaves 127 bytes A5 after a 0 at index 0"
  "pwhash-str-empty" (entries-lines 0 0 127 0 0 0))

(entries-row "crypto_pwhash_str_verify answers 1; the other two are the control's"
  "verify-other" (entries-lines 0 93 34 0 1 0))

(entries-row "with no FIFO named both collect-safe calls answer -1 at once and write nothing: the out block stays 11"
  "pwhash-blocks" (entries-lines -1 'none 0 128 -1 0))

;; --- the constants, with a NULL prefix ------------------------------------------------------

(let ((so (so-of "control")))
  (test-equal "decoy control under \"strprefix-null\": the prefix is recorded as #f, the other thirteen constants the control's"
    (cons 0 (loaded so 'override
                    (with-constants control-report
                                    (cons (car control-constants) (cons #f (cddr control-constants))))
                    (loaded-calls "strprefix-null")))
    (cons (compiled-status "control")
          (probe-with (cons (override so) (switch-args "strprefix-null"))
                      '("--constants" "yes")))))

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

(test-end "library-loading-password-entries")

(exit (suite-exit-status runner))
