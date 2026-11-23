;;; Development toolchain for chez-sodium (ADR-0011).
;;;
;;; Enter it with scripts/guix-env, which pins Guix to channels.scm and runs
;;; this manifest in a container with no network. Plain
;;; `guix shell -m manifest.scm` also loads this file, but against whatever
;;; Guix you have pulled.

(specifications->manifest
 '(;; Chez, and libsodium bound with no C shim (ADR-0001). "libsodium"
   ;; brings libsodium.so.26 and sodium.h (ADR-0011): the library the suites
   ;; load, and the header test-constants, the C oracle and the decoy compile
   ;; against. gcc-toolchain compiles those programs and the free() interposer
   ;; test-wipe preloads, each at test time.
   "chez-scheme" "libsodium" "gcc-toolchain"
   ;; The memory gate (ADR-0011).
   "valgrind"
   ;; What the Makefile and scripts shell out to. bash also gives the
   ;; self-test its network probe, /dev/tcp. The container has nothing else.
   "bash" "coreutils" "make" "grep" "sed" "gawk" "findutils" "diffutils"))
