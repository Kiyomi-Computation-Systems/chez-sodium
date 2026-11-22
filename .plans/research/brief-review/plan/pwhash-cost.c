/* Times crypto_pwhash_str at a named limit set, N times, and prints the
   hash string and limits. Usage: pwhash-cost min|interactive|moderate|sensitive [N] */
#include <sodium.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

static double now(void) {
  struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(int argc, char **argv) {
  int r = sodium_init();
  int r2 = sodium_init();
  printf("sodium_init: %d then %d; version %s lib %d.%d\n", r, r2,
         sodium_version_string(), sodium_library_version_major(), sodium_library_version_minor());
  printf("opslimit min %zu interactive %zu moderate %zu sensitive %zu max %zu\n",
         crypto_pwhash_opslimit_min(), crypto_pwhash_opslimit_interactive(),
         crypto_pwhash_opslimit_moderate(), crypto_pwhash_opslimit_sensitive(), crypto_pwhash_opslimit_max());
  printf("memlimit min %zu interactive %zu moderate %zu sensitive %zu max %zu\n",
         crypto_pwhash_memlimit_min(), crypto_pwhash_memlimit_interactive(),
         crypto_pwhash_memlimit_moderate(), crypto_pwhash_memlimit_sensitive(), crypto_pwhash_memlimit_max());
  printf("strbytes %zu passwd_min %zu passwd_max %zu alg_default %d alg_argon2id13 %d\n",
         crypto_pwhash_strbytes(), crypto_pwhash_passwd_min(), crypto_pwhash_passwd_max(),
         crypto_pwhash_alg_default(), crypto_pwhash_alg_argon2id13());
  printf("generichash bytes %zu min %zu max %zu keybytes %zu min %zu max %zu\n",
         crypto_generichash_bytes(), crypto_generichash_bytes_min(), crypto_generichash_bytes_max(),
         crypto_generichash_keybytes(), crypto_generichash_keybytes_min(), crypto_generichash_keybytes_max());
  const char *which = argc > 1 ? argv[1] : "min";
  int n = argc > 2 ? atoi(argv[2]) : 1;
  unsigned long long ops; size_t mem;
  if (!strcmp(which, "min")) { ops = crypto_pwhash_opslimit_min(); mem = crypto_pwhash_memlimit_min(); }
  else if (!strcmp(which, "interactive")) { ops = crypto_pwhash_opslimit_interactive(); mem = crypto_pwhash_memlimit_interactive(); }
  else if (!strcmp(which, "moderate")) { ops = crypto_pwhash_opslimit_moderate(); mem = crypto_pwhash_memlimit_moderate(); }
  else { ops = crypto_pwhash_opslimit_sensitive(); mem = crypto_pwhash_memlimit_sensitive(); }
  char out[crypto_pwhash_STRBYTES];
  double t0 = now();
  for (int i = 0; i < n; i++) {
    if (crypto_pwhash_str(out, "password", 8, ops, mem) != 0) { printf("pwhash_str failed\n"); return 1; }
  }
  double t1 = now();
  int v = crypto_pwhash_str_verify(out, "password", 8);
  double t2 = now();
  int nr = crypto_pwhash_str_needs_rehash(out, ops, mem);
  printf("%s: ops %llu mem %zu: %d hashes in %.6f s (%.6f s each); verify %d in %.6f s; needs_rehash %d\n",
         which, ops, mem, n, t1 - t0, (t1 - t0) / n, v, t2 - t1, nr);
  printf("hash: %s (len %zu)\n", out, strlen(out));
  /* empty password with a NULL pointer: does 1.0.18 accept it at run time? */
  char out2[crypto_pwhash_STRBYTES];
  int e = crypto_pwhash_str(out2, "", 0, crypto_pwhash_opslimit_min(), crypto_pwhash_memlimit_min());
  printf("empty password (non-NULL): %d; verify '' %d; verify 'a' %d\n", e,
         crypto_pwhash_str_verify(out2, "", 0), crypto_pwhash_str_verify(out2, "a", 1));
  unsigned char buf[16]; randombytes_buf(buf, sizeof buf);
  unsigned char h[32]; crypto_generichash(h, 32, (const unsigned char *)"abc", 3, NULL, 0);
  printf("blake2b-256(abc): "); for (int i = 0; i < 32; i++) printf("%02x", h[i]); printf("\n");
  /* generichash at outlen 1 and keylen 1: below the _min constants */
  unsigned char h1[1]; unsigned char k1[1] = {7};
  printf("generichash outlen 1: %d; keylen 1: %d; outlen 65: %d; keylen 65: %d\n",
         crypto_generichash(h1, 1, (const unsigned char *)"abc", 3, NULL, 0),
         crypto_generichash(h, 32, (const unsigned char *)"abc", 3, k1, 1),
         crypto_generichash(h, 65, (const unsigned char *)"abc", 3, NULL, 0),
         crypto_generichash(h, 32, (const unsigned char *)"abc", 3, h, 65));
  return 0;
}
