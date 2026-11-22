/* LD_PRELOAD oracle: interposes free(), and when the pointer freed is the
   one watched, records whether its N bytes were all zero at the free.
   0 = not freed yet, 1 = freed all zero, 2 = freed holding a non-zero byte. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
static void (*real_free)(void *) = 0;
static void *watched = 0;
static size_t watched_n = 0;
static volatile int verdict = 0;
void watch_set(void *p, size_t n) { watched = p; watched_n = n; verdict = 0; }
int watch_verdict(void) { return verdict; }
void free(void *p) {
  if (!real_free) real_free = (void (*)(void *)) dlsym(RTLD_NEXT, "free");
  if (p && p == watched) {
    const unsigned char *b = p; size_t i; int nz = 0;
    for (i = 0; i < watched_n; i++) if (b[i]) { nz = 1; break; }
    verdict = nz ? 2 : 1;
    watched = 0;
  }
  real_free(p);
}
