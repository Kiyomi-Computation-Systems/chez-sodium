/* Writes an argon2i hash string, at ops 3 and the minimum memory, for codes.sps to read. */
#include <sodium.h>
#include <stdio.h>
int main(int argc, char **argv)
{
  char h[crypto_pwhash_STRBYTES];
  if (argc < 2 || sodium_init() < 0) return 2;
  if (crypto_pwhash_str_alg(h, "pw", 2, 3, crypto_pwhash_memlimit_min(), crypto_pwhash_ALG_ARGON2I13) != 0) return 1;
  FILE *f = fopen(argv[1], "w");
  fprintf(f, "%s\n", h);
  fclose(f);
  return 0;
}
