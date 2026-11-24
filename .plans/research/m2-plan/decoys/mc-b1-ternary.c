#include <sodium.h>
#include <stdio.h>
static char calls[256];
int sodium_memcmp(const void * const b1, const void * const b2, size_t len)
{ snprintf(calls, sizeof calls, "memcmp(b1=%s,%zu)", b1 ? "p" : "NULL", len); (void) b2; return 0; }
