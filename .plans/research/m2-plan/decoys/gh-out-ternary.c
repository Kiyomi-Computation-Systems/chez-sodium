#include <sodium.h>
#include <stdio.h>
static char calls[256];
int crypto_generichash(unsigned char *out, size_t outlen, const unsigned char *in, unsigned long long inlen, const unsigned char *key, size_t keylen)
{ snprintf(calls, sizeof calls, "gh(out=%s,%zu,%llu,%zu)", out ? "p" : "NULL", outlen, inlen, keylen); (void) in; (void) key; return 0; }
