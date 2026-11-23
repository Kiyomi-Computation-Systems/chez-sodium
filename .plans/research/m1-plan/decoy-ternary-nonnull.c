/* P-F7 again, on functions sodium.h marks nonnull: randombytes_buf and
   crypto_pwhash_str, logged as chez-sqlite3's decoy logs a pointer. */
#include <sodium.h>
#include <stdio.h>
static char calls[256];
void randombytes_buf(void * const buf, const size_t size)
{
  snprintf(calls, sizeof calls, "randombytes_buf(%s,%zu)", buf ? "p" : "NULL", size);
}
const char *decoy_calls(void) { return calls; }
