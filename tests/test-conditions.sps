#!r6rs
;;; The suite for (chez-sodium private conditions): the root every library
;;; condition sits under, the conditions beneath it, and the procedures that
;;; raise them (ADR-0006, ADR-0002).
;;;
;;;   &chez-sodium-error           the fieldless root, under &error
;;;   &sodium-library-unavailable  libsodium was refused: six reasons, and
;;;                                what the refusal is about
;;;   &sodium-failed               libsodium answered a failure: the C
;;;                                function's name and the integer it answered
;;;
;;; Then kind-of, shown-value and checked-accessor, which name a value by
;;; its kind where a refusal would print it, secret-shown, which does so for
;;; any value whatever, and refuse-secret, which refuses a secret parameter
;;; by its kind alone.
;;;
;;; The kinds are held as a whole matrix, so no type can sit under another.
;;; A refusal is asserted by its who and its irritants, never its message;
;;; each refusal names the field or the rule first among its irritants.
;;;
;;; Each expected value is one the code under test cannot produce by failing.
;;; SRFI-64 turns a raise in the actual expression into #f, so no expected
;;; value here is #f, and every refusal is compared against a no-raise
;;; sentinel. Each fixture field holds a value no other field holds, so an
;;; accessor that read the wrong field cannot pass.
(import (rnrs)
        (rnrs mutable-pairs)
        (rnrs records inspection)
        (only (chezscheme) library-exports)
        (srfi :64)
        (chez-sodium-testing)
        (chez-sodium private conditions))

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

;; raised : (-> Any) -> Any
;; What THUNK raised: (assertion-violation WHO IRRITANTS), (other TEXT) for
;; any other raise, or (no-raise VALUE). The message is a condition's type,
;; not its text: its wording is no contract (ADR-0006).
(define (raised thunk)
  (guard (e ((and (assertion-violation? e) (who-condition? e) (message-condition? e)
                  (irritants-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other (describe e))))
    (list 'no-raise (thunk))))

;; contains? : String String -> Boolean
(define (contains? text part)
  (let ((n (string-length text)) (k (string-length part)))
    (let loop ((i 0))
      (and (<= (+ i k) n) (or (string=? (substring text i (+ i k)) part) (loop (+ i 1)))))))

;; kinds : Any -> (List Boolean Boolean Boolean)
;; Which of error?, chez-sodium-error? and sodium-library-unavailable? hold.
(define (kinds c)
  (list (error? c) (chez-sodium-error? c) (sodium-library-unavailable? c)))

;; A refusal whose every field differs from every other field.
(define (a-library-unavailable)
  (make-sodium-library-unavailable 'below-floor
                                   "/opt/sodium/lib/libsodium.so.26"
                                   'override
                                   "1.0.17"
                                   '("/opt/sodium/lib/libsodium.so.26" "/usr/lib/libsodium.so.23")))

;; A failure whose two fields differ.
(define (a-sodium-failed) (make-sodium-failed "crypto_pwhash_str" -1))

(define secret "Pr0xyS3cr3t")

(define (sorted-names names)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) names))

(test-begin "conditions")

(test-equal "(chez-sodium private conditions) exports exactly these names, written out"
  (sorted-names
   '(&chez-sodium-error make-chez-sodium-error chez-sodium-error?
     &sodium-library-unavailable make-sodium-library-unavailable sodium-library-unavailable?
     sodium-library-unavailable-reason sodium-library-unavailable-path
     sodium-library-unavailable-source sodium-library-unavailable-detail
     sodium-library-unavailable-candidates
     sodium-library-unavailable-reasons raise-library-unavailable
     &sodium-failed make-sodium-failed sodium-failed? sodium-failed-function
     sodium-failed-code raise-sodium-failed
     kind-of shown-value secret-shown refuse-secret checked-accessor))
  (guard (e (#t (list 'raised (describe e))))
    (sorted-names (library-exports '(chez-sodium private conditions)))))

;; --- &chez-sodium-error ---------------------------------------------------

(test-equal "make-chez-sodium-error: an error and a chez-sodium-error, and not a library-unavailable"
  '(#t #t #f)
  (kinds (make-chez-sodium-error)))

(test-equal "chez-sodium-error? is false for a plain error, a message, a symbol and #f"
  '(#f #f #f #f)
  (map chez-sodium-error? (list (make-error) (make-message-condition "m") 'x #f)))

;; --- &sodium-library-unavailable --------------------------------------------

(test-equal "library-unavailable: an error, a chez-sodium-error and a library-unavailable"
  '(#t #t #t)
  (kinds (a-library-unavailable)))

(test-equal "library-unavailable carries its reason, path, source, detail and candidates"
  '(below-floor
    "/opt/sodium/lib/libsodium.so.26"
    override
    "1.0.17"
    ("/opt/sodium/lib/libsodium.so.26" "/usr/lib/libsodium.so.23"))
  (let ((c (a-library-unavailable)))
    (list (sodium-library-unavailable-reason c)
          (sodium-library-unavailable-path c)
          (sodium-library-unavailable-source c)
          (sodium-library-unavailable-detail c)
          (sodium-library-unavailable-candidates c))))

(test-equal "the reasons are exactly ADR-0002's six, amended, in order"
  '(invalid-override not-found load-failed below-floor missing-api init-failed)
  sodium-library-unavailable-reasons)

;; Written out here, not taken from the export: a reason dropped from the
;; exported list must fail this test, not shrink it.
(test-equal "the constructor takes each of the six reasons"
  '(invalid-override not-found load-failed below-floor missing-api init-failed)
  (map (lambda (reason)
         (sodium-library-unavailable-reason
          (make-sodium-library-unavailable reason #f #f #f '())))
       '(invalid-override not-found load-failed below-floor missing-api init-failed)))

;; One refusal of each reason, with the fields that reason carries (ADR-0002):
;; each field read back, none a default.
(test-equal "each reason, built with the fields it carries, answers every field"
  '((invalid-override #f override "lib/x.so" ())
    (not-found #f #f #f ("/a/libsodium.so.26" "/b/libsodium.so.26"))
    (load-failed "/c/libsodium.so.26" guix-home "cannot open shared object file" ())
    (below-floor "/d/libsodium.so.23" system "1.0.17" ())
    (below-floor "/d/libsodium.so.23" system #f ())
    (missing-api "/f/libsodium.so.26" guix-system "sodium_memzero" ())
    (init-failed "/g/libsodium.so.26" system 2 ())
    (init-failed "/g/libsodium.so.26" system -1 ()))
  (map (lambda (c)
         (list (sodium-library-unavailable-reason c)
               (sodium-library-unavailable-path c)
               (sodium-library-unavailable-source c)
               (sodium-library-unavailable-detail c)
               (sodium-library-unavailable-candidates c)))
       (list
        (make-sodium-library-unavailable 'invalid-override #f 'override "lib/x.so" '())
        (make-sodium-library-unavailable 'not-found #f #f #f
                                         '("/a/libsodium.so.26" "/b/libsodium.so.26"))
        (make-sodium-library-unavailable 'load-failed "/c/libsodium.so.26" 'guix-home
                                         "cannot open shared object file" '())
        (make-sodium-library-unavailable 'below-floor "/d/libsodium.so.23" 'system "1.0.17" '())
        (make-sodium-library-unavailable 'below-floor "/d/libsodium.so.23" 'system #f '())
        (make-sodium-library-unavailable 'missing-api "/f/libsodium.so.26" 'guix-system
                                         "sodium_memzero" '())
        (make-sodium-library-unavailable 'init-failed "/g/libsodium.so.26" 'system 2 '())
        (make-sodium-library-unavailable 'init-failed "/g/libsodium.so.26" 'system -1 '()))))

(test-equal "the record's own fields are reason, path, source, detail and candidates, and no more"
  '#(reason path source detail candidates)
  (guard (e (#t (list 'raised (describe e))))
    (record-type-field-names (record-type-descriptor &sodium-library-unavailable))))

(test-equal "the constructor refuses a symbol that is not a reason"
  '(assertion-violation make-sodium-library-unavailable (library-missing))
  (raised (lambda ()
            (make-sodium-library-unavailable 'library-missing #f #f #f '()))))

(test-equal "the constructor refuses no-ssl, #f, a number, () and a reason spelled as a string, and chez-sqlite3's not-threadsafe"
  '((assertion-violation make-sodium-library-unavailable (no-ssl))
    (assertion-violation make-sodium-library-unavailable (#f))
    (assertion-violation make-sodium-library-unavailable (5))
    (assertion-violation make-sodium-library-unavailable (()))
    (assertion-violation make-sodium-library-unavailable ((kind string)))
    (assertion-violation make-sodium-library-unavailable (not-threadsafe)))
  (map (lambda (r)
         (raised (lambda () (make-sodium-library-unavailable r #f #f #f '()))))
       (list 'no-ssl #f 5 '() "not-found" 'not-threadsafe)))

;; The allowlist against its whole complement, for each of the six: the
;; symbol upper-cased, with a suffix, and missing its last character. A reason
;; matched case-insensitively, by prefix, or as text takes one of these.
(define near-reasons
  '(INVALID-OVERRIDE NOT-FOUND LOAD-FAILED BELOW-FLOOR MISSING-API INIT-FAILED
    invalid-override-x not-found-x load-failed-x below-floor-x missing-api-x init-failed-x
    invalid-overrid not-foun load-faile below-floo missing-ap init-faile))

(test-equal "the constructor refuses each reason upper-cased, with a suffix, or missing its last character"
  (map (lambda (r) (list 'assertion-violation 'make-sodium-library-unavailable (list r)))
       near-reasons)
  (map (lambda (r)
         (raised (lambda () (make-sodium-library-unavailable r #f #f #f '()))))
       near-reasons))

(test-equal "the constructor refuses each of the six reasons spelled as a string, naming it by its kind"
  (map (lambda (r)
         '(assertion-violation make-sodium-library-unavailable ((kind string))))
       '(1 2 3 4 5 6))
  (map (lambda (r)
         (raised (lambda () (make-sodium-library-unavailable r #f #f #f '()))))
       '("invalid-override" "not-found" "load-failed" "below-floor" "missing-api"
         "init-failed")))

(test-equal "the constructor refuses a char, a vector and a condition as a reason"
  '((assertion-violation make-sodium-library-unavailable (#\n))
    (assertion-violation make-sodium-library-unavailable ((kind vector)))
    (assertion-violation make-sodium-library-unavailable ((kind other))))
  (map (lambda (r)
         (raised (lambda () (make-sodium-library-unavailable r #f #f #f '()))))
       (list #\n (vector 'not-found) (make-error))))

;; --- raise-library-unavailable -----------------------------------------------------

;; refused : (-> Any) -> Any
;; What THUNK raised, as the whole condition: its type, who, message
;; (whether there is one, never its text), irritants and five fields; or
;; (assertion-violation ...) or (no-raise) when it raised something else or
;; nothing.
(define (refused thunk)
  (guard (e ((sodium-library-unavailable? e)
             (list 'refused
                   (kinds e)
                   (serious-condition? e)
                   (and (who-condition? e) (condition-who e))
                   (message-condition? e)
                   (and (irritants-condition? e) (condition-irritants e))
                   (sodium-library-unavailable-reason e)
                   (sodium-library-unavailable-path e)
                   (sodium-library-unavailable-source e)
                   (sodium-library-unavailable-detail e)
                   (sodium-library-unavailable-candidates e)))
            ((and (assertion-violation? e) (who-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other-raise (describe e))))
    (thunk)
    'no-raise))

(test-equal "raise-library-unavailable raises the whole condition: the types, who chez-sodium, a message, the irritants as given and the five fields"
  '(refused (#t #t #t) #t chez-sodium #t ("/p" lib 3)
    below-floor "/opt/p/libsodium.so.26" guix-system "1.0.17" ("/c1" "/c2"))
  (refused (lambda ()
             (raise-library-unavailable 'below-floor "/opt/p/libsodium.so.26" 'guix-system "1.0.17"
                                        '("/c1" "/c2") "any message" '("/p" lib 3)))))

(test-equal "raise-library-unavailable with no path or source, and no irritants"
  '(refused (#t #t #t) #t chez-sodium #t ()
    not-found #f #f #f ("/a"))
  (refused (lambda ()
             (raise-library-unavailable 'not-found #f #f #f '("/a") "another message" '()))))

;; A handler that returns must not make the raise return: the load would go on
;; as if the library were accepted.
(test-equal "raise-library-unavailable never returns: a handler that returns gets nothing back, and the raise goes on to the next handler"
  'raised-on
  (guard (e (#t 'raised-on))
    (with-exception-handler
     (lambda (c) 'handled)
     (lambda () (raise-library-unavailable 'not-found #f #f #f '() "m" '())))
    'returned-normally))

(test-equal "raise-library-unavailable takes each of the six reasons"
  '(invalid-override not-found load-failed below-floor missing-api init-failed)
  (map (lambda (r)
         (let ((c (refused (lambda ()
                             (raise-library-unavailable r #f #f #f '() "m" '())))))
           (if (and (pair? c) (eq? (car c) 'refused)) (list-ref c 6) c)))
       '(invalid-override not-found load-failed below-floor missing-api init-failed)))

(test-equal "raise-library-unavailable refuses a reason the constructor refuses, with an assertion violation from the constructor"
  '(assertion-violation make-sodium-library-unavailable (no-ssl))
  (refused (lambda ()
             (raise-library-unavailable 'no-ssl #f #f #f '() "m" '()))))

;; The five accessors, each refusing what is not a refusal by its kind.
(define lib-accessors
  (list (cons 'sodium-library-unavailable-reason sodium-library-unavailable-reason)
        (cons 'sodium-library-unavailable-path sodium-library-unavailable-path)
        (cons 'sodium-library-unavailable-source sodium-library-unavailable-source)
        (cons 'sodium-library-unavailable-detail sodium-library-unavailable-detail)
        (cons 'sodium-library-unavailable-candidates sodium-library-unavailable-candidates)))

;; refusal : Symbol Symbol Any -> List
;; A refusal by WHO under RULE, the rule symbol leading the irritants.
(define (refusal who rule shown)
  (list 'assertion-violation who (list rule shown)))

;; The rule each family's accessors refuse under.
(define (lib-refusal who shown)
  (refusal who 'not-a-sodium-library-unavailable shown))
(define (failed-refusal who shown)
  (refusal who 'not-a-sodium-failed shown))

(test-equal "every accessor refuses a string by its kind, naming the accessor, not the string"
  (map (lambda (a) (lib-refusal (car a) '(kind string))) lib-accessors)
  (map (lambda (a) (raised (lambda () ((cdr a) secret)))) lib-accessors))

;; A symbol, a number, a boolean and a list of chars come from a caller, so
;; each is named by its kind too: none is shown as it is.
(test-equal "every accessor refuses a plain error, the root alone, a message, an &sodium-failed, #f, a number, a symbol, a list holding a string and a vector holding one, each by its kind"
  (map (lambda (a)
         (list (lib-refusal (car a) '(kind other))
               (lib-refusal (car a) '(kind other))
               (lib-refusal (car a) '(kind other))
               (lib-refusal (car a) '(kind other))
               (lib-refusal (car a) '(kind boolean))
               (lib-refusal (car a) '(kind number))
               (lib-refusal (car a) '(kind symbol))
               (lib-refusal (car a) '(kind list))
               (lib-refusal (car a) '(kind vector))))
       lib-accessors)
  (map (lambda (a)
         (map (lambda (v) (raised (lambda () ((cdr a) v))))
              (list (make-error) (make-chez-sodium-error) (make-message-condition secret)
                    (a-sodium-failed) #f 5 'hunter2
                    (list "u" secret) (vector secret))))
       lib-accessors))

(test-equal "no accessor prints the secret it refused, bare, in a list or in a vector"
  (map (lambda (a) '(absent absent absent)) lib-accessors)
  (map (lambda (a)
         (map (lambda (v)
                (let ((text (guard (e (#t (describe e)))
                              ((cdr a) v)
                              'no-raise)))
                  (cond ((eq? text 'no-raise) 'no-raise)
                        ((contains? text secret) 'printed)
                        (else 'absent))))
              (list secret (list "u" secret) (vector secret))))
       lib-accessors))

;; --- checked-accessor --------------------------------------------------------

(test-equal "checked-accessor answers the accessor's value for what the predicate holds, and refuses the rest, from WHO, naming it by kind, a number, a pair and a vector holding a string among them"
  '((no-raise 11)
    (assertion-violation my-who (my-rule (kind string)))
    (assertion-violation my-who (my-rule (kind number)))
    (assertion-violation my-who (my-rule (kind list)))
    (assertion-violation my-who (my-rule (kind vector))))
  (let ((get (checked-accessor 'my-who 'my-rule (lambda (x) (and (pair? x) (number? (car x)))) "a thing"
                               (lambda (x) (+ 1 (car x))))))
    (list (raised (lambda () (get '(10))))
          (raised (lambda () (get secret)))
          (raised (lambda () (get 7)))
          (raised (lambda () (get (list "u" secret))))
          (raised (lambda () (get (vector secret)))))))

;; --- a value, as a refusal names it ---------------------------------
;; circular : List
;; A list whose last pair points back at its first.
(define circular (let ((l (list 1 2))) (set-cdr! (cdr l) l) l))

(test-equal "kind-of, written out: a string, a list, () among them, a number, exact and inexact, a boolean, a char, a symbol, a bytevector, a vector, a procedure, and anything else"
  '(string list list number number boolean char symbol bytevector vector procedure other)
  (map kind-of (list "s" '(a) '() 5 1.5 #t #\a 'x (make-bytevector 1 0) (vector 1) car (make-eq-hashtable))))

(define shown-values
  (list 'x 5 #f #\a '() '(429 503) '(get post)
        secret (list "u" secret) '(1 . 2) circular
        (make-bytevector 1 0) (vector secret) car (make-eq-hashtable)))

(test-equal "shown-value, written out against the whole complement of what it shows: a symbol, a number, a boolean, a char, (), and a proper list of them, as given; any other by its kind"
  (list 'x 5 #f #\a '() '(429 503) '(get post)
        '(kind string) '(kind list) '(kind list) '(kind list) '(kind bytevector) '(kind vector)
        '(kind procedure) '(kind other))
  (map shown-value shown-values))

;; --- secret-shown and refuse-secret ------------------------------------------------

;; Every kind of value, including what shown-value shows as it is.
(define secret-values
  (list "" secret 'hunter2 5 1.5 (expt 10 30) #t #f #\a '() (list #\p #\w) '(hunter2 s3cret)
        (list "u" secret) '(1 . 2) circular (make-bytevector 0 0) (string->utf8 secret)
        (vector) (vector secret) car (make-eq-hashtable) (make-error) (eof-object)))

(define secret-kinds
  '(string string symbol number number number boolean boolean char list list list
    list list list bytevector bytevector vector vector procedure other other other))

(test-equal "secret-shown names every value by its kind alone, never the value: a string, a symbol, numbers, booleans, a char, lists of chars and of symbols, a circular list, bytevectors, vectors and the rest"
  (map (lambda (k) (list 'kind k)) secret-kinds)
  (map secret-shown secret-values))

(test-equal "secret-shown shows no length: strings, lists, bytevectors and vectors of different lengths answer alike"
  '((kind string) (kind string) (kind list) (kind list) (kind bytevector) (kind bytevector)
    (kind vector) (kind vector))
  (list (secret-shown "a") (secret-shown (make-string 1000 #\a))
        (secret-shown '(a)) (secret-shown (vector->list (make-vector 1000 'a)))
        (secret-shown (make-bytevector 1 0)) (secret-shown (make-bytevector 1000 0))
        (secret-shown (vector 1)) (secret-shown (make-vector 1000 1))))

(test-equal "refuse-secret raises an assertion violation from WHO, irritants the rule, the parameter and the value's kind, for every kind of value"
  (map (lambda (k) (list 'assertion-violation 'password-hash
                         (list 'password-not-a-string 'password (list 'kind k))))
       secret-kinds)
  (map (lambda (v)
         (raised (lambda () (refuse-secret 'password-hash 'password-not-a-string 'password v))))
       secret-values))

;; The three a refusal shown by value would print as they are: a symbol, a
;; number and a list of chars (brief section 8.1, row 16).
(test-equal "refuse-secret shows a symbol, a number and a list of chars as their kinds, never as they are"
  '((assertion-violation hmac-sha256 (key-not-a-bytevector key (kind symbol)))
    (assertion-violation hmac-sha256 (key-not-a-bytevector key (kind number)))
    (assertion-violation hmac-sha256 (key-not-a-bytevector key (kind list))))
  (map (lambda (v)
         (raised (lambda () (refuse-secret 'hmac-sha256 'key-not-a-bytevector 'key v))))
       (list 'hunter2 123456 (list #\h #\u #\n #\t))))

(test-equal "refuse-secret says the rule and the parameter it was given, in that order, whatever the who"
  '((assertion-violation a (r1 p1 (kind string)))
    (assertion-violation b (r2 p2 (kind string))))
  (list (raised (lambda () (refuse-secret 'a 'r1 'p1 "v")))
        (raised (lambda () (refuse-secret 'b 'r2 'p2 "v")))))

(test-equal "a refusal by refuse-secret prints none of the secret, whatever its kind"
  (map (lambda (v) 'absent) (list 1 2 3 4 5 6))
  (map (lambda (v)
         (let ((text (guard (e (#t (describe e)))
                       (refuse-secret 'blake2b 'input-not-a-bytevector 'input v)
                       'no-raise)))
           (if (and (string? text) (not (contains? text secret))) 'absent 'printed)))
       (list secret (string->symbol secret) (string->utf8 secret) (string->list secret)
             (vector secret) (list (list secret)))))

(test-equal "refuse-secret raises an assertion violation with a message for every kind, and nothing else"
  (map (lambda (v) '(#t #t #t)) secret-values)
  (map (lambda (v)
         (guard (e (#t (list (assertion-violation? e) (who-condition? e) (message-condition? e))))
           (refuse-secret 'w 'r 'p v)
           'no-raise))
       secret-values))

(test-equal "refuse-secret refuses a who, a rule or a parameter that is no symbol, from itself, naming which, and showing it by its kind: a secret in the wrong place is not shown"
  '((assertion-violation refuse-secret (who (kind string)))
    (assertion-violation refuse-secret (rule (kind string)))
    (assertion-violation refuse-secret (parameter (kind number)))
    (assertion-violation refuse-secret (who (kind list))))
  (list (raised (lambda () (refuse-secret "v" 'r 'p 'x)))
        (raised (lambda () (refuse-secret 'w "hunter2" 'p 'x)))
        (raised (lambda () (refuse-secret 'w 'r 123456 'x)))
        (raised (lambda () (refuse-secret (list #\p #\w) 'r 'p 'x)))))

;; A bound that is no exact natural is refused by refuse-secret itself, by its
;; kind: a string, a float, a negative, a bytevector holding a secret, and #f,
;; which is no "no bound" (the call has six arguments).
(test-equal "refuse-secret refuses a low that is no exact natural, from itself, naming low, showing it by its kind alone: a string, a float, a negative, a bytevector and #f"
  '((assertion-violation refuse-secret (low (kind string)))
    (assertion-violation refuse-secret (low (kind number)))
    (assertion-violation refuse-secret (low (kind number)))
    (assertion-violation refuse-secret (low (kind bytevector)))
    (assertion-violation refuse-secret (low (kind boolean))))
  (list (raised (lambda () (refuse-secret 'w 'r 'p "v" "hunter2" 10)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 1.5 10)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" -1 10)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" (string->utf8 "hunter2") 10)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" #f 10)))))

(test-equal "refuse-secret refuses a high that is no exact natural, from itself, naming high, showing it by its kind alone: a string, a float, a negative, a bytevector and #f"
  '((assertion-violation refuse-secret (high (kind string)))
    (assertion-violation refuse-secret (high (kind number)))
    (assertion-violation refuse-secret (high (kind number)))
    (assertion-violation refuse-secret (high (kind bytevector)))
    (assertion-violation refuse-secret (high (kind boolean))))
  (list (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 "hunter2")))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 1.5)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 -1)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 (string->utf8 "hunter2"))))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 #f)))))

(test-equal "refuse-secret checks low before high: two bad bounds are refused as low"
  '(assertion-violation refuse-secret (low (kind string)))
  (raised (lambda () (refuse-secret 'w 'r 'p "v" "hunter2" "hunter2"))))

(test-equal "refuse-secret refuses a low above the high as high, from itself, and a low equal to the high is no refusal of the bound"
  '((assertion-violation refuse-secret (high (kind number)))
    (assertion-violation w (r p (kind string))))
  (list (raised (lambda () (refuse-secret 'w 'r 'p "v" 11 10)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 10 10)))))

(test-equal "refuse-secret checks who, rule and parameter before the bound"
  '((assertion-violation refuse-secret (who (kind string)))
    (assertion-violation refuse-secret (rule (kind string)))
    (assertion-violation refuse-secret (parameter (kind number))))
  (list (raised (lambda () (refuse-secret "v" 'r 'p 'x "hunter2" -1)))
        (raised (lambda () (refuse-secret 'w "hunter2" 'p 'x "hunter2" -1)))
        (raised (lambda () (refuse-secret 'w 'r 123456 'x "hunter2" -1)))))

(test-equal "refuse-secret with a bound refuses as without it: the irritants are the rule, the parameter and the kind, whatever the bound says"
  '((assertion-violation w (r p (kind string)))
    (assertion-violation w (r p (kind string)))
    (assertion-violation w (r p (kind string)))
    (assertion-violation w (r p (kind string))))
  (list (raised (lambda () (refuse-secret 'w 'r 'p "v")))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 65536)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 16 64)))
        (raised (lambda () (refuse-secret 'w 'r 'p "v" 0 0)))))

;; A call with five arguments matches no clause: what Chez raises names the
;; count and the procedure, and holds none of the arguments.
(test-equal "refuse-secret called with five arguments raises Chez's own refusal, whose irritants and printed form hold no part of the arguments"
  '(raised (clean clean clean clean clean))
  (let ((outcome (guard (e (#t e))
                   (refuse-secret 'whoever 'ruling 'param (string->utf8 "hunter2") 4242424)
                   'no-raise)))
    (if (condition? outcome)
        (let ((text (string-append
                     (describe outcome)
                     (if (irritants-condition? outcome)
                         (call-with-string-output-port
                          (lambda (port) (write (condition-irritants outcome) port)))
                         ""))))
          (list 'raised
                (map (lambda (part) (if (contains? text part) 'leaks 'clean))
                     (list "hunter2" "4242424" "whoever" "ruling" "param"))))
        (list 'no-raise outcome))))

;; --- &sodium-failed ------------------------------------------------------------------

(test-equal "an &sodium-failed carries its function and its code"
  '("crypto_pwhash_str" -1)
  (let ((c (a-sodium-failed))) (list (sodium-failed-function c) (sodium-failed-code c))))

(test-equal "an &sodium-failed's fields are not swapped: another fixture, other values"
  '("other_function" 7)
  (let ((c (make-sodium-failed "other_function" 7)))
    (list (sodium-failed-function c) (sodium-failed-code c))))

(test-equal "the record's own fields are function and code, and no more"
  '#(function code)
  (guard (e (#t (list 'raised (describe e))))
    (record-type-field-names (record-type-descriptor &sodium-failed))))

(test-equal "a code is any exact integer: negative, zero, positive and beyond a fixnum"
  (list -1 0 2 (expt 2 70) (- (expt 2 70)))
  (map (lambda (n) (sodium-failed-code (make-sodium-failed "f" n)))
       (list -1 0 2 (expt 2 70) (- (expt 2 70)))))

(test-equal "make-sodium-failed refuses a function that is no string, naming the field first and the value by its kind"
  (map (lambda (k) (list 'assertion-violation 'make-sodium-failed (list 'function (list 'kind k))))
       '(symbol boolean number list bytevector))
  (map (lambda (f) (raised (lambda () (make-sodium-failed f -1))))
       (list 'crypto_pwhash_str #f 5 '("f") (string->utf8 "f"))))

(test-equal "make-sodium-failed refuses a code that is no exact integer, naming the field first and the value by its kind"
  (map (lambda (k) (list 'assertion-violation 'make-sodium-failed (list 'code (list 'kind k))))
       '(number string boolean number number symbol))
  (map (lambda (c) (raised (lambda () (make-sodium-failed "f" c))))
       (list 1.0 "1" #f 1/2 +nan.0 'x)))

(test-equal "the &sodium-failed accessors refuse another type's condition, the root alone, a string, a number and a list holding a string, from the accessor, by kind"
  (map (lambda (who)
         (list (failed-refusal who '(kind other))
               (failed-refusal who '(kind other))
               (failed-refusal who '(kind string))
               (failed-refusal who '(kind number))
               (failed-refusal who '(kind list))))
       '(sodium-failed-function sodium-failed-code))
  (map (lambda (get)
         (map (lambda (v) (raised (lambda () (get v))))
              (list (a-library-unavailable) (make-chez-sodium-error) secret 5 (list "u" secret))))
       (list sodium-failed-function sodium-failed-code)))

(test-equal "no &sodium-failed accessor prints the secret it refused, bare, in a list or in a vector"
  (map (lambda (a) '(absent absent absent)) '(1 2))
  (map (lambda (get)
         (map (lambda (v)
                (let ((text (guard (e (#t (describe e))) (get v) 'no-raise)))
                  (cond ((eq? text 'no-raise) 'no-raise)
                        ((contains? text secret) 'printed)
                        (else 'absent))))
              (list secret (list "u" secret) (vector secret))))
       (list sodium-failed-function sodium-failed-code)))

;; failed : (-> Any) -> Any
;; What THUNK raised, as the whole condition: its irritants are #f when it
;; holds no &irritants.
(define (failed thunk)
  (guard (e ((sodium-failed? e)
             (list 'failed
                   (list (error? e) (assertion-violation? e) (chez-sodium-error? e)
                         (sodium-library-unavailable? e))
                   (serious-condition? e)
                   (and (who-condition? e) (condition-who e))
                   (message-condition? e)
                   (and (irritants-condition? e) (condition-irritants e))
                   (sodium-failed-function e)
                   (sodium-failed-code e)))
            ((and (assertion-violation? e) (who-condition? e))
             (list 'assertion-violation (condition-who e) (condition-irritants e)))
            (#t (list 'other-raise (describe e))))
    (thunk)
    'no-raise))

(test-equal "raise-sodium-failed raises the whole condition: an error and a chez-sodium-error, no assertion violation, who as given, a message, no irritants, its function and its code"
  '(failed (#t #f #t #f) #t password-hash #t #f "crypto_pwhash_str" -1)
  (failed (lambda () (raise-sodium-failed 'password-hash "crypto_pwhash_str" -1))))

(test-equal "raise-sodium-failed names the who it is given, and the fields it is given"
  '((failed (#t #f #t #f) #t password-verify #t #f "other_function" 3)
    (failed (#t #f #t #f) #t some-verb #t #f "f" 0))
  (list (failed (lambda () (raise-sodium-failed 'password-verify "other_function" 3)))
        (failed (lambda () (raise-sodium-failed 'some-verb "f" 0)))))

(test-equal "raise-sodium-failed's condition is exactly three simple conditions: the type, its &who and its &message, nothing else"
  '(3 #t #t #t)
  (guard (e (#t (list (length (simple-conditions e))
                      (sodium-failed? (car (simple-conditions e)))
                      (who-condition? (cadr (simple-conditions e)))
                      (message-condition? (caddr (simple-conditions e))))))
    (raise-sodium-failed 'w "f" 1)))

(test-equal "raise-sodium-failed's message is a non-empty string, the same from each who, and no other raise helper's"
  '(#t #t #t)
  (let ((m1 (guard (e (#t (condition-message e))) (raise-sodium-failed 'a "f" 1)))
        (m2 (guard (e (#t (condition-message e))) (raise-sodium-failed 'b "g" 2)))
        (m3 (guard (e (#t (condition-message e)))
              (raise-library-unavailable 'not-found #f #f #f '() "other text" '()))))
    (list (and (string? m1) (> (string-length m1) 0))
          (equal? m1 m2)
          (not (equal? m1 m3)))))

(test-equal "raise-sodium-failed refuses a who that is no symbol, from itself, naming the field, before it checks the others"
  '((assertion-violation raise-sodium-failed (who (kind string)))
    (assertion-violation raise-sodium-failed (who (kind boolean)))
    (assertion-violation raise-sodium-failed (who (kind string))))
  (list (failed (lambda () (raise-sodium-failed "password-hash" "f" 1)))
        (failed (lambda () (raise-sodium-failed #f 'not-a-string 'not-an-integer)))
        (failed (lambda () (raise-sodium-failed "password-hash" 7 1.0)))))

(test-equal "raise-sodium-failed refuses a function or a code the constructor refuses, from the constructor"
  '((assertion-violation make-sodium-failed (function (kind symbol)))
    (assertion-violation make-sodium-failed (code (kind number))))
  (list (failed (lambda () (raise-sodium-failed 'w 'f 1)))
        (failed (lambda () (raise-sodium-failed 'w "f" 1.5)))))

(test-equal "raise-sodium-failed never returns: a handler that returns gets nothing back, and the raise goes on to the next handler"
  'raised-on
  (guard (e (#t 'raised-on))
    (with-exception-handler
     (lambda (c) 'handled)
     (lambda () (raise-sodium-failed 'w "f" 1)))
    'returned-normally))

;; --- the types, whole ----------------------------------------------------------------

;; kinds-of : Any -> (Listof Boolean)
;; error?, assertion-violation?, chez-sodium-error?, sodium-library-unavailable?
;; and sodium-failed?.
(define (kinds-of c)
  (list (error? c) (assertion-violation? c) (chez-sodium-error? c)
        (sodium-library-unavailable? c) (sodium-failed? c)))

(test-equal "the matrix, whole: each of the two library conditions is an error and a chez-sodium-error, of its own type alone, and no assertion violation; the root alone is no type below it; an assertion violation and a plain error are none of them"
  '((#t #f #t #t #f)
    (#t #f #t #f #t)
    (#t #f #t #f #f)
    (#f #t #f #f #f)
    (#t #f #f #f #f))
  (map (lambda (thunk) (guard (e (#t (list 'raised (describe e)))) (kinds-of (thunk))))
       (list a-library-unavailable a-sodium-failed make-chez-sodium-error
             make-assertion-violation make-error)))

(test-equal "the predicates are false for what is no condition and for a condition of no library type: a symbol, #f, #t, (), a string, a number, a char, a vector, a procedure, a message, a plain error"
  (map (lambda (v) '(#f #f #f)) '(1 2 3 4 5 6 7 8 9 10 11))
  (map (lambda (v) (list (chez-sodium-error? v) (sodium-library-unavailable? v)
                         (sodium-failed? v)))
       (list 'x #f #t '() "s" 5 #\a (vector 1) car (make-message-condition "m") (make-error))))

(test-equal "the exported types sit where the matrix says: each leaf's parent is &chez-sodium-error, whose parent is &error"
  '(#t #t #t)
  (guard (e (#t (list 'raised (describe e))))
    (list (eq? (record-type-parent (record-type-descriptor &sodium-library-unavailable))
               (record-type-descriptor &chez-sodium-error))
          (eq? (record-type-parent (record-type-descriptor &sodium-failed))
               (record-type-descriptor &chez-sodium-error))
          (eq? (record-type-parent (record-type-descriptor &chez-sodium-error))
               (record-type-descriptor &error)))))

(test-end "conditions")

(exit (suite-exit-status runner))
