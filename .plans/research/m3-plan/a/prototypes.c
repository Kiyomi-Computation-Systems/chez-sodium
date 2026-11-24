/* Do sodium.h's prototypes match brief 3.4's C types, by _Generic on each
   function's address? Compiled -Wall -Werror -std=c11. 1 is a match. The last
   two rows are planted wrong and must answer 0. */
#include <sodium.h>
#include <stdio.h>
#define CHECK(f, T) printf("%-44s %d\n", #f, _Generic(&f, T: 1, default: 0))
int main(void)
{
  CHECK(crypto_pwhash_str, int (*)(char *, const char *, unsigned long long, unsigned long long, size_t));
  CHECK(crypto_pwhash_str_verify, int (*)(const char *, const char *, unsigned long long));
  CHECK(crypto_pwhash_str_needs_rehash, int (*)(const char *, unsigned long long, size_t));
  CHECK(crypto_pwhash_strprefix, const char *(*)(void));
  CHECK(crypto_pwhash_strbytes, size_t (*)(void));
  CHECK(crypto_pwhash_opslimit_min, size_t (*)(void));
  CHECK(crypto_pwhash_opslimit_max, size_t (*)(void));
  CHECK(crypto_pwhash_opslimit_interactive, size_t (*)(void));
  CHECK(crypto_pwhash_opslimit_moderate, size_t (*)(void));
  CHECK(crypto_pwhash_opslimit_sensitive, size_t (*)(void));
  CHECK(crypto_pwhash_memlimit_min, size_t (*)(void));
  CHECK(crypto_pwhash_memlimit_max, size_t (*)(void));
  CHECK(crypto_pwhash_memlimit_interactive, size_t (*)(void));
  CHECK(crypto_pwhash_memlimit_moderate, size_t (*)(void));
  CHECK(crypto_pwhash_memlimit_sensitive, size_t (*)(void));
  CHECK(crypto_pwhash_passwd_min, size_t (*)(void));
  CHECK(crypto_pwhash_passwd_max, size_t (*)(void));
  /* planted wrong: opslimit as int */
  CHECK(crypto_pwhash_str_needs_rehash, int (*)(const char *, int, size_t));
  /* planted wrong: opslimit as size_t (a different C type from unsigned long long) */
  CHECK(crypto_pwhash_str, int (*)(char *, const char *, unsigned long long, size_t, size_t));
  return 0;
}
