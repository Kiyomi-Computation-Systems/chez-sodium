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
 *   (generichash-bytes F M)   then four more lines, one for each of
 *                             crypto_generichash's five sizes, in this
 *                             order: generichash-bytes, -bytes-min,
 *                             -bytes-max, -keybytes-min and -keybytes-max.
 *                             F is the size function's answer, called
 *                             through the library; M is the header's macro
 *                             for it, crypto_generichash_BYTES, _BYTES_MIN,
 *                             _BYTES_MAX, _KEYBYTES_MIN or _KEYBYTES_MAX
 *   (pwhash-strbytes F M)     then thirteen more lines, one for each of the
 *                             password hash's fourteen constants, after the
 *                             five generichash lines, in this order:
 *                             strbytes, strprefix, the five opslimits (min,
 *                             max, interactive, moderate, sensitive), the
 *                             five memlimits likewise, then passwd-min and
 *                             passwd-max. F is the function's answer and M
 *                             the header's macro, crypto_pwhash_STRBYTES,
 *                             _OPSLIMIT_MIN, ... _PASSWD_MAX. The prefix's
 *                             line is (pwhash-strprefix "F" "M"), F being #f
 *                             when the function answers NULL
 *   (valgrind . yes)          whether this process runs under Valgrind's
 *                             memcheck: yes when /proc/self/maps maps
 *                             vgpreload_memcheck, else no. Under make
 *                             test-memory the suites require yes (ADR-0011).
 *
 * Two more modes take a hex string, the bytes of a password, empty for the
 * empty password:
 *
 *   libsodium-oracle PATH hash HEX
 *       hashes the password with crypto_pwhash_str at the library's own
 *       minimum opslimit and memlimit, and prints (hash . "STRING"), then
 *       (valgrind . yes) or (valgrind . no) as above
 *   libsodium-oracle PATH verify STRING HEX
 *       prints (verify . CODE), crypto_pwhash_str_verify's answer for STRING
 *       and the password, then the (valgrind . ...) line
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

/* hex_value: the value of one hex digit, or -1. */
static int hex_value(int c)
{
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

/* decode_hex: HEX's bytes in a fresh block of at least one byte, so the
 * pointer is never NULL, and *LEN their count; NULL for an odd length or a
 * character that is no hex digit. */
static unsigned char *decode_hex(const char *hex, size_t *len)
{
  size_t n = strlen(hex);
  size_t i;
  unsigned char *bytes;
  if (n % 2) return NULL;
  bytes = calloc(n / 2 + 1, 1);
  if (!bytes) return NULL;
  for (i = 0; i < n / 2; i++) {
    int hi = hex_value((unsigned char) hex[2 * i]);
    int lo = hex_value((unsigned char) hex[2 * i + 1]);
    if (hi < 0 || lo < 0) {
      free(bytes);
      return NULL;
    }
    bytes[i] = (unsigned char) (hi * 16 + lo);
  }
  *len = n / 2;
  return bytes;
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
  int hash_mode = argc == 4 && !strcmp(argv[2], "hash");
  int verify_mode = argc == 5 && !strcmp(argv[2], "verify");
  if (argc != 2 && !hash_mode && !verify_mode) {
    fprintf(stderr, "usage: libsodium-oracle PATH [hash HEX | verify STRING HEX]\n");
    return 2;
  }
  lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!lib) {
    fprintf(stderr, "libsodium-oracle: %s\n", dlerror());
    return 1;
  }
  if (hash_mode || verify_mode) {
    FIND(init, sodium_init)
    FIND(str, crypto_pwhash_str)
    FIND(str_verify, crypto_pwhash_str_verify)
    FIND(strbytes, crypto_pwhash_strbytes)
    FIND(opslimit_min, crypto_pwhash_opslimit_min)
    FIND(memlimit_min, crypto_pwhash_memlimit_min)
    {
      size_t len = 0;
      unsigned char *password = decode_hex(argv[hash_mode ? 3 : 4], &len);
      if (!password) {
        fprintf(stderr, "libsodium-oracle: not a hex string\n");
        return 2;
      }
      if (init() < 0) {
        fprintf(stderr, "libsodium-oracle: sodium_init failed\n");
        return 1;
      }
      if (hash_mode) {
        size_t out_size = strbytes();
        char *out = calloc(out_size + 1, 1);
        size_t ops = opslimit_min();
        size_t mem = memlimit_min();
        int code;
        if (!out) return 1;
        code = str(out, (const char *) password, len, ops, mem);
        if (code != 0) {
          fprintf(stderr, "libsodium-oracle: crypto_pwhash_str answered %d\n", code);
          return 1;
        }
        printf("(hash . ");
        put_quoted(out);
        printf(")\n");
        free(out);
      } else {
        printf("(verify . %d)\n", str_verify(argv[3], (const char *) password, len));
      }
      printf("(valgrind . %s)\n", under_valgrind() ? "yes" : "no");
      free(password);
      return 0;
    }
  }
  {
    FIND(version, sodium_version_string)
    FIND(major, sodium_library_version_major)
    FIND(minor, sodium_library_version_minor)
    FIND(init, sodium_init)
    FIND(bytes, crypto_generichash_bytes)
    FIND(bytes_min, crypto_generichash_bytes_min)
    FIND(bytes_max, crypto_generichash_bytes_max)
    FIND(keybytes_min, crypto_generichash_keybytes_min)
    FIND(keybytes_max, crypto_generichash_keybytes_max)
    FIND(strbytes, crypto_pwhash_strbytes)
    FIND(strprefix, crypto_pwhash_strprefix)
    FIND(opslimit_min, crypto_pwhash_opslimit_min)
    FIND(opslimit_max, crypto_pwhash_opslimit_max)
    FIND(opslimit_interactive, crypto_pwhash_opslimit_interactive)
    FIND(opslimit_moderate, crypto_pwhash_opslimit_moderate)
    FIND(opslimit_sensitive, crypto_pwhash_opslimit_sensitive)
    FIND(memlimit_min, crypto_pwhash_memlimit_min)
    FIND(memlimit_max, crypto_pwhash_memlimit_max)
    FIND(memlimit_interactive, crypto_pwhash_memlimit_interactive)
    FIND(memlimit_moderate, crypto_pwhash_memlimit_moderate)
    FIND(memlimit_sensitive, crypto_pwhash_memlimit_sensitive)
    FIND(passwd_min, crypto_pwhash_passwd_min)
    FIND(passwd_max, crypto_pwhash_passwd_max)
    /* C leaves the order of a call's arguments open: each answer is read
     * into its own variable first, in the order they are printed. */
    {
      const char *version_answer = version();
      int major_answer = major();
      int minor_answer = minor();
      int first_init = init();
      int second_init = init();
      size_t bytes_answer = bytes();
      size_t bytes_min_answer = bytes_min();
      size_t bytes_max_answer = bytes_max();
      size_t keybytes_min_answer = keybytes_min();
      size_t keybytes_max_answer = keybytes_max();
      size_t strbytes_answer = strbytes();
      const char *strprefix_answer = strprefix();
      size_t opslimit_min_answer = opslimit_min();
      size_t opslimit_max_answer = opslimit_max();
      size_t opslimit_interactive_answer = opslimit_interactive();
      size_t opslimit_moderate_answer = opslimit_moderate();
      size_t opslimit_sensitive_answer = opslimit_sensitive();
      size_t memlimit_min_answer = memlimit_min();
      size_t memlimit_max_answer = memlimit_max();
      size_t memlimit_interactive_answer = memlimit_interactive();
      size_t memlimit_moderate_answer = memlimit_moderate();
      size_t memlimit_sensitive_answer = memlimit_sensitive();
      size_t passwd_min_answer = passwd_min();
      size_t passwd_max_answer = passwd_max();
      printf("(version . ");
      put_quoted(version_answer);
      printf(")\n(major . %d)\n(minor . %d)\n(init %d %d)\n",
             major_answer, minor_answer, first_init, second_init);
      printf("(generichash-bytes %zu %zu)\n", bytes_answer, (size_t) crypto_generichash_BYTES);
      printf("(generichash-bytes-min %zu %zu)\n", bytes_min_answer,
             (size_t) crypto_generichash_BYTES_MIN);
      printf("(generichash-bytes-max %zu %zu)\n", bytes_max_answer,
             (size_t) crypto_generichash_BYTES_MAX);
      printf("(generichash-keybytes-min %zu %zu)\n", keybytes_min_answer,
             (size_t) crypto_generichash_KEYBYTES_MIN);
      printf("(generichash-keybytes-max %zu %zu)\n", keybytes_max_answer,
             (size_t) crypto_generichash_KEYBYTES_MAX);
      printf("(pwhash-strbytes %zu %zu)\n", strbytes_answer, (size_t) crypto_pwhash_STRBYTES);
      printf("(pwhash-strprefix ");
      put_quoted(strprefix_answer);
      printf(" ");
      put_quoted(crypto_pwhash_STRPREFIX);
      printf(")\n");
      printf("(pwhash-opslimit-min %zu %zu)\n", opslimit_min_answer, (size_t) crypto_pwhash_OPSLIMIT_MIN);
      printf("(pwhash-opslimit-max %zu %zu)\n", opslimit_max_answer, (size_t) crypto_pwhash_OPSLIMIT_MAX);
      printf("(pwhash-opslimit-interactive %zu %zu)\n", opslimit_interactive_answer, (size_t) crypto_pwhash_OPSLIMIT_INTERACTIVE);
      printf("(pwhash-opslimit-moderate %zu %zu)\n", opslimit_moderate_answer, (size_t) crypto_pwhash_OPSLIMIT_MODERATE);
      printf("(pwhash-opslimit-sensitive %zu %zu)\n", opslimit_sensitive_answer, (size_t) crypto_pwhash_OPSLIMIT_SENSITIVE);
      printf("(pwhash-memlimit-min %zu %zu)\n", memlimit_min_answer, (size_t) crypto_pwhash_MEMLIMIT_MIN);
      printf("(pwhash-memlimit-max %zu %zu)\n", memlimit_max_answer, (size_t) crypto_pwhash_MEMLIMIT_MAX);
      printf("(pwhash-memlimit-interactive %zu %zu)\n", memlimit_interactive_answer, (size_t) crypto_pwhash_MEMLIMIT_INTERACTIVE);
      printf("(pwhash-memlimit-moderate %zu %zu)\n", memlimit_moderate_answer, (size_t) crypto_pwhash_MEMLIMIT_MODERATE);
      printf("(pwhash-memlimit-sensitive %zu %zu)\n", memlimit_sensitive_answer, (size_t) crypto_pwhash_MEMLIMIT_SENSITIVE);
      printf("(pwhash-passwd-min %zu %zu)\n", passwd_min_answer, (size_t) crypto_pwhash_PASSWD_MIN);
      printf("(pwhash-passwd-max %zu %zu)\n", passwd_max_answer, (size_t) crypto_pwhash_PASSWD_MAX);
      printf("(valgrind . %s)\n", under_valgrind() ? "yes" : "no");
    }
  }
  return 0;
}
