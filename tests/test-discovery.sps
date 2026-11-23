#!r6rs
;;; The suite for (chez-sodium private discovery): ADR-0002's search for
;;; libsodium, as a pure function, on synthetic inputs. Each rule has a test
;;; that fails by name when the rule is relaxed:
;;;
;;;   - the override: an absolute CHEZ_SODIUM_LIBRARY is taken as given, never
;;;     checked with exists?, on every platform; anything else set, the empty
;;;     string too, is invalid-override, with no fallback; the rule is a "/" at
;;;     the first position, nothing else;
;;;   - the platform comes from the machine type: ...le is Linux, any other
;;;     has no candidates;
;;;   - the world: Guix when some line of /proc/self/maps names a libc.so.6
;;;     under /gnu/store/, FHS otherwise, wherever the line stands, and only
;;;     on Linux;
;;;   - a Guix world never yields a standard directory, and an FHS world never
;;;     a Guix profile, even when one exists;
;;;   - each world's list, in order, and the first that exists wins;
;;;   - an unset, empty or relative GUIX_ENVIRONMENT, GUIX_PROFILE or HOME
;;;     contributes nothing;
;;;   - the triple table: ta6le and a6le, tarm64le and arm64le;
;;;   - not-found lists every path it checked, in order;
;;;   - in each directory libsodium.so.26 comes before libsodium.so.23, a
;;;     directory's pair before the next directory's, and the bare
;;;     libsodium.so is never a candidate;
;;;   - nothing is read but the four variables, and no other is one.
;;;
;;; Then the real /proc/self/maps: the world it gives must agree with
;;; whether this Chez's own binary lies under /gnu/store/, which holds in the
;;; Guix container and on an FHS CI runner alike.
;;;
;;; Each expected value is one the code under test cannot produce by failing.
;;; SRFI-64 turns a raise in the actual expression into #f, so no expected
;;; value here is #f: every call goes through `outcome`, which names what
;;; was raised or returned.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (only (chezscheme) get-process-id)
        (chez-sodium private conditions)
        (chez-sodium private discovery))

;; SRFI-64 sets no exit status. This suite's last line turns the runner's
;; counts into one.
(define runner (test-runner-simple))
(test-runner-current runner)

;; The simple runner names a failing test but not its values. Print both.
(let ((simple-end (test-runner-on-test-end runner)))
  (test-runner-on-test-end! runner
    (lambda (r)
      (simple-end r)
      (when (memq (test-result-kind r) (quote (fail xpass)))
        (display "  expected: ")
        (write (test-result-ref r (quote expected-value)))
        (newline)
        (display "  actual:   ")
        (write (test-result-ref r (quote actual-value)))
        (newline)))))

;; outcome : (-> Any ...) -> (U (Cons 'chose (Listof Any))
;;                              (List 'refused Symbol Any Any Any Any)
;;                              (List 'assertion-violation Any)
;;                              (List 'other-raise String))
;; What THUNK did: returned its values, raised &sodium-library-unavailable
;; (its reason, path, source, detail and candidates), raised an assertion
;; violation (its who), or raised something else.
(define (outcome thunk)
  (guard (e ((sodium-library-unavailable? e)
             (list 'refused
                   (sodium-library-unavailable-reason e)
                   (sodium-library-unavailable-path e)
                   (sodium-library-unavailable-source e)
                   (sodium-library-unavailable-detail e)
                   (sodium-library-unavailable-candidates e)))
            ((and (assertion-violation? e) (who-condition? e))
             (list 'assertion-violation (condition-who e)))
            (#t (list 'other-raise (describe e))))
    (call-with-values thunk (lambda results (cons 'chose results)))))

;; env : (Listof (Pairof String String)) -> (String -> (U String #f))
;; A getenv that knows only BINDINGS.
(define (env bindings)
  (lambda (name)
    (let ((binding (assoc name bindings)))
      (and binding (cdr binding)))))

;; present : String ... -> (String -> Boolean)
;; An exists? for which only PATHS exist.
(define (present . paths)
  (lambda (path) (and (member path paths) #t)))

(define nothing (present))
(define (everything path) #t)

;; choose : Bindings Symbol (U String #f) (String -> Boolean) -> Outcome
(define (choose bindings machine maps exists?)
  (outcome (lambda () (choose-libsodium (env bindings) machine maps exists?))))

;; choose/asked : Bindings Symbol (U String #f) (String -> Boolean)
;;                -> (List Outcome (Listof String))
;; choose's outcome, then every path it asked EXISTS? about, in order.
(define (choose/asked bindings machine maps exists?)
  (let* ((asked '())
         (probe (lambda (path) (set! asked (cons path asked)) (exists? path)))
         (result (choose bindings machine maps probe)))
    (list result (reverse asked))))

;; --- fixtures ------------------------------------------------------------------

;; A Guix user's environment: every variable discovery may read is set, each
;; to its own value.
(define guix-vars
  '(("GUIX_ENVIRONMENT" . "/gnu/store/aaa-profile")
    ("GUIX_PROFILE" . "/home/ana/work/profile")
    ("HOME" . "/home/ana")))

(define d-env    "/gnu/store/aaa-profile/lib")
(define d-profile "/home/ana/work/profile/lib")
(define d-home    "/home/ana/.guix-home/profile/lib")
(define d-user    "/home/ana/.guix-profile/lib")
(define d-system  "/run/current-system/profile/lib")

;; so26, so23 : String -> String
;; The two sonames in directory DIR.
(define (so26 dir) (string-append dir "/libsodium.so.26"))
(define (so23 dir) (string-append dir "/libsodium.so.23"))

;; pair-in : String Symbol -> (Listof (Pairof String Symbol))
;; DIR's candidates, the newer soname first.
(define (pair-in dir source)
  (list (cons (so26 dir) source) (cons (so23 dir) source)))

(define g-env     (so26 d-env))
(define g-env23   (so23 d-env))
(define g-profile (so26 d-profile))
(define g-profile23 (so23 d-profile))
(define g-home    (so26 d-home))
(define g-home23  (so23 d-home))
(define g-user    (so26 d-user))
(define g-user23  (so23 d-user))
(define g-system  (so26 d-system))
(define g-system23 (so23 d-system))

;; Each profile's pair, and the whole list, in ADR-0002's order.
(define env-pair (pair-in d-env 'guix-environment))
(define profile-pair (pair-in d-profile 'guix-profile))
(define home-pair (pair-in d-home 'guix-home))
(define user-pair (pair-in d-user 'guix-user-profile))
(define system-pair (pair-in d-system 'guix-system))

(define guix-list
  (append env-pair profile-pair home-pair user-pair system-pair))

(define f-local  (so26 "/usr/local/lib"))
(define f-local23 (so23 "/usr/local/lib"))
(define f-triple (so26 "/usr/lib/x86_64-linux-gnu"))
(define f-triple23 (so23 "/usr/lib/x86_64-linux-gnu"))
(define f-lib64  (so26 "/usr/lib64"))
(define f-lib64-23 (so23 "/usr/lib64"))
(define f-lib    (so26 "/usr/lib"))
(define f-lib23  (so23 "/usr/lib"))

(define fhs-list
  (append (pair-in "/usr/local/lib" 'system)
          (pair-in "/usr/lib/x86_64-linux-gnu" 'system)
          (pair-in "/usr/lib64" 'system)
          (pair-in "/usr/lib" 'system)))

(define override "/opt/sodium/lib/libsodium.so.26")

;; LD_LIBRARY_PATH is set in every override fixture:
;; ADR-0002 says nothing reads them, and a variable that is unset cannot show it.
(define ld-vars
  '(("LD_LIBRARY_PATH" . "/opt/ld/lib")))

(define (with-override value)
  (cons (cons "CHEZ_SODIUM_LIBRARY" value) (append guix-vars ld-vars)))

;; Guix Chez's maps, cut down: libc is on the third line, after the binary,
;; itself under /gnu/store/.
(define guix-maps
  (string-append
   "00400000-00409000 r--p 00000000 fc:01 9450589                            /gnu/store/nrl-chez-scheme-10.4.0/lib/csv10.4.0/ta6le/scheme\n"
   "14b8c000-14bad000 rw-p 00000000 00:00 0                                  [heap]\n"
   "71486b199000-71486b1c1000 r--p 00000000 fc:01 5153215                    /gnu/store/m31-glibc-2.41/lib/libc.so.6\n"
   "7ffd5a3e2000-7ffd5a403000 rw-p 00000000 00:00 0                          [stack]\n"))

;; A host-built Chez's maps, cut down.
(define fhs-maps
  (string-append
   "55d0c0a00000-55d0c0a09000 r--p 00000000 08:02 1234                       /usr/local/bin/scheme\n"
   "7f1e2a000000-7f1e2a028000 r--p 00000000 08:02 5678                       /usr/lib/x86_64-linux-gnu/libc.so.6\n"
   "7ffd5a3e2000-7ffd5a403000 rw-p 00000000 00:00 0                          [stack]\n"))

;; maps-line : String -> String
;; One line of /proc/self/maps naming PATH.
(define (maps-line path)
  (string-append "7f1e2b000000-7f1e2b028000 r--p 00000000 08:02 9999                       "
                 path "\n"))

(define heap-line "14b8c000-14bad000 rw-p 00000000 00:00 0                                  [heap]\n")
(define guix-libc-line (maps-line "/gnu/store/m31-glibc-2.41/lib/libc.so.6"))
(define fhs-libc-line (maps-line "/usr/lib/x86_64-linux-gnu/libc.so.6"))
(define other-guix-line (maps-line "/gnu/store/xyz-libsodium-1.0.22/lib/libsodium.so.26.4.0"))

;; without-last-newline : String -> String
(define (without-last-newline text)
  (substring text 0 (- (string-length text) 1)))

(test-begin "discovery")

;; --- the override -------------------------------------------------------------

;; Every Guix candidate exists, so only the override can be chosen.
(test-equal "override: an absolute CHEZ_SODIUM_LIBRARY is chosen as given, with source override"
  `(chose ,override override)
  (choose (with-override override) 'ta6le guix-maps everything))

(test-equal "override: it is never checked with exists?, since loading decides"
  `((chose ,override override) ())
  (choose/asked (with-override override) 'ta6le guix-maps nothing))

(test-equal "override: it beats every FHS candidate when all exist"
  `(chose ,override override)
  (choose (with-override override) 'ta6le fhs-maps everything))

(test-equal "override: a relative path is invalid-override, carrying the value, with no fallback"
  '(refused invalid-override #f override "lib/libsodium.so.0" ())
  (choose (with-override "lib/libsodium.so.0") 'ta6le guix-maps everything))

(test-equal "override: a bare name is invalid-override"
  '(refused invalid-override #f override "libsodium.so.0" ())
  (choose (with-override "libsodium.so.0") 'ta6le guix-maps everything))

(test-equal "override: set but empty is invalid-override"
  '(refused invalid-override #f override "" ())
  (choose (with-override "") 'ta6le guix-maps everything))

;; The rule is a / at position 0. A path with a / anywhere else, a space or a
;; tab or newline before it, a dot, a tilde or a scheme is not absolute.
(test-equal "override: absolute means a slash first: \"/\" alone is chosen"
  '(chose "/" override)
  (choose (with-override "/") 'ta6le fhs-maps nothing))

(test-equal "override: a slash anywhere but first is invalid-override, with the value as detail, in every shape"
  (map (lambda (v) (list 'refused 'invalid-override #f 'override v '()))
       '(" /opt/x" "./x" "../x" "~/x" "file:///x" "x/y" "\t/x" "\n/x" "a/"))
  (map (lambda (v) (choose (with-override v) 'ta6le fhs-maps everything))
       '(" /opt/x" "./x" "../x" "~/x" "file:///x" "x/y" "\t/x" "\n/x" "a/")))

(test-equal "override: chosen on a platform with no list"
  `(chose ,override override)
  (choose (with-override override) 'ta6fb #f everything))

(test-equal "override: invalid-override on a platform with no list refuses too, with no fallback"
  '((refused invalid-override #f override "x" ()) (refused invalid-override #f override "x" ()))
  (list (choose (with-override "x") 'tarm64osx #f everything)
        (choose (with-override "x") 'ta6fb #f everything)))

;; The override is a path as given: a soname beside it is not looked for, and
;; the file is never asked about, though its neighbour exists.
(test-equal "override: a libsodium.so.23 path is chosen as given, whatever else exists, and is never asked about"
  '((chose "/opt/sodium/lib/libsodium.so.23" override) ())
  (choose/asked (with-override "/opt/sodium/lib/libsodium.so.23") 'ta6le guix-maps
                (present "/opt/sodium/lib/libsodium.so.26")))


;; The variables a copied rule would still read: chez-curl's, and chez-sqlite3's.
(test-equal "no other variable is an override: the candidates decide"
  `(chose ,f-lib system)
  (choose (append '(("CHEZ_CURL_LIBCURL" . "/opt/curl/libcurl.so.4")
                    ("CHEZ_SQLITE3_LIBRARY" . "/opt/a/libsqlite3.so.0")
                    ("SODIUM_LIBRARY" . "/opt/b/libsodium.so.26")
                    ("CHEZ_SODIUM" . "/opt/c/libsodium.so.26")
                    ("LIBSODIUM" . "/opt/d/libsodium.so.26"))
                  guix-vars)
          'ta6le fhs-maps (present f-lib)))

;; --- the platform, from the machine type ----------------------------------------

;; trv64le has no triple, so its list is the three plain directories.
(test-equal "platform: a machine type ending in le is Linux"
  `(chose ,f-lib system)
  (choose guix-vars 'trv64le fhs-maps (present f-lib)))

(test-equal "platform: a machine type ending in osx has no candidates, on both architectures, threaded or not"
  (map (lambda (m) '(refused not-found #f #f #f ())) '(1 2 3 4))
  (map (lambda (m) (choose guix-vars m guix-maps everything)) '(ta6osx a6osx tarm64osx arm64osx)))

;; The Guix maps text and a world where everything exists: neither may
;; produce a candidate on these platforms.
(test-equal "platform: any other has no candidates, so not-found with an empty list"
  '((refused not-found #f #f #f ())
    (refused not-found #f #f #f ())
    (refused not-found #f #f #f ()))
  (map (lambda (machine) (choose guix-vars machine guix-maps everything))
       '(ta6fb ta6ob ta6s2)))

;; The Windows, NetBSD and QNX machine types, in every width and threading:
;; none ends in le, and none may be taken for Linux.
(define other-machines '(ta6nt a6nt ti3nt i3nt ta6nb a6nb ti3nb i3nb ta6qnx ti3qnx))

(test-equal "platform: the nt, nb and qnx machine types have no candidates either, not-found with an empty list"
  (map (lambda (machine) '(refused not-found #f #f #f ())) other-machines)
  (map (lambda (machine) (choose guix-vars machine guix-maps everything)) other-machines))

;; --- the world ----------------------------------------------------------------

(test-equal "world: libc.so.6 under /gnu/store/, on any line, is guix"
  'guix
  (libsodium-world guix-maps))

(test-equal "world: libc.so.6 under /usr/lib is fhs"
  'fhs
  (libsodium-world fhs-maps))

(test-equal "world: an unreadable /proc/self/maps, #f, is fhs"
  'fhs
  (libsodium-world #f))

(test-equal "world: other libraries from /gnu/store/ in an FHS process are fhs"
  'fhs
  (libsodium-world (string-append fhs-maps other-guix-line
                                   (maps-line "/gnu/store/m31-glibc-2.41/lib/libm.so.6"))))

(test-equal "world: a basename that only resembles libc.so.6 is fhs"
  'fhs
  (libsodium-world (string-append fhs-maps
                                   (maps-line "/gnu/store/aaa-libc.so.6/lib/libm.so.6")
                                   (maps-line "/gnu/store/bbb-glibc/lib/libc.so.6.1")
                                   (maps-line "/gnu/store/ccc-glibc/lib/xlibc.so.6"))))

(test-equal "world: libc.so.6 under a /gnu/store/ that is not at the root is fhs"
  'fhs
  (libsodium-world (string-append fhs-maps
                                   (maps-line "/opt/gnu/store/ddd-glibc/lib/libc.so.6"))))

;; The prefix is /gnu/store/ whole: /gnu/ alone is not it, and neither is
;; /gnu/store without its slash.
(test-equal "world: libc.so.6 under /gnu/lib/ or /gnu/storex/ is fhs: the prefix is all of /gnu/store/"
  '(fhs fhs)
  (map (lambda (path) (libsodium-world (string-append fhs-maps (maps-line path))))
       '("/gnu/lib/libc.so.6" "/gnu/storex/abc-glibc/lib/libc.so.6")))

;; The scan, with the libc line at every position of the text: first, in the
;; middle, last, last with no newline after it, and alone, with and without
;; its newline. Fillers hold a /gnu/store/ library that is not libc and an
;; anonymous mapping.
(define filler (string-append heap-line other-guix-line heap-line))

(test-equal "world: a Guix libc line is found first, in the middle, last, last without a newline, and alone"
  '(guix guix guix guix guix guix)
  (map libsodium-world
       (list (string-append guix-libc-line filler)
             (string-append filler guix-libc-line filler)
             (string-append filler guix-libc-line)
             (without-last-newline (string-append filler guix-libc-line))
             guix-libc-line
             (without-last-newline guix-libc-line))))

(test-equal "world: an FHS libc line is fhs at every position too, whatever else is under /gnu/store/"
  '(fhs fhs fhs fhs fhs)
  (map libsodium-world
       (list (string-append fhs-libc-line filler)
             (string-append filler fhs-libc-line filler)
             (string-append filler fhs-libc-line)
             (without-last-newline (string-append filler fhs-libc-line))
             fhs-libc-line)))

;; "Some line" is not "the first libc line": an FHS libc ahead of a Guix one
;; leaves the world Guix.
(test-equal "world: an FHS libc line before a Guix one is still guix, whatever else lies between"
  '(guix guix)
  (map libsodium-world
       (list (string-append fhs-libc-line guix-libc-line)
             (string-append heap-line fhs-libc-line filler guix-libc-line filler))))

(test-equal "world: no text, no file lines, and lines with no path are fhs"
  '(fhs fhs fhs fhs)
  (map libsodium-world
       (list "" "\n" heap-line (string-append heap-line heap-line "7ffd-7ffe rw-p 0 00:00 0 [stack]"))))

;; --- the Guix world -------------------------------------------------------------

(test-equal "guix: the candidate list, in ADR-0002's order"
  guix-list
  (libsodium-candidates 'guix 'ta6le (env guix-vars)))

(test-equal "guix: GUIX_ENVIRONMENT unset contributes nothing"
  (list-tail guix-list 2)
  (libsodium-candidates 'guix 'ta6le
                         (env '(("GUIX_PROFILE" . "/home/ana/work/profile")
                                ("HOME" . "/home/ana")))))

(test-equal "guix: GUIX_ENVIRONMENT set but empty contributes nothing"
  (list-tail guix-list 2)
  (libsodium-candidates 'guix 'ta6le
                         (env (cons '("GUIX_ENVIRONMENT" . "") (cdr guix-vars)))))

(test-equal "guix: a relative GUIX_ENVIRONMENT contributes nothing"
  (list-tail guix-list 2)
  (libsodium-candidates 'guix 'ta6le
                         (env '(("GUIX_ENVIRONMENT" . "aaa-profile")
                                ("GUIX_PROFILE" . "/home/ana/work/profile")
                                ("HOME" . "/home/ana")))))

(test-equal "guix: a relative GUIX_PROFILE contributes nothing"
  (append env-pair home-pair user-pair system-pair)
  (libsodium-candidates 'guix 'ta6le
                         (env '(("GUIX_ENVIRONMENT" . "/gnu/store/aaa-profile")
                                ("GUIX_PROFILE" . "work/profile")
                                ("HOME" . "/home/ana")))))

(test-equal "guix: HOME unset contributes neither home candidate"
  (append env-pair profile-pair system-pair)
  (libsodium-candidates 'guix 'ta6le
                         (env '(("GUIX_ENVIRONMENT" . "/gnu/store/aaa-profile")
                                ("GUIX_PROFILE" . "/home/ana/work/profile")))))

(test-equal "guix: a relative HOME contributes neither home candidate"
  (append env-pair profile-pair system-pair)
  (libsodium-candidates 'guix 'ta6le
                         (env '(("GUIX_ENVIRONMENT" . "/gnu/store/aaa-profile")
                                ("GUIX_PROFILE" . "/home/ana/work/profile")
                                ("HOME" . "home/ana")))))

(test-equal "guix: a standard directory is never chosen, even when every one exists"
  `(refused not-found #f #f #f ,(map car guix-list))
  (choose guix-vars 'ta6le guix-maps (apply present (map car fhs-list))))

;; tails : (Listof A) -> (Listof (Listof A))
;; Each nonempty tail of XS, longest first.
(define (tails xs)
  (if (null? xs) '() (cons xs (tails (cdr xs)))))

;; Candidate i and every one after it exist: candidate i must win.
(test-equal "guix: precedence: each candidate wins over every one after it"
  (map (lambda (c) (list 'chose (car c) (cdr c))) guix-list)
  (map (lambda (tail) (choose guix-vars 'ta6le guix-maps (apply present (map car tail))))
       (tails guix-list)))

(test-equal "guix: probing asks in order, and stops at the first that exists"
  `((chose ,g-home guix-home) (,g-env ,g-env23 ,g-profile ,g-profile23 ,g-home))
  (choose/asked guix-vars 'ta6le guix-maps (present g-home g-system)))

(test-equal "guix: with no variable set, the one candidate is the system profile's"
  `(refused not-found #f #f #f (,g-system ,g-system23))
  (choose '() 'ta6le guix-maps nothing))

(test-equal "guix: with only HOME set, the home profiles and the system's, in order"
  `(refused not-found #f #f #f (,g-home ,g-home23 ,g-user ,g-user23 ,g-system ,g-system23))
  (choose '(("HOME" . "/home/ana")) 'ta6le guix-maps nothing))

;; --- the FHS world --------------------------------------------------------------

(test-equal "fhs: the candidate list for ta6le, in ADR-0002's order"
  fhs-list
  (libsodium-candidates 'fhs 'ta6le (env guix-vars)))

(test-equal "fhs: the candidate list for a6le is the same, under x86_64-linux-gnu"
  fhs-list
  (libsodium-candidates 'fhs 'a6le (env guix-vars)))

(define fhs-arm
  (append (pair-in "/usr/local/lib" 'system)
          (pair-in "/usr/lib/aarch64-linux-gnu" 'system)
          (pair-in "/usr/lib64" 'system)
          (pair-in "/usr/lib" 'system)))

;; The directories of a Linux machine type with no triple: the three plain ones.
(define fhs-plain
  (append (pair-in "/usr/local/lib" 'system)
          (pair-in "/usr/lib64" 'system)
          (pair-in "/usr/lib" 'system)))

(test-equal "fhs: the candidate list for tarm64le and arm64le, under aarch64-linux-gnu"
  (list fhs-arm fhs-arm)
  (list (libsodium-candidates 'fhs 'tarm64le (env guix-vars))
        (libsodium-candidates 'fhs 'arm64le (env guix-vars))))

(test-equal "fhs: an unknown Linux machine type has no triple directory"
  fhs-plain
  (libsodium-candidates 'fhs 'trv64le (env guix-vars)))

(define other-linux-machines
  '(i3le ti3le arm32le tarm32le ppc32le tppc32le rv64le trv64le la64le tla64le))

(test-equal "fhs: every other Linux machine type has no triple directory, only the three plain ones"
  (map (lambda (machine)
         `(chose ,fhs-plain))
       other-linux-machines)
  (map (lambda (machine)
         (outcome (lambda () (libsodium-candidates 'fhs machine (env guix-vars)))))
       other-linux-machines))

(test-equal "fhs: a Guix profile is never chosen, even when every one exists"
  `(refused not-found #f #f #f ,(map car fhs-list))
  (choose guix-vars 'ta6le fhs-maps (apply present (map car guix-list))))

(test-equal "fhs: precedence: each candidate wins over every one after it"
  (map (lambda (c) (list 'chose (car c) (cdr c))) fhs-list)
  (map (lambda (tail) (choose guix-vars 'ta6le fhs-maps (apply present (map car tail))))
       (tails fhs-list)))

(test-equal "fhs: probing asks in order, and stops at the first that exists"
  `((chose ,f-lib64 system) (,f-local ,f-local23 ,f-triple ,f-triple23 ,f-lib64))
  (choose/asked guix-vars 'ta6le fhs-maps (present f-lib64 f-lib)))

(test-equal "fhs: end to end on tarm64le, the aarch64 triple's candidate is chosen"
  '(chose "/usr/lib/aarch64-linux-gnu/libsodium.so.26" system)
  (choose guix-vars 'tarm64le fhs-maps (present "/usr/lib/aarch64-linux-gnu/libsodium.so.26")))

(test-equal "fhs: an unreadable /proc/self/maps, #f, asks the FHS list, even with Guix variables set"
  `((chose ,f-lib system) ,(reverse (cdr (reverse (map car fhs-list)))))
  (choose/asked guix-vars 'ta6le #f (present f-lib)))

(test-equal "libsodium-candidates refuses a Linux world that is neither guix nor fhs, #f among them"
  '((assertion-violation libsodium-candidates) (assertion-violation libsodium-candidates))
  (list (outcome (lambda () (libsodium-candidates 'nix 'ta6le (env guix-vars))))
        (outcome (lambda () (libsodium-candidates #f 'ta6le (env guix-vars))))))

(test-equal "a platform with no list has no candidates, whatever the world"
  '(() () () () () ())
  (apply append
         (map (lambda (machine)
                (map (lambda (world) (libsodium-candidates world machine (env guix-vars)))
                     '(#f guix fhs)))
              '(ta6fb tarm64osx))))

;; append-map-paths : (String -> (Listof String)) (Listof String) -> (Listof String)
(define (append-map-paths f xs)
  (apply append (map f xs)))

(test-equal "sonames: in a directory that holds both, libsodium.so.26 is chosen and libsodium.so.23 is never asked about, in the FHS world and in each Guix profile"
  (list `((chose ,f-lib system) (,f-local ,f-local23 ,f-triple ,f-triple23 ,f-lib64 ,f-lib64-23 ,f-lib))
        `((chose ,g-env guix-environment) (,g-env))
        `((chose ,g-profile guix-profile) (,g-env ,g-env23 ,g-profile))
        `((chose ,g-home guix-home) (,g-env ,g-env23 ,g-profile ,g-profile23 ,g-home))
        `((chose ,g-user guix-user-profile)
          (,g-env ,g-env23 ,g-profile ,g-profile23 ,g-home ,g-home23 ,g-user))
        `((chose ,g-system guix-system)
          (,g-env ,g-env23 ,g-profile ,g-profile23 ,g-home ,g-home23 ,g-user ,g-user23
           ,g-system)))
  (list (choose/asked guix-vars 'ta6le fhs-maps (present f-lib f-lib23))
        (choose/asked guix-vars 'ta6le guix-maps (present g-env g-env23))
        (choose/asked guix-vars 'ta6le guix-maps (present g-profile g-profile23))
        (choose/asked guix-vars 'ta6le guix-maps (present g-home g-home23))
        (choose/asked guix-vars 'ta6le guix-maps (present g-user g-user23))
        (choose/asked guix-vars 'ta6le guix-maps (present g-system g-system23))))

(test-equal "sonames: a directory that holds only libsodium.so.23 is chosen, libsodium.so.26 asked about first"
  `((chose ,f-lib23 system) (,f-local ,f-local23 ,f-triple ,f-triple23 ,f-lib64 ,f-lib64-23 ,f-lib ,f-lib23))
  (choose/asked guix-vars 'ta6le fhs-maps (present f-lib23)))

(test-equal "sonames: the directory comes first, then the soname: an earlier directory's libsodium.so.23 beats a later one's libsodium.so.26"
  `(chose ,f-triple23 system)
  (choose guix-vars 'ta6le fhs-maps (present f-triple23 f-lib64 f-lib)))

;; Only the bare development link, and a versioned file that is neither
;; soname, exist in every directory: nothing is found, and neither is asked
;; about.
(define bare-paths
  (append-map-paths
   (lambda (dir) (list (string-append dir "/libsodium.so") (string-append dir "/libsodium.so.26.4.0")))
   '("/usr/local/lib" "/usr/lib/x86_64-linux-gnu" "/usr/lib64" "/usr/lib"
     "/gnu/store/aaa-profile/lib" "/home/ana/work/profile/lib"
     "/home/ana/.guix-home/profile/lib" "/home/ana/.guix-profile/lib"
     "/run/current-system/profile/lib")))

(test-equal "sonames: the bare libsodium.so is never a candidate, in either world: nothing is found, and it is not asked about"
  (list `((refused not-found #f #f #f ,(map car fhs-list)) ,(map car fhs-list))
        `((refused not-found #f #f #f ,(map car guix-list)) ,(map car guix-list)))
  (list (choose/asked guix-vars 'ta6le fhs-maps (apply present bare-paths))
        (choose/asked guix-vars 'ta6le guix-maps (apply present bare-paths))))

(test-equal "triple table: ta6le and a6le, tarm64le and arm64le"
  '("x86_64-linux-gnu" "x86_64-linux-gnu" "aarch64-linux-gnu" "aarch64-linux-gnu")
  (map linux-triple '(ta6le a6le tarm64le arm64le)))

;; The complement: every other Linux machine type Chez names, and two non-Linux
;; ones. none stands for #f, which a raise would also become.
(test-equal "triple table: no other machine type has a triple"
  (map (lambda (m) 'none)
       '(i3le ti3le arm32le tarm32le ppc32le tppc32le rv64le trv64le la64le tla64le
         tarm64osx ta6osx))
  (map (lambda (m) (guard (e (#t 'raised)) (or (linux-triple m) 'none)))
       '(i3le ti3le arm32le tarm32le ppc32le tppc32le rv64le trv64le la64le tla64le
         tarm64osx ta6osx)))

;; --- the sources ---------------------------------------------------------------

;; Computed under a guard: a raise at top level would end the suite with no
;; test named. A symbol no source equals stands for a failed computation.
(define yielded-sources
  (guard (e (#t '(candidates-raised)))
    (map cdr (append (libsodium-candidates 'guix 'ta6le (env guix-vars))
                     (libsodium-candidates 'fhs 'ta6le (env guix-vars))))))

(test-equal "libsodium-sources: exactly the seven sources, in order"
  '(override guix-environment guix-profile guix-home guix-user-profile guix-system
    system)
  libsodium-sources)

(test-equal "every source a candidate list yields is one of libsodium-sources"
  '()
  (filter (lambda (s) (not (memq s libsodium-sources))) yielded-sources))

(test-equal "every source but the override's is yielded by some candidate list"
  '()
  (filter (lambda (s) (not (memq s yielded-sources)))
          (filter (lambda (s) (not (eq? s 'override))) libsodium-sources)))

;; --- not-found, and what discovery reads -------------------------------------------

(test-equal "not-found lists every path it checked, in order, with no path, source or detail"
  `((refused not-found #f #f #f ,(map car fhs-list)) ,(map car fhs-list))
  (choose/asked guix-vars 'ta6le fhs-maps nothing))

(test-equal "every refusal is a chez-sodium-error, an error, from who chez-sodium, with a message"
  '((#t #t chez-sodium #t) (#t #t chez-sodium #t))
  (map (lambda (thunk)
         (guard (e ((sodium-library-unavailable? e)
                    (list (chez-sodium-error? e) (error? e)
                          (and (who-condition? e) (condition-who e))
                          (message-condition? e)))
                   (#t 'other-raise))
           (thunk)
           'no-raise))
       (list (lambda () (choose-libsodium (env (with-override "libsodium.so.0")) 'ta6le #f nothing))
             (lambda () (choose-libsodium (env guix-vars) 'ta6le #f nothing)))))

;; ADR-0002: nothing reads LD_LIBRARY_PATH on chez-sodium's behalf.
;; Every variable below is set, and every path exists, so a read that fed a
;; search would change an answer as well as the names.

;; names-read : Bindings Symbol (U String #f) -> (Listof String)
;; The names choose-libsodium asked getenv for, sorted.
(define (names-read bindings machine maps)
  (let* ((names '())
         (getenv (lambda (name)
                   (unless (member name names) (set! names (cons name names)))
                   ((env bindings) name))))
    (outcome (lambda () (choose-libsodium getenv machine maps everything)))
    (list-sort string<? names)))

;; The four fixtures: Linux in a Guix world, Linux in an FHS world, a
;; non-Linux machine type and an unknown platform, neither with a list.
(define world-cases
  (list (cons 'ta6le guix-maps) (cons 'ta6le fhs-maps) (cons 'tarm64osx #f) (cons 'ta6fb #f)))

(test-equal "discovery reads only CHEZ_SODIUM_LIBRARY when a valid override is set, on every platform"
  (map (lambda (c) '("CHEZ_SODIUM_LIBRARY")) world-cases)
  (map (lambda (c) (names-read (with-override override) (car c) (cdr c))) world-cases))

(test-equal "discovery reads only CHEZ_SODIUM_LIBRARY when an invalid override is set, on every platform"
  (map (lambda (c) '("CHEZ_SODIUM_LIBRARY")) world-cases)
  (map (lambda (c) (names-read (with-override "libsodium.so.0") (car c) (cdr c))) world-cases))

(test-equal "with no override, discovery reads GUIX_ENVIRONMENT, GUIX_PROFILE and HOME in a Guix world and nothing else, never LD_LIBRARY_PATH"
  '(("CHEZ_SODIUM_LIBRARY" "GUIX_ENVIRONMENT" "GUIX_PROFILE" "HOME")
    ("CHEZ_SODIUM_LIBRARY")
    ("CHEZ_SODIUM_LIBRARY")
    ("CHEZ_SODIUM_LIBRARY"))
  (map (lambda (c) (names-read (append guix-vars ld-vars) (car c) (cdr c))) world-cases))

;; --- the real /proc/self/maps ----------------------------------------------------

(define (string-prefix? prefix s)
  (let ((n (string-length s)) (m (string-length prefix)))
    (and (>= n m) (string=? (substring s 0 m) prefix))))

;; real-maps : (U String #f)
;; This process's /proc/self/maps, or #f when it cannot be read: what the
;; native layer will hand discovery.
(define real-maps
  (guard (e (#t #f))
    (call-with-port (open-file-input-port "/proc/self/maps" (file-options)
                                          (buffer-mode block)
                                          (make-transcoder (utf-8-codec)))
      get-string-all)))

;; binary-world : (U 'guix 'fhs (List 'unknown Any))
;; guix when this Chez's own binary, its symlinks resolved, lies under
;; /gnu/store/; fhs when it does not. Anything else is a sentinel no world
;; can equal.
(define binary-world
  (guard (e (#t (list 'unknown (describe e))))
        (let ((answer (capture-command
                       (list "readlink" "-f"
                             (string-append "/proc/" (number->string (get-process-id))
                                            "/exe")))))
          (if (and (= (car answer) 0) (string-prefix? "/" (cadr answer)))
              (begin
                ;; readlink's line, newline and all.
                (display (string-append "this Chez's binary: " (cadr answer)))
                (if (string-prefix? "/gnu/store/" (cadr answer)) 'guix 'fhs))
              (list 'unknown answer)))))

(test-equal "the real /proc/self/maps is read"
  'read
  (if (string? real-maps) 'read 'unread))

(test-equal "the real /proc/self/maps: guix exactly when this Chez's binary lies under /gnu/store/"
  binary-world
  (libsodium-world real-maps))

(test-end "discovery")

(exit (suite-exit-status runner))
