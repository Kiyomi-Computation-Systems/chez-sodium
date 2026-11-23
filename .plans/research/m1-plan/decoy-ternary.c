/* chez-sqlite3's decoy logs a pointer as p ? "p" : "NULL". Against
   sodium.h's nonnull attributes, under -Wall -Werror, this must fail. */
#include <sodium.h>
#include <stdio.h>
static char calls[256];
void sodium_memzero(void * const pnt, const size_t len)
{
  snprintf(calls, sizeof calls, "sodium_memzero(%s,%zu)", pnt ? "p" : "NULL", len);
}
const char *decoy_calls(void) { return calls; }
