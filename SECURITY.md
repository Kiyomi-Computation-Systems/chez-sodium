# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| The latest release (see [CHANGELOG.md](CHANGELOG.md)) | ✅ |
| Earlier releases | ❌ |

## Reporting a vulnerability

Please report suspected vulnerabilities privately via GitHub:
**Security → Report a vulnerability** on this repository. Do not open a
public issue.

You can expect an acknowledgement within 7 days.

This library handles passwords and keys, so these reports are especially
welcome:

- a secret that reaches a condition, a message or a log;
- a block freed without being wiped;
- a wrong answer from `password-verify` or `constant-time-bytevector=?`;
- a timing difference that tells secrets apart;
- a raise inside a critical section;
- a Scheme object crossing into C;
- a load that accepts a libsodium below the floor.

A vulnerability in libsodium itself goes to its maintainers, at
<https://github.com/jedisct1/libsodium>, by their policy. A report about how
chez-sodium uses libsodium is welcome here.

Please include your platform, Chez version, libsodium version
(`sodium-version`), and the smallest program that shows it. Don't include real
passwords or keys.
