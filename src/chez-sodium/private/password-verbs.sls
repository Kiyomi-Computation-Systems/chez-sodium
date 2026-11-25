#!r6rs
;;; (chez-sodium private password-verbs): the password verbs, password-hash,
;;; password-verify and password-needs-rehash?, and make-password-limits
;;; (ADR-0007, ADR-0009, ADR-0012). It holds no foreign-procedure and no
;;; foreign memory of its own: native binds libsodium and makes every block,
;;; and this library reads foreign memory only through native's helpers.
;;;
;;; Each verb has the shape of the byte verbs (ADR-0007, decisions 1 to 4):
;;;
;;;   1. its arguments are checked, left to right, each one's type before its
;;;      range, and the first mistake is refused before any block exists. A
;;;      password and a hash string are secrets, refused by their kind alone
;;;      through refuse-secret; limits are shown by shown-value
;;;   2. a hash string that fails the pre-check, or, for
;;;      password-needs-rehash?, the shape check, is answered without a
;;;      section and without C; a hash made at other limits does reach C
;;;   3. otherwise its whole extent, the blocks, the writes, the C call, the
;;;      reads and the wipe and free, is one call-in-section, which answers
;;;      data: the hash, the code libsodium gave, or which string changed
;;;   4. what the data says is raised, if at all, after the section
;;;
;;; A password is written into its block as its UTF-8 bytes, straight from its
;;; characters: this library holds no copy of it, and no procedure here
;;; encodes, slices or lists a string. A test reads this file as data to hold
;;; each of these (tests/test-password-verbs.sps).
;;;
;;; Every number a verb checks against is native's, read from libsodium once at
;;; the load. None is written here.
(library (chez-sodium private password-verbs)
  (export password-hash password-verify password-needs-rehash? make-password-limits)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (chez-sodium private native)
          (chez-sodium private conditions)
          (chez-sodium private cap)
          (chez-sodium private password-text))

  ;; The record make-password-limits makes: opaque and sealed, and its type,
  ;; predicate and accessors are not exported, so a Password-limits is made
  ;; only by the constructor, which checks its ranges.
  (define-record-type (limits-record new-limits limits?)
    (sealed #t)
    (opaque #t)
    (fields (immutable ops limits-ops)
            (immutable kib limits-kib)))

  ;; natural? : Any -> Boolean
  ;; Whether X is an exact integer, 0 or more.
  (define (natural? x)
    (and (integer? x) (exact? x) (>= x 0)))

  ;; leave-unwritten : Natural -> Boolean
  ;; The FILL! of an output block: C writes every byte of it.
  (define (leave-unwritten block) #f)

  ;; ops-message : -> String
  ;; The refusal of an opslimit, with libsodium's range as native read it.
  (define (ops-message)
    (string-append "ops is from " (number->string pwhash-opslimit-min)
                   " to " (number->string pwhash-opslimit-max)))

  ;; memory-message : -> String
  ;; The refusal of a memory limit, in KiB, with libsodium's range as native
  ;; read it, the least rounded up and the greatest rounded down.
  (define (memory-message)
    (string-append "memory-kib is from " (number->string (least-kib))
                   " to " (number->string (greatest-kib))))

  ;; least-kib, greatest-kib : -> Natural
  ;; The whole KiB inside libsodium's memory range.
  (define (least-kib) (div (+ pwhash-memlimit-min 1023) 1024))
  (define (greatest-kib) (div pwhash-memlimit-max 1024))

  ;; make-password-limits : Natural Natural -> Password-limits   ; ops, memory in KiB
  ;; Limits for password-hash and password-needs-rehash?: OPS passes of the
  ;; hash and MEMORY-KIB KiB of memory, each within libsodium's range, so a
  ;; Password-limits is always in range. Its first call reads native's numbers,
  ;; which runs the load. Refused from make-password-limits, assertion
  ;; violations, irritants (RULE PARAMETER V), V by shown-value: not-a-natural
  ;; and ops-out-of-range for OPS, then not-a-natural and memory-out-of-range
  ;; for MEMORY-KIB.
  (define (make-password-limits ops memory-kib)
    (unless (natural? ops)
      (assertion-violation 'make-password-limits "ops is not an exact natural"
                           'not-a-natural 'ops (shown-value ops)))
    (unless (and (>= ops pwhash-opslimit-min) (<= ops pwhash-opslimit-max))
      (assertion-violation 'make-password-limits (ops-message)
                           'ops-out-of-range 'ops (shown-value ops)))
    (unless (natural? memory-kib)
      (assertion-violation 'make-password-limits "memory-kib is not an exact natural"
                           'not-a-natural 'memory-kib (shown-value memory-kib)))
    (unless (and (>= memory-kib (least-kib)) (<= memory-kib (greatest-kib)))
      (assertion-violation 'make-password-limits (memory-message)
                           'memory-out-of-range 'memory-kib (shown-value memory-kib)))
    (new-limits ops memory-kib))

  ;; resolve-limits : Symbol Any -> (Pair Natural Natural)
  ;; LIMITS as the opslimit and the memlimit in bytes: a preset's pair, as
  ;; native read it, or a Password-limits' ops and its KiB times 1024. Anything
  ;; else is refused from WHO, irritants (not-password-limits limits V), V by
  ;; shown-value: a string is shown by its kind alone.
  (define (resolve-limits who limits)
    (cond ((eq? limits 'interactive)
           (cons pwhash-opslimit-interactive pwhash-memlimit-interactive))
          ((eq? limits 'moderate)
           (cons pwhash-opslimit-moderate pwhash-memlimit-moderate))
          ((eq? limits 'sensitive)
           (cons pwhash-opslimit-sensitive pwhash-memlimit-sensitive))
          ((limits? limits)
           (cons (limits-ops limits) (* 1024 (limits-kib limits))))
          (else
           (assertion-violation who "limits is not a preset or Password-limits"
                                'not-password-limits 'limits (shown-value limits)))))

  ;; check-password : Symbol Any -> Natural
  ;; PASSWORD's UTF-8 length, when PASSWORD is a string within the cap and
  ;; within libsodium's length range. Else refused from WHO through
  ;; refuse-secret, by kind alone: not-a-string, then over-the-cap, bound 0 to
  ;; the cap, then length-out-of-range, bound libsodium's range.
  (define (check-password who password)
    (unless (string? password)
      (refuse-secret who 'not-a-string 'password password))
    (let ((n (utf8-length password)))
      (unless (<= n input-cap)
        (refuse-secret who 'over-the-cap 'password password 0 input-cap))
      (unless (and (>= n pwhash-passwd-min) (<= n pwhash-passwd-max))
        (refuse-secret who 'length-out-of-range 'password password
                       pwhash-passwd-min pwhash-passwd-max))
      n))

  ;; password-hash : String [Limits] -> String
  ;;   Limits = (U 'interactive 'moderate 'sensitive Password-limits), by default 'interactive
  ;; A hash string of PASSWORD, its UTF-8 bytes exactly as given, at LIMITS:
  ;; libsodium's own string, a fresh Scheme string. PASSWORD is a secret, shown
  ;; by its kind alone. Refused before any block, from password-hash,
  ;; assertion violations: not-a-string, over-the-cap and length-out-of-range
  ;; for PASSWORD, irritants (RULE password (kind K)), then not-password-limits
  ;; for LIMITS. Libsodium answering anything but 0, or answering 0 with no
  ;; string that passes the pre-check, an empty one included, raises a
  ;; &sodium-failed after the section, its function "crypto_pwhash_str" and
  ;; its code the answer, 0 for no string. A PASSWORD
  ;; another thread changed during the call is refused after the section,
  ;; (changed-during-call password (kind string)).
  (define password-hash
    (case-lambda
      ((password) (password-hash password 'interactive))
      ((password limits)
       (let* ((n (check-password 'password-hash password))
              (pair (resolve-limits 'password-hash limits))
              (outcome
               (call-in-section
                (lambda ()
                  (call-with-utf8 'password-hash password n
                    (lambda (in)
                      (call-with-block 'password-hash pwhash-strbytes leave-unwritten
                        (lambda (out)
                          (let ((code (crypto-pwhash-str out in n (car pair) (cdr pair))))
                            (if (eqv? code 0)
                                (let ((hash (foreign-ascii-string out pwhash-strbytes)))
                                  (if (and hash (readable-hash-string? hash))
                                      (cons 'hash hash)
                                      (cons 'failed 0)))
                                (cons 'failed code))))))
                    (lambda () (cons 'changed 'password)))))))
         (cond ((eq? (car outcome) 'hash) (cdr outcome))
               ((eq? (car outcome) 'failed)
                (raise-sodium-failed 'password-hash "crypto_pwhash_str" (cdr outcome)))
               (else
                (refuse-secret 'password-hash 'changed-during-call 'password password)))))))

  ;; password-verify : String String -> Boolean   ; hash, password
  ;; Whether PASSWORD is the one HASH was made from. #f for a wrong password,
  ;; and for a HASH libsodium cannot read or that fails the pre-check, which
  ;; calls no C, and for any other answer of libsodium, short memory included.
  ;; HASH and PASSWORD are secrets, shown by their kind alone. Every refusal
  ;; comes before the pre-check, from password-verify, assertion violations:
  ;; not-a-string for HASH, then not-a-string, over-the-cap and
  ;; length-out-of-range for PASSWORD, irritants (RULE PARAMETER (kind K)). A
  ;; HASH or a PASSWORD another thread changed during the call is refused after
  ;; the section, (changed-during-call PARAMETER (kind string)).
  (define (password-verify hash password)
    (unless (string? hash)
      (refuse-secret 'password-verify 'not-a-string 'hash hash))
    (let ((n (check-password 'password-verify password)))
      (if (not (readable-hash-string? hash))
          #f
          (let ((outcome
                 (call-in-section
                  (lambda ()
                    (call-with-c-string 'password-verify hash
                      (lambda (str)
                        (call-with-utf8 'password-verify password n
                          (lambda (in)
                            (cons 'code (crypto-pwhash-str-verify str in n)))
                          (lambda () (cons 'changed 'password))))
                      (lambda () (cons 'changed 'hash)))))))
            (cond ((eq? (car outcome) 'code) (eqv? (cdr outcome) 0))
                  ((eq? (cdr outcome) 'hash)
                   (refuse-secret 'password-verify 'changed-during-call 'hash hash))
                  (else
                   (refuse-secret 'password-verify 'changed-during-call 'password password)))))))

  ;; password-needs-rehash? : String [Limits] -> Boolean   ; hash
  ;; #t for any HASH that is not what password-hash would make now at LIMITS:
  ;; other limits, a string libsodium cannot read, one that fails the pre-check,
  ;; a prefix other than the loaded library's, or parameters that do not read
  ;; p=1; #f otherwise. The last three are answered without a section and
  ;; without C. It never raises because of HASH, a HASH another thread changed
  ;; during the call included, which answers #t. Refused from
  ;; password-needs-rehash?, assertion violations: not-a-string for HASH,
  ;; irritants (not-a-string hash (kind K)), then not-password-limits for LIMITS.
  (define password-needs-rehash?
    (case-lambda
      ((hash) (password-needs-rehash? hash 'interactive))
      ((hash limits)
       (unless (string? hash)
         (refuse-secret 'password-needs-rehash? 'not-a-string 'hash hash))
       (let ((pair (resolve-limits 'password-needs-rehash? limits)))
         (if (and (readable-hash-string? hash)
                  (current-hash-shape? hash pwhash-strprefix))
             (let ((outcome
                    (call-in-section
                     (lambda ()
                       (call-with-c-string 'password-needs-rehash? hash
                         (lambda (str)
                           (cons 'code (crypto-pwhash-str-needs-rehash str (car pair) (cdr pair))))
                         (lambda () (cons 'changed 'hash)))))))
               (not (and (eq? (car outcome) 'code) (eqv? (cdr outcome) 0))))
             #t))))))
