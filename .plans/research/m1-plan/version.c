/* What libsodium answers for the load's entry points, in C, linked by path.
   Usage: cc -Wall -Werror version.c -o version -lsodium && ./version */
#include <sodium.h>
#include <stdio.h>
#include <string.h>
int main(void)
{
  unsigned char block[32];
  size_t i;
  int nonzero = 0, first, second, third;
  printf("before init: version_string=\"%s\" major=%d minor=%d minimal=%d\n",
         sodium_version_string(), sodium_library_version_major(),
         sodium_library_version_minor(), sodium_library_minimal());
  printf("header: SODIUM_VERSION_STRING=\"%s\" MAJOR=%d MINOR=%d\n", SODIUM_VERSION_STRING,
         SODIUM_LIBRARY_VERSION_MAJOR, SODIUM_LIBRARY_VERSION_MINOR);
  first = sodium_init();
  second = sodium_init();
  third = sodium_init();
  printf("sodium_init: first=%d second=%d third=%d\n", first, second, third);
  memset(block, 0x41, sizeof block);
  sodium_memzero(block, sizeof block);
  for (i = 0; i < sizeof block; i++) if (block[i]) nonzero = 1;
  printf("sodium_memzero over 32 bytes of 0x41: %s\n", nonzero ? "non-zero byte left" : "all zero");
  sodium_memzero(block, 0);
  printf("sodium_memzero with length 0: returned\n");
  return 0;
}
