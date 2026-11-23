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
 *   (none)                   the control: the five entry points
 *                            (chez-sodium private native) binds
 *   DECOY_LACKS_<entry>      that one entry point left out
 *   DECOY_NOT_SODIUM         no sodium_* function at all
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
 *   anything else      the control's behaviour, an empty value included
 *
 * The call log. Loading the library writes its first entry, decoy(SWITCH):
 * decoy(control) when the variable is unset, decoy(?VALUE) for a value not
 * listed above. Then every sodium_* function appends one entry, its name
 * and its arguments, as it is called. decoy_calls() returns the log,
 * entries separated by one space. The suite asserts it whole, so the log
 * holds which switch the library read, the load's order, and that nothing
 * runs after a refusal.
 *
 * Every pointer it logs is read through a volatile uintptr_t, and only that
 * is tested, whether or not sodium.h marks the parameter nonnull: a plain
 * test of a nonnull parameter fails -Werror=nonnull-compare, and the
 * compiler may delete it (ADR-0011).
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

/* called: appends one entry, printf-style, to the call log. */
static void called(const char *format, ...)
{
  size_t used = strlen(calls);
  va_list args;
  if (used > 0 && used + 1 < sizeof calls) {
    calls[used++] = ' ';
    calls[used] = '\0';
  }
  va_start(args, format);
  vsnprintf(calls + used, sizeof calls - used, format, args);
  va_end(args);
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
  INIT_ALREADY
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

#endif /* DECOY_NOT_SODIUM */
