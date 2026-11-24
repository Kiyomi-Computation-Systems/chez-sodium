/* tests/decoy-libsodium.c: a stand-in libsodium, for the
 * tests/test-library-loading-*.sps suites only, through
 * tests/library-loading.sls. chez-sodium itself compiles no C (ADR-0001).
 *
 * The suite compiles this file at test time, once per build below, as a
 * shared object (-Wall -Werror -shared -fPIC), and points
 * CHEZ_SODIUM_LIBRARY at it, so each refusal of the load can be watched
 * firing by name. It includes sodium.h, so every function it defines has
 * the header's own prototype: a definition that disagrees fails the compile,
 * and the suite with it, never a skip (ADR-0001).
 *
 * It states no version of its own. The suite passes the floor, read from
 * packaging/floors.sexp, and the version one below it (ADR-0011):
 *
 *   -DDECOY_VERSION="T" -DDECOY_BELOW="T-1"
 *
 * Builds, chosen at compile time, since what a library exports is fixed
 * when it is linked and no switch read at run time can hide an entry point
 * from dlsym:
 *
 *   (none)                   the control: the thirteen entry points
 *                            (chez-sodium private native) binds
 *   DECOY_LACKS_<entry>      that one entry point left out
 *   DECOY_NOT_SODIUM         no sodium_*, randombytes_* or crypto_* function
 *                            at all
 *   DECOY_MARKER             also defines decoy_marker, which no other
 *                            build has: whether a process ever loaded this
 *                            build is foreign-entry?'s answer for it
 *
 * Behaviour, chosen at run time by CHEZ_SODIUM_DECOY, read once, when the
 * library is loaded, and compared whole:
 *
 *   unset              the control: at the floor, libtool 10.3, and
 *                      sodium_init answers 0
 *   below-floor        the version one below the floor
 *   version-null       sodium_version_string answers NULL
 *   version-malformed  the floor's text followed by "-stable"
 *   version-bom        the floor's text after a UTF-8 byte order mark
 *   libtool-high       the version below the floor, libtool 99.99
 *   libtool-low        the floor, libtool 0.0
 *   init-fails         sodium_init answers -1
 *   init-other         sodium_init answers 2, a second code, so that no
 *                      single value passes for "refused"
 *   init-already       sodium_init answers 1, which loads
 *   sizes-other        crypto_generichash's five size functions answer 33,
 *                      8, 80, 9 and 81, which no release does (the control's
 *                      are 32, 16, 64, 16 and 64)
 *   generichash-fails  crypto_generichash answers -1
 *   generichash-other  crypto_generichash answers 1, a second code
 *   memcmp-other       sodium_memcmp answers 1 for equal operands, -1 for
 *                      different ones (the control's are 0 and -1); at
 *                      length 0 it answers 0, and with exactly one NULL
 *                      operand at a nonzero length -1, under every switch
 *   anything else      the control's behaviour, an empty value included
 *
 * The call log. Loading the library writes its first entry, decoy(SWITCH):
 * decoy(control) when the variable is unset, decoy(?VALUE) for a value not
 * listed above. Then every sodium_*, randombytes_* and crypto_* function
 * appends one entry, its name and its arguments, as it is called, with p
 * for a pointer and NULL for NULL. decoy_calls() returns the log, entries
 * separated by one space. The suite asserts it whole, so the log holds which
 * switch the library read, the load's order, and that nothing runs after a
 * refusal. A log too full for the next entry ends in one overflow entry and
 * takes nothing more, so a long run cannot pass for a short one.
 *
 * randombytes_buf and crypto_generichash write the byte A5 over every byte
 * of their output, under every switch, so that a block they fill is never
 * zero before its wipe.
 *
 * Every pointer it logs is read through a volatile uintptr_t, and only that
 * is tested, logged and written through, whether or not sodium.h marks the
 * parameter nonnull: a plain test of a nonnull parameter fails
 * -Werror=nonnull-compare, and the compiler may delete it (ADR-0011).
 * tests/test-decoy-source.sps holds every sodium_*, randombytes_* and
 * crypto_* function here to that; the helpers called and decoy_calls are
 * outside it.
 */
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sodium.h>

#if !defined(DECOY_VERSION) || !defined(DECOY_BELOW)
#error "tests/library-loading.sls passes the floor and the version below it: -DDECOY_VERSION and -DDECOY_BELOW"
#endif

static char calls[4096];
static int overflowed = 0;

#define DECOY_OVERFLOW " overflow"

/* called: appends one entry, printf-style, to the call log. An entry that
   would leave no room for the overflow entry is not written: the log ends
   in overflow instead, and takes nothing more. */
static void called(const char *format, ...)
{
  char entry[512];
  size_t used = strlen(calls);
  size_t room = sizeof calls - sizeof DECOY_OVERFLOW;
  int length;
  va_list args;
  if (overflowed)
    return;
  va_start(args, format);
  length = vsnprintf(entry, sizeof entry, format, args);
  va_end(args);
  if (length < 0 || (size_t) length >= sizeof entry
      || used + (used > 0 ? 1 : 0) + (size_t) length > room) {
    memcpy(calls + used, DECOY_OVERFLOW, sizeof DECOY_OVERFLOW);
    overflowed = 1;
    return;
  }
  if (used > 0)
    calls[used++] = ' ';
  memcpy(calls + used, entry, (size_t) length + 1);
}

/* decoy_calls: the call log. Not a libsodium name, so a real libsodium
   lacks it. */
const char *decoy_calls(void)
{
  return calls;
}

#ifdef DECOY_MARKER
/* decoy_marker: present only in a build with DECOY_MARKER. */
int decoy_marker(void)
{
  return 1;
}
#endif

enum decoy_switch {
  CONTROL,
  BELOW_FLOOR,
  VERSION_NULL,
  VERSION_MALFORMED,
  VERSION_BOM,
  LIBTOOL_HIGH,
  LIBTOOL_LOW,
  INIT_FAILS,
  INIT_OTHER,
  INIT_ALREADY,
  SIZES_OTHER,
  GENERICHASH_FAILS,
  GENERICHASH_OTHER,
  MEMCMP_OTHER
};

static const struct {
  const char *name;
  enum decoy_switch which;
} switches[] = {
  {"below-floor", BELOW_FLOOR},
  {"version-null", VERSION_NULL},
  {"version-malformed", VERSION_MALFORMED},
  {"version-bom", VERSION_BOM},
  {"libtool-high", LIBTOOL_HIGH},
  {"libtool-low", LIBTOOL_LOW},
  {"init-fails", INIT_FAILS},
  {"init-other", INIT_OTHER},
  {"init-already", INIT_ALREADY},
  {"sizes-other", SIZES_OTHER},
  {"generichash-fails", GENERICHASH_FAILS},
  {"generichash-other", GENERICHASH_OTHER},
  {"memcmp-other", MEMCMP_OTHER},
};

static enum decoy_switch mode = CONTROL;

/* decoy_load: reads CHEZ_SODIUM_DECOY once, when the library is loaded,
   and logs what it read. */
__attribute__((constructor)) static void decoy_load(void)
{
  const char *value = getenv("CHEZ_SODIUM_DECOY");
  size_t i;
  if (!value) {
    called("decoy(control)");
    return;
  }
  for (i = 0; i < sizeof switches / sizeof switches[0]; i++) {
    if (strcmp(value, switches[i].name) == 0) {
      mode = switches[i].which;
      called("decoy(%s)", value);
      return;
    }
  }
  called("decoy(?%s)", value);
}

#ifndef DECOY_NOT_SODIUM

#ifndef DECOY_LACKS_sodium_version_string
const char *sodium_version_string(void)
{
  called("sodium_version_string()");
  switch (mode) {
  case BELOW_FLOOR:
  case LIBTOOL_HIGH:
    return DECOY_BELOW;
  case VERSION_NULL:
    return NULL;
  case VERSION_MALFORMED:
    return DECOY_VERSION "-stable";
  case VERSION_BOM:
    /* Two literals: a hex escape reads every hex digit after it. */
    return "\xEF\xBB\xBF" DECOY_VERSION;
  default:
    return DECOY_VERSION;
  }
}
#endif

/* The libtool numbers: 10.3 apart from the two switches, different from
   each other, so a swap shows. They are never compared (ADR-0003). */
#ifndef DECOY_LACKS_sodium_library_version_major
int sodium_library_version_major(void)
{
  called("sodium_library_version_major()");
  return mode == LIBTOOL_HIGH ? 99 : mode == LIBTOOL_LOW ? 0 : 10;
}
#endif

#ifndef DECOY_LACKS_sodium_library_version_minor
int sodium_library_version_minor(void)
{
  called("sodium_library_version_minor()");
  return mode == LIBTOOL_HIGH ? 99 : mode == LIBTOOL_LOW ? 0 : 3;
}
#endif

#ifndef DECOY_LACKS_sodium_init
int sodium_init(void)
{
  called("sodium_init()");
  return mode == INIT_FAILS ? -1 : mode == INIT_OTHER ? 2 : mode == INIT_ALREADY ? 1 : 0;
}
#endif

#ifndef DECOY_LACKS_sodium_memzero
/* Logs its call, then zeroes what it was given, so that a decoy that holds
   a wipe wipes. Nothing is written for a NULL address. */
void sodium_memzero(void *const pnt, const size_t len)
{
  volatile uintptr_t p = (uintptr_t) pnt;
  volatile unsigned char *bytes = (volatile unsigned char *) p;
  size_t i;
  called("sodium_memzero(%s,%zu)", p ? "p" : "NULL", len);
  if (p)
    for (i = 0; i < len; i++)
      bytes[i] = 0;
}
#endif

#ifndef DECOY_LACKS_randombytes_buf
/* Logs its call, then writes A5 over every byte of BUF. Nothing is written
   for a NULL address. */
void randombytes_buf(void *const buf, const size_t size)
{
  volatile uintptr_t p = (uintptr_t) buf;
  volatile unsigned char *bytes = (volatile unsigned char *) p;
  size_t i;
  called("randombytes_buf(%s,%zu)", p ? "p" : "NULL", size);
  if (p)
    for (i = 0; i < size; i++)
      bytes[i] = 0xA5;
}
#endif

#ifndef DECOY_LACKS_crypto_generichash
/* Logs its call, writes A5 over every byte of OUT under every switch, and
   answers 0, or -1 and 1 under the two switches. */
int crypto_generichash(unsigned char *out, size_t outlen,
                       const unsigned char *in, unsigned long long inlen,
                       const unsigned char *key, size_t keylen)
{
  volatile uintptr_t o = (uintptr_t) out;
  volatile uintptr_t i = (uintptr_t) in;
  volatile uintptr_t k = (uintptr_t) key;
  volatile unsigned char *bytes = (volatile unsigned char *) o;
  size_t n;
  called("crypto_generichash(%s,%zu,%s,%llu,%s,%zu)",
         o ? "p" : "NULL", outlen, i ? "p" : "NULL", inlen, k ? "p" : "NULL", keylen);
  if (o)
    for (n = 0; n < outlen; n++)
      bytes[n] = 0xA5;
  return mode == GENERICHASH_FAILS ? -1 : mode == GENERICHASH_OTHER ? 1 : 0;
}
#endif

/* The five sizes: the control's are 32, 16, 64, 16 and 64, and sizes-other's
   are 33, 8, 80, 9 and 81. */
#ifndef DECOY_LACKS_crypto_generichash_bytes
size_t crypto_generichash_bytes(void)
{
  called("crypto_generichash_bytes()");
  return mode == SIZES_OTHER ? 33 : 32;
}
#endif

#ifndef DECOY_LACKS_crypto_generichash_bytes_min
size_t crypto_generichash_bytes_min(void)
{
  called("crypto_generichash_bytes_min()");
  return mode == SIZES_OTHER ? 8 : 16;
}
#endif

#ifndef DECOY_LACKS_crypto_generichash_bytes_max
size_t crypto_generichash_bytes_max(void)
{
  called("crypto_generichash_bytes_max()");
  return mode == SIZES_OTHER ? 80 : 64;
}
#endif

#ifndef DECOY_LACKS_crypto_generichash_keybytes_min
size_t crypto_generichash_keybytes_min(void)
{
  called("crypto_generichash_keybytes_min()");
  return mode == SIZES_OTHER ? 9 : 16;
}
#endif

#ifndef DECOY_LACKS_crypto_generichash_keybytes_max
size_t crypto_generichash_keybytes_max(void)
{
  called("crypto_generichash_keybytes_max()");
  return mode == SIZES_OTHER ? 81 : 64;
}
#endif

#ifndef DECOY_LACKS_sodium_memcmp
/* At length 0 it answers 0, under every switch. At a nonzero length, with
   exactly one NULL address, it answers -1, under every switch: an operand
   that cannot be read is no match. Only two readable operands are compared,
   byte by byte: 0 when equal, -1 when they differ, and under memcmp-other 1
   and -1. */
int sodium_memcmp(const void *const b1, const void *const b2, size_t len)
{
  volatile uintptr_t p1 = (uintptr_t) b1;
  volatile uintptr_t p2 = (uintptr_t) b2;
  volatile const unsigned char *x = (volatile const unsigned char *) p1;
  volatile const unsigned char *y = (volatile const unsigned char *) p2;
  size_t i;
  int equal = 1;
  called("sodium_memcmp(%s,%s,%zu)", p1 ? "p" : "NULL", p2 ? "p" : "NULL", len);
  if (len == 0)
    return 0;
  if (!p1 || !p2)
    return -1;
  for (i = 0; i < len; i++)
    if (x[i] != y[i])
      equal = 0;
  if (mode == MEMCMP_OTHER)
    return equal ? 1 : -1;
  return equal ? 0 : -1;
}
#endif

#endif /* DECOY_NOT_SODIUM */
