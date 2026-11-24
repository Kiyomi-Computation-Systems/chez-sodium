#include <sodium.h>
#include <stdio.h>
static char calls[256];
int crypto_generichash(unsigned char *out, size_t outlen, const unsigned char *in, unsigned long long inlen, const unsigned char *key, size_t keylen)
{ snprintf(calls, sizeof calls, "gh(in=%s,%zu,%llu,%zu)", in ? "p" : "NULL", outlen, inlen, keylen); (void) out; (void) key; return 0; }
