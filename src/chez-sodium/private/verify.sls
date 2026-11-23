#!r6rs
;;; (chez-sodium private verify): what a loaded libsodium must offer
;;; (ADR-0002, ADR-0003).
;;;
;;; Pure: the native layer reads sodium_version_string and calls sodium_init,
;;; and hands their answers here, so tests/test-verify.sps can make every
;;; decision on synthetic inputs. Each check takes the library's path and
;;; source, and every refusal carries them. Which runs first, the floor and
;;; then sodium_init, is native's order (ADR-0002).
;;;
;;;   check-version  the version string read as three naturals at or above
;;;                  the floor, else below-floor: a lower version, NULL and
;;;                  a string that is not three naturals alike
;;;   check-init     sodium_init's answer, 0 or 1, else init-failed
;;;
;;; The floor is held to packaging/floors.sexp by behaviour, in
;;; tests/test-verify.sps (ADR-0011).
(library (chez-sodium private verify)
  (export sodium-floor check-version check-init)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (chez-sodium private conditions))

  ;; sodium-floor : (List Natural Natural Natural)
  ;; The oldest libsodium chez-sodium loads: major, minor, patch (ADR-0003).
  (define sodium-floor '(1 0 18))

  ;; exact-integer? : Any -> Boolean
  (define (exact-integer? x)
    (and (integer? x) (exact? x)))

  ;; check-version : (U String #f) String Symbol -> #t
  ;; #t when VERSION-STRING reads as three naturals, with no sign, space or
  ;; leading zero, that are at or above the floor, compared as numbers.
  ;; Otherwise, a lower version, #f (NULL) and a string that is not three
  ;; naturals alike, raises &sodium-library-unavailable, reason below-floor,
  ;; carrying PATH, SOURCE and VERSION-STRING as its detail. Anything that is
  ;; neither a string nor #f is an assertion violation: only a fault in the
  ;; caller makes one.
  (define (check-version version-string path source)
    (unless (or (not version-string) (string? version-string))
      (assertion-violation 'check-version "the version is neither a string nor #f"
                           'not-a-version (secret-shown version-string)))
    (let ((version (and version-string (parse-version version-string))))
      (if (and version (version<=? sodium-floor version))
          #t
          (raise-library-unavailable
           'below-floor path source version-string '()
           (string-append
            (if version-string
                (string-append "libsodium " version-string " is older than chez-sodium's floor, ")
                "libsodium's version string is NULL, and chez-sodium's floor is ")
            (floor->string)
            "; name a newer one with CHEZ_SODIUM_LIBRARY")
           (list path)))))

  ;; check-init : Integer String Symbol -> #t
  ;; #t when ANSWER, what sodium_init answered, is 0 or 1: 1 means it had been
  ;; called already, which is no failure. Any other exact integer raises
  ;; &sodium-library-unavailable, reason init-failed, detail ANSWER, carrying
  ;; PATH and SOURCE. An ANSWER that is no exact integer is an assertion
  ;; violation: a foreign int always answers one, and 0 is truthy, so no flag
  ;; can stand for it.
  (define (check-init answer path source)
    (unless (exact-integer? answer)
      (assertion-violation 'check-init "the answer is not an exact integer"
                           'not-an-answer (secret-shown answer)))
    (if (or (= answer 0) (= answer 1))
        #t
        (raise-library-unavailable
         'init-failed path source answer '()
         "sodium_init failed; name another libsodium with CHEZ_SODIUM_LIBRARY"
         (list path))))

  ;; parse-version : String -> (U (List Natural Natural Natural) #f)
  ;; S as three naturals joined by dots, each part ASCII digits alone, none
  ;; with a leading zero but 0 itself; #f for anything else. Characters are
  ;; tested one by one: string->number takes signs, fractions and radix
  ;; prefixes, and char-numeric? takes digits of other scripts.
  (define (parse-version s)
    (let ((parts (split-dots s)))
      (and (= (length parts) 3)
           (for-all natural-text? parts)
           (map string->number parts))))

  ;; natural-text? : String -> Boolean
  (define (natural-text? part)
    (let ((n (string-length part)))
      (and (> n 0)
           (for-all ascii-digit? (string->list part))
           (or (= n 1) (not (char=? (string-ref part 0) #\0))))))

  ;; ascii-digit? : Char -> Boolean
  (define (ascii-digit? c)
    (and (char>=? c #\0) (char<=? c #\9)))

  ;; split-dots : String -> (Listof String)
  ;; S split at each dot, empty parts kept.
  (define (split-dots s)
    (let loop ((i 0) (start 0) (found '()))
      (cond ((= i (string-length s))
             (reverse (cons (substring s start i) found)))
            ((char=? (string-ref s i) #\.)
             (loop (+ i 1) (+ i 1) (cons (substring s start i) found)))
            (else (loop (+ i 1) start found)))))

  ;; version<=? : (Listof Natural) (Listof Natural) -> Boolean
  ;; A is at or below B, part by part from the major, as numbers.
  (define (version<=? a b)
    (cond ((null? a) #t)
          ((< (car a) (car b)) #t)
          ((> (car a) (car b)) #f)
          (else (version<=? (cdr a) (cdr b)))))

  ;; floor->string : -> String
  ;; The floor as dotted text, for a remedy.
  (define (floor->string)
    (let loop ((parts sodium-floor) (out ""))
      (cond ((null? parts) out)
            ((string=? out "") (loop (cdr parts) (number->string (car parts))))
            (else (loop (cdr parts) (string-append out "." (number->string (car parts)))))))))
