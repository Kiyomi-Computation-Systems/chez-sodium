/* tests/free-watch.c: an LD_PRELOAD interposer of free(), for the one row
 * that holds every block the library frees to have been wiped first
 * (tests/test-wipe.sps).
 *
 *   watch_set(PTR, N)    names a block, and how many bytes of it to read
 *   watch_verdict()      0  the named block has not been freed yet
 *                        1  it was freed, and all N bytes read zero
 *                        2  it was freed holding a non-zero byte
 *
 * Every free() in the process comes here. When the pointer freed is the one
 * watched, its N bytes are read before the real free runs, through a
 * volatile pointer so that the reads stay, and the verdict is kept. watch_set
 * clears the verdict. A block freed unwiped reads 2, and one still live reads
 * 0: the row shows both, so a verdict of 1 is never a witness that cannot say
 * otherwise.
 *
 * The test compiles it with -Wall -Werror -shared -fPIC, and links no library
 * but libdl. LD_PRELOAD makes it the process's free, and the program loads
 * the same file by path to reach its two functions.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>

static void (*real_free)(void *) = 0;
static void *watched = 0;
static size_t watched_n = 0;
static volatile int verdict = 0;

void watch_set(void *p, size_t n)
{
  watched = p;
  watched_n = n;
  verdict = 0;
}

int watch_verdict(void)
{
  return verdict;
}

void free(void *p)
{
  if (!real_free)
    real_free = (void (*)(void *)) dlsym(RTLD_NEXT, "free");
  if (p && p == watched) {
    const volatile unsigned char *b = (const volatile unsigned char *) p;
    size_t i;
    int nonzero = 0;
    for (i = 0; i < watched_n; i++)
      if (b[i]) {
        nonzero = 1;
        break;
      }
    verdict = nonzero ? 2 : 1;
    watched = 0;
  }
  real_free(p);
}
