;; The oldest Chez and libsodium chez-sodium supports (ADR-0003, ADR-0004,
;; ADR-0011). make check-floors holds README.org to this file;
;; test-require-threaded holds Chez's check, and test-verify libsodium's.
((chez "10.4.0")
 (sodium "1.0.18"))
