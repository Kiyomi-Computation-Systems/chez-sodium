#include <sodium.h>
#include <stdio.h>
#include <stdint.h>
static char calls[256];
void randombytes_buf(void * const buf, const size_t size)
{ volatile uintptr_t p = (uintptr_t) buf; snprintf(calls, sizeof calls, "randombytes_buf(%s,%zu)", p ? "p" : "NULL", size); }
