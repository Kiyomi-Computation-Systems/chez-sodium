#!r6rs
;;; (chez-sodium private native): loads libsodium, once, and binds it
;;; (ADR-0001, ADR-0002, ADR-0007, ADR-0008). The only library that calls
;;; into libsodium.
;;;
;;; Its body is the load, in ADR-0002's order. A library body evaluates its
;;; definitions in order, so the order below is the order at run time. Nothing
;;; binds lazily:
;;;
;;;   0. once        a failure recorded by an earlier run of this body is
;;;                  raised again, before anything else runs
;;;   1. choose      (chez-sodium private discovery) picks the path and its
;;;                  source, from getenv, the machine type, /proc/self/maps'
;;;                  text and file-exists?
;;;   2. load        load-shared-object, once. A raise is load-failed, and no
;;;                  other candidate is ever tried: a library once loaded
;;;                  cannot be unloaded, and Chez binds each name to the most
;;;                  recently loaded object
;;;   3. versions    sodium_version_string, sodium_library_version_major and
;;;                  sodium_library_version_minor, bound and called once each.
;;;                  They answer before sodium_init. A NULL string is #f
;;;   4. the floor   check-version, from the string alone: major and minor are
;;;                  libtool numbers, recorded and never compared (ADR-0003)
;;;   5. init        sodium_init, bound and called once; 0 and 1 load, any
;;;                  other answer is init-failed, and the answer is recorded
;;;   6. the rest    every other entry point, bound eagerly: sodium_memzero,
;;;                  then randombytes_buf, crypto_generichash, its five size
;;;                  functions and sodium_memcmp. Each later verb's entry
;;;                  points are appended here. Each binding a verb calls has
;;;                  one pair in the answers; a size function has none, and
;;;                  its value has one, from step 7
;;;   7. the sizes   crypto_generichash's five size functions, each called
;;;                  once, its answer recorded: the verbs check against these
;;;                  numbers, and no size is written in Scheme (ADR-0001)
;;;
;;; Steps 1 to 7 are the let* of one definition, load-answers, run inside one
;;; call-in-section: dlopen, every bind, sodium_init and the size calls happen
;;; in one critical section, which answers data (ADR-0007, decision 9). Our
;;; own pure code refuses inside it, and the guard of call-in-section raises the refusal
;;; again once the section has ended, where load-step, outside it, makes the
;;; raise serious, records it and raises it. So no caller's handler runs
;;; inside the section. An engine spends no ticks inside a section, so the
;;; load is never abandoned half-done by an expiry; one abandoned before the
;;; section starts leaves the library wedged, which no code closes, and every
;;; engine row references native once before its first engine.
;;;
;;; The load runs once per process, whatever it decides. Chez runs a library
;;; body that raised again at every later reference, so load-answers runs
;;; inside load-step, from (chez-sodium private load-state), which records the
;;; first failure and raises it, made serious. Step 0 raises that recorded
;;; failure at every later reference: nothing is loaded twice, and a
;;; CHEZ_SODIUM_LIBRARY changed in between is never read (ADR-0002).
;;;
;;; foreign-procedure resolves its entry point when it is evaluated, so a
;;; binding must follow the load, and an entry point the library lacks fails
;;; with Chez's bare "no entry for". So every entry point is asked of
;;; foreign-entry? first, and an absent one is missing-api, naming it. Every
;;; binding is a literal foreign-procedure form, the whole second argument of
;;; bind-required, and the whole init of its let* binding:
;;;
;;;   (NAME (bind-required chosen
;;;           (foreign-procedure [CONVENTION] "C_NAME" (ARG-TYPE ...) RESULT-TYPE)))
;;;
;;; so the convention suite reads each binding at its use, as data, and the
;;; entry point bind-required checks is the one the form binds: the binder
;;; takes the name from the form. CHOSEN is the pair (PATH . SOURCE) of step 1,
;;; which every refusal carries.
;;;
;;; No binding takes a Scheme object: every argument is an integer or the
;;; address of a counted block, and every pointer is a uptr, never Chez's
;;; string, utf-8, u8* or scheme-object types, nor a bytevector (ADR-0001).
;;; Every binding here is plain: none is known to wait, and none is
;;; __collect_safe.
;;;
;;; Strings and bytes cross in counted blocks (ADR-0001). call-with-bytes
;;; hands C a copy of a bytevector's bytes in a counted block of at least one
;;; byte, so an empty value is never NULL, read in place and written straight
;;; into the block, with no Scheme copy of it (ADR-0008); foreign-bytes copies
;;; a counted run out of a pointer; c-string->bytevector copies the bytes up to
;;; a NUL, undecoded; and c-string->string decodes what it reads. No other
;;; library may read or write foreign memory (check-seam).
;;;
;;; Each block is freed when PROC returns, raises or escapes, and a PROC
;;; re-entered after that raises. Every block is wiped first, by one
;;; sodium_memzero call inside the critical cleanup, handed to
;;; free-foreign-block! and run between its check that the block is live and
;;; its free (ADR-0008): never in a wrapper of PROC, where the block is already
;;; freed, and never as a foreign-set! loop. foreign-block and
;;; free-foreign-block! appear in call-with-block's definition alone, so every
;;; block is made and freed there (ADR-0012).
;;;
;;; Each helper that takes a WHO is given the name of the public procedure it
;;; serves, so its refusals name that one. A bytevector is a secret: its
;;; refusal names the parameter and its kind alone (ADR-0006). None raises
;;; inside the critical thunks that make and free its block: a raise there
;;; would reach a with-exception-handler handler with interrupts still
;;; disabled. An engine's expiry unwinds the extent and frees the block, and
;;; its resume is a re-entry, so a verb holds the whole extent in one
;;; call-in-section, and raises what it caught there after it.
;;;
;;; Every refusal of the load is a &sodium-library-unavailable, raised through
;;; raise-library-unavailable, carrying the path and its source. The reasons
;;; raised here, beside those of discovery and verify:
;;;
;;;   load-failed  the loader refused the path (detail: its message)
;;;   missing-api  a required entry point is absent (detail: its C name)
;;;
;;; The version, major, minor and sodium_init's answer are native's record of
;;; the load; the verbs' exports are (chez-sodium)'s (ADR-0012).
(library (chez-sodium private native)
  (export loaded-libsodium sodium-version
          sodium-version-string sodium-library-version-major sodium-library-version-minor
          sodium-init sodium-memzero
          randombytes-buf crypto-generichash sodium-memcmp
          generichash-bytes generichash-bytes-min generichash-bytes-max
          generichash-keybytes-min generichash-keybytes-max
          call-in-section call-with-block call-with-bytes foreign-bytes
          c-string->bytevector c-string->string)
  (import (chez-sodium private require-threaded)
          (except (rnrs) dynamic-wind)
          (only (chezscheme) critical-section display-condition dynamic-wind foreign-entry?
                foreign-procedure foreign-ref foreign-set! format format-condition? getenv
                load-shared-object machine-type)
          (chez-sodium private load-state)
          (chez-sodium private conditions)
          (chez-sodium private memory)
          (chez-sodium private discovery)
          (chez-sodium private verify))

  ;; --- 0. once -------------------------------------------------------------------

  ;; The first definition: an earlier run of this body failed, and that
  ;; failure is raised again. The steps below never run twice.
  (define earlier-failure
    (let ((failure (load-failure)))
      (when failure (raise failure))
      #f))

  ;; --- helpers -------------------------------------------------------------------

  ;; call-in-section : (-> A) -> A
  ;; THUNK's answer, run in one critical section. A raise inside, of any
  ;; object, is caught there and raised again, the same object, once the
  ;; section has ended, so a handler of it runs with interrupts enabled. THUNK
  ;; answers data, and a verb raises what that data says after the call: for a
  ;; verb the guard is a net for a bug, not a channel. The tags are a fresh
  ;; list per call, so an answer shaped like (raised X) is an answer, never a
  ;; raise (ADR-0007, decision 7).
  (define (call-in-section thunk)
    (let ((outcome (critical-section
                    (guard (c (#t (list 'raised c)))
                      (list 'answered (thunk))))))
      (if (eq? (car outcome) 'answered)
          (cadr outcome)
          (raise (cadr outcome)))))

  ;; linux-machine? : Symbol -> Boolean
  ;; Chez's Linux machine types end in le: ta6le, tarm64le.
  (define (linux-machine? type)
    (let* ((name (symbol->string type)) (n (string-length name)))
      (and (>= n 2) (string=? (substring name (- n 2) n) "le"))))

  ;; maps-text : -> (U String #f)
  ;; /proc/self/maps, read whole, on Linux; #f on any failure, and on any
  ;; other platform. Discovery reads the world from it.
  (define (maps-text)
    (and (linux-machine? (machine-type))
         (guard (e (#t #f))
           (let ((text (call-with-port
                        (open-file-input-port "/proc/self/maps" (file-options)
                                              (buffer-mode block)
                                              (make-transcoder (utf-8-codec)))
                        get-string-all)))
             (and (string? text) text)))))

  ;; loader-message : Condition -> String
  ;; What the loader said, as Chez would print it after "Exception: ".
  (define (loader-message e)
    (if (and (format-condition? e) (message-condition? e) (irritants-condition? e))
        (apply format (condition-message e) (condition-irritants e))
        (call-with-string-output-port (lambda (p) (display-condition e p)))))

  ;; required-entry : String (Pair String Symbol) -> Void
  ;; Raises missing-api, naming NAME and carrying WHERE's path and source,
  ;; unless the loaded library has NAME. WHERE is step 1's (PATH . SOURCE).
  (define (required-entry name where)
    (unless (foreign-entry? name)
      (raise-library-unavailable
       'missing-api (car where) (cdr where) name '()
       (string-append "the library has no " name
                      ", so it is not a libsodium chez-sodium can use; name another with CHEZ_SODIUM_LIBRARY")
       (list (car where)))))

  ;; (bind-required WHERE (foreign-procedure CONVENTION ... ENTRY (ARG-TYPE ...) RESULT-TYPE))
  ;; The foreign-procedure form's value, once required-entry has found ENTRY
  ;; in the loaded library, carrying WHERE, the chosen path and source, if
  ;; not. The form is the binding, literal at its use, and the name checked is
  ;; the one it binds. Anything else in its place is a syntax violation.
  ;; Internal: check-seam rule (k) lets native export no macro.
  (define-syntax bind-required
    (lambda (x)
      (syntax-case x ()
        ((_ where (fp convention ... entry (arg ...) result))
         (and (identifier? #'fp)
              (free-identifier=? #'fp #'foreign-procedure)
              (string? (syntax->datum #'entry)))
         #'(begin
             (required-entry entry where)
             (fp convention ... entry (arg ...) result))))))

  ;; exact-natural? : Any -> Boolean
  (define (exact-natural? x)
    (and (integer? x) (exact? x) (>= x 0)))

  ;; check-who : Symbol Any -> Void
  ;; HELPER's refusal of a WHO that is no symbol. A WHO is a procedure's name,
  ;; never a secret.
  (define (check-who helper who)
    (unless (symbol? who)
      (assertion-violation helper "a who is a symbol" (shown-value who))))

  ;; call-with-block : Symbol Positive-Integer (Positive-Integer -> Any)
  ;;                   (Positive-Integer -> A) -> A
  ;; PROC's answer, PROC given the address of a counted block of SIZE bytes
  ;; that FILL! has written. The block is wiped, then freed, once PROC returns,
  ;; raises or escapes, and re-entering PROC through a continuation after that
  ;; raises an assertion violation from WHO, so the address is never used
  ;; after. The block's extent is a critical dynamic-wind: its before thunk,
  ;; with the block's making, and its after thunk, with the block's wipe and
  ;; freeing, each run in one critical section with the record that the extent
  ;; was entered or left, so no escaping interrupt leaves a block made and
  ;; unrecorded.
  ;;
  ;; Neither critical thunk raises. Each records what it caught, and the
  ;; raise follows, from a plain thunk of a dynamic-wind around the block's:
  ;;   - a re-entry: from its before thunk, before the block's extent is
  ;;     entered again, so no second block is made. A resume between the free
  ;;     and the end of the outer extent is refused too, though PROC has
  ;;     returned: a window of a few instructions, from the inner wind's exit
  ;;     to the outer's;
  ;;   - a block that could not be made: from the body, before FILL!;
  ;;   - a free that failed, as when PROC freed the block itself: from its
  ;;     after thunk, once the block's extent is left. That block is dead, so
  ;;     free-foreign-block! refuses it before it wipes anything.
  (define (call-with-block who size fill! proc)
    (let ((block #f)
          (freed #f)
          (make-failure #f)
          (free-failure #f))
      (dynamic-wind
        ;; Latent: a raise that left PROC under a guard that did not match it
        ;; would be handed on from inside PROC's extent, which re-enters this
        ;; thunk, and the refusal below would replace the raise. No raise gets
        ;; that far, since every verb makes its blocks inside call-in-section,
        ;; whose guard takes every object. Whoever makes a block outside it,
        ;; or narrows its guard, must meet this first.
        (lambda ()
          (when freed
            (assertion-violation who "re-entered after its block was freed")))
        (lambda ()
          (dynamic-wind #t
            (lambda ()
              (set! make-failure
                    (guard (c (#t (list c)))
                      (set! block (foreign-block size))
                      #f)))
            (lambda ()
              (when make-failure (raise (car make-failure)))
              (fill! block)
              (proc block))
            (lambda ()
              (set! freed #t)
              (when block
                (let ((made block))
                  (set! block #f)
                  (set! free-failure
                        (guard (c (#t (list c)))
                          (free-foreign-block! made sodium-memzero)
                          #f)))))))
        (lambda ()
          (when free-failure
            (let ((failure (car free-failure)))
              (set! free-failure #f)
              (raise failure)))))))

  ;; c-string->string : Natural -> (U String #f)
  ;; The NUL-terminated string at ADDRESS, read byte by byte up to its NUL,
  ;; into a bytevector of exactly that length, and decoded as UTF-8; #f for
  ;; NULL. The decoding is lenient: an invalid byte is replaced, never
  ;; refused. Chez's utf8->string drops one leading U+FEFF, so when the bytes
  ;; begin EF BB BF the string begins U+FEFF. That matters here: the version
  ;; string EF BB BF then 1.0.18 would otherwise read as "1.0.18" and pass the
  ;; floor, where the string it is, U+FEFF then 1.0.18, is no version, and
  ;; check-version refuses it. An ADDRESS that is no exact natural is an
  ;; assertion violation.
  (define (c-string->string address)
    (unless (exact-natural? address)
      (assertion-violation 'c-string->string "an address is an exact non-negative integer"
                           (shown-value address)))
    (let ((bytes (c-string->bytevector address)))
      (and bytes
           (let ((n (bytevector-length bytes))
                 (decoded (utf8->string bytes)))
             (if (and (>= n 3) (eqv? (bytevector-u8-ref bytes 0) #xEF)
                      (eqv? (bytevector-u8-ref bytes 1) #xBB)
                      (eqv? (bytevector-u8-ref bytes 2) #xBF))
                 (string-append (string #\xFEFF) decoded)
                 decoded)))))

  ;; c-string->bytevector : Natural -> (U Bytevector #f)
  ;; The bytes of the NUL-terminated string at ADDRESS, up to its NUL and
  ;; without it, undecoded, in a fresh bytevector of exactly that length; #f
  ;; for NULL. c-string->string decodes what it answers. An ADDRESS that is no
  ;; exact natural is an assertion violation, by shown-value.
  (define (c-string->bytevector address)
    (unless (exact-natural? address)
      (assertion-violation 'c-string->bytevector "an address is an exact non-negative integer"
                           (shown-value address)))
    (and (not (eqv? address 0))
         (foreign-bytes address
                        (let scan ((i 0))
                          (if (eqv? (foreign-ref 'unsigned-8 address i) 0) i (scan (+ i 1)))))))

  ;; foreign-bytes : Natural Natural -> Bytevector
  ;; The N bytes at ADDRESS, read with foreign-ref, in a fresh bytevector: a
  ;; run C answered, for the count it answered. N of 0 answers an empty one,
  ;; and reads nothing, NULL included. An ADDRESS or an N that is no exact
  ;; natural, and NULL with N above 0, are assertion violations from
  ;; foreign-bytes, their irritants the field, address or count, then the
  ;; value by shown-value, or null-address and N.
  (define (foreign-bytes address n)
    (unless (exact-natural? address)
      (assertion-violation 'foreign-bytes "an address is an exact non-negative integer"
                           'address (shown-value address)))
    (unless (exact-natural? n)
      (assertion-violation 'foreign-bytes "a count of bytes is an exact non-negative integer"
                           'count (shown-value n)))
    (when (and (eqv? address 0) (> n 0))
      (assertion-violation 'foreign-bytes "NULL holds no bytes to read" 'null-address n))
    (let ((bytes (make-bytevector n)))
      (let fill ((i 0))
        (when (< i n)
          (bytevector-u8-set! bytes i (foreign-ref 'unsigned-8 address i))
          (fill (+ i 1))))
      bytes))

  ;; call-with-bytes : Symbol Bytevector (Positive-Integer -> A) -> A
  ;; PROC's answer, PROC given the address of a counted block of (max 1 N)
  ;; bytes holding BYTES' N bytes, written with foreign-set!, wiped and freed
  ;; once PROC returns, raises or escapes, by call-with-block. An empty BYTES
  ;; gets a block of one byte, written 0, so the address is never NULL.
  ;; BYTES is read in place, N read once, and never copied: a bytevector's
  ;; length cannot change, so the read is memory-safe, and no Scheme copy of a
  ;; secret is made (ADR-0008, decision 4). A WHO that is no symbol is an
  ;; assertion violation from call-with-bytes; a BYTES that is no bytevector
  ;; is refused through refuse-secret from WHO, irritants (not-a-bytevector
  ;; bytes (kind K)), and a PROC that is no procedure, from WHO, by
  ;; shown-value; each before anything is allocated. Re-entering PROC after
  ;; the free raises from WHO.
  (define (call-with-bytes who bytes proc)
    (check-who 'call-with-bytes who)
    (unless (bytevector? bytes)
      (refuse-secret who 'not-a-bytevector 'bytes bytes))
    (unless (procedure? proc)
      (assertion-violation who "not a procedure" (shown-value proc)))
    (let ((n (bytevector-length bytes)))
      (call-with-block who (max 1 n)
        (lambda (block)
          (if (= n 0)
              (foreign-set! 'unsigned-8 block 0 0)
              (let loop ((i 0))
                (when (< i n)
                  (foreign-set! 'unsigned-8 block i (bytevector-u8-ref bytes i))
                  (loop (+ i 1))))))
        proc)))

  ;; --- 1 to 7. the load, in one section ------------------------------------------

  ;; The load's answers, as an alist: the record of the load, each raw
  ;; binding, and the sizes. The let* is the order of the steps above. A later
  ;; verb's entry points are bound by inits appended after raw-memcmp, before
  ;; the sizes are read, with one pair each added to the answers.
  (define load-answers
    (load-step
     (call-in-section
      (lambda ()
        (let* ((chosen (call-with-values
                        (lambda ()
                          (choose-libsodium getenv (machine-type) (maps-text) file-exists?))
                        cons))
               (libsodium-loaded
                (guard (e (#t (raise-library-unavailable
                               'load-failed (car chosen) (cdr chosen) (loader-message e) '()
                               "the loader refused this libsodium; name one this Chez can load with CHEZ_SODIUM_LIBRARY, an absolute path"
                               (list (car chosen)))))
                  (load-shared-object (car chosen))
                  #t))
               ;; const char *sodium_version_string(void)
               (raw-version-string
                (bind-required chosen
                  (foreign-procedure "sodium_version_string" () uptr)))
               ;; int sodium_library_version_major(void)
               (raw-major
                (bind-required chosen
                  (foreign-procedure "sodium_library_version_major" () int)))
               ;; int sodium_library_version_minor(void)
               (raw-minor
                (bind-required chosen
                  (foreign-procedure "sodium_library_version_minor" () int)))
               (version (c-string->string (raw-version-string)))
               (major (raw-major))
               (minor (raw-minor))
               (version-checked (check-version version (car chosen) (cdr chosen)))
               ;; int sodium_init(void)
               ;; 0 the first time, 1 once it has been called, -1 when it
               ;; failed. Thread-safe.
               (raw-init
                (bind-required chosen
                  (foreign-procedure "sodium_init" () int)))
               (init (raw-init))
               (init-checked (check-init init (car chosen) (cdr chosen)))
               ;; void sodium_memzero(void * const pnt, const size_t len)
               (raw-memzero
                (bind-required chosen
                  (foreign-procedure "sodium_memzero" (uptr size_t) void)))
               ;; void randombytes_buf(void * const buf, const size_t size)
               (raw-randombytes-buf
                (bind-required chosen
                  (foreign-procedure "randombytes_buf" (uptr size_t) void)))
               ;; int crypto_generichash(unsigned char *out, size_t outlen,
               ;;                        const unsigned char *in, unsigned long long inlen,
               ;;                        const unsigned char *key, size_t keylen)
               (raw-generichash
                (bind-required chosen
                  (foreign-procedure "crypto_generichash" (uptr size_t uptr unsigned-64 uptr size_t)
                                     int)))
               ;; size_t crypto_generichash_bytes(void)
               (raw-generichash-bytes
                (bind-required chosen
                  (foreign-procedure "crypto_generichash_bytes" () size_t)))
               ;; size_t crypto_generichash_bytes_min(void)
               (raw-generichash-bytes-min
                (bind-required chosen
                  (foreign-procedure "crypto_generichash_bytes_min" () size_t)))
               ;; size_t crypto_generichash_bytes_max(void)
               (raw-generichash-bytes-max
                (bind-required chosen
                  (foreign-procedure "crypto_generichash_bytes_max" () size_t)))
               ;; size_t crypto_generichash_keybytes_min(void)
               (raw-generichash-keybytes-min
                (bind-required chosen
                  (foreign-procedure "crypto_generichash_keybytes_min" () size_t)))
               ;; size_t crypto_generichash_keybytes_max(void)
               (raw-generichash-keybytes-max
                (bind-required chosen
                  (foreign-procedure "crypto_generichash_keybytes_max" () size_t)))
               ;; int sodium_memcmp(const void *const b1_, const void *const b2_, size_t len)
               (raw-memcmp
                (bind-required chosen
                  (foreign-procedure "sodium_memcmp" (uptr uptr size_t) int)))
               (bytes (raw-generichash-bytes))
               (bytes-min (raw-generichash-bytes-min))
               (bytes-max (raw-generichash-bytes-max))
               (keybytes-min (raw-generichash-keybytes-min))
               (keybytes-max (raw-generichash-keybytes-max)))
          (list (cons 'path (car chosen)) (cons 'source (cdr chosen))
                (cons 'version version) (cons 'major major) (cons 'minor minor)
                (cons 'init init)
                (cons 'sodium-version-string raw-version-string)
                (cons 'sodium-library-version-major raw-major)
                (cons 'sodium-library-version-minor raw-minor)
                (cons 'sodium-init raw-init)
                (cons 'sodium-memzero raw-memzero)
                (cons 'randombytes-buf raw-randombytes-buf)
                (cons 'crypto-generichash raw-generichash)
                (cons 'sodium-memcmp raw-memcmp)
                (cons 'generichash-bytes bytes)
                (cons 'generichash-bytes-min bytes-min)
                (cons 'generichash-bytes-max bytes-max)
                (cons 'generichash-keybytes-min keybytes-min)
                (cons 'generichash-keybytes-max keybytes-max)))))))

  ;; answer : Symbol -> Any
  ;; KEY's value among the load's answers. Every element is a pair, so this
  ;; cannot raise for a key the load made.
  (define (answer key)
    (cdr (assq key load-answers)))

  (define libsodium-path (answer 'path))
  (define libsodium-source (answer 'source))
  (define libsodium-version (answer 'version))
  (define libsodium-major (answer 'major))
  (define libsodium-minor (answer 'minor))
  (define libsodium-init (answer 'init))

  ;; sodium-version-string : -> Natural
  ;; const char *sodium_version_string(void): the address of libsodium's
  ;; version string, for c-string->string.
  (define sodium-version-string (answer 'sodium-version-string))

  ;; sodium-library-version-major : -> Integer
  ;; int sodium_library_version_major(void): a libtool number, never compared.
  (define sodium-library-version-major (answer 'sodium-library-version-major))

  ;; sodium-library-version-minor : -> Integer
  ;; int sodium_library_version_minor(void): a libtool number, never compared.
  (define sodium-library-version-minor (answer 'sodium-library-version-minor))

  ;; sodium-init : -> Integer
  ;; int sodium_init(void): 0 the first time in a process, 1 after. The load
  ;; has called it, so a call here answers 1.
  (define sodium-init (answer 'sodium-init))

  ;; sodium-memzero : Positive-Integer Natural -> Void
  ;; void sodium_memzero(void * const pnt, const size_t len): zeroes LEN bytes
  ;; at PNT. The wipe call-with-block hands free-foreign-block!.
  (define sodium-memzero (answer 'sodium-memzero))

  ;; randombytes-buf : Positive-Integer Natural -> Void
  ;; void randombytes_buf(void * const buf, const size_t size): writes SIZE
  ;; random bytes at BUF. It aborts the process when no entropy source is
  ;; available.
  (define randombytes-buf (answer 'randombytes-buf))

  ;; crypto-generichash : Positive-Integer Natural Positive-Integer Natural
  ;;                      Positive-Integer Natural -> Integer
  ;; int crypto_generichash(out, outlen, in, inlen, key, keylen): the BLAKE2b
  ;; hash of INLEN bytes at IN, keyed by KEYLEN bytes at KEY, unkeyed for a
  ;; KEYLEN of 0, written as OUTLEN bytes at OUT. 0; or -1 for an OUTLEN of 0
  ;; or above 64, or a KEYLEN above 64, which leaves OUT as it was.
  (define crypto-generichash (answer 'crypto-generichash))

  ;; sodium-memcmp : Positive-Integer Positive-Integer Natural -> Integer
  ;; int sodium_memcmp(b1, b2, len): 0 when the LEN bytes at B1 and B2 are
  ;; equal, -1 when they differ, in constant time; 0 at a LEN of 0.
  (define sodium-memcmp (answer 'sodium-memcmp))

  ;; generichash-bytes : Natural
  ;; crypto_generichash_bytes(), read once at the load: the default size.
  (define generichash-bytes (answer 'generichash-bytes))

  ;; generichash-bytes-min : Natural
  ;; crypto_generichash_bytes_min(), read once at the load: the least size.
  (define generichash-bytes-min (answer 'generichash-bytes-min))

  ;; generichash-bytes-max : Natural
  ;; crypto_generichash_bytes_max(), read once at the load: the greatest size.
  (define generichash-bytes-max (answer 'generichash-bytes-max))

  ;; generichash-keybytes-min : Natural
  ;; crypto_generichash_keybytes_min(), read once at the load: the shortest key.
  (define generichash-keybytes-min (answer 'generichash-keybytes-min))

  ;; generichash-keybytes-max : Natural
  ;; crypto_generichash_keybytes_max(), read once at the load: the longest key.
  (define generichash-keybytes-max (answer 'generichash-keybytes-max))

  ;; --- the load's record -----------------------------------------------------------

  ;; loaded-libsodium : -> (List (Pair 'path String) (Pair 'source Symbol)
  ;;                             (Pair 'version String) (Pair 'major Integer)
  ;;                             (Pair 'minor Integer) (Pair 'init Integer))
  ;; The libsodium this process loaded and accepted: its path and source, the
  ;; version string, the libtool major and minor, and what sodium_init answered
  ;; at the load, 0 or 1. A fresh list and fresh strings at every call, so
  ;; nothing a caller does to an answer reaches the next. Reaching this
  ;; binding runs the load above, once; a refusal raises from there instead,
  ;; at this reference and every later one. It holds no section (ADR-0007,
  ;; decision 8).
  (define (loaded-libsodium)
    (list (cons 'path (string-copy libsodium-path))
          (cons 'source libsodium-source)
          (cons 'version (string-copy libsodium-version))
          (cons 'major libsodium-major)
          (cons 'minor libsodium-minor)
          (cons 'init libsodium-init)))

  ;; sodium-version : -> String
  ;; libsodium's version string, as the load read it: a fresh string at every
  ;; call. It makes no block and calls no C, so it holds no section
  ;; (ADR-0007, decision 8).
  (define (sodium-version)
    (string-copy libsodium-version)))
