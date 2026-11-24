#include <sodium.h>
/* the header spells str as an array at 1.0.18 (-DSTR_ARRAY) and as a pointer at 1.0.22 */
#ifdef STR_ARRAY
#define STR_PARAM const char str[crypto_pwhash_STRBYTES]
#else
#define STR_PARAM const char *str
#endif
#include <stdio.h>
#include <stdint.h>
static char calls[256];
int crypto_pwhash_str_needs_rehash(STR_PARAM, unsigned long long opslimit, size_t memlimit)
{ volatile uintptr_t p = (uintptr_t) str; snprintf(calls, sizeof calls, "rehash-str(%s)", p ? "p" : "NULL"); (void) opslimit; (void) memlimit; return 0; }
