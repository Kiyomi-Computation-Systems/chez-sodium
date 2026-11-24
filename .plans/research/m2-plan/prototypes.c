/* Do sodium.h's prototypes match brief 3.4's C types, by _Generic on each
   function's address? Compiled -Wall -Werror -std=c11. 1 is a match. The last
   row is planted wrong (int for size_t) and must answer 0. */
#include <sodium.h>
#include <stdio.h>
#define CHECK(f, T) printf("%-44s %d\n", #f, _Generic(&f, T: 1, default: 0))
int main(void)
{
  CHECK(randombytes_buf, void (*)(void *, size_t));
  CHECK(crypto_generichash, int (*)(unsigned char *, size_t, const unsigned char *, unsigned long long, const unsigned char *, size_t));
  CHECK(crypto_generichash_bytes, size_t (*)(void));
  CHECK(crypto_generichash_bytes_min, size_t (*)(void));
  CHECK(crypto_generichash_bytes_max, size_t (*)(void));
  CHECK(crypto_generichash_keybytes, size_t (*)(void));
  CHECK(crypto_generichash_keybytes_min, size_t (*)(void));
  CHECK(crypto_generichash_keybytes_max, size_t (*)(void));
  CHECK(sodium_memcmp, int (*)(const void *, const void *, size_t));
  /* planted wrong: size_t result declared int */
  CHECK(crypto_generichash_bytes, int (*)(void));
  /* planted wrong: inlen as size_t is a different C type from unsigned long long */
  CHECK(crypto_generichash, int (*)(unsigned char *, size_t, const unsigned char *, size_t, const unsigned char *, size_t));
  return 0;
}
