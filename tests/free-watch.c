/* tests/free-watch.c: an LD_PRELOAD interposer of free(), for the rows that
 * hold every block the library frees to have been wiped first
 * (tests/test-wipe.sps).
 *
 *   watch_reset()        forgets every name
 *   watch_set(PTR, N)    appends a name: a block, and how many bytes of it to
 *                        read when it is freed. Names are kept in the order
 *                        given, with their lengths
 *   watch_count()        how many names since the reset
 *   watch_length(I)      name I's length, or -1 where I is not a name
 *   watch_verdict(I)     name I's verdict:
 *                        0  the block has not been freed yet
 *                        1  it was freed, and all N bytes read zero
 *                        2  it was freed holding a non-zero byte
 *                        -1 I is not a name, or it is past the table
 *
 * Every free() in the process comes here. Each name whose pointer is the one
 * freed, and that has not been freed yet, has its N bytes read before the
 * real free runs, through a volatile pointer so that the reads stay, and
 * keeps its verdict. A block freed unwiped reads 2 and one still live reads
 * 0: the rows show both, so a verdict of 1 is never a witness that cannot say
 * otherwise. A name of length 0 reads 1 whatever happens: no byte is read.
 *
 * The table holds WATCH_MAX names; more are counted, and answer -1.
 *
 * The test compiles it with -Wall -Werror -shared -fPIC, and links no library
 * but libdl. LD_PRELOAD makes it the process's free, and the program loads
 * the same file by path to reach its functions. The decoy
 * (tests/decoy-libsodium.c) reaches watch_set through a weak symbol: it
 * resolves only in a process this is preloaded in.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>

#define WATCH_MAX 256

static void (*real_free)(void *) = 0;

static struct {
  void *ptr;
  size_t n;
  int verdict;
} names[WATCH_MAX];
static size_t count = 0;

void watch_reset(void)
{
  size_t i;
  for (i = 0; i < WATCH_MAX; i++) {
    names[i].ptr = 0;
    names[i].n = 0;
    names[i].verdict = 0;
  }
  count = 0;
}

void watch_set(void *p, size_t n)
{
  if (count < WATCH_MAX) {
    names[count].ptr = p;
    names[count].n = n;
    names[count].verdict = 0;
  }
  count++;
}

int watch_count(void)
{
  return (int) count;
}

long watch_length(int i)
{
  return (i >= 0 && (size_t) i < count && (size_t) i < WATCH_MAX) ? (long) names[i].n : -1;
}

int watch_verdict(int i)
{
  return (i >= 0 && (size_t) i < count && (size_t) i < WATCH_MAX) ? names[i].verdict : -1;
}

void free(void *p)
{
  size_t k;
  if (!real_free)
    real_free = (void (*)(void *)) dlsym(RTLD_NEXT, "free");
  if (p) {
    for (k = 0; k < count && k < WATCH_MAX; k++) {
      if (names[k].ptr == p && names[k].verdict == 0) {
        const volatile unsigned char *b = (const volatile unsigned char *) p;
        size_t i;
        int nonzero = 0;
        for (i = 0; i < names[k].n; i++)
          if (b[i]) {
            nonzero = 1;
            break;
          }
        names[k].verdict = nonzero ? 2 : 1;
      }
    }
  }
  real_free(p);
}
