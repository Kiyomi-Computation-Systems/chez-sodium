/* A C call that blocks for MS milliseconds, for probing collect-safety. */
#include <time.h>
void block_ms(int ms) {
  struct timespec t = { ms / 1000, (long) (ms % 1000) * 1000000L };
  while (nanosleep(&t, &t) != 0) { }
}
