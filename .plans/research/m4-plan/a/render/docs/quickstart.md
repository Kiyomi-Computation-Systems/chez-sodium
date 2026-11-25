# Quick start

A stub page, to see the sibling's generator render chez-sodium's shape.

## Install

```sh
git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git
scheme --libdirs chez-sodium/src --program app.sps
```

## Hash a password

```scheme run
(let ((hash (password-hash "pässwörd€" (make-password-limits 1 8))))
  (password-verify hash "pässwörd€"))
;; => #t
```

See [the reference](reference.md#password-hash), and
[README.org's Requirements](../README.org#requirements).

> ⚠️ `password-verify` answers `#f` for a wrong password, an unreadable hash and short memory alike.
