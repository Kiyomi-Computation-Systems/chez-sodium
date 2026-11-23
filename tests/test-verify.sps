#!r6rs
;;; The suite for (chez-sodium private verify): what a loaded libsodium must
;;; offer (ADR-0002, ADR-0003), decided here on synthetic inputs.
;;;
;;;   check-version  the version string read as three naturals at or above
;;;                  the floor, 1.0.18, else below-floor: a lower version,
;;;                  NULL and anything unreadable alike
;;;   check-init     sodium_init's answer, 0 or 1, else init-failed
;;;
;;; The strings are written out here, never taken from the library, so a
;;; wrong constant fails here. The floor is also held to
;;; packaging/floors.sexp, the one file that writes it: sodium-floor must
;;; equal that file's libsodium floor, and check-version must accept it and
;;; refuse the version one patch below it (ADR-0011). A file and a library
;;; that disagree fail here, by name. The literal rows stay, so a floor
;;; changed in both places at once is a decision a reader of this suite sees.
;;;
;;; Which check runs first is native's order, not verify's.
;;;
;;; Each expected value is one the code under test cannot produce by failing.
;;; SRFI-64 turns a raise in the actual expression into #f, so no expected
;;; value here is #f: every call goes through `outcome`, which names what
;;; was raised or returned.
(import (rnrs)
        (srfi :64)
        (chez-sodium-testing)
        (chez-sodium private conditions)
        (chez-sodium private verify)
        (floors))

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

;; outcome : (-> Any) -> (U (List 'returned Any)
;;                          (List 'refused Symbol Any Any Any Any)
;;                          (List 'assertion-violation Any Any)
;;                          (List 'other-raise String))
;; What THUNK did: returned a value, raised &sodium-library-unavailable (its
;; reason, path, source, detail and candidates), raised an assertion
;; violation (its who and irritants), or raised something else.
(define (outcome thunk)
  (guard (e ((sodium-library-unavailable? e)
             (list 'refused
                   (sodium-library-unavailable-reason e)
                   (sodium-library-unavailable-path e)
                   (sodium-library-unavailable-source e)
                   (sodium-library-unavailable-detail e)
                   (sodium-library-unavailable-candidates e)))
            ((and (assertion-violation? e) (who-condition? e) (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other-raise (describe e))))
    (list 'returned (thunk))))

;; readable : (-> Any) -> List
;; What THUNK raised, as the default handler would show it: its type, its
;; who, and whether it holds a message; no-raise when it returned.
(define (readable thunk)
  (guard (e ((sodium-library-unavailable? e)
             (list (chez-sodium-error? e) (and (who-condition? e) (condition-who e))
                   (message-condition? e)))
            (#t 'other-raise))
    (thunk)
    'no-raise))

(define path "/usr/lib/aarch64-linux-gnu/libsodium.so.23")

;; refused-below : String-or-#f Symbol -> List
;; The outcome check-version must answer for an unreadable or low version.
(define (below detail source)
  (list 'refused 'below-floor path source detail '()))

;; version-outcome : Any Symbol -> List
(define (version-outcome v source)
  (outcome (lambda () (check-version v path source))))

;; --- the floor, from packaging/floors.sexp -----------------------------------

;; Each value is computed under a guard, and is a symbol when the file cannot
;; give it: a raise at top level would end the suite with no test named, and
;; one in an expected expression would escape SRFI-64.

;; floor-text-of-file : String or Symbol
;; The libsodium floor of packaging/floors.sexp, as text.
(define floor-text-of-file
  (guard (e (#t 'floors-file-unreadable))
    (floor-text (read-floors) 'sodium)))

;; floor-parts : (Listof Natural) or Symbol
;; That floor as three numbers.
(define floor-parts
  (guard (e (#t 'floors-file-unreadable))
    (let ((parts (floor-numbers (read-floors) 'sodium)))
      (if (= (length parts) 3) parts 'not-a-version))))

;; below-text : String or Symbol
;; The version one patch below the floor, written here and not by the library.
(define below-text
  (if (and (list? floor-parts) (> (caddr floor-parts) 0))
      (string-append (number->string (car floor-parts)) "."
                     (number->string (cadr floor-parts)) "."
                     (number->string (- (caddr floor-parts) 1)))
      'no-version-below))

(test-begin "verify")

;; --- check-version: the floor ------------------------------------------------

(test-equal "the floor is 1.0.18"
  '(1 0 18)
  sodium-floor)

(test-equal "the floor is the libsodium floor of packaging/floors.sexp"
  floor-parts
  sodium-floor)

(test-equal "check-version: the floor of packaging/floors.sexp is accepted"
  '(returned #t)
  (version-outcome floor-text-of-file 'system))

(test-equal "check-version: one patch below the floor of packaging/floors.sexp is below-floor, with that version"
  (list 'refused 'below-floor path 'system below-text '())
  (version-outcome below-text 'system))

(test-equal "check-version: 1.0.18, the floor itself, is accepted"
  '(returned #t)
  (version-outcome "1.0.18" 'system))

(test-equal "check-version: 1.0.17 is below-floor, with the version, path and source"
  (below "1.0.17" 'guix-home)
  (version-outcome "1.0.17" 'guix-home))

;; Each part is a number, and the major decides before the minor, the minor
;; before the patch. A comparison of text gets "1.0.9" and "1.0.100" wrong,
;; and a comparison of the patch alone gets "0.99.99" and "2.0.0" wrong.
(define above-floor
  '("1.0.18" "1.0.19" "1.0.22" "1.0.99" "1.0.100" "1.0.1000" "1.1.0" "1.9.0" "1.10.0"
    "1.100.0" "2.0.0" "10.0.0" "99.99.99" "1.0.99999999999999999999"))

(test-equal "check-version: at and above the floor, in every part: accepted"
  (map (lambda (v) '(returned #t)) above-floor)
  (map (lambda (v) (version-outcome v 'override)) above-floor))

(define below-floor-versions
  '("1.0.17" "1.0.9" "1.0.1" "1.0.0" "0.99.99" "0.100.0" "0.0.0" "0.1000.1000"))

(test-equal "check-version: below the floor, in every part: below-floor with the string as detail"
  (map (lambda (v) (below v 'override)) below-floor-versions)
  (map (lambda (v) (version-outcome v 'override)) below-floor-versions))

;; --- check-version: what it cannot read ------------------------------------------

;; The string must be exactly three parts of ASCII digits, joined by dots,
;; no part with a leading zero but 0 itself. Anything else is below-floor,
;; whatever number it might be read as, and raises nothing else. Each
;; string here would read as a version at or above the floor under some
;; looser rule: string->number, a trimmed or split string.
(define unreadable
  (list "1.0" "1" "1.0.18.0" "01.0.18" "1.00.18" "1.0.018" "00.0.18" "1.0.00" " 1.0.18"
        "1.0.18 " "1.0.18\n" "1.0.18\t" "\n1.0.18" "1.0.18-stable" "1.0.18rc1" "v1.0.18"
        "" "." ".." "..." "1..18" ".0.18" "1.0." "1.0.18." ".1.0.18" "+1.0.18" "1.+0.18"
        "1.0.+18" "-1.0.18" "1.0.-18" "1,0,18" "1.0.1e1" "1e0.0.18" "#x1.0.18"
        "1/1.0.18" "1.0.36/2" "1.0.18.5/3" "1. 0.18" "1.0.1 8"
        (string #\1 #\. #\0 #\. #\1 #\8 (integer->char 0))))

(test-equal "check-version: a string that is not three naturals is below-floor, with that string as detail"
  (map (lambda (v) (below v 'system)) unreadable)
  (map (lambda (v) (version-outcome v 'system)) unreadable))

;; char-numeric? holds for digits of other scripts, and string->number may
;; read some of them: only ASCII 0 to 9 are digits here.
(define non-ascii-digits
  (list (string (integer->char #x661) #\. #\0 #\. #\1 #\8)
        (string #\1 #\. #\0 #\. #\1 (integer->char #xFF18))
        (string #\1 #\. (integer->char #x660) #\. #\1 #\8)
        (string #\1 #\. #\0 #\. #\1 #\8 (integer->char #xA0))))

(test-equal "check-version: a digit that is not ASCII, or a trailing no-break space, is below-floor"
  (map (lambda (v) (below v 'system)) non-ascii-digits)
  (map (lambda (v) (version-outcome v 'system)) non-ascii-digits))

(test-equal "check-version: NULL, #f, is below-floor, with detail #f"
  (below #f 'system)
  (version-outcome #f 'system))

(test-equal "check-version: an object that is neither a string nor #f is an assertion violation from check-version, shown by kind"
  (list '(assertion-violation check-version (not-a-version (kind number)))
        '(assertion-violation check-version (not-a-version (kind symbol)))
        '(assertion-violation check-version (not-a-version (kind bytevector)))
        '(assertion-violation check-version (not-a-version (kind list)))
        '(assertion-violation check-version (not-a-version (kind char)))
        '(assertion-violation check-version (not-a-version (kind boolean))))
  (map (lambda (v) (version-outcome v 'system))
       (list 5 'x (string->utf8 "1.0.18") '("1.0.18") #\v #t)))

(test-equal "check-version: the answer is the string's alone: no other argument, libtool numbers least, decides it"
  (list '(returned #t) (below "1.0.17" 'system))
  (list (version-outcome "1.0.18" 'system)
        (version-outcome "1.0.17" 'system)))

;; --- check-init: sodium_init's answer ----------------------------------------------

(test-equal "check-init: 0, the first call, and 1, already initialized, are accepted"
  '((returned #t) (returned #t))
  (map (lambda (n) (outcome (lambda () (check-init n path 'system)))) '(0 1)))

(test-equal "check-init: any other integer is init-failed, detail the answer, with the path and source"
  (map (lambda (n) (list 'refused 'init-failed path 'override n '()))
       '(-1 2 3 256 -2147483648 4294967295 -4294967296))
  (map (lambda (n) (outcome (lambda () (check-init n path 'override))))
       '(-1 2 3 256 -2147483648 4294967295 -4294967296)))

;; 0 is truthy in Scheme, and 1.0 is an integer: neither a boolean nor an
;; inexact number may stand for an answer.
(test-equal "check-init: an answer that is no exact integer is an assertion violation from check-init, by kind: #f, 1.0, \"0\", a symbol, (), 1/2"
  (map (lambda (k) (list 'assertion-violation 'check-init (list 'not-an-answer (list 'kind k))))
       '(boolean number string symbol list number))
  (map (lambda (v) (outcome (lambda () (check-init v path 'system))))
       (list #f 1.0 "0" 'zero '() 1/2)))

;; --- both checks ---------------------------------------------------------------

(test-equal "every refusal is a chez-sodium-error from who chez-sodium, with a message, for the default handler"
  '((#t chez-sodium #t) (#t chez-sodium #t) (#t chez-sodium #t))
  (list (readable (lambda () (check-version "1.0.17" path 'system)))
        (readable (lambda () (check-version #f path 'system)))
        (readable (lambda () (check-init -1 path 'system)))))

;; Native runs them in its own order. Called on one path, in either order,
;; each decides alone.
(test-equal "the two checks decide alone: a pass of one never hides the refusal of the other, in either order"
  (list (list '(returned #t) (list 'refused 'init-failed "/p" 'system 2 '()))
        (list '(returned #t) (list 'refused 'below-floor "/p" 'system "1.0.9" '())))
  (let* ((v1 (outcome (lambda () (check-version "1.0.18" "/p" 'system))))
         (i1 (outcome (lambda () (check-init 2 "/p" 'system))))
         (i2 (outcome (lambda () (check-init 0 "/p" 'system))))
         (v2 (outcome (lambda () (check-version "1.0.9" "/p" 'system)))))
    (list (list v1 i1) (list i2 v2))))

(test-end "verify")

(exit (suite-exit-status runner))
