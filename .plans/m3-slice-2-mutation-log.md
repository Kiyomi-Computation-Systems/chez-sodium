# M3 slice 2 mutation log

Each mutant ran in a whole copy of `src/`, `tests/` and `packaging/`, made with
`shutil.copytree(..., symlinks=True)` under `build/m3s2-<agent>/<name>/`, never in place, and each
real file passes after it. Three Sonnet builders wrote the three parts below, each over its own
files; the caller planted the last part's mutants again, at the join. The form is Guards,
Mutation, Result, Clean rerun.

## The verbs agent

Each mutant is made in a whole copy of src/, tests/ and packaging/ under build/m3s2-verbs/NAME/, run with --libdirs src:tests:../../scheme-libs against tests/test-password-verbs.sps and tests/test-library-loading-passwords.sps (run plain, at 1.0.22). The clean rerun is the same two suites on the real tree.

#### r3-char-count

- **Guards:** R3 non-ASCII hash and verify; decoy rows with UTF-8 lengths
- **Mutation:** check-password counts characters, not UTF-8 bytes (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 150 pass, 21 fail: the minimum limits and the first hash were made; R3 password-hash of a non-ASCII password at the minimum limits is a hash string of argon2id v=19 at m=8,t=1,p=; R3 password-verify of that hash against the same non-ASCII password answers #t
- **Result** (test-library-loading-passwords.sps): exit 1, 15 pass, 6 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r5-limits-ignored

- **Guards:** R5 m=16,t=2,p=1; R5 m=24,t=3
- **Mutation:** a Password-limits resolves to the interactive pair (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 158 pass, 13 fail: R3 password-hash of a non-ASCII password at the minimum limits is a hash string of argon2id v=19 at m=8,t=1,p=; R5 (make-password-limits 2 16) gives a hash whose prefix, version and parameter field are argon2id, v=19 and m; R5 (make-password-limits 3 24) gives m=24,t=3,p=1: both numbers are the limits given, memory in KiB
- **Result** (test-library-loading-passwords.sps): exit 1, 15 pass, 6 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control under "pwhash-str-fails": crypto_pwhash_str answering -1 is a &sodium-failed of password-hash; verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any 
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r5-kib-as-bytes

- **Guards:** R5 limits rows; decoy 16384 memory
- **Mutation:** a Password-limits passes its KiB as bytes (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 255, 0 pass, 21 fail: the minimum limits and the first hash were made; R3 password-hash of a non-ASCII password at the minimum limits is a hash string of argon2id v=19 at m=8,t=1,p=; R3 password-verify of that hash against the same non-ASCII password answers #t
- **Result** (test-library-loading-passwords.sps): exit 1, 15 pass, 6 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control under "pwhash-str-fails": crypto_pwhash_str answering -1 is a &sodium-failed of password-hash; verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any 
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r6-presets-swapped

- **Guards:** R6 preset strings; decoy presets
- **Mutation:** the interactive and moderate presets are swapped (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 8 fail: R7 password-hash with no limits reads m=65536,t=2, the interactive preset; R7 password-hash with 'interactive reads the same; R6 the interactive preset's hand-written string at 'interactive is current: #f, and nothing is raised
- **Result** (test-library-loading-passwords.sps): exit 1, 12 pass, 9 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control under "pwhash-str-fails": crypto_pwhash_str answering -1 is a &sodium-failed of password-hash; verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any 
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r7-default-hash

- **Guards:** R7 default hash reads m=65536,t=2; decoy default
- **Mutation:** password-hash defaults to moderate (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R7 password-hash with no limits reads m=65536,t=2, the interactive preset; R18 password-hash with no limits argument under an engine at every fuel: each run answers a hash string of the
- **Result** (test-library-loading-passwords.sps): exit 1, 13 pass, 8 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control under "pwhash-str-fails": crypto_pwhash_str answering -1 is a &sodium-failed of password-hash; verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any 
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r7-default-rehash

- **Guards:** R8/R6 default needs-rehash; decoy default
- **Mutation:** password-needs-rehash? defaults to moderate (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: R6 a hash string at the interactive preset's own numbers is current at the default
- **Result** (test-library-loading-passwords.sps): exit 1, 15 pass, 6 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control under "pwhash-str-fails": crypto_pwhash_str answering -1 is a &sodium-failed of password-hash; verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any 
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r8-limits-differ

- **Guards:** R8 stale at higher and lower limits; R6
- **Mutation:** needs-rehash answers #f for any code (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 160 pass, 11 fail: R6 the interactive preset's hand-written string at 'moderate is stale: #t, and nothing is raised; R6 the interactive preset's hand-written string at 'sensitive is stale: #t, and nothing is raised; R6 the moderate preset's hand-written string at 'interactive is stale: #t, and nothing is raised
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r8-p1-rule

- **Guards:** R8 the p=4 string at 64 KiB
- **Mutation:** current-hash-shape? accepts any p (",p=1$" becomes ",p=") (`src/chez-sodium/private/password-text.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: R8 a p=4 string at 1 pass and 64 KiB, its own limits, which libsodium answers 0 for, is #t
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: a hash string that fails the pre-check, or the shape check, is #f from password-verify and #; verbs on control under "pwhash-limits-other": the prefix is the decoy's $argon2i$: an argon2i-shaped string re
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r8-prefix-rule

- **Guards:** R8 the argon2i string at ops 3, the argon2i-prefixed copy
- **Mutation:** current-hash-shape? ignores the prefix text: it skips to the second $ (`src/chez-sodium/private/password-text.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R8 a string of prefix $argon2i$, which libsodium reads as current, is #t: the prefix is the loaded library's; R8 an argon2i string at ops 3 and 8 KiB, its own limits, which libsodium answers 0 for, is #t
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: a hash string that fails the pre-check, or the shape check, is #f from password-verify and #; verbs on control under "pwhash-limits-other": the prefix is the decoy's $argon2i$: an argon2i-shaped string re
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r8-shape-removed

- **Guards:** R8 p=4, argon2i prefix; decoy argon2id-vs-argon2i row
- **Mutation:** needs-rehash skips the shape check (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 166 pass, 5 fail: R8 a string of prefix $argon2i$, which libsodium reads as current, is #t: the prefix is the loaded library's; R8 an argon2i string at ops 3 and 8 KiB, its own limits, which libsodium answers 0 for, is #t; R8 a p=4 string at 1 pass and 64 KiB, its own limits, which libsodium answers 0 for, is #t
- **Result** (test-library-loading-passwords.sps): exit 1, 18 pass, 3 fail: verbs on control: a hash string that fails the pre-check, or the shape check, is #f from password-verify and #; verbs on control under "strprefix-null": a NULL prefix is recorded as #f: password-needs-rehash? answers #t fo; verbs on control under "pwhash-limits-other": the prefix is the decoy's $argon2i$: an argon2i-shaped string re
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r8-null-prefix-ok

- **Guards:** strprefix-null row (#t without C)
- **Mutation:** a #f prefix is read as the argon2id prefix (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "strprefix-null": a NULL prefix is recorded as #f: password-needs-rehash? answers #t fo
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r9-verify-precheck

- **Guards:** R9 hash-then-NUL verify; decoy no-C rows
- **Mutation:** password-verify skips the pre-check (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 161 pass, 10 fail: R9 a hash then a NUL then junk, which libsodium verifies, is #f from password-verify: the pre-check answers, w; R9 password-verify of a hash with a trailing space answers #f, and raises nothing; R9 password-verify of a hash with a trailing newline answers #f, and raises nothing
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: a hash string that fails the pre-check, or the shape check, is #f from password-verify and #; verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r9-rehash-precheck

- **Guards:** R8 hash-then-NUL needs-rehash, non-ASCII, over-cap; decoy
- **Mutation:** password-needs-rehash? skips the pre-check (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: a hash string that fails the pre-check, or the shape check, is #f from password-verify and #
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r12-c-string-length

- **Guards:** R12 password holding a NUL
- **Mutation:** the password length is taken as a C string: up to the first NUL (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R12 a password holding a NUL is hashed whole: it verifies against itself, and not against the text before the ; S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-make-ops-natural

- **Guards:** R15 make-password-limits ops not-a-natural
- **Mutation:** the check removed: make-ops-natural (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 8 fail: R15 make-password-limits ops -1 is refused, not-a-natural, its value shown as it is; R15 make-password-limits ops 1.5 is refused, not-a-natural, its value shown as it is; R15 make-password-limits ops 2.0, which is no exact natural is refused, not-a-natural, its value shown as it i
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-make-ops-range

- **Guards:** R15 ops-out-of-range
- **Mutation:** the check removed: make-ops-range (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 167 pass, 4 fail: R15 make-password-limits ops one below libsodium's least is refused, ops-out-of-range, its value shown; R15 make-password-limits ops one above libsodium's greatest is refused, ops-out-of-range; R15 make-password-limits order: ops 0 and a bad memory-kib are refused at ops' range
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-make-mem-natural

- **Guards:** R15 memory not-a-natural
- **Mutation:** the check removed: make-mem-natural (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 164 pass, 7 fail: R15 make-password-limits memory-kib -1 is refused, not-a-natural, its value shown as it is; R15 make-password-limits memory-kib 1.5 is refused, not-a-natural, its value shown as it is; R15 make-password-limits memory-kib 16.0, which is no exact natural is refused, not-a-natural, its value shown
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-make-mem-range

- **Guards:** R15 memory-out-of-range
- **Mutation:** the check removed: make-mem-range (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 168 pass, 3 fail: R15 make-password-limits memory-kib one below the least is refused, memory-out-of-range; R15 make-password-limits memory-kib one above the greatest is refused, memory-out-of-range; R15 make-password-limits memory-kib 0 is refused, memory-out-of-range
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-pw-not-string

- **Guards:** R15 password not-a-string
- **Mutation:** the check removed: pw-not-string (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 156 pass, 15 fail: R15 password-hash of a symbol is refused, not-a-string password, by kind alone; R15 password-hash of a number is refused, not-a-string password, by kind alone; R15 password-hash of a list is refused, not-a-string password, by kind alone
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-pw-cap

- **Guards:** R15 over-the-cap
- **Mutation:** the check removed: pw-cap (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 158 pass, 13 fail: R15 password-hash of 65537 ASCII characters, 65537 bytes is refused, over-the-cap, by kind alone; R15 password-verify of 65537 ASCII characters, 65537 bytes is refused, over-the-cap, by kind alone; R15 password-hash of 21845 euro signs and two more, 65537 bytes, 21847 characters is refused, over-the-cap, by
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-pw-range

- **Guards:** decoy length-out-of-range
- **Mutation:** the check removed: pw-range (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 16 pass, 5 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an; R16 the probe's --describe answers, for three passwords each of password-hash and password-verify, status 0, t; R16 password-hash of 101 ASCII characters, of 101 bytes with non-ASCII characters, and of 102 bytes: the print
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-verify-hash-string

- **Guards:** R15 verify hash not-a-string
- **Mutation:** the check removed: verify-hash-string (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 8 fail: R15 password-verify of a hash that is a symbol is refused, not-a-string hash, by kind alone; R15 password-verify of a hash that is a number is refused, not-a-string hash, by kind alone; R15 password-verify of a hash that is a list is refused, not-a-string hash, by kind alone
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-rehash-hash-string

- **Guards:** R15 needs-rehash hash not-a-string
- **Mutation:** the check removed: rehash-hash-string (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 8 fail: R15 password-needs-rehash? of a hash that is a symbol is refused, not-a-string hash, by kind alone; R15 password-needs-rehash? of a hash that is a number is refused, not-a-string hash, by kind alone; R15 password-needs-rehash? of a hash that is a list is refused, not-a-string hash, by kind alone
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-no-limits-check

- **Guards:** R15 not-password-limits
- **Mutation:** an unknown limits value is read as the interactive preset (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 159 pass, 12 fail: R15 password-hash limits a symbol that is no preset is refused, not-password-limits, shown by shown-value; R15 password-hash limits a number is refused, not-password-limits, shown by shown-value; R15 password-hash limits #f is refused, not-password-limits, shown by shown-value
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-order-limits-first

- **Guards:** R15 order: bad password and bad limits refused at the password
- **Mutation:** password-hash checks limits before the password (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R15 password-hash order: a bad password and bad limits are refused at the password; R15 password-hash order: an over-long password and bad limits are refused at the cap
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-order-pw-first-verify

- **Guards:** R15 password-verify order: bad hash and bad password refused at the hash
- **Mutation:** password-verify checks its password before its hash (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 255, 0 pass, 37 fail: make-password-limits answers a value at libsodium's least ops and memory, at its greatest of each, and at each; the minimum limits and the first hash were made; R3 password-hash of a non-ASCII password at the minimum limits is a hash string of argon2id v=19 at m=8,t=1,p=
- **Result** (test-library-loading-passwords.sps): exit 1, 6 pass, 15 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control: a hash string that fails the pre-check, or the shape check, is #f from password-verify and #
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-precheck-before-refusal

- **Guards:** R15 bad hash with a non-string password is not-a-string, not #f
- **Mutation:** password-verify answers #f for a bad hash before it checks the password (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 168 pass, 3 fail: R15 password-verify order: a hash that fails the pre-check and a password that is no string are refused at the; R15 password-verify order: a hash that fails the pre-check and a password over the cap are refused at the cap; S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r15-range-before-cap

- **Guards:** decoy: over-the-cap before length-out-of-range for 65537 bytes
- **Mutation:** the length range is checked before the cap (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r16-shown-value

- **Guards:** R15/R16 secret refused by kind alone
- **Mutation:** the password is shown by shown-value in not-a-string (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 158 pass, 13 fail: R15 password-hash of a symbol is refused, not-a-string password, by kind alone; R15 password-hash of a number is refused, not-a-string password, by kind alone; R15 password-hash of a list is refused, not-a-string password, by kind alone
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r16-length-in-cap-message

- **Guards:** R16 over-the-cap print holds no length and is the same
- **Mutation:** over-the-cap prints the password length in its message (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 8 fail: R16 password-hash of a password over the cap: refused, the printed refusal holds the condition's whole message; R16 password-verify of a password over the cap: refused, the printed refusal holds the condition's whole messa; R16 password-hash of a password over the cap: the printed refusal is the same for another string of the same U
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r16-length-in-range-message

- **Guards:** R16 length-out-of-range print the same (decoy)
- **Mutation:** length-out-of-range prints the password length in its message (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 168 pass, 3 fail: S2 the helpers hold the checks and no section: check-password and resolve-limits refuse, make-password-limits ; S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies; S7 string-append appears only in the two top-level definitions of no parameters whose names end in -message, w
- **Result** (test-library-loading-passwords.sps): exit 1, 18 pass, 3 fail: R16 password-hash of 101 ASCII characters, of 101 bytes with non-ASCII characters, and of 102 bytes: the print; R16 password-verify of 101 ASCII characters, of 101 bytes with non-ASCII characters, and of 102 bytes: the pri; R16 the printed refusal states the bound, 1 to 100 bytes, and its rule, and holds none of the secret's text, i
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r17-raise-inside

- **Guards:** S3 no raise inside; row 17 decoy
- **Mutation:** password-hash raises its &sodium-failed inside the section (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 168 pass, 3 fail: S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-; S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t; S3 no raise inside a section: none of raise, assertion-violation, error, refuse-secret, raise-sodium-failed, c
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r17-code-minus-one

- **Guards:** decoy pwhash-str-other code 1
- **Mutation:** the &sodium-failed code is written as -1 (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any ; verbs on control under "pwhash-str-unreadable": crypto_pwhash_str answering 0 and leaving no string is a &sodi
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r17-minus-one-only

- **Guards:** decoy pwhash-str-other (code 1 must fail)
- **Mutation:** only -1 is a failure; any other code reads the string (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-str-other": crypto_pwhash_str answering 1 is a &sodium-failed too, code 1: any 
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### unreadable-hash-false

- **Guards:** decoy pwhash-str-unreadable
- **Mutation:** an unreadable out block answers #f as the hash (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-str-unreadable": crypto_pwhash_str answering 0 and leaving no string is a &sodi
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### unreadable-string-op-inside

- **Guards:** decoy pwhash-str-unreadable
- **Mutation:** a string operation on #f inside the section (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t; S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-str-unreadable": crypto_pwhash_str answering 0 and leaving no string is a &sodi
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### unreadable-n-128

- **Guards:** decoy pwhash-limits-other 140-character hash
- **Mutation:** foreign-ascii-string is given a Scheme 128 for N (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an; verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### changed-hash-not-raised

- **Guards:** R18 changed password-hash sweep
- **Mutation:** password-hash does not refuse a changed password (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R18 password-hash with a password that changes width at each expiry: each run answers a hash string or the ref; S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### changed-verify-false

- **Guards:** R18 changed verify sweeps
- **Mutation:** password-verify answers #f for a changed string (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 168 pass, 3 fail: R18 password-verify with a password that changes width at each expiry: each run answers #t, or #f for the chan; R18 password-verify with a hash that gains a character out of U+0021 to U+007E at each expiry: each run answer; S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### changed-verify-hash-not-raised

- **Guards:** R18 changed verify hash sweep
- **Mutation:** password-verify answers #f for a changed hash only (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R18 password-verify with a hash that gains a character out of U+0021 to U+007E at each expiry: each run answer; S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### changed-rehash-raises

- **Guards:** R18 changed needs-rehash sweep
- **Mutation:** password-needs-rehash? raises for a changed hash (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: R18 password-needs-rehash? with a hash that gains a character out of U+0021 to U+007E at each expiry: each run; S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r18-verify-no-section

- **Guards:** R18 verify sweeps; S1
- **Mutation:** password-verify has no section (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 161 pass, 10 fail: R18 password-verify under an engine at every fuel: each run answers #t for the right password; R18 password-verify under an engine at every fuel: each run answers #f for a wrong password, and raises nothin; R18 password-verify with a password that changes width at each expiry: each run answers #t, or #f for the chan
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### r18-hash-no-section

- **Guards:** R18 hash sweeps; S1
- **Mutation:** password-hash has no section (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 162 pass, 9 fail: R18 password-hash under an engine at every fuel from 1 until it completes: each run answers a hash string at t; R18 password-hash with no limits argument under an engine at every fuel: each run answers a hash string of the; R18 password-hash with a password that changes width at each expiry: each run answers a hash string or the ref
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-second-section

- **Guards:** S1
- **Mutation:** a second section in password-needs-rehash? (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 167 pass, 4 fail: S1 each verb's definition holds exactly one call-in-section, as a symbol anywhere in it, and make-password-lim; S1 the library's whole body holds three call-in-section symbols, one in each verb: no helper holds a section o; S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-check-after

- **Guards:** S2/S3
- **Mutation:** password-hash resolves its limits inside the section (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 167 pass, 4 fail: S2 every check is before the section, every raise after it: in each verb, the checks (check-password, resolve-; S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t; S3 no raise inside a section: none of raise, assertion-violation, error, refuse-secret, raise-sodium-failed, c
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-critical-section-import

- **Guards:** S4 import clause
- **Mutation:** a critical-section import from (chezscheme) (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S4 password-verbs' import clauses, whole: require-threaded first, then (rnrs), native, conditions, cap and pas
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-utf8-length-copy

- **Guards:** S6 allow-list
- **Mutation:** the password length through string->utf8 (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-string-copy

- **Guards:** S6 allow-list
- **Mutation:** a Scheme copy of the password made by string-copy (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-extra-export

- **Guards:** S4 exports; exports row
- **Mutation:** natural? exported (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 169 pass, 2 fail: (chez-sodium private password-verbs) exports exactly the three verbs and make-password-limits; S4 the library exports the three verbs and make-password-limits, as written
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-missing-export

- **Guards:** exports row; every row that needs make-password-limits
- **Mutation:** make-password-limits not exported (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 255, 0 pass, 25 fail: make-password-limits answers a value at libsodium's least ops and memory, at its greatest of each, and at each; the minimum limits and the first hash were made; R3 password-hash of a non-ASCII password at the minimum limits is a hash string of argon2id v=19 at m=8,t=1,p=
- **Result** (test-library-loading-passwords.sps): exit 1, 14 pass, 7 fail: verbs on control: password-hash reaches C with its UTF-8 length, the limits' numbers in memory bytes and the o; verbs on control: every refusal of the table is (refused WHO IRRITANTS) whole, and the log gains nothing: no b; verbs on control under "pwhash-str-fails": crypto_pwhash_str answering -1 is a &sodium-failed of password-hash
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### s-lambda-outside

- **Guards:** S2 no lambda outside the section
- **Mutation:** a let-bound lambda holds a check outside the section (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S2 no lambda in a verb's definition lies outside its call-in-section argument, but case-lambda's clauses: a ch
- **Result** (test-library-loading-passwords.sps): exit 0, 21 pass, 0 fail
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-strbytes-block

- **Guards:** decoy limits-other: wipe of 160
- **Mutation:** a constant written in Scheme: strbytes-block (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S3 every symbol inside each verb's call-in-section argument, whole and in reading order: no helper is called t
- **Result** (test-library-loading-passwords.sps): exit 1, 19 pass, 2 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an; verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-strprefix

- **Guards:** decoy limits-other prefix; strprefix-null
- **Mutation:** a constant written in Scheme: strprefix (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 18 pass, 3 fail: verbs on control under "strprefix-null": a NULL prefix is recorded as #f: password-needs-rehash? answers #t fo; verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin; verbs on control under "pwhash-limits-other": the prefix is the decoy's $argon2i$: an argon2i-shaped string re
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-passwd-max

- **Guards:** decoy limits-other 101-byte refusal
- **Mutation:** a constant written in Scheme: passwd-max (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 16 pass, 5 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an; R16 the probe's --describe answers, for three passwords each of password-hash and password-verify, status 0, t; R16 password-hash of 101 ASCII characters, of 101 bytes with non-ASCII characters, and of 102 bytes: the print
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-passwd-min

- **Guards:** decoy limits-other empty refusal
- **Mutation:** a constant written in Scheme: passwd-min (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-ops-min

- **Guards:** decoy ops 1 refused
- **Mutation:** a constant written in Scheme: ops-min (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-ops-max

- **Guards:** decoy ops 10 refused
- **Mutation:** a constant written in Scheme: ops-max (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 0, 171 pass, 0 fail
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-mem-min

- **Guards:** decoy memory 15 refused
- **Mutation:** a constant written in Scheme: mem-min (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-mem-max

- **Guards:** decoy memory 1025 refused
- **Mutation:** a constant written in Scheme: mem-max (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-preset-interactive-ops

- **Guards:** decoy presets
- **Mutation:** a constant written in Scheme: preset-interactive-ops (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 18 pass, 3 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an; verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin; verbs on control under "pwhash-limits-other": the prefix is the decoy's $argon2i$: an argon2i-shaped string re
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-preset-interactive-mem

- **Guards:** decoy presets
- **Mutation:** a constant written in Scheme: preset-interactive-mem (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 18 pass, 3 fail: verbs on control under "pwhash-limits-other": ops 1 and 10 and memory 15 and 1025 KiB are refused, 2, 9, 16 an; verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin; verbs on control under "pwhash-limits-other": the prefix is the decoy's $argon2i$: an argon2i-shaped string re
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-preset-moderate

- **Guards:** decoy presets
- **Mutation:** a constant written in Scheme: preset-moderate (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

#### const-preset-sensitive

- **Guards:** decoy presets
- **Mutation:** a constant written in Scheme: preset-sensitive (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 1 fail: S6 the allow-list: the whole, sorted set of symbols the library's body references, so no procedure that copies
- **Result** (test-library-loading-passwords.sps): exit 1, 20 pass, 1 fail: verbs on control under "pwhash-limits-other": each preset hashes at the decoy's numbers, read from the log lin
- **Verdict:** CAUGHT
- **Clean rerun:** test-password-verbs.sps exit 0, 171 pass, 0 fail; test-library-loading-passwords.sps exit 0, 21 pass, 0 fail

## The public library and wipe agent

Each mutant is a copy in build/m3s2-public/NAME/, run with
`scheme --libdirs src:tests:../../scheme-libs --program tests/test-X.sps`.
In test-never-loads copies the "testing child" row also fails on a missing
(srfi :64): the child's libdirs are relative to the repo root. That failure is a
copy artifact, present in every copy; the rows named below are the ones that
show each mutant.
Clean rerun, for every row: real tree, test-public and test-never-loads pass
under `make test-memory` (2 of 2), test-wipe passes 3 of 3.

### extra-name
- Guards: test-public, "(chez-sodium) exports exactly ..." row
- Mutation: src/chez-sodium.sls also exports sodium-memzero from native
- Result: that row FAILS (pass 7, fail 1)
- Clean rerun: pass

### missing-name
- Guards: test-public export row and the eq? row
- Mutation: make-password-limits removed from the export clause
- Result: both rows FAIL (pass 6, fail 2)
- Clean rerun: pass

### wrapper
- Guards: test-public "one library form with no body" and "eq?" rows
- Mutation: password-verify defined in (chez-sodium) as a wrapper of the private one
- Result: both rows FAIL (pass 6, fail 2); the export row passes, as the name is still exported
- Clean rerun: pass

### verb-names
- Guards: test-never-loads, "condition exports ... exactly the names the condition children check"
- Mutation: password-hash dropped from verb-names
- Result: that row FAILS
- Clean rerun: pass

### text-imports-native
- Guards: test-never-loads loaders row
- Mutation: (chez-sodium private password-text) imports native
- Result: loaders row FAILS (password-text became a loader)
- Clean rerun: pass

### loaders-missing
- Guards: test-never-loads loaders row
- Mutation: password-verbs removed from the expected loader list
- Result: loaders row FAILS
- Clean rerun: pass

### ctl-str, ctl-verify, ctl-rehash
- Guards: test-wipe, each password standing control
- Mutation: the control frees its blocks through free-foreign-block! with sodium-memzero, not unwiped
- Result: its line reads (128 1) (9 1), (94 1) (9 1) and (94 1) in place of 2; the verbs row FAILS
- Clean rerun: pass

### wipe-nop
- Guards: test-wipe, verbs row, against each password verb's blocks
- Mutation: memory.sls free-foreign-block! calls no wipe
- Result: password-hash ((128 2) (9 2)), password-verify ((94 2) (9 2)), password-needs-rehash ((94 2)); row FAILS
- Clean rerun: pass

### decoy-drop-str-out, decoy-drop-verify-str, decoy-drop-rehash
- Guards: test-wipe, verbs row, the decoy's name_block calls
- Mutation: one name_block dropped in a decoy copy: pwhash_str's out; pwhash_str_verify's str; needs_rehash's str
- Result: lists read ((9 1)), ((9 1)) and () for the three verbs; row FAILS each time
- Clean rerun: pass

## The collect-safe and oracle agent

Each mutant is a copy in build/m3s2-safe/NAME/ run from inside with
`--libdirs src:tests:../../scheme-libs`, CHEZ=scheme, in the container, plain (no gate).

### plain-hash
- Guards: row "password-hash is __collect_safe" (tests/test-collect-safe.sps).
- Mutation: native.sls, `(foreign-procedure __collect_safe "crypto_pwhash_str"` made plain.
- Result: FAIL by name, no hang. actual `released-by watchdog`, rendezvous 10008 ms; 7 pass, 1 fail.
  password-verify row and the control still pass.
- Clean rerun: real tree, 8 pass 0 fail (1.0.22 default, 1.0.22 explicit, 1.0.18 floor, and under the gate).

### plain-verify
- Guards: row "password-verify is __collect_safe".
- Mutation: native.sls, `crypto_pwhash_str_verify` made plain.
- Result: FAIL by name: `watchdog`, rendezvous 10008 ms; 7 pass, 1 fail.
- Clean rerun: as above, 8 pass.

### safe-control
- Guards: row "the standing control" (tests/collect-probe.sps' own plain binding).
- Mutation: collect-probe.sps, the control's binding made `__collect_safe`.
- Result: FAIL by name: reads `collector`, rendezvous 1 ms; 7 pass, 1 fail.
- Clean rerun: 8 pass.

### verify-true
- Guards: the oracle rows "C hashes ... the verb verifies", and the "two hashes" row.
- Mutation: password-verbs.sls, `password-verify` answers #t for any code from C.
- Result: FAIL, 4 rows (the three changed-password pairs and the empty-vs-"a" row); 4 pass, 4 fail.
- Clean rerun: 8 pass.

### latin1
- Guards: the oracle rows for the non-ASCII password.
- Mutation: native.sls call-with-utf8: width 1 and one Latin-1 byte for U+0080 to U+00FF.
- Result: FAIL, 2 rows (non-ASCII, both directions), by a `changed-during-call` raise (the written
  length no longer matches the password's UTF-8 length). 6 pass, 2 fail.
- Clean rerun: 8 pass.

### latin1-padded
- Guards: the oracle rows for the non-ASCII password, by C's answer rather than a raise.
- Mutation: native.sls call-with-utf8: a two-byte character writes its low byte then 0x80, so the
  length stays right and the bytes are wrong.
- Result: FAIL, 2 rows: the verb's verify of C's hash answers #f; C's verify of the verb's hash is -1.
  6 pass, 2 fail.
- Clean rerun: 8 pass.

## The caller, at the join

### pub-verify-unexported

- Guards: `test-public`'s export and `eq?` rows
- Mutation: `password-verify` dropped from `(chez-sodium)`'s exports
- Result: `(chez-sodium) exports exactly …` and `each public name is the procedure its private library defines, eq?` fail; 6 pass
- Clean rerun: the real files pass, 8 of 8

### verify-plain

- Guards: `test-collect-safe`'s `password-verify` row
- Mutation: native binds `crypto_pwhash_str_verify` plain
- Result: `password-verify is __collect_safe: …` fails by name, with no hang; 7 pass
- Clean rerun: the real files pass, 8 of 8

### verify-any-but-minus-one

- Guards: `test-library-loading-passwords`' `verify-other` row
- Mutation: `password-verify` reads any code but -1 as a match
- Result: `verbs on control under "verify-other": crypto_pwhash_str_verify answering 1 is #f …` fails; 20 pass
- Clean rerun: the real files pass, 21 of 21

After slice 2's review (`research/m3-slice-2-review/`), two Sonnet fix agents, on disjoint
files, logged these. The caller reran the review's F1 mutant against the fixed suites, and the
`/nonexistent` probe.

## The review fixes: the verbs and the decoy rows

Each mutant ran in a whole copy of `src/`, `tests/` and `packaging/` made with
`shutil.copytree(..., symlinks=True)` under `build/m3s2-fix-verbs/<name>/`
(`mk.py` there makes one), run from inside the copy with
`--libdirs src:tests:../../scheme-libs`-equivalent (`run.sh`), plain at 1.0.22 unless
the Result says gate. The real tree is rerun after each. No run below exited 255.

### Earlier log entries whose run exited 255

In `.plans/m3-slice-2-mutation-log.md`, the verbs agent's `r5-kib-as-bytes`, `r15-order-pw-first-verify`
and `s-missing-export` have `test-password-verbs.sps` at "exit 255, 0 pass": the suite died at top
level (a raise in a top-level definition), named no test, and the "N fail" beside it counts
nothing the suite ran. Those three rows hold only the other suite's verdict. The top-level
raises are fixed (item 2), so a rerun of each now names its failing rows and exits 1.

##### rehash-changed-false

- **Guards:** `--rehash-change-sweep` rows of test-library-loading-passwords: a hash changed during the call answers #t
- **Mutation:** `password-needs-rehash?` answers `(and (eq? (car outcome) 'code) (not (eqv? (cdr outcome) 0)))`: a changed hash answers #f (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-library-loading-passwords.sps): exit 1, 22 pass, 1 fail: "password-needs-rehash? of a hash changed during the call: every run that only wiped the hash string's block ... answers #t". (test-password-verbs.sps: exit 0, 172 pass, 0 fail: its engine sweep cannot tell the two #t apart; the decoy row holds it.)
- **Clean rerun:** test-library-loading-passwords.sps exit 0, 23 pass; test-password-verbs.sps exit 0, 172 pass

##### not-opaque

- **Guards:** "a Password-limits is opaque: record? answers #f"; "... record-rtd of it is refused"
- **Mutation:** `(sealed #f) (opaque #f)` on limits-record (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 170 pass, 2 fail: the two rows named above
- **Clean rerun:** test-password-verbs.sps exit 0, 172 pass

##### empty-hash-accepted

- **Guards:** `-passwords` row under "pwhash-str-empty": (failed password-hash "crypto_pwhash_str" 0)
- **Mutation:** `(if (and hash (readable-hash-string? hash))` back to `(if hash` (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-library-loading-passwords.sps): exit 1, 22 pass, 1 fail: verbs on control under "pwhash-str-empty". (test-password-verbs.sps: exit 1, 171 pass, 1 fail: S3, the section's symbols.)
- **Clean rerun:** both exit 0, 23 and 172 pass

##### decoy-empty-writes-hash

- **Guards:** `-password-entries` row under "pwhash-str-empty": first 0 at 0, 127 bytes A5
- **Mutation:** the decoy's `pwhash-str-empty` branch disabled (`if (0)`), so it writes the control hash (`tests/decoy-libsodium.c`)
- **Result** (test-library-loading-password-entries.sps): exit 1, 13 pass, 1 fail: "password entries under "pwhash-str-empty""
- **Clean rerun:** exit 0, 14 pass

##### c-string-no-nul (row 10, terminating 0 dropped)

- **Guards:** the decoy's `p[L]` in `-passwords`; the memory gate in test-password-verbs
- **Mutation:** `call-with-c-string` no longer writes the block's terminating 0 (`src/chez-sodium/private/native.sls`); the reviewer's `build/m3s2-review/c-string-no-nul` holds the same
- **Result** (test-library-loading-passwords.sps, plain): exit 1, 13 pass, 10 fail (every row that reaches verify or needs-rehash, and the sweep). (test-password-verbs.sps, plain): exit 1, 171 pass, 1 fail: R3 password-verify answers #t. (Gate, `make test-memory` in the copy): test-password-verbs.sps "FAIL (exit 9, Valgrind's: an error or a definite leak)"; test-library-loading-passwords.sps failed too.
- **Clean rerun:** both exit 0 plain; both pass under the gate

##### hash-ignores-limits

- **Guards:** the changed R18 row, `password-hash ""` at the minimum limits under an engine
- **Mutation:** `password-hash` resolves `'interactive` whatever its LIMITS (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 152 pass, 20 fail, among them "R18 password-hash of the empty password under an engine at every fuel: each run answers a hash string at the minimum limits", R5 and R8 rows
- **Clean rerun:** exit 0, 172 pass

##### rehash-ops-fixed

- **Guards:** R8 "a string of 1 fewer pass than 2 passes and 16 KiB is #t" (passes alone)
- **Mutation:** `crypto-pwhash-str-needs-rehash` is given `pwhash-opslimit-min` for the opslimit (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 9 fail, among them the row named, R6 current rows, S3
- **Clean rerun:** exit 0, 172 pass

##### rehash-mem-fixed

- **Guards:** R8 "a string of 8 KiB less memory than 2 passes and 16 KiB is #t" (memory alone)
- **Mutation:** the memlimit is `pwhash-memlimit-min` (`src/chez-sodium/private/password-verbs.sls`)
- **Result** (test-password-verbs.sps): exit 1, 163 pass, 9 fail, among them the row named, R6 current rows, S3
- **Clean rerun:** exit 0, 172 pass

Rows removed, no mutant owed: R5 (3,24), R7 "'interactive", R8's argon2i-string and limits-3-8, -1-16, -2-8, -1-64 rows
(replaced by hand-written strings and the one pair (2,16)), "the length range is libsodium's", "the non-ASCII string ... 21847 characters".

## The review fixes: collect-probe

Each mutant is a copy in build/m3s2-fix-safe/NAME/ (src, tests, packaging; symlinks kept), run from inside
with `--libdirs src:tests:../../scheme-libs`, in the container, via build/m3s2-fix-safe/run.sh.

### trip
- Guards: the watchdog outside the process (a forced collect request while the control's thread is blocked in a plain C call).
- Mutation: tests/collect-probe.sps, `(make-bytevector (* 2 (collect-trip-bytes)) 0)` between the marker and the 1 s pause.
- Result: no hang. Probe run direct: `released-by watchdog`, rendezvous 0 ms (the forced collection waited for the call; the
  watchdog released it at about 11 s), answer 0, whole run 12.3 s, rc 0, TMPDIR empty after. The suite's control row fails by
  name, as it must: its rendezvous is no longer the one that waited (7 pass, 1 fail). No process, FIFO or marker left.
- Clean rerun: real tree, 8 pass 0 fail (1.0.22, 1.0.18 floor, both gates).

### plain-verify
- Guards: row "password-verify is __collect_safe".
- Mutation: native.sls, `crypto_pwhash_str_verify` form made plain (no `__collect_safe`).
- Result: FAIL by name, no hang: password-verify rendezvous 10001 ms, released by the watchdog; 7 pass, 1 fail; 24 s.
- Clean rerun: real tree, 8 pass 0 fail.

## The caller, after the fixes

### rehash-changed-false, against the fixed suites

- Guards: `test-library-loading-passwords`' changed-path row
- Mutation: `password-needs-rehash?` answers `#f` for a hash changed during its call (the review's copy, with the fixed suites, probe and decoy copied in)
- Result: `password-needs-rehash? of a hash changed during the call: every run that only wiped the hash string's block … answers #t, and at least one such run exists` fails; 22 pass
- Clean rerun: the real files pass, 23 of 23

### the suite with no libsodium

- Guards: `test-password-verbs`' rows, each named
- Mutation: `CHEZ_SODIUM_LIBRARY=/nonexistent/libsodium.so`
- Result: exit 1, every row named; before the fix, exit 255 at top level
- Clean rerun: 172 of 172 with the real library

### the control row under a forced collection

- Guards: `test-collect-safe`'s control row
- Mutation: the fix agent's `trip` copy, which forces a collection between the marker and the pause
- Result: with the row's time bound in place, the control failed by its time though the watchdog released it, so the caller dropped the time from the control row: released by the watchdog is what shows the plain call held the collection. After that, 8 of 8, no hang, and nothing left behind
- Clean rerun: the real files pass, 8 of 8
