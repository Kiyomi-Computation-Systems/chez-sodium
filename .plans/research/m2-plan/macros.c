/* The header's macros for the generichash sizes and randombytes_BYTES_MAX. */
#include <sodium.h>
#include <stdio.h>
int main(void)
{
  printf("sodium_version_string %s\n", sodium_version_string());
  printf("crypto_generichash_BYTES %zu\n", (size_t) crypto_generichash_BYTES);
  printf("crypto_generichash_BYTES_MIN %zu\n", (size_t) crypto_generichash_BYTES_MIN);
  printf("crypto_generichash_BYTES_MAX %zu\n", (size_t) crypto_generichash_BYTES_MAX);
  printf("crypto_generichash_KEYBYTES %zu\n", (size_t) crypto_generichash_KEYBYTES);
  printf("crypto_generichash_KEYBYTES_MIN %zu\n", (size_t) crypto_generichash_KEYBYTES_MIN);
  printf("crypto_generichash_KEYBYTES_MAX %zu\n", (size_t) crypto_generichash_KEYBYTES_MAX);
  printf("randombytes_BYTES_MAX %zu\n", (size_t) randombytes_BYTES_MAX);
  return 0;
}
