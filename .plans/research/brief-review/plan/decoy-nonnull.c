/* Does a decoy that includes sodium.h, defines a nonnull-attributed
   function with the header's prototype, and logs its pointer arguments as
   chez-sqlite3's decoy does (p ? "p" : "NULL"), compile under -Wall -Werror? */
#include <stdio.h>
#include <sodium.h>
static char calls[256];
int crypto_pwhash_str(char out[crypto_pwhash_STRBYTES], const char *const passwd,
                      unsigned long long passwdlen, unsigned long long opslimit, size_t memlimit)
{
  snprintf(calls, sizeof calls, "crypto_pwhash_str(%s,%s,%llu,%llu,%zu)", out ? "out" : "NULL",
           passwd ? "passwd" : "NULL", passwdlen, opslimit, memlimit);
  return -1;
}
int sodium_init(void) { return 1; }
const char *decoy_calls(void) { return calls; }
