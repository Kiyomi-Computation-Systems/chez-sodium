#!r6rs
;;; (chez-sodium private conditions): chez-sodium's condition types. Every
;;; one is a &chez-sodium-error, so a caller can catch the family or one
;;; member (ADR-0006).
;;;
;;;   &chez-sodium-error           the root, fieldless, under &error
;;;   &sodium-library-unavailable  libsodium was refused (ADR-0002)
;;;   &sodium-failed               libsodium answered a failure for a call
;;;                                that passed its range checks (ADR-0006)
;;;
;;; A raise may compound one with &who, &message and &irritants, so that the
;;; default handler prints readable text. Tests assert the reason symbol,
;;; who and irritants, never that text.
;;;
;;; Also the helpers that name a caller's value by its kind, and
;;; refuse-secret, which refuses a secret parameter by that kind alone
;;; (ADR-0006, decision 6).
(library (chez-sodium private conditions)
  (export &chez-sodium-error make-chez-sodium-error chez-sodium-error?

          &sodium-library-unavailable make-sodium-library-unavailable
          sodium-library-unavailable?
          sodium-library-unavailable-reason sodium-library-unavailable-path
          sodium-library-unavailable-source sodium-library-unavailable-detail
          sodium-library-unavailable-candidates
          sodium-library-unavailable-reasons

          raise-library-unavailable

          &sodium-failed make-sodium-failed sodium-failed?
          sodium-failed-function sodium-failed-code
          raise-sodium-failed

          kind-of shown-value secret-shown refuse-secret checked-accessor)
  (import (chez-sodium private require-threaded)
          (rnrs))

  ;; make-chez-sodium-error : -> &chez-sodium-error
  ;; chez-sodium-error? : Any -> Boolean
  (define-condition-type &chez-sodium-error &error
    make-chez-sodium-error chez-sodium-error?)

  ;; --- a caller's value, as a refusal names it -------------------------------------

  ;; kind-of : Any -> Symbol
  ;; X's kind: string, list, number, boolean, char, symbol, bytevector,
  ;; vector, procedure or other. Pure, and never walks X.
  (define (kind-of x)
    (cond ((string? x) 'string)
          ((or (pair? x) (null? x)) 'list)
          ((number? x) 'number)
          ((boolean? x) 'boolean)
          ((char? x) 'char)
          ((symbol? x) 'symbol)
          ((bytevector? x) 'bytevector)
          ((vector? x) 'vector)
          ((procedure? x) 'procedure)
          (else 'other)))

  ;; shown-atom? : Any -> Boolean
  (define (shown-atom? x)
    (or (symbol? x) (number? x) (boolean? x) (char? x) (null? x)))

  ;; shown-value : Any -> Any
  ;; X as a refusal names a library-internal value: itself when it is
  ;; shown-atom?, or a proper list of them; else (kind K). Only for sizes,
  ;; limits and preset names, never for a value a caller supplied: use
  ;; secret-shown for that. Pure.
  (define (shown-value x)
    (if (or (shown-atom? x) (and (list? x) (for-all shown-atom? x)))
        x
        (list 'kind (kind-of x))))

  ;; secret-shown : Any -> (List 'kind Symbol)
  ;; X by its kind alone, whatever X is: never the value, never its length.
  (define (secret-shown x)
    (list 'kind (kind-of x)))

  ;; refuse-field : Symbol Symbol String Any -> Nothing
  ;; WHO's refusal of VALUE for FIELD: an assertion violation, "not WHAT",
  ;; whose irritants are FIELD, then VALUE by kind, so two refusals from one
  ;; WHO are told apart without their message.
  (define (refuse-field who field what value)
    (assertion-violation who (string-append "not " what) field (secret-shown value)))

  ;; refuse-secret : Symbol Symbol Symbol Any [Natural Natural] -> Nothing
  ;; WHO's refusal of VALUE, a secret parameter, under RULE: an assertion
  ;; violation whose irritants are RULE, PARAMETER and VALUE's kind, in that
  ;; order. WHO, RULE and PARAMETER must be symbols, else the refusal is
  ;; refuse-secret's own. LOW and HIGH, when given, are the bound the message
  ;; states, in bytes: each an exact natural, LOW no more than HIGH, else the
  ;; refusal is refuse-secret's own, irritants (low (kind K)) or (high (kind
  ;; K)), K the kind of what was given. The message is written here from the
  ;; two numbers; nothing of VALUE reaches it, and a bound never changes the
  ;; irritants.
  (define refuse-secret
    (case-lambda
      ((who rule parameter value) (refuse-secret* who rule parameter value no-bound no-bound))
      ((who rule parameter value low high)
       (refuse-secret* who rule parameter value low high))))

  ;; no-bound : Any
  ;; What refuse-secret passes for LOW and HIGH when the caller gave none. No
  ;; caller's value is eq? to it, so a bound of #f is still a refusal.
  (define no-bound (list 'no-bound))

  ;; exact-natural? : Any -> Boolean
  (define (exact-natural? x)
    (and (integer? x) (exact? x) (>= x 0)))

  ;; refuse-secret* : Symbol Symbol Symbol Any Any Any -> Nothing
  ;; refuse-secret's body: LOW and HIGH are no-bound when there is no bound.
  (define (refuse-secret* who rule parameter value low high)
    (define bound? (not (eq? low no-bound)))
    (unless (symbol? who)
      (refuse-field 'refuse-secret 'who "a symbol" who))
    (unless (symbol? rule)
      (refuse-field 'refuse-secret 'rule "a symbol" rule))
    (unless (symbol? parameter)
      (refuse-field 'refuse-secret 'parameter "a symbol" parameter))
    (when bound?
      (unless (exact-natural? low)
        (refuse-field 'refuse-secret 'low "an exact natural" low))
      (unless (and (exact-natural? high) (<= low high))
        (refuse-field 'refuse-secret 'high "an exact natural, no less than low" high)))
    (assertion-violation who
                         (string-append
                          (symbol->string parameter) " is refused: "
                          (symbol->string rule) ", shown by its kind alone"
                          (cond ((not bound?) "")
                                ((= low 0)
                                 (string-append "; " (symbol->string parameter)
                                                " is at most " (number->string high) " bytes"))
                                (else
                                 (string-append "; " (symbol->string parameter) " is "
                                                (number->string low) " to "
                                                (number->string high) " bytes"))))
                         rule parameter (secret-shown value)))

  ;; checked-accessor : Symbol Symbol (Any -> Boolean) String (Any -> Any) -> (Any -> Any)
  ;; ACCESSOR, a record's or a condition type's, for WHO: called on what
  ;; PREDICATE holds; anything else an assertion violation from WHO, "not
  ;; WHAT", whose irritants are RULE, then the argument by kind, never the
  ;; value.
  (define (checked-accessor who rule predicate what accessor)
    (lambda (x)
      (unless (predicate x)
        (assertion-violation who (string-append "not " what) rule (secret-shown x)))
      (accessor x)))

  ;; --- &sodium-library-unavailable ---------------------------------------------

  ;; sodium-library-unavailable-reasons : (Listof Symbol)
  ;; Why a libsodium was refused. They are the contract: tests and CI assert
  ;; these symbols, never the message (ADR-0002).
  ;;
  ;;   invalid-override  CHEZ_SODIUM_LIBRARY is set, but not to an absolute path
  ;;   not-found         no candidate exists
  ;;   load-failed       the loader refused the chosen path
  ;;   below-floor       the library is older than the floor, or its version
  ;;                     cannot be read
  ;;   missing-api       a required entry point is absent
  ;;   init-failed       sodium_init answered anything but 0 or 1
  (define sodium-library-unavailable-reasons
    '(invalid-override not-found load-failed below-floor missing-api init-failed))

  ;; The fields:
  ;;
  ;;   reason      one of sodium-library-unavailable-reasons
  ;;   path        (U String #f): the library refused, #f when none was chosen
  ;;   source      (U Symbol #f): where the path came from, one of
  ;;               (chez-sodium private discovery)'s libsodium-sources, or #f
  ;;   detail      by reason: the override's value (invalid-override), the
  ;;               loader's message (load-failed), the version string, or #f
  ;;               for NULL (below-floor), the entry point's C name
  ;;               (missing-api), the integer sodium_init answered
  ;;               (init-failed), #f (not-found)
  ;;   candidates  (Listof String): every path checked, in order (not-found)
  ;;
  ;; sodium-library-unavailable? : Any -> Boolean
  (define-condition-type &sodium-library-unavailable &chez-sodium-error
    unchecked-make-sodium-library-unavailable sodium-library-unavailable?
    (reason unchecked-sodium-library-unavailable-reason)
    (path unchecked-sodium-library-unavailable-path)
    (source unchecked-sodium-library-unavailable-source)
    (detail unchecked-sodium-library-unavailable-detail)
    (candidates unchecked-sodium-library-unavailable-candidates))

  ;; Each accessor checks its argument first: anything else is an assertion
  ;; violation from the accessor, naming it by kind.
  ;;
  ;; sodium-library-unavailable-reason : SodiumLibraryUnavailable -> Reason
  ;;   Reason = (U 'invalid-override 'not-found 'load-failed 'below-floor
  ;;               'missing-api 'init-failed)
  ;; sodium-library-unavailable-path : SodiumLibraryUnavailable -> (U String #f)
  ;; sodium-library-unavailable-source : SodiumLibraryUnavailable -> (U Symbol #f)
  ;; sodium-library-unavailable-detail : SodiumLibraryUnavailable -> Any
  ;; sodium-library-unavailable-candidates : SodiumLibraryUnavailable -> (Listof String)
  (define sodium-library-unavailable-reason
    (checked-accessor 'sodium-library-unavailable-reason
                      'not-a-sodium-library-unavailable
                      sodium-library-unavailable? "a &sodium-library-unavailable"
                      unchecked-sodium-library-unavailable-reason))
  (define sodium-library-unavailable-path
    (checked-accessor 'sodium-library-unavailable-path
                      'not-a-sodium-library-unavailable
                      sodium-library-unavailable? "a &sodium-library-unavailable"
                      unchecked-sodium-library-unavailable-path))
  (define sodium-library-unavailable-source
    (checked-accessor 'sodium-library-unavailable-source
                      'not-a-sodium-library-unavailable
                      sodium-library-unavailable? "a &sodium-library-unavailable"
                      unchecked-sodium-library-unavailable-source))
  (define sodium-library-unavailable-detail
    (checked-accessor 'sodium-library-unavailable-detail
                      'not-a-sodium-library-unavailable
                      sodium-library-unavailable? "a &sodium-library-unavailable"
                      unchecked-sodium-library-unavailable-detail))
  (define sodium-library-unavailable-candidates
    (checked-accessor 'sodium-library-unavailable-candidates
                      'not-a-sodium-library-unavailable
                      sodium-library-unavailable? "a &sodium-library-unavailable"
                      unchecked-sodium-library-unavailable-candidates))

  ;; make-sodium-library-unavailable : Symbol (U String #f) (U Symbol #f) Any
  ;;                                   (Listof String) -> &sodium-library-unavailable
  ;; Refuses a REASON that is not one of the six with an assertion violation,
  ;; so a misspelt reason cannot reach a caller who tests for the right one.
  ;; A reason is an internal name, so it is shown as it is.
  (define (make-sodium-library-unavailable reason path source detail candidates)
    (unless (memq reason sodium-library-unavailable-reasons)
      (assertion-violation 'make-sodium-library-unavailable
                           "not a reason chez-sodium refuses a libsodium for"
                           (shown-value reason)))
    (unchecked-make-sodium-library-unavailable reason path source detail candidates))

  ;; raise-library-unavailable : Symbol (U String #f) (U Symbol #f) Any (Listof String)
  ;;                              String (Listof Any) -> Nothing
  ;; The one way a private caller refuses a libsodium: raises a
  ;; &sodium-library-unavailable built with REASON, PATH, SOURCE, DETAIL and
  ;; CANDIDATES, compounded with &who chez-sodium, a &message holding MESSAGE
  ;; and &irritants holding IRRITANTS. A REASON the constructor refuses is an
  ;; assertion violation.
  (define (raise-library-unavailable reason path source detail candidates message irritants)
    (raise (condition (make-sodium-library-unavailable reason path source detail candidates)
                      (make-who-condition 'chez-sodium)
                      (make-message-condition message)
                      (make-irritants-condition irritants))))

  ;; --- &sodium-failed (ADR-0006) -----------------------------------------------------
  ;;
  ;;   function  the C function's name, a string
  ;;   code      the integer it answered
  ;;
  ;; The verb is the raise's &who. Neither field is a secret.
  ;;
  ;; sodium-failed? : Any -> Boolean
  (define-condition-type &sodium-failed &chez-sodium-error
    unchecked-make-sodium-failed sodium-failed?
    (function unchecked-sodium-failed-function)
    (code unchecked-sodium-failed-code))

  ;; sodium-failed-function : SodiumFailed -> String
  ;; sodium-failed-code : SodiumFailed -> Integer
  (define sodium-failed-function
    (checked-accessor 'sodium-failed-function 'not-a-sodium-failed sodium-failed? "a &sodium-failed"
                      unchecked-sodium-failed-function))
  (define sodium-failed-code
    (checked-accessor 'sodium-failed-code 'not-a-sodium-failed sodium-failed? "a &sodium-failed"
                      unchecked-sodium-failed-code))

  ;; exact-integer? : Any -> Boolean
  (define (exact-integer? x) (and (integer? x) (exact? x)))

  ;; make-sodium-failed : String Integer -> &sodium-failed
  ;; FUNCTION must be a string and CODE an exact integer, else an assertion
  ;; violation naming the field.
  (define (make-sodium-failed function code)
    (unless (string? function)
      (refuse-field 'make-sodium-failed 'function "a string" function))
    (unless (exact-integer? code)
      (refuse-field 'make-sodium-failed 'code "an exact integer" code))
    (unchecked-make-sodium-failed function code))

  ;; check-raise-who : Symbol Any -> Void
  ;; HELPER's refusal of a WHO that is no symbol.
  (define (check-raise-who helper who)
    (unless (symbol? who)
      (refuse-field helper 'who "a symbol" who)))

  ;; raise-sodium-failed : Symbol String Integer -> Nothing
  ;; A &sodium-failed of FUNCTION and CODE, compounded with &who WHO and a
  ;; fixed &message, no irritants. A WHO that is no symbol is an assertion
  ;; violation from raise-sodium-failed; a field the constructor refuses, one
  ;; from it.
  (define (raise-sodium-failed who function code)
    (check-raise-who 'raise-sodium-failed who)
    (let ((c (make-sodium-failed function code)))
      (raise (condition c (make-who-condition who)
                        (make-message-condition
                         "libsodium answered a failure for a call that passed its checks"))))))
