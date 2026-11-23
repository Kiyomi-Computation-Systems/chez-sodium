/* Do sodium.h's prototypes match the convention table's C types, by
   _Generic on each function's address, for the entry points M1 binds and
   for the rest of Tier 1? Compiled with -Wall -Werror -std=c11; prints one
   line per function, 1 for a match. */
#include <sodium.h>
#include <stdio.h>
#define CHECK(f, T) printf("%-40s %d\n", #f, _Generic(&f, T: 1, default: 0))
int main(void)
{
  CHECK(sodium_version_string, const char *(*)(void));
  CHECK(sodium_library_version_major, int (*)(void));
  CHECK(sodium_library_version_minor, int (*)(void));
  CHECK(sodium_init, int (*)(void));
  CHECK(sodium_memzero, void (*)(void *, size_t));
  /* the header spells it void * const pnt, const size_t len: top-level
     qualifiers do not change a function's type */
  CHECK(sodium_memzero, void (*)(void * const, const size_t));
  CHECK(sodium_memcmp, int (*)(const void *, const void *, size_t));
  CHECK(randombytes_buf, void (*)(void *, size_t));
  CHECK(crypto_generichash, int (*)(unsigned char *, size_t, const unsigned char *, unsigned long long, const unsigned char *, size_t));
  CHECK(crypto_generichash_bytes, size_t (*)(void));
  CHECK(crypto_pwhash_str, int (*)(char *, const char *, unsigned long long, unsigned long long, size_t));
  CHECK(crypto_pwhash_str_verify, int (*)(const char *, const char *, unsigned long long));
  CHECK(crypto_pwhash_str_needs_rehash, int (*)(const char *, unsigned long long, size_t));
  CHECK(crypto_pwhash_strprefix, const char *(*)(void));
  CHECK(crypto_pwhash_opslimit_min, size_t (*)(void));
  CHECK(crypto_pwhash_memlimit_min, size_t (*)(void));
  /* a deliberately wrong row: int for size_t must answer 0 */
  CHECK(crypto_pwhash_strbytes, int (*)(void));
  return 0;
}
