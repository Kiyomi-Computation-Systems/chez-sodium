#!r6rs
;;; tests/preflight.sps: what `make build` runs. chez-sodium compiles nothing
;;; (ADR-0001), so build answers the question an install raises instead:
;;; which libsodium would chez-sodium load here, and does it accept it?
;;;
;;; Accepted: it prints the path and its source, and the version with the
;;; library's libtool major and minor, on stdout, and exits 0. Refused: it
;;; prints (reason . SYMBOL), then the path, the source, the detail, every
;;; candidate checked and a one-line remedy, on stderr, and exits 1. Either way
;;; its last line is its counts, (chez-sodium private counters)'
;;; native-counts. The reason is the contract; the rest is for the reader
;;; (ADR-0002). Anything else raised is a bug, not a refusal, and is left to
;;; Chez's default handler, which exits non-zero.
;;;
;;; It does not import (chez-sodium private native): Chez would run native's
;;; body, which is the load, before this program's guard could catch a
;;; refusal. It evaluates (loaded-libsodium) in native's environment inside
;;; the guard instead. The public (chez-sodium) loads the same way, so a
;;; program cannot guard its import either.
(import (rnrs)
        (only (chezscheme) eval environment)
        (chez-sodium private conditions)
        (chez-sodium private counters))

;; say : Output-Port Any ... -> Void
;; PARTS displayed, then a newline.
(define (say port . parts)
  (for-each (lambda (part) (display part port)) parts)
  (newline port))

(define (or-none value) (or value "none"))

;; say-counts : Output-Port -> Void
;; The last line: every native count, as native-counts gives them.
(define (say-counts port)
  (display "  counts:     " port)
  (write (native-counts) port)
  (newline port))

(guard (e ((sodium-library-unavailable? e)
           (let ((err (current-error-port))
                 (candidates (sodium-library-unavailable-candidates e)))
             (say err "chez-sodium: libsodium refused")
             (write (cons 'reason (sodium-library-unavailable-reason e)) err)
             (newline err)
             (say err "  path:       " (or-none (sodium-library-unavailable-path e)))
             (say err "  source:     " (or-none (sodium-library-unavailable-source e)))
             (say err "  detail:     " (or-none (sodium-library-unavailable-detail e)))
             (if (null? candidates)
                 (say err "  candidates: none")
                 (begin
                   (say err "  candidates:")
                   (for-each (lambda (path) (say err "    " path)) candidates)))
             (say err "  remedy:     " (if (message-condition? e)
                                            (condition-message e)
                                            "name a usable libsodium with CHEZ_SODIUM_LIBRARY, an absolute path"))
             (say-counts err)
             (exit 1))))
  (let ((info (eval '(loaded-libsodium) (environment '(chez-sodium private native))))
        (out (current-output-port)))
    (say out "chez-sodium: libsodium loaded and accepted")
    (say out "  path:       " (cdr (assq 'path info)) " (" (cdr (assq 'source info)) ")")
    (say out "  version:    " (cdr (assq 'version info))
         " (library " (cdr (assq 'major info)) "." (cdr (assq 'minor info)) ")")
    (say-counts out)
    (exit 0)))
