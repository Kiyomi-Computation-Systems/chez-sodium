/* The decoy's rule (brief 7.2, P-F7): each pointer is logged through a
   volatile uintptr_t, so neither -Werror=nonnull-compare nor GCC's
   deletion of a test sodium.h says cannot fail touches it. This build
   also answers sodium_init from DECOY_INIT and its version from
   DECOY_VERSION, and logs every call. */
#include <sodium.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
static char calls[1024];
static void called(const char *entry)
{
  size_t used = strlen(calls);
  snprintf(calls + used, sizeof calls - used, "%s%s", used ? " " : "", entry);
}
void sodium_memzero(void * const pnt, const size_t len)
{
  volatile uintptr_t p = (uintptr_t) pnt;
  char entry[96];
  snprintf(entry, sizeof entry, "sodium_memzero(%s,%zu)", p ? "p" : "NULL", len);
  called(entry);
  if (p) memset((void *) p, 0, len);
}
int sodium_init(void) { called("sodium_init"); return DECOY_INIT; }
const char *sodium_version_string(void) { called("sodium_version_string"); return DECOY_VERSION; }
int sodium_library_version_major(void) { called("sodium_library_version_major"); return 26; }
int sodium_library_version_minor(void) { called("sodium_library_version_minor"); return 4; }
const char *decoy_calls(void) { return calls; }
