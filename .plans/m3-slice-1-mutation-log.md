# M3 slice 1 mutation log

Each mutant ran in a whole copy of `src/` and `tests/`, made with `shutil.copytree(..., symlinks=True)`
under `build/m3s1-<agent>/<name>/`, never in place, and each real file passes after it. Four Sonnet
builders wrote the four parts below, each over its own files; the caller planted the last part's
mutants again, at the join. The form is Guards, Mutation, Result, Clean rerun.

## The load agent

Each mutant is a whole copy of src/ and tests/ (the whole checkout for the gate rows) in build/m3s1-load/NAME/, run with `--libdirs src:tests:../../scheme-libs`. The `floor` mode runs against 1.0.18. The real files pass every suite (final runs below).

Final clean runs: test-native 109 pass / 0 fail, test-native-codes 31 / 0, test-blocks 34 / 0, each at 1.0.22 and at the 1.0.18 floor; `make test-memory MEMORY_SUITES='tests/test-blocks.sps tests/test-native.sps tests/test-native-codes.sps'` passes all three.

#### w-miss0

- Guards: test-blocks writers rows, under the gate
- Mutation: call-with-c-string never writes its terminating 0 (`src/chez-sodium/private/native.sls`, gate, tests/test-blocks.sps)
- Result:
    test-memory: FAIL tests/test-blocks.sps (exit 9, Valgrind's: an error or a definite leak)
  ==848== Conditional jump or move depends on uninitialised value(s)
  ==848== ERROR SUMMARY: 4 errors from 1 contexts (suppressed: 0 from 0)
  test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- Clean rerun: real file passes under the gate (final gate run, 3 of 3)

#### w-miss0-utf8empty

- Guards: test-blocks empty-string row, under the gate
- Mutation: call-with-utf8 does not write the empty string's one byte (`src/chez-sodium/private/native.sls`, gate, tests/test-blocks.sps)
- Result:
    test-memory: FAIL tests/test-blocks.sps (exit 9, Valgrind's: an error or a definite leak)
  ==848== Conditional jump or move depends on uninitialised value(s)
  ==848== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)
  test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- Clean rerun: real file passes under the gate (final gate run, 3 of 3)

#### w-past-cstr

- Guards: test-blocks, under the gate
- Mutation: call-with-c-string's block is one byte short: its 0 is written past the block (`src/chez-sodium/private/native.sls`, gate, tests/test-blocks.sps)
- Result:
    test-memory: FAIL tests/test-blocks.sps (exit 9, Valgrind's: an error or a definite leak)
  ==848== Invalid write of size 1
  ==848== ERROR SUMMARY: 7 errors from 2 contexts (suppressed: 0 from 0)
  test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- Clean rerun: real file passes under the gate (final gate run, 3 of 3)

#### w-past-utf8

- Guards: test-blocks, under the gate
- Mutation: call-with-utf8 writes each character with a bound of N+1, so a changed string writes one byte past the block (`src/chez-sodium/private/native.sls`, gate, tests/test-blocks.sps)
- Result:
    test-memory: FAIL tests/test-blocks.sps (exit 9, Valgrind's: an error or a definite leak)
  ==848== Invalid write of size 1
  ==848== ERROR SUMMARY: 10 errors from 1 contexts (suppressed: 0 from 0)
  test-memory: ran 1, passed 0, failed 1, hung 0, slow 0
- Clean rerun: real file passes under the gate (final gate run, 3 of 3)

#### w-null-empty

- Guards: test-blocks empty-string row
- Mutation: call-with-utf8 hands PROC NULL for the empty string (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 writes the UTF-8 of each string into a block of (max 1 N), read back inside PROC with the block's address above 0 and one block live: "" as the one byte 0, "a", "a" NUL "b", "pässw
    actual:   (raised "Exception: invalid memory reference.  Some debugging context lost")
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-width-short

- Guards: test-blocks changed rows
- Mutation: call-with-utf8 does not check that exactly N bytes were written: a shorter string answers PROC (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count: "pässwörd€" (13 bytes) at 14 and 12, each width's string at its count +
  FAIL call-with-utf8 answers PROC's value whatever it is: #f, 0, '() and a string are each the answer, and CHANGED's answer is its own value, unwrapped
  # of expected passes      32
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 32, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-width-long

- Guards: test-blocks changed rows
- Mutation: call-with-utf8 checks only the start of each character against N, not its width (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count: "pässwörd€" (13 bytes) at 14 and 12, each width's string at its count +
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-width-never

- Guards: test-blocks changed rows
- Mutation: call-with-utf8 never answers CHANGED (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count: "pässwörd€" (13 bytes) at 14 and 12, each width's string at its count +
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-cstr-string-copy

- Guards: test-native E13
- Mutation: call-with-c-string copies its string with string-copy (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E13 the string writers copy no secret: call-with-c-string's and call-with-utf8's definitions hold none of string->utf8, string->list, list->string, substring, string-copy, string-append, utf8->st
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-cstr-space

- Guards: test-blocks c-string range row
- Mutation: call-with-c-string accepts U+0020 (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-c-string answers CHANGED's value and never calls PROC for a character outside U+0021 to U+007E, first, in the middle or last: a space, U+007F, U+00E9, U+0000 and U+20AC
  FAIL call-with-c-string frees its block, and answers PROC's value or CHANGED's: none counted after a run and after a changed string; #f from PROC is the answer
  # of expected passes      32
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 32, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-cstr-del

- Guards: test-blocks c-string range row
- Mutation: call-with-c-string accepts U+007F (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-c-string answers CHANGED's value and never calls PROC for a character outside U+0021 to U+007E, first, in the middle or last: a space, U+007F, U+00E9, U+0000 and U+20AC
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-cstr-nocheck

- Guards: test-blocks c-string range row
- Mutation: call-with-c-string checks no character (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-c-string answers CHANGED's value and never calls PROC for a character outside U+0021 to U+007E, first, in the middle or last: a space, U+007F, U+00E9, U+0000 and U+20AC
  FAIL call-with-c-string frees its block, and answers PROC's value or CHANGED's: none counted after a run and after a changed string; #f from PROC is the answer
    actual:   (raised "Exception in foreign-set!: invalid value 8364 for foreign type unsigned-8")
  # of expected passes      32
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 32, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-utf8-w2

- Guards: test-blocks bytes row
- Mutation: a 2-byte edge off by one: U+0080 as one byte (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 writes the UTF-8 of each string into a block of (max 1 N), read back inside PROC with the block's address above 0 and one block live: "" as the one byte 0, "a", "a" NUL "b", "pässw
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-utf8-w3

- Guards: test-blocks bytes row
- Mutation: a 3-byte edge off by one: U+0800 as two bytes (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 writes the UTF-8 of each string into a block of (max 1 N), read back inside PROC with the block's address above 0 and one block live: "" as the one byte 0, "a", "a" NUL "b", "pässw
  FAIL call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count: "pässwörd€" (13 bytes) at 14 and 12, each width's string at its count +
  FAIL call-with-utf8 never writes past N: a four-byte character that does not fit the last 3 of N bytes answers CHANGED, a three-byte one the last 2, and a two-byte one the last 1, with PROC never call
  # of expected passes      31
  # of unexpected failures  3
  suite-exit-status: exit 1 (pass 31, fail 3, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-utf8-w4

- Guards: test-blocks bytes row
- Mutation: a 4-byte edge off by one: U+10000 as three bytes (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL call-with-utf8 writes the UTF-8 of each string into a block of (max 1 N), read back inside PROC with the block's address above 0 and one block live: "" as the one byte 0, "a", "a" NUL "b", "pässw
  FAIL call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count: "pässwörd€" (13 bytes) at 14 and 12, each width's string at its count +
  FAIL call-with-utf8 never writes past N: a four-byte character that does not fit the last 3 of N bytes answers CHANGED, a three-byte one the last 2, and a two-byte one the last 1, with PROC never call
  # of expected passes      31
  # of unexpected failures  3
  suite-exit-status: exit 1 (pass 31, fail 3, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-ascii-80

- Guards: test-blocks foreign-ascii-string rows
- Mutation: foreign-ascii-string accepts a byte of 0x80 (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL foreign-ascii-string answers #f, compared as the symbol false, when no 0 lies within N: 61 62 63 with N 3, a 0 at index 3 with N 3, and N 0; and when a byte before the 0 is 0x80 or more: 80, and 
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-ascii-bound

- Guards: test-blocks foreign-ascii-string rows
- Mutation: foreign-ascii-string looks one byte past N for the 0 (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL foreign-ascii-string answers #f, compared as the symbol false, when no 0 lies within N: 61 62 63 with N 3, a 0 at index 3 with N 3, and N 0; and when a byte before the 0 is 0x80 or more: 80, and 
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-who

- Guards: test-blocks refusal row
- Mutation: call-with-utf8 does not check its who (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL the writers refuse before any block: a who that is no symbol, from the helper; a string that is no string by its kind alone; an N that is no exact natural, a PROC and a CHANGED that are no proced
  FAIL the writers check in order: a bad who before a bad string, a bad string before a bad N, a bad N before a bad PROC, a bad PROC before a bad CHANGED
  # of expected passes      32
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 32, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-secret-shown

- Guards: test-blocks refusal row
- Mutation: call-with-c-string names the string it was given in its refusal (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL the writers refuse before any block: a who that is no symbol, from the helper; a string that is no string by its kind alone; an N that is no exact natural, a PROC and a CHANGED that are no proced
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-n-check

- Guards: test-blocks refusal row
- Mutation: call-with-utf8 does not check N (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL the writers refuse before any block: a who that is no symbol, from the helper; a string that is no string by its kind alone; an N that is no exact natural, a PROC and a CHANGED that are no proced
  FAIL the writers check in order: a bad who before a bad string, a bad string before a bad N, a bad N before a bad PROC, a bad PROC before a bad CHANGED
  # of expected passes      32
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 32, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-changed-check

- Guards: test-blocks refusal row
- Mutation: call-with-c-string does not check CHANGED (`src/chez-sodium/private/native.sls`, plain, tests/test-blocks.sps)
- Result:
    FAIL the writers refuse before any block: a who that is no symbol, from the helper; a string that is no string by its kind alone; an N that is no exact natural, a PROC and a CHANGED that are no proced
  # of expected passes      33
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 33, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### w-utf8-string-to-utf8

- Guards: test-native E13
- Mutation: call-with-utf8 calls string->utf8 (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E13 the string writers copy no secret: call-with-c-string's and call-with-utf8's definitions hold none of string->utf8, string->list, list->string, substring, string-copy, string-append, utf8->st
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-lazy

- Guards: E3, E5
- Mutation: raw-pwhash-passwd-min bound lazily, inside a lambda (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  FAIL E3 every foreign-procedure form in native.sls binds eagerly: thirty in all, exactly crypto_pwhash_str and crypto_pwhash_str_verify __collect_safe, each the whole second argument of (bind-required
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-conv-plain

- Guards: E3 collect-safe list
- Mutation: crypto_pwhash_str_verify bound plain (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E3 every foreign-procedure form in native.sls binds eagerly: thirty in all, exactly crypto_pwhash_str and crypto_pwhash_str_verify __collect_safe, each the whole second argument of (bind-required
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-conv-extra

- Guards: E3 collect-safe list
- Mutation: crypto_pwhash_str_needs_rehash bound collect-safe (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E3 every foreign-procedure form in native.sls binds eagerly: thirty in all, exactly crypto_pwhash_str and crypto_pwhash_str_verify __collect_safe, each the whole second argument of (bind-required
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-type-str

- Guards: test-native-codes
- Mutation: crypto_pwhash_str's limits bound unsigned-32 (`src/chez-sodium/private/native.sls`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str answers -1 and leaves all 128 bytes of out zero for an opslimit of 0, 2^32 and 2^64-1, and a memlimit of 0, one under the minimum, one over the maximum and 2^64-1 (each call's c
    actual:   (raised "Exception in $oops: invalid who argument raw-pwhash-str (message = \"invalid foreign-procedure argument ~s\", irritants = (4294967296))")
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-type-rehash

- Guards: test-native-codes
- Mutation: crypto_pwhash_str_needs_rehash's opslimit bound int (`src/chez-sodium/private/native.sls`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: the hash then a NUL and junk is 0; ops 0, memory 0 and both 0 are 1; ops 2^32 is -1; ops 2^32-1 with memlimit_max is 1; ops and memory 2^64-1 are -1
    actual:   (raised "Exception in $oops: invalid who argument raw-pwhash-str-needs-rehash (message = \"invalid foreign-procedure argument ~s\", irritants = (4294967296))")
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-type-opsmax

- Guards: test-native constants rows
- Mutation: crypto_pwhash_opslimit_max bound to return int (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-opslimit-max is F of the oracle's line (pwhash-opslimit-max F M): the function's answer
  FAIL native's pwhash-opslimit-max is M of the oracle's line (pwhash-opslimit-max F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  # of expected passes      106
  # of unexpected failures  3
  suite-exit-status: exit 1 (pass 106, fail 3, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-type-memmax

- Guards: test-native constants rows
- Mutation: crypto_pwhash_memlimit_max bound to return unsigned-32 (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-memlimit-max is F of the oracle's line (pwhash-memlimit-max F M): the function's answer
  FAIL native's pwhash-memlimit-max is M of the oracle's line (pwhash-memlimit-max F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  # of expected passes      106
  # of unexpected failures  3
  suite-exit-status: exit 1 (pass 106, fail 3, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-type-prefix

- Guards: test-native constants rows
- Mutation: `crypto_pwhash_strprefix`'s form bound to another entry point, so the prefix is read from a wrong address (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps). Binding it `() size_t` instead of `() uptr` is an equivalent mutant on LP64: the caller planted it at the join, and `test-native` passed all 109 rows, while `test-conventions`' src row failed by name. So the convention table alone holds that type
- Result:
    FAIL (chez-sodium private native) loads, reached through eval
  FAIL loaded-libsodium answers a fresh list at every call: its keys in order, equal and never eq?, fresh strings, and what a caller changes in one never reaches the next
  FAIL sodium-init, called after the load, answers 1, and again 1: the load called it first
  FAIL the load's path and source are the ones this suite chose
  FAIL native's version is the C oracle's, whole
  FAIL native's major is the C oracle's, whole
  FAIL native's minor is the C oracle's, whole
  FAIL native's init is the C oracle's, whole
  FAIL native's generichash-bytes is F of the oracle's line (generichash-bytes F M): the size function's answer
  FAIL native's generichash-bytes is M of the oracle's line (generichash-bytes F M): the header's macro
  FAIL native's generichash-bytes-min is F of the oracle's line (generichash-bytes-min F M): the size function's answer
  FAIL native's generichash-bytes-min is M of the oracle's line (generichash-bytes-min F M): the header's macro
    actual:   (raised "Exception in c-string->string: an address is an exact non-negative integer with irritant -1942248443")
    actual:   (raised "Exception in loaded-libsodium: (chez-sodium private native) could not be reached with irritant \"Exception in c-string->string: an address is an exact non-negative integer with irritant -1942248443\"")
    actual:   (raised "Exception in sodium-init: (chez-sodium private native) could not be reached with irritant \"Exception in c-string->string: an address is an exact non-negative integer with irritant -1942248443\"")
    actual:   (raised "Exception in assq: improperly formed alist (raised \"Exception in loaded-libsodium: (chez-sodium private native) could not be reached with irritant \\\"Exception in c-string->string: an address is an exact non-negative integer with irritant -1942248443\\\"\")")
    actual:   (version raised "Exception in assq: improperly formed alist (raised \"Exception in loaded-libsodium: (chez-sodium private native) could not be reached with irritant \\\"Exception in c-string->string: an address is an exact non-negative integer with irritant -1942248443\\\"\")")
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-drop-answer

- Guards: E5
- Mutation: the answer pair of crypto-pwhash-str-verify removed (the definition then reads a missing key) (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL (chez-sodium private native) loads, reached through eval
  FAIL loaded-libsodium answers a fresh list at every call: its keys in order, equal and never eq?, fresh strings, and what a caller changes in one never reaches the next
  FAIL sodium-init, called after the load, answers 1, and again 1: the load called it first
  FAIL the load's path and source are the ones this suite chose
  FAIL native's version is the C oracle's, whole
  FAIL native's major is the C oracle's, whole
  FAIL native's minor is the C oracle's, whole
  FAIL native's init is the C oracle's, whole
  FAIL native's generichash-bytes is F of the oracle's line (generichash-bytes F M): the size function's answer
  FAIL native's generichash-bytes is M of the oracle's line (generichash-bytes F M): the header's macro
  FAIL native's generichash-bytes-min is F of the oracle's line (generichash-bytes-min F M): the size function's answer
  FAIL native's generichash-bytes-min is M of the oracle's line (generichash-bytes-min F M): the header's macro
    actual:   (raised "Exception in cdr: #f is not a pair")
    actual:   (raised "Exception in loaded-libsodium: (chez-sodium private native) could not be reached with irritant \"Exception in cdr: #f is not a pair\"")
    actual:   (raised "Exception in sodium-init: (chez-sodium private native) could not be reached with irritant \"Exception in cdr: #f is not a pair\"")
    actual:   (raised "Exception in assq: improperly formed alist (raised \"Exception in loaded-libsodium: (chez-sodium private native) could not be reached with irritant \\\"Exception in cdr: #f is not a pair\\\"\")")
    actual:   (version raised "Exception in assq: improperly formed alist (raised \"Exception in loaded-libsodium: (chez-sodium private native) could not be reached with irritant \\\"Exception in cdr: #f is not a pair\\\"\")")
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-key-swap

- Guards: E5
- Mutation: pwhash-opslimit-moderate defined under pwhash-opslimit-sensitive's key (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-opslimit-moderate is F of the oracle's line (pwhash-opslimit-moderate F M): the function's answer
  FAIL native's pwhash-opslimit-moderate is M of the oracle's line (pwhash-opslimit-moderate F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  FAIL E5 the answers are top-level definitions (define NAME (answer 'KEY)): the record's six, the load's five raw bindings, the verbs' three, the five sizes, then the password hash's three bindings and
  # of expected passes      105
  # of unexpected failures  4
  suite-exit-status: exit 1 (pass 105, fail 4, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-moved-before-init

- Guards: E2
- Mutation: crypto_pwhash_str's binding moved before sodium_init's (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  FAIL E3 every foreign-procedure form in native.sls binds eagerly: thirty in all, exactly crypto_pwhash_str and crypto_pwhash_str_verify __collect_safe, each the whole second argument of (bind-required
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-twice

- Guards: E2
- Mutation: step 7 calls crypto_pwhash_strbytes twice (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-other

- Guards: E2, constant rows
- Mutation: step 7 reads opslimit_min from opslimit_max's function (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-opslimit-min is F of the oracle's line (pwhash-opslimit-min F M): the function's answer
  FAIL native's pwhash-opslimit-min is M of the oracle's line (pwhash-opslimit-min F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  # of expected passes      105
  # of unexpected failures  4
  suite-exit-status: exit 1 (pass 105, fail 4, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-twin

- Guards: E2 (source) and constant rows (values)
- Mutation: step 7 reads opslimit_max from passwd_max's function (a twin) (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-early

- Guards: E2
- Mutation: strbytes read before every entry point is bound (before raw-pwhash-passwd-max's binding) (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-prefix

- Guards: constant rows
- Mutation: strprefix read as a plain address, not a string (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-strprefix is F of the oracle's line (pwhash-strprefix F M): the function's answer
  FAIL native's pwhash-strprefix is M of the oracle's line (pwhash-strprefix F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  # of expected passes      105
  # of unexpected failures  4
  suite-exit-status: exit 1 (pass 105, fail 4, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-const-in-scheme

- Guards: constant rows, E2
- Mutation: strbytes written in Scheme as 128 (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-macro

- Guards: test-native oracle constant rows
- Mutation: the oracle's memlimit-moderate macro read from MEMLIMIT_SENSITIVE (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-memlimit-moderate is M of the oracle's line (pwhash-memlimit-moderate F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-twin-macro

- Guards: test-native oracle constant rows (expected to survive)
- Mutation: the oracle reads opslimit-max's macro from crypto_pwhash_PASSWD_MAX (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    # of expected passes      109
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-prefix

- Guards: test-native oracle constant rows
- Mutation: the oracle prints the prefix from the opposite place: M is the quoted function answer (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-strprefix is M of the oracle's line (pwhash-strprefix F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-hex-limits

- Guards: test-native hex-mode rows
- Mutation: hash mode hashes at ops 2, not libsodium's minimum (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL the oracle's hex mode hashes at the minimum limits and verifies its own hash: right 0, wrong -1, for a non-ASCII password, a password with a NUL, and the empty one
  # of expected passes      108
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 108, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-hex-trunc

- Guards: test-native hex-mode rows
- Mutation: hex decode drops the last byte (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL the oracle's hex mode hashes at the minimum limits and verifies its own hash: right 0, wrong -1, for a non-ASCII password, a password with a NUL, and the empty one
  FAIL the oracle's hex mode: a hash of "a" does not verify the empty password, and the empty hash does not verify "a"; two hashes of one password differ
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-hex-empty

- Guards: test-native hex-mode rows
- Mutation: an empty HEX hashes "a" (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL the oracle's hex mode hashes at the minimum limits and verifies its own hash: right 0, wrong -1, for a non-ASCII password, a password with a NUL, and the empty one
  FAIL the oracle's hex mode: a hash of "a" does not verify the empty password, and the empty hash does not verify "a"; two hashes of one password differ
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-str-ok

- Guards: row 22: (test-equal "crypto_pwhash_str at the minimum
- Mutation: expected value planted wrong: (list 0 93 -> (list 0 92 (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str at the minimum limits answers 0 and writes a string of 93 characters, then zeros to the end of out's 128 bytes, none left 5A; its fields are the prefix, v=19, m=8,t=1,p=1, a sal
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-str-neg1

- Guards: row 22: (test-equal "crypto_pwhash_str answers -1
- Mutation: expected value planted wrong: '(-1 #t) -> '(-1 #f) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str answers -1 and leaves all 128 bytes of out zero for an opslimit of 0, 2^32 and 2^64-1, and a memlimit of 0, one under the minimum, one over the maximum and 2^64-1 (each call's c
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-str-empty

- Guards: row 22: (test-equal "crypto_pwhash_str of the empty
- Mutation: expected value planted wrong: '(0 0 -1) -> '(0 0 0) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str of the empty password, length 0 on a one-byte block, answers 0 and writes a string that verifies the empty password 0, and not "x" (-1)
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-str-floor

- Guards: row 22: (test-equal "crypto_pwhash_str at ops 2 floors
- Mutation: expected value planted wrong: "m=16,t=2,p=1" "m=16,t=2,p=1" 94 -> "m=17,t=2,p=1" "m=16,t=2,p=1" 94 (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str at ops 2 floors a memlimit of 16 KiB + 1 byte to whole KiB: the parameter field is m=16,t=2,p=1, as at 16 KiB, with a 94-character string
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-verify-basic

- Guards: row 22: (test-equal "crypto_pwhash_str_verify: the right
- Mutation: expected value planted wrong: '(0 -1 -1 -1 -1 -1 -1 -1 0) -> '(0 -1 -1 -1 -1 -1 -1 -1 -1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_verify: the right password 0, a wrong one -1; "garbage", an empty string, the hash then "junk", then a newline, and after a space -1; the hash then a NUL and "junk" 0, as C read
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-verify-nul

- Guards: row 22: (test-equal "crypto_pwhash_str_verify: a password of 3
- Mutation: expected value planted wrong: '(0 -1 0 -1) -> '(0 -1 0 0) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_verify: a password of 3 bytes with a NUL, 61 00 62, verifies its own hash 0 and "a" -1; the empty password verifies its own 0 and "x" -1
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-verify-136

- Guards: row 22: (test-equal "crypto_pwhash_str_verify: a 136
- Mutation: expected value planted wrong: '(136 0 -1) -> '(136 -1 -1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_verify: a 136-character hash, longer than strbytes, verifies "pw" 0 and "pX" -1
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-verify-nonascii

- Guards: row 22: (test-equal "crypto_pwhash_str_verify: the bytes of a non-AS
- Mutation: expected value planted wrong: '(13 0 -1 -1 -1 -1) -> '(13 0 -1 -1 -1 0) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_verify: the bytes of a non-ASCII password against its own hash 0; its last character changed, its Latin-1 bytes and the ASCII part alone -1 (the four calls' codes)
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-limits

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash of the hash of
- Mutation: expected value planted wrong: '(0 1 1 1 0 1) -> '(0 1 1 1 1 1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash of the hash of "pw" at the minimum limits: the same limits 0; ops+1, memory x2 and memory -1 byte 1; memory +1023 bytes 0 and +1024 bytes 1 (the six calls' codes, i
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-ops3

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: a hash made at 
- Mutation: expected value planted wrong: '(0 1 1) -> '(0 0 1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: a hash made at ops 3 against ops 1 is 1, and against ops 3 0; one made at four times the minimum memory against the minimum is 1
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-garbage

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: \"garbage\"
- Mutation: expected value planted wrong: '(-1 -1 -1) -> '(-1 -1 1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: "garbage" is -1, and so is the 136-character hash, at its own limits and at ops+1: any string of strbytes characters or more is unreadable
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-argon2i

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: an argon2i
- Mutation: expected value planted wrong: '(0 1) -> '(0 0) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: an argon2i string at ops 3 and its own memory is 0, at ops 4 it is 1, and the prefix is not compared (the two calls' codes)
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-edits

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: p=2
- Mutation: expected value planted wrong: '(0 0 0 -1 -1 -1 -1 -1 0 -1) -> '(0 0 0 0 -1 -1 -1 -1 0 -1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: p=2 and p=4 at 64 KiB are 0 as p=1 is, though p=4 and p=0 at 8 KiB are -1 (four lanes need 32 KiB); the argon2d prefix, no $v= and $v=16 are -1; an argon2i prefix 
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-ranges

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: the hash then a
- Mutation: expected value planted wrong: '(0 1 1 1 -1 1 -1) -> '(0 1 1 1 1 1 -1) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: the hash then a NUL and junk is 0; ops 0, memory 0 and both 0 are 1; ops 2^32 is -1; ops 2^32-1 with memlimit_max is 1; ops and memory 2^64-1 are -1
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-0x80-current

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: a byte of 0xC3
- Mutation: expected value planted wrong: (else -1) -> (else 0) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: a byte of 0xC3 as the salt's first character is 0 at 1.0.18 and -1 at 1.0.22, by the version this suite loaded; verify of it is -1 at both (the two calls' codes)
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-0x80-floor

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: a byte of 0xC3
- Mutation: expected value planted wrong: (equal? version "1.0.18") 0) -> (equal? version "1.0.18") -1) (`tests/test-native-codes.sps`, floor, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: a byte of 0xC3 as the salt's first character is 0 at 1.0.18 and -1 at 1.0.22, by the version this suite loaded; verify of it is -1 at both (the two calls' codes)
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.18 (final floor run)

#### c-rehash-presets

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: each hand-writt
- Mutation: expected value planted wrong: '((0 1 1) (1 0 1) (1 1 0)) -> '((0 1 1) (1 0 1) (1 0 0)) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: each hand-written preset string, with a salt of 22 characters and a tag of 43, is 0 at its own preset's limits and 1 at the other two: the rows interactive, modera
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### c-rehash-short

- Guards: row 22: (test-equal "crypto_pwhash_str_needs_rehash: at the moderate
- Mutation: expected value planted wrong: '(0 -1 -1) -> '(0 -1 0) (`tests/test-native-codes.sps`, plain, tests/test-native-codes.sps)
- Result:
    FAIL crypto_pwhash_str_needs_rehash: at the moderate limits, the intact string is 0, a salt of 21 characters -1 and a tag of 42 -1
  # of expected passes      30
  # of unexpected failures  1
  suite-exit-status: exit 1 (pass 30, fail 1, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-swap2

- Guards: test-native oracle constant rows
- Mutation: oracle prints sensitive's answer under opslimit-moderate and the reverse (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL native's pwhash-opslimit-moderate is F of the oracle's line (pwhash-opslimit-moderate F M): the function's answer
  FAIL native's pwhash-opslimit-sensitive is F of the oracle's line (pwhash-opslimit-sensitive F M): the function's answer
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  # of expected passes      106
  # of unexpected failures  3
  suite-exit-status: exit 1 (pass 106, fail 3, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-twin2

- Guards: test-native oracle constant rows (expected to survive)
- Mutation: the oracle prints passwd_max's answer under opslimit-max's name and the reverse (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    # of expected passes      109
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### o-hex-verify0b

- Guards: test-native hex-mode rows
- Mutation: verify mode always prints 0 (`tests/libsodium-oracle.c`, plain, tests/test-native.sps)
- Result:
    FAIL the oracle's hex mode hashes at the minimum limits and verifies its own hash: right 0, wrong -1, for a non-ASCII password, a password with a NUL, and the empty one
  FAIL the oracle's hex mode: a hash of "a" does not verify the empty password, and the empty hash does not verify "a"; two hashes of one password differ
  # of expected passes      107
  # of unexpected failures  2
  suite-exit-status: exit 1 (pass 107, fail 2, xpass 0): a suite needs a pass, and no fail or xpass
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### s7-twin-values-only2

- Guards: constant value rows alone (E2 expectation made to match the mutant)
- Mutation: step 7 reads opslimit_max from passwd_max's function; E2's expected list changed to match (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    # of expected passes      109
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

#### b-drop-binding

- Guards: E2, E3, E5, export row
- Mutation: crypto_pwhash_passwd_max's binding, read, answer, definition and export removed (`src/chez-sodium/private/native.sls`, plain, tests/test-native.sps)
- Result:
    FAIL (chez-sodium private native) exports exactly the load's record, the eleven raw bindings, the five sizes, the fourteen password constants, call-in-section and the block, byte and string helpers, a
  FAIL native's pwhash-passwd-max is F of the oracle's line (pwhash-passwd-max F M): the function's answer
  FAIL native's pwhash-passwd-max is M of the oracle's line (pwhash-passwd-max F M): the header's macro
  FAIL the fourteen password constants are the measured ones, written here: native's, and the oracle's F and M of each line
  FAIL E2 the load's let* steps, in order: choose, load, the three version bindings, the version, major and minor read, the floor, sodium_init's binding, call and check, sodium_memzero's binding, the se
  FAIL E3 every foreign-procedure form in native.sls binds eagerly: thirty in all, exactly crypto_pwhash_str and crypto_pwhash_str_verify __collect_safe, each the whole second argument of (bind-required
  FAIL E5 the answers are top-level definitions (define NAME (answer 'KEY)): the record's six, the load's five raw bindings, the verbs' three, the five sizes, then the password hash's three bindings and
    actual:   (raised "Exception: attempt to reference unbound identifier pwhash-passwd-max")
    actual:   (raised "Exception: attempt to reference unbound identifier pwhash-passwd-max")
    actual:   ((pwhash-strbytes 128 128 128) (pwhash-strprefix "$argon2id$" "$argon2id$" "$argon2id$") (pwhash-opslimit-min 1 1 1) (pwhash-opslimit-max 4294967295 4294967295 4294967295) (pwhash-opslimit-interactive 2 2 2) (pwhash-opslimit-moderate 3 3 3) (pwhash-opslimit-sensitive 4 4 4) (pwhash-memlimit-min 8192 8192 8192) (pwhash-memlimit-max 4398046510080 4398046510080 4398046510080) (pwhash-memlimit-interactive 67108864 67108864 67108864) (pwhash-memlimit-moderate 268435456 268435456 268435456) (pwhash-memlimit-sensitive 1073741824 1073741824 1073741824) (pwhash-passwd-min 0 0 0) (pwhash-passwd-max (raised "Exception: attempt to reference unbound identifier pwhash-passwd-max") 4294967295 4294967295))
  # of expected passes      102
  # of unexpected failures  7
- Clean rerun: real file passes at 1.0.22 and 1.0.18 (final runs)

  

## The conventions agent

Every mutant is a whole copy of `src/` and `tests/` (symlinks kept) in
`build/m3s1-conv/<name>/`, run from inside it. Floor = 1.0.18's headers first on
`C_INCLUDE_PATH`; current = the container's 1.0.22. Pass/fail are SRFI-64's
expected passes / unexpected failures. Baselines: test-conventions 54/0 and
test-constants 23/0 at both headers, 54/0 and 23/0 under the gate.

Mutant rows that run test-conventions show 9 to 13 failures, none of them the
`every-entry` row once the decoy agent's list landed; each is named by the
suite as failing.

### 1. A new row's C prototype wrong (test-constants, floor and current)

Guards: `prototypes: the header declares each row's prototype exactly` (and the
Chez map for result types the map can see).
Mutation: in `tests/foreign-conventions.sls`, the row's prototype result
written wrong (`size_t` -> `unsigned long long`, `int` -> `long`,
`const char *` -> `char *`); for the three password calls also the last
parameter (`str`: memlimit `size_t` -> `unsigned long long`; `str_verify`:
passwdlen `unsigned long long` -> `size_t`; `needs_rehash`: memlimit
`size_t` -> `unsigned long long`).
Mutants: `proto-result-<name>` for all 17 names, `proto-param-crypto_pwhash_str`,
`proto-param-crypto_pwhash_str_verify`, `proto-param-crypto_pwhash_str_needs_rehash`.
Result: every mutant fails at both headers (19/4 for all but
`proto-result-crypto_pwhash_strprefix`, which the map cannot see, so it fails
the header row alone: 21/2). 40 runs, 40 red.
Clean rerun: 23/0 at both headers.

### 2. A new row's Chez types wrong in the table (test-conventions, test-constants)

Guards: conventions' `src: no violation`, `the thirty rows are written out`,
the sweeps; constants' `each row's Chez types are the map of its C types`.
Mutation: the row's result type written `int` (`uptr` for an `int` row).
Mutants: `chez-result-<name>`, 17.
Result: conventions 44/10 for every mutant; constants 20/3 for `str`,
`str_verify`, `needs_rehash`, `strprefix`, and 21/2 for the rest. 34 runs, 34 red.
Clean rerun: conventions 54/0, constants 23/0.

Mutation: an argument type of a password call written wrong in the table:
`chez-args-str` (`memlimit` `size_t`: opslimit -> `size_t`), 
`chez-args-str-memlimit-ull` (memlimit -> `unsigned-64`), `chez-args-verify`
(passwdlen -> `size_t`), `chez-args-needs-rehash` (opslimit -> `size_t`).
Result: conventions 44/10 for each, constants 21/2 for each. Red.
Clean rerun: 54/0 and 23/0.

### 3. The native form's convention against its row (test-conventions)

Guards: `convention-of` against the row's convention (`mismatch ... convention`),
`src: no violation`, the sweeps.
Mutation, in the copy of `src/chez-sodium/private/native.sls`:
- `native-str-plain`: `__collect_safe` removed from `crypto_pwhash_str`;
- `native-verify-plain`: removed from `crypto_pwhash_str_verify`;
- `native-rehash-collect-safe`: `__collect_safe` added to `crypto_pwhash_str_needs_rehash`;
- `native-strbytes-collect-safe`: added to `crypto_pwhash_strbytes`.
Result: each 45/9, red (`src: no violation` names the mismatch).
Mutation, in the table: `row-str-plain` (row says plain), `row-rehash-collect-safe`
(row says collect-safe): each 43/11, red (also `every row is plain but ...`).
Clean rerun: 54/0.

### 4. A row dropped, a row added

Guards: `table: it has a row for each of the thirty entry points`, the
written-out rows, `src: no violation` (no-row), `sweep: a row with no form`.
Mutation: each of the 17 rows removed from the table (`drop-row-<name>`).
Result: each 41/13, red. 17 runs.
Mutation: `add-row-no-binding`, a row `crypto_pwhash_str_alg` that native does
not bind. Result: conventions 42/12 (no-form via `src: no violation`), constants
20/3 (the prototype row of a function the header lacks fails the compile). Red.
Clean rerun: 54/0 and 23/0.

### 5. Each prototype row's planted mistake (test-constants, floor and current)

Guards: `the prototype check refuses each kind of wrong row, by name`.
Mutation: in the copy of `tests/test-constants.sps`, a `set!` after `plants`
that replaces the k-th password plant with its correct prototype, read from the
table, still expecting 0 (the plant is no longer wrong).
Mutants: `plant-00` to `plant-25`, the 26 new plants, in order:
str x5 (opslimit as size_t, memlimit as ull, passwd as char *, passwdlen as
size_t, void result), verify x3, needs_rehash x3, strprefix x2, strbytes,
opslimit_{min,max,interactive,moderate,sensitive}, memlimit_{min,max,
interactive,moderate,sensitive}, passwd_min, passwd_max.
Result: every mutant 22/1 at both headers (the plants row), red. 52 runs.
Clean rerun: 23/0 at both headers.

### 6. The map sweep over all thirty rows (test-constants)

Guards: `the map check names, for each of the thirty rows, its result written
wrong, and each argument written wrong, one problem each`.
Mutation: `sweep-map-noop`, `other-chez` made the identity, so nothing is written wrong.
Result: 22/1, that row red. Clean rerun: 23/0.

## The decoy agent

Clean rerun, for every entry below: the real tree, unmutated, passes each named suite at 1.0.22, at the floor (1.0.18) and under the gate (see the hand-back for counts).

#### native copy: bind-required of crypto_pwhash_str replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_str
- Mutation: native copy: bind-required of crypto_pwhash_str replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_str: a library without crypto_pwhash_str is 
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_str_verify replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_str_verify
- Mutation: native copy: bind-required of crypto_pwhash_str_verify replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_str_verify: a library without crypto_pwhash_
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_str_needs_rehash replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_str_needs_rehash
- Mutation: native copy: bind-required of crypto_pwhash_str_needs_rehash replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_str_needs_rehash: a library without crypto_p
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_strbytes replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_strbytes
- Mutation: native copy: bind-required of crypto_pwhash_strbytes replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_strbytes: a library without crypto_pwhash_st
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_strprefix replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_strprefix
- Mutation: native copy: bind-required of crypto_pwhash_strprefix replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_strprefix: a library without crypto_pwhash_s
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_opslimit_min replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_opslimit_min
- Mutation: native copy: bind-required of crypto_pwhash_opslimit_min replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_opslimit_min: a library without crypto_pwhas
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_opslimit_max replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_opslimit_max
- Mutation: native copy: bind-required of crypto_pwhash_opslimit_max replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_opslimit_max: a library without crypto_pwhas
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_opslimit_interactive replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_opslimit_interactive
- Mutation: native copy: bind-required of crypto_pwhash_opslimit_interactive replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_opslimit_interactive: a library without cryp
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_opslimit_moderate replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_opslimit_moderate
- Mutation: native copy: bind-required of crypto_pwhash_opslimit_moderate replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_opslimit_moderate: a library without crypto_
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_opslimit_sensitive replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-passwords: missing-api row for crypto_pwhash_opslimit_sensitive
- Mutation: native copy: bind-required of crypto_pwhash_opslimit_sensitive replaced by a bare foreign-procedure
- Result: 1 FAIL, 18 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_opslimit_sensitive: a library without crypto
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_memlimit_min replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_memlimit_min
- Mutation: native copy: bind-required of crypto_pwhash_memlimit_min replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_memlimit_min: a library without crypto_pwhas
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_memlimit_max replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_memlimit_max
- Mutation: native copy: bind-required of crypto_pwhash_memlimit_max replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_memlimit_max: a library without crypto_pwhas
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_memlimit_interactive replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_memlimit_interactive
- Mutation: native copy: bind-required of crypto_pwhash_memlimit_interactive replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_memlimit_interactive: a library without cryp
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_memlimit_moderate replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_memlimit_moderate
- Mutation: native copy: bind-required of crypto_pwhash_memlimit_moderate replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_memlimit_moderate: a library without crypto_
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_memlimit_sensitive replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_memlimit_sensitive
- Mutation: native copy: bind-required of crypto_pwhash_memlimit_sensitive replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_memlimit_sensitive: a library without crypto
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_passwd_min replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_passwd_min
- Mutation: native copy: bind-required of crypto_pwhash_passwd_min replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_passwd_min: a library without crypto_pwhash_
- Clean rerun: the real tree passes, as this part's note says

#### native copy: bind-required of crypto_pwhash_passwd_max replaced by a bare foreign-procedure
- Guards: test-library-loading-missing-limits: missing-api row for crypto_pwhash_passwd_max
- Mutation: native copy: bind-required of crypto_pwhash_passwd_max replaced by a bare foreign-procedure
- Result: 1 FAIL, 15 pass; the named row failed: yes; fails: decoy lacks-crypto_pwhash_passwd_max: a library without crypto_pwhash_
- Clean rerun: the real tree passes, as this part's note says

#### native copy: memlimit-min read twice: (begin (raw-pwhash-memlimit-min) (raw-pwhash-memlimit-min))
- Guards: the load log of step 7 (control row of -decoys, pwhash-limits-other row of -verbs)
- Mutation: native copy: memlimit-min read twice: (begin (raw-pwhash-memlimit-min) (raw-pwhash-memlimit-min))
- Result: test-library-loading-decoys: 7 FAIL, 13 pass; decoy control: the floor itself is accepted: the report's four fields, native's five sizes and fourteen consta; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: the string deci; decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the load records 1; decoy control under "sizes-other": sizes-other loads, and native records its five sizes: 33, 8, 80, 9 and 81 || test-library-loading-verbs: 1 FAIL, 14 pass; decoy control under "pwhash-limits-other": native's fourteen recorded constants under pwhash-limits-other, eac
- Clean rerun: the real tree passes, as this part's note says

#### native copy: passwd-min read dropped, 0 recorded in its place
- Guards: the load log of step 7
- Mutation: native copy: passwd-min read dropped, 0 recorded in its place
- Result: test-library-loading-decoys: 7 FAIL, 13 pass; decoy control: the floor itself is accepted: the report's four fields, native's five sizes and fourteen consta; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: the string deci; decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the load records 1; decoy control under "sizes-other": sizes-other loads, and native records its five sizes: 33, 8, 80, 9 and 81 || test-library-loading-verbs: 1 FAIL, 14 pass; decoy control under "pwhash-limits-other": native's fourteen recorded constants under pwhash-limits-other, eac
- Clean rerun: the real tree passes, as this part's note says

#### native copy: opslimit-moderate and opslimit-sensitive reads swapped in order (values swap too)
- Guards: the load log of step 7
- Mutation: native copy: opslimit-moderate and opslimit-sensitive reads swapped in order (values swap too)
- Result: test-library-loading-decoys: 7 FAIL, 13 pass; decoy control: the floor itself is accepted: the report's four fields, native's five sizes and fourteen consta; decoy control under "libtool-low": the floor with libtool numbers 0.0 loads, and reports them: the string deci; decoy control under "init-already": sodium_init answering 1 is no failure: it loads, and the load records 1; decoy control under "sizes-other": sizes-other loads, and native records its five sizes: 33, 8, 80, 9 and 81 || test-library-loading-verbs: 1 FAIL, 14 pass; decoy control under "pwhash-limits-other": native's fourteen recorded constants under pwhash-limits-other, eac
- Clean rerun: the real tree passes, as this part's note says

#### oracle copy: opslimit_max and passwd_max F answers swapped between their two lines (both variables still used)
- Guards: the oracle child under pwhash-limits-other (-verbs)
- Mutation: oracle copy: opslimit_max and passwd_max F answers swapped between their two lines (both variables still used)
- Result: 1 FAIL, 14 pass; the C oracle on the control build under pwhash-limits-other: its output whole, each constant line the decoy's answer for its own function an
- Clean rerun: the real tree passes, as this part's note says

#### native copy: the passwd-max key records opslimit-max's value
- Guards: refusal-probe --constants under pwhash-limits-other (-verbs); the control row of -decoys cannot see it (twins both 4294967295)
- Mutation: native copy: the passwd-max key records opslimit-max's value
- Result: test-library-loading-decoys: 0 FAIL, 20 pass;  || test-library-loading-verbs: 1 FAIL, 14 pass; decoy control under "pwhash-limits-other": native's fourteen recorded constants under pwhash-limits-other, each under its own key: the twins opslimit_
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `out ? 1 : 0` planted in crypto_pwhash_str's definition number 1
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `out ? 1 : 0` planted in crypto_pwhash_str's definition number 1
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `passwd ? 1 : 0` planted in crypto_pwhash_str's definition number 1
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `passwd ? 1 : 0` planted in crypto_pwhash_str's definition number 1
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 1
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 1
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `passwd ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 1
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `passwd ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 1
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 2
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 2
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `passwd ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 2
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `passwd ? 1 : 0` planted in crypto_pwhash_str_verify's definition number 2
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_needs_rehash's definition number 1
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_needs_rehash's definition number 1
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_needs_rehash's definition number 2
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a ternary `str ? 1 : 0` planted in crypto_pwhash_str_needs_rehash's definition number 2
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a second use `(void) passwd;` in crypto_pwhash_str's definition number 1
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a second use `(void) passwd;` in crypto_pwhash_str's definition number 1
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: a second use `(void) str;` in crypto_pwhash_str_needs_rehash's definition number 2
- Guards: test-decoy-source: the real files row (pointer rule)
- Mutation: decoy copy: a second use `(void) str;` in crypto_pwhash_str_needs_rehash's definition number 2
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: needs_rehash (array arm) takes its last parameter as a parameter macro MEMLIMIT_PARAM
- Guards: test-decoy-source: the real files row
- Mutation: decoy copy: needs_rehash (array arm) takes its last parameter as a parameter macro MEMLIMIT_PARAM
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### test copy: the scanner's one-identifier rule removed
- Guards: test-decoy-source: the planted row "a parameter that is one identifier alone"
- Mutation: test copy: the scanner's one-identifier rule removed
- Result: 1 FAIL, 89 pass; a parameter that is one identifier alone, a macro for a whole parameter, is unreadable, though a scalar word alone is no
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: crypto_pwhash_str_verify's pointer-arm definition deleted whole, the array arm left
- Guards: test-decoy-source: the real files row (the whole list names each function twice)
- Mutation: decoy copy: crypto_pwhash_str_verify's pointer-arm definition deleted whole, the array arm left
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: crypto_pwhash_str_needs_rehash's array-arm definition deleted whole, the pointer arm left
- Guards: test-decoy-source: the real files row (the whole list names each function twice)
- Mutation: decoy copy: crypto_pwhash_str_needs_rehash's array-arm definition deleted whole, the pointer arm left
- Result: 1 FAIL, 89 pass; the real tests/*.c that include sodium.h: the functions read, whole, and no breach
- Clean rerun: the real tree passes, as this part's note says

#### decoy copy: the log's overflow flag never set, so every call past the end appends another overflow entry
- Guards: test-library-loading-combined: the control drive row's overflow lines (head, tail, unmoved, one overflow entry, fits)
- Mutation: decoy copy: the log's overflow flag never set, so every call past the end appends another overflow entry
- Result: 1 FAIL, 17 pass; the control, called directly: the sizes 32, 16, 64, 16 and 64, A5 over exactly the length, 0, and 0, -1, 0, -1, -1; then a full log ends in one overflow entry a
- Clean rerun: the real tree passes, as this part's note says

#### Note on the oracle mutant
A first attempt changed only one line's variable, leaving the other unused: the oracle then failed to compile under -Werror, which failed three rows for the wrong reason. Replaced by the swap of both lines above, which fails exactly the pwhash-limits-other row; the sizes-other and no-switch oracle rows pass, because at the control's values the twins are equal.

## The pure core agent

### pre-low-bound
- Guards: readable-hash-string?
- Mutation: readable-hash-string?: lower bound U+0021 dropped
- Result: CAUGHT (2 failing rows: FAIL R U+0020 is refused; FAIL R U+0020 inside a hash is refused)
- Clean rerun: see end

### pre-high-bound
- Guards: readable-hash-string?
- Mutation: readable-hash-string?: upper bound U+007E dropped
- Result: CAUGHT (1 failing rows: FAIL R U+007F is refused)
- Clean rerun: see end

### pre-cap
- Guards: readable-hash-string?
- Mutation: readable-hash-string?: cap removed
- Result: CAUGHT (1 failing rows: FAIL R input-cap + 1 characters are refused)
- Clean rerun: see end

### pre-cap-off
- Guards: readable-hash-string?
- Mutation: readable-hash-string?: cap off by one (<)
- Result: CAUGHT (1 failing rows: FAIL R input-cap characters are accepted)
- Clean rerun: see end

### pre-empty
- Guards: readable-hash-string?
- Mutation: readable-hash-string?: empty string accepted
- Result: CAUGHT (1 failing rows: FAIL R the empty string is refused)
- Clean rerun: see end

### w1-up
- Guards: utf8-length
- Mutation: utf8-length: edge U+0080 -> U+0081
- Result: CAUGHT (1 failing rows: FAIL U width of U+80)
- Clean rerun: see end

### w1-down
- Guards: utf8-length
- Mutation: utf8-length: edge U+0080 -> U+007F
- Result: CAUGHT (1 failing rows: FAIL U width of U+7F)
- Clean rerun: see end

### w2-up
- Guards: utf8-length
- Mutation: utf8-length: edge U+0800 -> U+0801
- Result: CAUGHT (2 failing rows: FAIL U width of U+800; FAIL U a long mixed string agrees with the encoder)
- Clean rerun: see end

### w2-down
- Guards: utf8-length
- Mutation: utf8-length: edge U+0800 -> U+07FF
- Result: CAUGHT (1 failing rows: FAIL U width of U+7FF)
- Clean rerun: see end

### w3-up
- Guards: utf8-length
- Mutation: utf8-length: edge U+10000 -> U+10001
- Result: CAUGHT (2 failing rows: FAIL U width of U+10000; FAIL U a long mixed string agrees with the encoder)
- Clean rerun: see end

### w3-down
- Guards: utf8-length
- Mutation: utf8-length: edge U+10000 -> U+FFFF
- Result: CAUGHT (1 failing rows: FAIL U width of U+FFFF)
- Clean rerun: see end

### shape-prefix
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: prefix not checked
- Result: CAUGHT (5 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-v
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: v= not checked
- Result: CAUGHT (5 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-v-digits
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: digits after v= not required
- Result: CAUGHT (6 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-m
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: $m= not checked
- Result: CAUGHT (5 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-m-digits
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: digits after m= not required
- Result: CAUGHT (6 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-t
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: ,t= not checked
- Result: CAUGHT (5 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-t-digits
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: digits after t= not required
- Result: CAUGHT (6 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-p1
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: p=1 loosened to any p
- Result: CAUGHT (5 failing rows: FAIL H p=4; FAIL H p=2; FAIL H p=10; FAIL H ,p=1 with nothing after $)
- Clean rerun: see end

### shape-dollar
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: the $ after p=1 dropped
- Result: CAUGHT (2 failing rows: FAIL H p=10; FAIL H ,p=1 with nothing after $)
- Clean rerun: see end

### shape-rest
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: at least one more character not required
- Result: CAUGHT (6 failing rows: FAIL H an argon2id hash against the argon2id prefix; FAIL H an argon2i hash against the argon2i prefix; FAIL H the 136-character hash; FAIL H the generated shape holds)
- Clean rerun: see end

### shape-false-prefix
- Guards: current-hash-shape?
- Mutation: current-hash-shape?: #f prefix read as the empty prefix
- Result: CAUGHT (1 failing rows: FAIL H a #f prefix is not an empty one: a hash that is only the parameters)
- Clean rerun: see end

### copy-utf8
- Guards: no-copy row
- Mutation: no-copy row: utf8-length through string->utf8
- Result: CAUGHT (1 failing rows: FAIL S the library holds no copying or encoding primitive)
- Clean rerun: see end

### copy-substring
- Guards: no-copy row
- Mutation: no-copy row: a substring in the shape check
- Result: CAUGHT (1 failing rows: FAIL S the library holds no copying or encoding primitive)
- Clean rerun: see end

### import-native
- Guards: test-never-loads loaders row
- Mutation: test-never-loads loaders row: password-text imports native
- Result: CAUGHT (2 failing rows: FAIL the libraries under src/ that load libsodium, found from their imports: native, and each that i; FAIL a child that references every export of (chez-sodium-testing) runs its body, and maps no libsod)
- Clean rerun: see end

### Clean rerun of test-password-text.sps on the real tree
- exit 0; # of expected passes      60

### Clean rerun of test-never-loads.sps on the real tree
- exit 0; # of expected passes      8

## The caller, at the join

### text-p1-loosened

- Guards: `test-password-text`'s H rows
- Mutation: `current-hash-shape?` reads `,p=` where it reads `,p=1$`
- Result: 5 rows fail, among them `H p=4`, `H p=2` and `H ,p=1 with nothing after $`; 55 pass
- Clean rerun: the real file passes, 60 of 60, with `CHEZ_SODIUM_LIBRARY` at a path that does not exist

### conv-pwhash-str-plain

- Guards: `test-conventions`' src row
- Mutation: native binds `crypto_pwhash_str` plain, its row still collect-safe
- Result: `src: no violation: each form is a literal binding held to its row, and each row has its form` fails
- Clean rerun: the real files pass, 54 of 54 at 1.0.22 and at the floor

### utf8-no-bound

- Guards: `test-blocks`' writer rows
- Mutation: `call-with-utf8` never checks a character's bytes against what is left of N
- Result: `call-with-utf8 answers CHANGED's value, and never calls PROC, when N is one more or one less than the string's UTF-8 count…` fails; 33 pass
- Clean rerun: the real file passes, 34 of 34 at 1.0.22 and at the floor

### native-twin-swap

- Guards: `test-library-loading-verbs`' `--constants` row under `pwhash-limits-other`
- Mutation: native records `passwd_max`'s value under the key `pwhash-opslimit-max`
- Result: that row alone fails; `test-native-codes` passes 31 of 31, since the twins are equal at every release
- Clean rerun: the real files pass

After slice 1's review (`research/m3-slice-1-review/`), three Sonnet fix agents, on disjoint
files, logged these, and the caller reran each review mutant against the fixed suites.

## The review fixes: the pure core

### M3S1-F1: H and R rows assert a guarded (answered X) value
- Guards: every R and H row; the six "H ends mid-shape" rows.
- Mutation: shape-nobound-literal (literal's (<= (+ i m) n) removed).
- Result: FAIL H ,p=1 with no $; the prefix only; the empty hash; a hash shorter than the prefix; ends mid-shape: empty, after v=19, after m=8, after t=1 (actual (raised)).
- Clean rerun: pass 68, fail 0.
- Mutation: shape-nobound-digits (digits' (< j n) removed).
- Result: FAIL ends mid-shape: after v=19, m=8, t=1, v=, m=.
- Clean rerun: pass 68.
- Mutation: shape-noprefix-guard ((and prefix ...) removed).
- Result: FAIL H a #f prefix; H a #f prefix is not an empty one.
- Clean rerun: pass 68.

### M3S1-F6: no-copy rows
- Guards: S string-append only in a non-procedure -message definition; S forbidden list (extended); S every symbol the body references, whole.
- Mutation: msg-lambda (copy-message bound to a lambda).
- Result: FAIL S string-append appears only in a top-level -message definition; FAIL S every symbol ... whole.
- Mutation: plant-string-copy (a (let ((string-copy! 1)) string-copy!) in the library).
- Result: FAIL S the library holds no copying or encoding primitive; FAIL S every symbol ... whole.
- Clean rerun: pass 68.

### M3S1-F11: no libsodium after the three calls
- Guards: "no libsodium is loaded after calling all three".
- Mutation: plant-native (suite imports (chez-sodium private native) and calls (sodium-init)).
- Result: FAIL no libsodium is loaded after calling all three (actual (answered #t)).
- Clean rerun: pass 68.

## The review fixes: native, the oracle and the blocks

Each mutant is a whole copy under build/m3s1-fix-load/<name>/, run at 1.0.22; the real tree passes.

### utf8-snapshot
- Guards: test-native "E13 ... mention exactly the symbols of their allow-lists, whole"
- Mutation: call-with-utf8 copies STRING into a make-string / string-set! snapshot first
- Result: that row fails (109 pass, 1 fail)
- Clean rerun: test-native 110 pass, 0 fail

### cstr-copy
- Guards: the same E13 row
- Mutation: call-with-c-string takes (string-length (string-copy string))
- Result: that row fails (109 pass, 1 fail)
- Clean rerun: 110 pass

### hex-noline
- Guards: both hex-mode rows of test-native (the verdict must be (valgrind . yes|no))
- Mutation: the oracle's hash mode prints no (valgrind . ...) line
- Result: "the oracle's hex mode hashes ... every run under Valgrind exactly when the gate asked" and "the oracle's hex mode: a hash of "a" ... " fail (108 pass, 2 fail)
- Clean rerun: 110 pass

### hex-no (under the gate: make test-memory MEMORY_SUITES=tests/test-native.sps, in the copy)
- Guards: the same two rows
- Mutation: the oracle's hex mode prints (valgrind . no) always
- Result: both rows fail under the gate (actual verdict ((valgrind . no)), expected ((valgrind . yes))); 107 pass, 2 fail
- Clean rerun: make test-memory of the three suites, pass

### ascii-high-anywhere
- Guards: test-blocks "foreign-ascii-string reads a 93-character hash string out of a 128-byte block that holds A5 after its 0, whole"
- Mutation: foreign-ascii-string answers #f for a byte of 0x80 or more anywhere within N
- Result: that row fails (34 pass, 1 fail)
- Clean rerun: test-blocks 35 pass

### cstr-shows-value
- Guards: test-blocks "a refusal of a secret string holds no part of it, at any depth ..."
- Mutation: call-with-c-string refuses a non-string with (shown-value string) as an irritant, no refuse-secret
- Result: that row fails, with "the writers refuse before any block" and the new c-string order row (32 pass, 3 fail)
- Clean rerun: 35 pass

### cstr-order
- Guards: test-blocks "call-with-c-string checks in order ..."
- Mutation: call-with-c-string checks CHANGED before PROC
- Result: that row fails (34 pass, 1 fail)
- Clean rerun: 35 pass

### prefix-mutable
- Guards: test-native "native's pwhash-strprefix is an immutable string, or #f for NULL ..."
- Mutation: the recorded prefix is the plain string, no string->immutable-string
- Result: that row fails (109 pass, 1 fail)
- Clean rerun: 110 pass

### seam-unlisted
- Guards: make check-seam and test-check-seam's allowed-chez-names rows
- Mutation: tests/check-seam.sps without string->immutable-string in allowed-chez-names
- Result: make check-seam refuses native's import; test-check-seam 5 rows fail (86 pass, 5 fail)
- Clean rerun: make check-seam passes (12 libraries), test-check-seam 91 pass

## The review fixes: the decoy

Each mutant is a whole copy under build/m3s1-fix-decoy/NAME/, run from inside it with --libdirs src:tests:../../scheme-libs.

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-str-fails'
- Mutation: copy build/m3s1-fix-decoy/str-fails-wrong: tests/decoy-libsodium.c answers 2, not -1, under pwhash-str-fails
- Result: 1 failure: password entries under "pwhash-str-fails"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-str-other'
- Mutation: str-other-wrong: crypto_pwhash_str answers 2, not 1, under pwhash-str-other
- Result: 1 failure: under "pwhash-str-other"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-str-unreadable'
- Mutation: unreadable-writes-hash: the unreadable switch writes the hash string and 0 as the control does
- Result: 1 failure: under "pwhash-str-unreadable"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-limits-other'
- Mutation: size-fixed-128: crypto_pwhash_str's A5 span is 128 bytes whatever the switch
- Result: 1 failure: under "pwhash-limits-other"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-limits-other'
- Mutation: other-hash-shorter: pwhash-limits-other's string 139 characters, its static assert changed to match
- Result: 1 failure: under "pwhash-limits-other"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'verify-other'
- Mutation: verify-other-0: crypto_pwhash_str_verify answers 0 under verify-other
- Result: 1 failure: under "verify-other"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-blocks'
- Mutation: blocks-unset-answers-1: hold_on_fifo answers 1 when CHEZ_SODIUM_DECOY_FIFO is unset
- Result: 1 failure: under "pwhash-blocks"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row 'pwhash-blocks'
- Mutation: blocks-writes-anyway: crypto_pwhash_str ignores hold_on_fifo's refusal and writes its string
- Result: 1 failure: under "pwhash-blocks" (the out block no longer 11)
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, row strprefix-null (--constants)
- Mutation: strprefix-null-ignored: crypto_pwhash_strprefix answers the prefix under strprefix-null
- Result: 1 failure: decoy control under "strprefix-null"
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, every entries row (growth)
- Mutation: verify-log-drops-len: the verify log line counts passwdlen + 1
- Result: 7 failures: all seven entries rows (control, pwhash-limits-other, -str-fails, -str-other, -str-unreadable, verify-other, pwhash-blocks)
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

- Guards: tests/test-library-loading-password-entries.sps, every entries row (rehash)
- Mutation: rehash-other: crypto_pwhash_str_needs_rehash answers 1
- Result: 7 failures: the same seven entries rows
- Clean rerun: the real files pass (13 of 13 at 1.0.22 and at the floor).

## The caller, after the fixes

### unreadable-has-a-0

- Guards: `test-library-loading-password-entries`' rows
- Mutation: the decoy writes a 0 into the last byte of `out` after its `A5` fill
- Result: every row that counts `A5` fails, the control and `pwhash-limits-other` among them
- Clean rerun: the real files pass

### review mutants against the fixed suites

- Guards: `test-password-text`, `test-native` and `test-blocks`
- Mutation: each of the review's mutant copies, with the fixed suites copied in
- Result: `shape-nobound-literal` 8 rows fail, `shape-nobound-digits` 5, `shape-noprefix-guard` 2, `msg-lambda` 2, `utf8-snapshot` 2, `ascii-high-anywhere` 1, `cstr-order` 1, `cstr-shows-value` 3
- Clean rerun: the real files pass: 68, 110 and 35, at 1.0.22 and at the floor
