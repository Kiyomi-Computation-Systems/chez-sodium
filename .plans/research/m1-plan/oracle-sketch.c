/* A sketch of libsodium-oracle's load mode: dlopen PATH exactly, dlsym
   each function on that handle alone, typed by __typeof__, and print
   Scheme data. Usage: oracle-sketch PATH */
#include <dlfcn.h>
#include <stdio.h>
#include <sodium.h>
#define FIND(var, name) \
  __typeof__(&name) var = (__typeof__(&name)) dlsym(lib, #name); \
  if (!var) { fprintf(stderr, "oracle: %s lacks %s\n", argv[1], #name); return 1; }
int main(int argc, char **argv)
{
  void *lib;
  if (argc != 2) { fprintf(stderr, "usage: oracle-sketch PATH\n"); return 2; }
  lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!lib) { fprintf(stderr, "oracle: %s\n", dlerror()); return 1; }
  {
    FIND(version, sodium_version_string)
    FIND(major, sodium_library_version_major)
    FIND(minor, sodium_library_version_minor)
    FIND(init, sodium_init)
    printf("(version . \"%s\")\n(major . %d)\n(minor . %d)\n", version(), major(), minor());
    {
      int first = init();
      int second = init();
      printf("(init %d %d)\n", first, second);
    }
  }
  return 0;
}
