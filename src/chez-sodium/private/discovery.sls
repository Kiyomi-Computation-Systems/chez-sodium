#!r6rs
;;; (chez-sodium private discovery): which libsodium to load (ADR-0002).
;;;
;;; Pure. It reads no file, calls no foreign code and reads no environment
;;; variable of its own: getenv, the machine type, the text of
;;; /proc/self/maps and an existence predicate all come in as arguments, so
;;; tests/test-discovery.sps can drive every rule with synthetic inputs.
;;;
;;;   1. CHEZ_SODIUM_LIBRARY, when set, must be an absolute path, and is
;;;      chosen as given: never checked with exists?, since loading decides,
;;;      and never a fallback. Anything else set, the empty string too, is
;;;      invalid-override. The path chosen, here or below, is what the
;;;      loader is given. Nothing reads LD_LIBRARY_PATH.
;;;   2. Otherwise a machine type whose name ends in le is Linux. Any other
;;;      has no candidates, so it is not-found.
;;;   3. On Linux, the world is Guix when /proc/self/maps shows libc.so.6
;;;      mapped from under /gnu/store/, and FHS otherwise, unreadable
;;;      included. Each world has its own list of directories, and in each
;;;      one libsodium.so.26 comes before libsodium.so.23. The bare
;;;      libsodium.so is never a candidate. The first candidate that exists
;;;      wins. None existing is not-found, listing every path checked.
(library (chez-sodium private discovery)
  (export choose-libsodium libsodium-world linux-triple libsodium-candidates
          libsodium-sources)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (chez-sodium private conditions))

  ;; libsodium-sources : (Listof Symbol)
  ;; Where a chosen path can come from, as a refusal or a report names it.
  ;;
  ;;   override            CHEZ_SODIUM_LIBRARY
  ;;   guix-environment    $GUIX_ENVIRONMENT, an active guix shell
  ;;   guix-profile        $GUIX_PROFILE
  ;;   guix-home           $HOME/.guix-home/profile
  ;;   guix-user-profile   $HOME/.guix-profile
  ;;   guix-system         /run/current-system/profile, Guix System's
  ;;   system              an FHS directory
  (define libsodium-sources
    '(override guix-environment guix-profile guix-home guix-user-profile
      guix-system system))

  ;; libsodium-sonames : (Listof String)
  ;; The file names tried in each directory, in order: the newer soname
  ;; first. Never the bare libsodium.so, which names no ABI.
  (define libsodium-sonames '("libsodium.so.26" "libsodium.so.23"))

  ;; choose-libsodium : (String -> (U String #f)) Symbol (U String #f)
  ;;                    (String -> Boolean) -> (Values String Symbol)
  ;; The path to load, and its source. GETENV reads the environment,
  ;; MACHINE-TYPE is Chez's (ta6le, tarm64le, ...), MAPS-TEXT is the text of
  ;; /proc/self/maps or #f when it cannot be read, and EXISTS? says whether
  ;; a path exists. Raises &sodium-library-unavailable with reason
  ;; invalid-override or not-found.
  (define (choose-libsodium getenv machine-type maps-text exists?)
    (let ((override (getenv "CHEZ_SODIUM_LIBRARY")))
      (cond
        ((not override)
         (if (linux-machine-type? machine-type)
             (first-existing (libsodium-candidates (libsodium-world maps-text)
                                                   machine-type getenv)
                             exists?)
             (first-existing '() exists?)))
        ((absolute? override) (values override 'override))
        (else
         (refuse 'invalid-override #f 'override override '()
                 "CHEZ_SODIUM_LIBRARY must be an absolute path to libsodium, which chez-sodium loads with no search of its own; set one, or unset it to use discovery"
                 override)))))

  ;; first-existing : (Listof (Pairof String Symbol)) (String -> Boolean)
  ;;                  -> (Values String Symbol)
  ;; The first of CANDIDATES that EXISTS? says exists, asked one at a time,
  ;; in order, stopping there. None is not-found, listing them all.
  (define (first-existing candidates exists?)
    (let loop ((rest candidates))
      (cond
        ((null? rest)
         (let ((paths (map car candidates)))
           (refuse 'not-found #f #f #f paths
                   "no libsodium found among the candidates; name one with CHEZ_SODIUM_LIBRARY, an absolute path"
                   paths)))
        ((exists? (caar rest)) (values (caar rest) (cdar rest)))
        (else (loop (cdr rest))))))

  ;; refuse : Symbol (U String #f) (U Symbol #f) Any (Listof String) String
  ;;          Any -> Nothing
  ;; A refusal made before any library was loaded: one irritant.
  (define (refuse reason path source detail candidates message irritant)
    (raise-library-unavailable reason path source detail candidates message
                               (list irritant)))

  ;; linux-machine-type? : Symbol -> Boolean
  (define (linux-machine-type? machine-type)
    (string-suffix? "le" (symbol->string machine-type)))

  ;; linux-triple : Symbol -> (U String #f)
  ;; The Debian multiarch directory under /usr/lib for MACHINE-TYPE, or #f
  ;; for any machine type but these four.
  (define (linux-triple machine-type)
    (case machine-type
      ((ta6le a6le) "x86_64-linux-gnu")
      ((tarm64le arm64le) "aarch64-linux-gnu")
      (else #f)))

  ;; libsodium-world : (U String #f) -> (U 'guix 'fhs)
  ;; guix when some line of MAPS-TEXT, the text of /proc/self/maps, names a
  ;; file whose basename is libc.so.6 under /gnu/store/; fhs otherwise, and
  ;; when MAPS-TEXT is #f.
  (define (libsodium-world maps-text)
    (if (and maps-text (exists guix-libc? (map line-path (lines maps-text))))
        'guix
        'fhs))

  ;; guix-libc? : (U String #f) -> Boolean
  (define (guix-libc? path)
    (and path
         (string-prefix? "/gnu/store/" path)
         (string=? (basename path) "libc.so.6")))

  ;; line-path : String -> (U String #f)
  ;; The pathname column of one line of /proc/self/maps: from its first /
  ;; to its end. No column before it holds a /.
  (define (line-path line)
    (let loop ((i 0))
      (cond ((= i (string-length line)) #f)
            ((char=? (string-ref line i) #\/) (substring line i (string-length line)))
            (else (loop (+ i 1))))))

  ;; libsodium-candidates : (U 'guix 'fhs) Symbol (String -> (U String #f))
  ;;                        -> (Listof (Pairof String Symbol))
  ;; Every candidate for WORLD and MACHINE-TYPE, in the order to probe, each
  ;; with its source. A machine type that is not Linux has none; WORLD must
  ;; be guix or fhs on Linux.
  (define (libsodium-candidates world machine-type getenv)
    (if (linux-machine-type? machine-type)
        (case world
          ((guix) (guix-candidates getenv))
          ((fhs) (fhs-candidates (linux-triple machine-type)))
          (else (assertion-violation 'libsodium-candidates "not a world: guix or fhs"
                                     world)))
        '()))

  ;; guix-candidates : (String -> (U String #f)) -> (Listof (Pairof String Symbol))
  ;; lib/libsodium.so.26, then lib/libsodium.so.23, under each Guix profile,
  ;; in ADR-0002's order. A variable unset or not absolute contributes
  ;; nothing. Never a standard directory.
  (define (guix-candidates getenv)
    (let* ((environment (absolute-or-false (getenv "GUIX_ENVIRONMENT")))
           (profile (absolute-or-false (getenv "GUIX_PROFILE")))
           (home (absolute-or-false (getenv "HOME"))))
      (append
       (profile-candidates environment 'guix-environment)
       (profile-candidates profile 'guix-profile)
       (profile-candidates (and home (string-append home "/.guix-home/profile"))
                           'guix-home)
       (profile-candidates (and home (string-append home "/.guix-profile"))
                           'guix-user-profile)
       (profile-candidates "/run/current-system/profile" 'guix-system))))

  ;; profile-candidates : (U String #f) Symbol -> (Listof (Pairof String Symbol))
  (define (profile-candidates profile source)
    (if profile
        (directory-candidates (string-append profile "/lib") source)
        '()))

  ;; directory-candidates : String Symbol -> (Listof (Pairof String Symbol))
  ;; Each soname in DIRECTORY, newer first, each with SOURCE.
  (define (directory-candidates directory source)
    (map (lambda (soname) (cons (string-append directory "/" soname) source))
         libsodium-sonames))

  ;; fhs-candidates : (U String #f) -> (Listof (Pairof String Symbol))
  ;; Each soname in each standard directory, in ADR-0002's order, directory
  ;; by directory. With no TRIPLE, no triple directory. Never a Guix profile.
  (define (fhs-candidates triple)
    (append-map
     (lambda (directory) (directory-candidates directory 'system))
     (append
      '("/usr/local/lib")
      (if triple (list (string-append "/usr/lib/" triple)) '())
      '("/usr/lib64" "/usr/lib"))))

  ;; append-map : (A -> (Listof B)) (Listof A) -> (Listof B)
  (define (append-map f lst)
    (apply append (map f lst)))

  ;; --- strings -----------------------------------------------------------------

  (define (absolute? s)
    (and (> (string-length s) 0) (char=? (string-ref s 0) #\/)))

  (define (absolute-or-false s)
    (and s (absolute? s) s))

  (define (string-prefix? prefix s)
    (let ((n (string-length s)) (m (string-length prefix)))
      (and (>= n m) (string=? (substring s 0 m) prefix))))

  (define (string-suffix? suffix s)
    (let ((n (string-length s)) (m (string-length suffix)))
      (and (>= n m) (string=? (substring s (- n m) n) suffix))))

  ;; basename : String -> String
  ;; What follows PATH's last /, or PATH when it holds none.
  (define (basename path)
    (let loop ((i (- (string-length path) 1)))
      (cond ((< i 0) path)
            ((char=? (string-ref path i) #\/)
             (substring path (+ i 1) (string-length path)))
            (else (loop (- i 1))))))

  ;; lines : String -> (Listof String)
  ;; TEXT split at each newline.
  (define (lines text)
    (let loop ((i 0) (start 0) (found '()))
      (cond ((= i (string-length text))
             (reverse (cons (substring text start i) found)))
            ((char=? (string-ref text i) #\newline)
             (loop (+ i 1) (+ i 1) (cons (substring text start i) found)))
            (else (loop (+ i 1) start found))))))
