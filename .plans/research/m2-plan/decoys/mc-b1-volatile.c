#include <sodium.h>
#include <stdio.h>
#include <stdint.h>
static char calls[256];
int sodium_memcmp(const void * const b1, const void * const b2, size_t len)
{ volatile uintptr_t p = (uintptr_t) b1; snprintf(calls, sizeof calls, "memcmp(b1=%s,%zu)", p ? "p" : "NULL", len); (void) b2; return 0; }
