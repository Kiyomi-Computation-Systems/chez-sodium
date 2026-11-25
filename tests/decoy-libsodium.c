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
 *   (none)                   the control: the thirty entry points
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
 *                      length 0 it answers 0, and with a NULL operand, one
 *                      or both, at a nonzero length -1, under every switch
 *   pwhash-limits-other  crypto_pwhash_strbytes answers 160, the opslimits 2 to
 *                      9 with the presets 5, 6 and 7, the memlimits 16384 to
 *                      1048576 with the presets 24576, 32768 and 40960, the
 *                      passwords 1 to 100, and crypto_pwhash_strprefix
 *                      "$argon2i$": none is a release's (the control's are
 *                      128; 1 to 4294967295, 2, 3 and 4; 8192 to 4398046510080,
 *                      64 MiB, 256 MiB and 1 GiB; 0 to 4294967295;
 *                      "$argon2id$"). crypto_pwhash_str writes a string of
 *                      140 characters, longer than the control's 128 bytes
 *   pwhash-limits-odd  every constant pwhash-limits-other answers, but the
 *                      memlimits: crypto_pwhash_memlimit_min answers 16385
 *                      and crypto_pwhash_memlimit_max 1048575 bytes, neither
 *                      a whole KiB
 *   pwhash-str-fails   crypto_pwhash_str answers -1
 *   pwhash-str-other   crypto_pwhash_str answers 1, a second code
 *   pwhash-str-unreadable
 *                      crypto_pwhash_str answers 0 and leaves its output all
 *                      A5, with no 0 in it
 *   pwhash-str-empty   crypto_pwhash_str answers 0 and leaves its output all
 *                      A5 but a 0 at index 0: an empty string
 *   verify-other       crypto_pwhash_str_verify answers 1, a second code
 *   strprefix-null     crypto_pwhash_strprefix answers NULL
 *   pwhash-blocks      crypto_pwhash_str and crypto_pwhash_str_verify each
 *                      first create the file named by CHEZ_SODIUM_DECOY_FIFO
 *                      with ".entered" added, then open the FIFO that
 *                      variable names, for reading, which blocks until a
 *                      writer opens it; read it to its end, close it, and
 *                      answer as the control does. With the variable unset
 *                      each answers -1 at once, and writes nothing
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
 * zero before its wipe. crypto_pwhash_str writes it over the decoy's own
 * strbytes of its output, then a fixed hash string and a 0: the control's of
 * 93 characters, pwhash-limits-other's of 140.
 *
 * A C string's pointer is logged as p[L], L its strlen, or NULL.
 *
 * Naming its blocks. randombytes_buf, crypto_generichash, sodium_memcmp and
 * the three password calls each hand every pointer they take, with the length
 * they take it with, in parameter order, to watch_set, when there is one (a
 * string's length is its strlen + 1, and crypto_pwhash_str's out is the
 * decoy's own strbytes): a weak symbol, which
 * tests/free-watch.c defines and no libsodium does. It resolves only in a
 * process that preloads that interposer, as tests/test-wipe.sps' second child
 * does; everywhere else it is NULL and nothing is named. That is how a block a
 * verb makes is reached from outside: the real library cannot be wrapped in
 * front of Chez's binding.
 *
 * Every pointer it logs is read through a volatile uintptr_t, and only that
 * is tested, logged and written through, whether or not sodium.h marks the
 * parameter nonnull: a plain test of a nonnull parameter fails
 * -Werror=nonnull-compare, and the compiler may delete it (ADR-0011).
 * tests/test-decoy-source.sps holds every sodium_*, randombytes_* and
 * crypto_* function here to that; the helpers called and decoy_calls are
 * outside it.
 *
 * crypto_pwhash_str_verify and crypto_pwhash_str_needs_rehash are each
 * defined twice, whole, because the header spells their str parameter as an
 * array in 1.0.18 (SODIUM_LIBRARY_VERSION_MAJOR 10) and as a pointer in
 * 1.0.22 (major 26), the two releases measured; releases between them are
 * not tested. A definition spelled otherwise fails -Werror=array-parameter. Each hands its volatile copy to one helper. Every
 * pointer of the three password calls is nonnull in the header.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
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
  MEMCMP_OTHER,
  PWHASH_LIMITS_OTHER,
  PWHASH_LIMITS_ODD,
  PWHASH_STR_FAILS,
  PWHASH_STR_OTHER,
  PWHASH_STR_UNREADABLE,
  PWHASH_STR_EMPTY,
  VERIFY_OTHER,
  STRPREFIX_NULL,
  PWHASH_BLOCKS
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
  {"pwhash-limits-other", PWHASH_LIMITS_OTHER},
  {"pwhash-limits-odd", PWHASH_LIMITS_ODD},
  {"pwhash-str-fails", PWHASH_STR_FAILS},
  {"pwhash-str-other", PWHASH_STR_OTHER},
  {"pwhash-str-unreadable", PWHASH_STR_UNREADABLE},
  {"pwhash-str-empty", PWHASH_STR_EMPTY},
  {"verify-other", VERIFY_OTHER},
  {"strprefix-null", STRPREFIX_NULL},
  {"pwhash-blocks", PWHASH_BLOCKS},
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

/* watch_set: defined by tests/free-watch.c when it is preloaded, NULL
   otherwise. */
extern void watch_set(void *, size_t) __attribute__((weak));

/* name_block: names the block at P, N bytes of it, to the interposer, when
   there is one. P is a volatile uintptr_t's value: the call goes through
   the copy, as everything else here does. */
static void name_block(uintptr_t p, size_t n)
{
  if (watch_set != NULL)
    watch_set((void *) p, n);
}

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
  name_block(p, size);
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
  name_block(o, outlen);
  name_block(i, (size_t) inlen);
  name_block(k, keylen);
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
   a NULL address, either or both, it answers -1, under every switch: an
   operand that cannot be read is no match. Only two readable operands are
   compared, byte by byte: 0 when equal, -1 when they differ, and under
   memcmp-other 1 and -1. */
int sodium_memcmp(const void *const b1, const void *const b2, size_t len)
{
  volatile uintptr_t p1 = (uintptr_t) b1;
  volatile uintptr_t p2 = (uintptr_t) b2;
  volatile const unsigned char *x = (volatile const unsigned char *) p1;
  volatile const unsigned char *y = (volatile const unsigned char *) p2;
  size_t i;
  int equal = 1;
  called("sodium_memcmp(%s,%s,%zu)", p1 ? "p" : "NULL", p2 ? "p" : "NULL", len);
  name_block(p1, len);
  name_block(p2, len);
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

/* --- the password hash ------------------------------------------------------- */

/* The fixed hash strings crypto_pwhash_str writes: a prefix, v=19, the
   parameters, a salt of 22 characters, a $ and a tag. The control's is 93
   characters, pwhash-limits-other's 140, which is longer than the control's
   128 bytes. */
#define CONTROL_HASH \
  "$argon2id$v=19$m=8,t=1,p=1$" "c2FsdHNhbHRzYWx0c2FsdA" "$" \
  "dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGE"
#define OTHER_HASH \
  "$argon2i$v=19$m=16,t=2,p=1$" "c2FsdHNhbHRzYWx0c2FsdA" "$" \
  "dGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndGFndG"

_Static_assert(sizeof CONTROL_HASH - 1 == 93, "the control's hash string is 93 characters");
_Static_assert(sizeof OTHER_HASH - 1 == 140, "pwhash-limits-other's hash string is 140 characters");

/* limits_other: whether the constants are pwhash-limits-other's (pwhash-limits-odd keeps all but the two memlimits). */
static int limits_other(void)
{
  return mode == PWHASH_LIMITS_OTHER || mode == PWHASH_LIMITS_ODD;
}

/* string_length: the strlen of the C string at P, read through a volatile
   pointer; 0 for NULL. */
static size_t string_length(uintptr_t p)
{
  volatile const char *s = (volatile const char *) p;
  size_t n = 0;
  if (!p)
    return 0;
  while (s[n] != 0)
    n++;
  return n;
}

/* show_string: writes the log's form of the C string at P into TEXT: p[L], or
   NULL. */
static void show_string(char *text, size_t room, uintptr_t p)
{
  if (p)
    snprintf(text, room, "p[%zu]", string_length(p));
  else
    snprintf(text, room, "NULL");
}

/* hold_on_fifo: under pwhash-blocks, creates the marker file, then opens the
   FIFO for reading, which blocks until a writer opens it (open is retried
   when a signal interrupts it), reads it to its end and closes it: 1. When
   the marker cannot be created, or the FIFO cannot be opened: 0, without
   opening the FIFO if it was the marker. With CHEZ_SODIUM_DECOY_FIFO unset:
   0, and nothing is done.
   In every other mode: 1, and nothing is done. */
static int hold_on_fifo(void)
{
  const char *fifo;
  char marker[4096];
  char buffer[64];
  int fd;
  ssize_t got;
  if (mode != PWHASH_BLOCKS)
    return 1;
  fifo = getenv("CHEZ_SODIUM_DECOY_FIFO");
  if (!fifo)
    return 0;
  if (snprintf(marker, sizeof marker, "%s.entered", fifo) >= (int) sizeof marker)
    return 0;
  fd = open(marker, O_WRONLY | O_CREAT, 0600);
  if (fd < 0)
    return 0;
  close(fd);
  do {
    fd = open(fifo, O_RDONLY);
  } while (fd < 0 && errno == EINTR);
  if (fd < 0)
    return 0;
  do {
    got = read(fd, buffer, sizeof buffer);
  } while (got > 0 || (got < 0 && errno == EINTR));
  close(fd);
  return 1;
}

#ifndef DECOY_LACKS_crypto_pwhash_str_verify
/* verify_answer: logs a crypto_pwhash_str_verify call and answers it. */
static int verify_answer(uintptr_t s, uintptr_t passwd, unsigned long long passwdlen)
{
  char shown[32];
  show_string(shown, sizeof shown, s);
  called("crypto_pwhash_str_verify(%s,%s,%llu)", shown, passwd ? "p" : "NULL", passwdlen);
  name_block(s, string_length(s) + 1);
  name_block(passwd, passwdlen > 1 ? (size_t) passwdlen : 1);
  if (!hold_on_fifo())
    return -1;
  return mode == VERIFY_OTHER ? 1 : 0;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_str_needs_rehash
/* rehash_answer: logs a crypto_pwhash_str_needs_rehash call and answers it. */
static int rehash_answer(uintptr_t s, unsigned long long opslimit, size_t memlimit)
{
  char shown[32];
  show_string(shown, sizeof shown, s);
  called("crypto_pwhash_str_needs_rehash(%s,%llu,%zu)", shown, opslimit, memlimit);
  name_block(s, string_length(s) + 1);
  return 0;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_str
/* Logs its call, writes A5 over the decoy's own strbytes of OUT, then the
   fixed hash string and a 0, and answers 0, -1 or 1 under the two switches.
   Under pwhash-str-unreadable it leaves OUT all A5 and answers 0, and under
   pwhash-str-empty all A5 but a 0 at index 0. Under
   pwhash-blocks it first waits on the FIFO. */
int crypto_pwhash_str(char out[crypto_pwhash_STRBYTES],
                      const char *const passwd, unsigned long long passwdlen,
                      unsigned long long opslimit, size_t memlimit)
{
  volatile uintptr_t o = (uintptr_t) out;
  volatile uintptr_t p = (uintptr_t) passwd;
  volatile unsigned char *bytes = (volatile unsigned char *) o;
  const char *hash = limits_other() ? OTHER_HASH : CONTROL_HASH;
  size_t size = limits_other() ? 160 : 128;
  size_t length = strlen(hash);
  size_t n;
  called("crypto_pwhash_str(%s,%s,%llu,%llu,%zu)", o ? "p" : "NULL", p ? "p" : "NULL",
         passwdlen, opslimit, memlimit);
  name_block(o, size);
  name_block(p, passwdlen > 1 ? (size_t) passwdlen : 1);
  if (!hold_on_fifo())
    return -1;
  if (o) {
    for (n = 0; n < size; n++)
      bytes[n] = 0xA5;
    if (mode == PWHASH_STR_EMPTY) {
      bytes[0] = 0;
    } else if (mode != PWHASH_STR_UNREADABLE) {
      for (n = 0; n < length; n++)
        bytes[n] = (unsigned char) hash[n];
      bytes[length] = 0;
    }
  }
  return mode == PWHASH_STR_FAILS ? -1 : mode == PWHASH_STR_OTHER ? 1 : 0;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_str_verify
/* Logs its call and answers 0, or 1 under verify-other. Defined twice, as the
   header spells str: an array at 1.0.18, a pointer at 1.0.22 (releases between
   are not tested). */
#if SODIUM_LIBRARY_VERSION_MAJOR < 26
int crypto_pwhash_str_verify(const char str[crypto_pwhash_STRBYTES],
                             const char *const passwd,
                             unsigned long long passwdlen)
{
  volatile uintptr_t s = (uintptr_t) str;
  volatile uintptr_t p = (uintptr_t) passwd;
  return verify_answer(s, p, passwdlen);
}
#else
int crypto_pwhash_str_verify(const char *str,
                             const char *const passwd,
                             unsigned long long passwdlen)
{
  volatile uintptr_t s = (uintptr_t) str;
  volatile uintptr_t p = (uintptr_t) passwd;
  return verify_answer(s, p, passwdlen);
}
#endif
#endif

#ifndef DECOY_LACKS_crypto_pwhash_str_needs_rehash
/* Logs its call and answers 0. Defined twice, as the header spells str. */
#if SODIUM_LIBRARY_VERSION_MAJOR < 26
int crypto_pwhash_str_needs_rehash(const char str[crypto_pwhash_STRBYTES],
                                   unsigned long long opslimit, size_t memlimit)
{
  volatile uintptr_t s = (uintptr_t) str;
  return rehash_answer(s, opslimit, memlimit);
}
#else
int crypto_pwhash_str_needs_rehash(const char *str,
                                   unsigned long long opslimit, size_t memlimit)
{
  volatile uintptr_t s = (uintptr_t) str;
  return rehash_answer(s, opslimit, memlimit);
}
#endif
#endif

#ifndef DECOY_LACKS_crypto_pwhash_strbytes
size_t crypto_pwhash_strbytes(void)
{
  called("crypto_pwhash_strbytes()");
  return limits_other() ? 160 : 128;
}
#endif

/* The prefix: "$argon2id$", "$argon2i$" under pwhash-limits-other, and NULL
   under strprefix-null. */
#ifndef DECOY_LACKS_crypto_pwhash_strprefix
const char *crypto_pwhash_strprefix(void)
{
  called("crypto_pwhash_strprefix()");
  if (mode == STRPREFIX_NULL)
    return NULL;
  return limits_other() ? "$argon2i$" : "$argon2id$";
}
#endif

/* The limits: the control's and pwhash-limits-other's. */
#ifndef DECOY_LACKS_crypto_pwhash_opslimit_min
size_t crypto_pwhash_opslimit_min(void)
{
  called("crypto_pwhash_opslimit_min()");
  return limits_other() ? 2 : 1;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_opslimit_max
size_t crypto_pwhash_opslimit_max(void)
{
  called("crypto_pwhash_opslimit_max()");
  return limits_other() ? 9 : 4294967295U;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_opslimit_interactive
size_t crypto_pwhash_opslimit_interactive(void)
{
  called("crypto_pwhash_opslimit_interactive()");
  return limits_other() ? 5 : 2;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_opslimit_moderate
size_t crypto_pwhash_opslimit_moderate(void)
{
  called("crypto_pwhash_opslimit_moderate()");
  return limits_other() ? 6 : 3;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_opslimit_sensitive
size_t crypto_pwhash_opslimit_sensitive(void)
{
  called("crypto_pwhash_opslimit_sensitive()");
  return limits_other() ? 7 : 4;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_memlimit_min
size_t crypto_pwhash_memlimit_min(void)
{
  called("crypto_pwhash_memlimit_min()");
  if (mode == PWHASH_LIMITS_ODD)
    return 16385;
  return limits_other() ? 16384 : 8192;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_memlimit_max
size_t crypto_pwhash_memlimit_max(void)
{
  called("crypto_pwhash_memlimit_max()");
  if (mode == PWHASH_LIMITS_ODD)
    return (size_t) 1048575;
  return limits_other() ? (size_t) 1048576 : (size_t) 4398046510080ULL;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_memlimit_interactive
size_t crypto_pwhash_memlimit_interactive(void)
{
  called("crypto_pwhash_memlimit_interactive()");
  return limits_other() ? 24576 : 67108864;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_memlimit_moderate
size_t crypto_pwhash_memlimit_moderate(void)
{
  called("crypto_pwhash_memlimit_moderate()");
  return limits_other() ? 32768 : 268435456;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_memlimit_sensitive
size_t crypto_pwhash_memlimit_sensitive(void)
{
  called("crypto_pwhash_memlimit_sensitive()");
  return limits_other() ? 40960 : 1073741824;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_passwd_min
size_t crypto_pwhash_passwd_min(void)
{
  called("crypto_pwhash_passwd_min()");
  return limits_other() ? 1 : 0;
}
#endif

#ifndef DECOY_LACKS_crypto_pwhash_passwd_max
size_t crypto_pwhash_passwd_max(void)
{
  called("crypto_pwhash_passwd_max()");
  return limits_other() ? 100 : 4294967295U;
}
#endif

#endif /* DECOY_NOT_SODIUM */
