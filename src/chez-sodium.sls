#!r6rs
;;; (chez-sodium): libsodium for Chez Scheme. The public library.
;;;
;;; It defines nothing: every name is re-exported from the private library
;;; that defines it (ADR-0012). So a reference runs that library alone, and a
;;; condition's predicate or accessor loads no libsodium: a program can test
;;; for &sodium-library-unavailable around an eval of the first name that
;;; loads. Every name that reaches libsodium runs the load at its first
;;; reference, once per process (ADR-0002).
;;;
;;; It exports predicates and accessors, never a condition's & name or constructor
;;; (ADR-0006, ADR-0012).
(library (chez-sodium)
  (export
   ;; --- the library (chez-sodium private native) ---
   ;; sodium-version : -> String
   sodium-version

   ;; --- the byte verbs (chez-sodium private byte-verbs) ---
   ;; random-bytes : Natural -> Bytevector
   random-bytes
   ;; blake2b : Bytevector [Natural] [Bytevector] -> Bytevector
   ;;   input, size, key
   blake2b
   ;; constant-time-bytevector=? : Bytevector Bytevector -> Boolean
   constant-time-bytevector=?

   ;; --- the password verbs (chez-sodium private password-verbs) ---
   ;;   Limits = (U 'interactive 'moderate 'sensitive Password-limits), by default 'interactive
   ;; password-hash : String [Limits] -> String
   password-hash
   ;; password-verify : String String -> Boolean
   ;;   hash, password
   password-verify
   ;; password-needs-rehash? : String [Limits] -> Boolean
   ;;   hash
   password-needs-rehash?
   ;; make-password-limits : Natural Natural -> Password-limits
   ;;   ops, memory in KiB
   make-password-limits

   ;; --- conditions (chez-sodium private conditions) ---
   ;; chez-sodium-error? : Any -> Boolean
   chez-sodium-error?
   ;; sodium-library-unavailable? : Any -> Boolean
   sodium-library-unavailable?
   ;; sodium-library-unavailable-reason : SodiumLibraryUnavailable -> Reason
   ;;   Reason = (U 'invalid-override 'not-found 'load-failed 'below-floor
   ;;               'missing-api 'init-failed)
   sodium-library-unavailable-reason
   ;; sodium-library-unavailable-path : SodiumLibraryUnavailable -> (U String #f)
   sodium-library-unavailable-path
   ;; sodium-library-unavailable-source : SodiumLibraryUnavailable -> (U Symbol #f)
   sodium-library-unavailable-source
   ;; sodium-library-unavailable-detail : SodiumLibraryUnavailable -> Any
   sodium-library-unavailable-detail
   ;; sodium-library-unavailable-candidates : SodiumLibraryUnavailable -> (Listof String)
   sodium-library-unavailable-candidates
   ;; sodium-failed? : Any -> Boolean
   sodium-failed?
   ;; sodium-failed-function : SodiumFailed -> String
   sodium-failed-function
   ;; sodium-failed-code : SodiumFailed -> Integer
   sodium-failed-code)
  (import (chez-sodium private require-threaded)
          (only (chez-sodium private native) sodium-version)
          (only (chez-sodium private byte-verbs)
                random-bytes blake2b constant-time-bytevector=?)
          (only (chez-sodium private password-verbs)
                password-hash password-verify password-needs-rehash?
                make-password-limits)
          (only (chez-sodium private conditions)
                sodium-failed? sodium-failed-function sodium-failed-code
                chez-sodium-error?
                sodium-library-unavailable? sodium-library-unavailable-reason
                sodium-library-unavailable-path sodium-library-unavailable-source
                sodium-library-unavailable-detail sodium-library-unavailable-candidates)))
