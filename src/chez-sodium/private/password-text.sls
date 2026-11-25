#!r6rs
;;; (chez-sodium private password-text): the text rules of the password verbs,
;;; as pure functions of a string.
;;;
;;; A UTF-8 length counted without encoding, the pre-check of a hash string,
;;; and the shape of a hash made with today's algorithm and parallelism. They
;;; load no libsodium and touch no foreign memory, so the suite runs without one.
;;;
;;; Each is called only on a string: the verbs check types before they call
;;; here, so nothing here raises for a wrong type. A hash string is a secret,
;;; so each function reads it by index and makes no copy of it: no substring,
;;; no list, no encoding.
(library (chez-sodium private password-text)
  (export utf8-length readable-hash-string? current-hash-shape?)
  (import (chez-sodium private require-threaded)
          (rnrs)
          (chez-sodium private cap))

  ;; utf8-length : String -> Natural
  ;; The number of bytes STR takes in UTF-8, summed from each character's
  ;; width. A Chez character is never a surrogate.
  (define (utf8-length str)
    (let ((n (string-length str)))
      (let loop ((i 0) (total 0))
        (if (= i n)
            total
            (let ((c (char->integer (string-ref str i))))
              (loop (+ i 1)
                    (+ total (cond ((< c #x80) 1)
                                   ((< c #x800) 2)
                                   ((< c #x10000) 3)
                                   (else 4)))))))))

  ;; readable-hash-string? : String -> Boolean
  ;; #t when STR is not empty, has at most input-cap characters, and every
  ;; character is U+0021 to U+007E, which rules out U+0000.
  (define (readable-hash-string? str)
    (let ((n (string-length str)))
      (and (> n 0)
           (<= n input-cap)
           (let loop ((i 0))
             (or (= i n)
                 (let ((c (char->integer (string-ref str i))))
                   (and (>= c #x21) (<= c #x7E) (loop (+ i 1)))))))))

  ;; digit? : Char -> Boolean
  (define (digit? c) (and (char>=? c #\0) (char<=? c #\9)))

  ;; current-hash-shape? : String (U String #f) -> Boolean
  ;; #t when HASH begins with PREFIX, then reads "v=" and digits, "$m=" and
  ;; digits, ",t=" and digits, ",p=1$", and at least one more character.
  ;; Anything else is #f, and so is a #f PREFIX. It is stricter than
  ;; libsodium's parser: a hash it refuses is only rehashed.
  (define (current-hash-shape? hash prefix)
    (and prefix
         (let ((n (string-length hash)))
           ;; literal : Natural String -> (U Natural #f)
           ;; The index after LIT when HASH holds it at I.
           (define (literal i lit)
             (let ((m (string-length lit)))
               (and (<= (+ i m) n)
                    (let loop ((k 0))
                      (cond ((= k m) (+ i m))
                            ((char=? (string-ref hash (+ i k)) (string-ref lit k))
                             (loop (+ k 1)))
                            (else #f))))))
           ;; digits : Natural -> (U Natural #f)
           ;; The index after one or more digits at I.
           (define (digits i)
             (let loop ((j i))
               (cond ((and (< j n) (digit? (string-ref hash j))) (loop (+ j 1)))
                     ((> j i) j)
                     (else #f))))
           ;; then : (U Natural #f) (Natural -> (U Natural #f)) -> (U Natural #f)
           (define (then i step) (and i (step i)))
           (let ((end (then (then (then (then (then (then (then (literal 0 prefix)
                                                               (lambda (i) (literal i "v=")))
                                                         digits)
                                                   (lambda (i) (literal i "$m=")))
                                             digits)
                                       (lambda (i) (literal i ",t=")))
                                 digits)
                           (lambda (i) (literal i ",p=1$")))))
             (and end (< end n)))))))
