#include <sodium.h>
#include <stdio.h>
#include <stdint.h>
static char calls[256];
int crypto_generichash(unsigned char *out, size_t outlen, const unsigned char *in, unsigned long long inlen, const unsigned char *key, size_t keylen)
{ volatile uintptr_t p = (uintptr_t) key; snprintf(calls, sizeof calls, "gh(key=%s,%zu,%llu,%zu)", p ? "p" : "NULL", outlen, inlen, keylen); (void) out; (void) in; return 0; }
