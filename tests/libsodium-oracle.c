/* tests/libsodium-oracle.c: what a libsodium says about itself, read in C,
 * for the suites that check what chez-sodium reports
 * (tests/libsodium-oracle.sls). chez-sodium itself compiles no C
 * (ADR-0001).
 *
 *   libsodium-oracle PATH
 *
 * It dlopens PATH, exactly as given, and finds each function it calls with
 * dlsym on that handle alone, never RTLD_DEFAULT: it links no libsodium, so
 * no other copy can answer. sodium.h is included for its prototypes alone,
 * found through C_INCLUDE_PATH or the system's include directory: each
 * pointer has the type the header gives the function, through __typeof__, so
 * the compile under -Werror holds the calls to the header's prototypes. It
 * prints, as Scheme data, one datum per line:
 *
 *   (version . "1.0.22")      sodium_version_string(), #f for NULL
 *   (major . 26)              sodium_library_version_major()
 *   (minor . 4)               sodium_library_version_minor()
 *   (init 0 1)                sodium_init() called twice: its first two
 *                             answers, 0 and then 1
 *   (valgrind . yes)          whether this process runs under Valgrind's
 *                             memcheck: yes when /proc/self/maps maps
 *                             vgpreload_memcheck, else no. Under make
 *                             test-memory the suites require yes (ADR-0011).
 *
 * The three version functions are called before the first sodium_init, which
 * libsodium allows. It exits 0, 1 with a message on stderr when PATH will not
 * load or lacks a function, and 2 on a wrong number of arguments. A missing
 * header or compiler fails the compile, and the suite with it: never a skip
 * (ADR-0001).
 */
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sodium.h>

/* put_quoted: "VALUE", with " and \ escaped, or #f for NULL. */
static void put_quoted(const char *value)
{
  const char *p;
  if (!value) {
    printf("#f");
    return;
  }
  putchar('"');
  for (p = value; *p; p++) {
    if (*p == '"' || *p == '\\')
      putchar('\\');
    putchar(*p);
  }
  putchar('"');
}

/* under_valgrind: 1 when /proc/self/maps maps memcheck's preload, else 0. */
static int under_valgrind(void)
{
  char line[4096];
  int found = 0;
  FILE *maps = fopen("/proc/self/maps", "r");
  if (!maps)
    return 0;
  while (!found && fgets(line, sizeof line, maps))
    found = strstr(line, "vgpreload_memcheck") != NULL;
  fclose(maps);
  return found;
}

/* FIND: VAR, NAME's address in the library LIB, typed by the header's
 * prototype, or exit 1 naming the function. */
#define FIND(var, name)                                                     \
  __typeof__(&name) var = (__typeof__(&name)) dlsym(lib, #name);            \
  if (!var) {                                                               \
    fprintf(stderr, "libsodium-oracle: %s has no %s\n", argv[1], #name);    \
    return 1;                                                               \
  }

int main(int argc, char **argv)
{
  void *lib;
  if (argc != 2) {
    fprintf(stderr, "usage: libsodium-oracle PATH\n");
    return 2;
  }
  lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!lib) {
    fprintf(stderr, "libsodium-oracle: %s\n", dlerror());
    return 1;
  }
  {
    FIND(version, sodium_version_string)
    FIND(major, sodium_library_version_major)
    FIND(minor, sodium_library_version_minor)
    FIND(init, sodium_init)
    /* C leaves the order of a call's arguments open: each answer is read
     * into its own variable first, in the order they are printed. */
    {
      const char *version_answer = version();
      int major_answer = major();
      int minor_answer = minor();
      int first_init = init();
      int second_init = init();
      printf("(version . ");
      put_quoted(version_answer);
      printf(")\n(major . %d)\n(minor . %d)\n(init %d %d)\n(valgrind . %s)\n",
             major_answer, minor_answer, first_init, second_init,
             under_valgrind() ? "yes" : "no");
    }
  }
  return 0;
}
