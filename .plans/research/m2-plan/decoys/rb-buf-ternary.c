#include <sodium.h>
#include <stdio.h>
static char calls[256];
void randombytes_buf(void * const buf, const size_t size)
{ snprintf(calls, sizeof calls, "randombytes_buf(%s,%zu)", buf ? "p" : "NULL", size); }
