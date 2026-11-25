#!r6rs
;;; (chez-sodium private cap): the most bytes any one input to a verb may
;;; hold, written here and nowhere else.
;;;
;;; A verb copies its input into a block with a Scheme loop, inside one
;;; critical section, which holds off every other thread's collection for as
;;; long as it runs. The cap keeps that wait short. Every verb that takes a
;;; byte input checks it before its section (ADR-0007).
;;;
;;; It is pure: it loads no libsodium, so a library that needs the number does
;;; not need the verbs.
(library (chez-sodium private cap)
  (export input-cap)
  (import (chez-sodium private require-threaded)
          (rnrs))

  ;; input-cap : Natural
  ;; The greatest length of a byte input, and the greatest count random-bytes
  ;; answers: 64 KiB. A length equal to it is accepted, one more is refused.
  (define input-cap 65536))
