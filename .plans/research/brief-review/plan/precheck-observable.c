/* Which of the section 8 "hash with a NUL inside" variants does libsodium
   already reject on its own? A row whose input C rejects anyway passes with
   the binding's pre-check deleted, so it cannot be watched failing that way.
   Also: does needs_rehash read limits from a hand-written string, so presets
   can be tested without hashing at them? */
#include <sodium.h>
#include <stdio.h>
#include <string.h>

static void row(const char *name, const char *s, size_t n) {
  /* s holds n bytes; C sees it up to its first NUL */
  char buf[512]; memcpy(buf, s, n); buf[n] = 0;
  printf("%-46s len %3zu: verify %2d, needs_rehash(min) %2d\n", name, n,
         crypto_pwhash_str_verify(buf, "pw", 2),
         crypto_pwhash_str_needs_rehash(buf, crypto_pwhash_opslimit_min(), crypto_pwhash_memlimit_min()));
}

int main(void) {
  if (sodium_init() < 0) return 1;
  char good[crypto_pwhash_STRBYTES];
  if (crypto_pwhash_str(good, "pw", 2, crypto_pwhash_opslimit_min(), crypto_pwhash_memlimit_min())) return 1;
  size_t g = strlen(good);
  char t[512];
  row("good", good, g);
  memcpy(t, good, g); memcpy(t + g, "\0junk", 5); row("good + NUL + junk (C sees good)", t, g + 5);
  memcpy(t, good, g); memcpy(t + g, "\xc3\xa9", 2); row("good + U+00E9 as UTF-8", t, g + 2);
  memcpy(t, good, g); t[g] = '\x01'; row("good + U+0001", t, g + 1);
  memcpy(t, good, g); t[g] = '\n'; row("good + newline", t, g + 1);
  memcpy(t, good, g); memset(t + g, 'A', 130 - g); row("good padded with A to 130 (>= strbytes)", t, 130);
  /* non-ASCII inside the salt */
  memcpy(t, good, g); t[30] = '\xc3'; row("good with a byte >= 0x80 in the salt", t, g);
  /* hand-written strings: needs_rehash parses, never hashes */
  const char *inter = "$argon2id$v=19$m=65536,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
  printf("hand-written m=65536,t=2: needs_rehash interactive %d, moderate %d, min %d\n",
         crypto_pwhash_str_needs_rehash(inter, crypto_pwhash_opslimit_interactive(), crypto_pwhash_memlimit_interactive()),
         crypto_pwhash_str_needs_rehash(inter, crypto_pwhash_opslimit_moderate(), crypto_pwhash_memlimit_moderate()),
         crypto_pwhash_str_needs_rehash(inter, crypto_pwhash_opslimit_min(), crypto_pwhash_memlimit_min()));
  /* needs_rehash: lower limits than made with? */
  char mid[crypto_pwhash_STRBYTES];
  crypto_pwhash_str(mid, "pw", 2, 2, 16384);
  printf("made at (2 . 16384) %s: needs_rehash same %d, lower ops %d, higher ops %d\n", mid,
         crypto_pwhash_str_needs_rehash(mid, 2, 16384), crypto_pwhash_str_needs_rehash(mid, 1, 16384),
         crypto_pwhash_str_needs_rehash(mid, 3, 16384));
  /* memlimit not a multiple of 1024: what does the string say? */
  char odd[crypto_pwhash_STRBYTES];
  crypto_pwhash_str(odd, "pw", 2, 1, 8192 + 1000);
  printf("made at mem 9192: %s; needs_rehash at 9192 %d, at 8192 %d\n", odd,
         crypto_pwhash_str_needs_rehash(odd, 1, 9192), crypto_pwhash_str_needs_rehash(odd, 1, 8192));
  /* argon2i string: str_verify and needs_rehash */
  char i2[crypto_pwhash_argon2i_STRBYTES];
  crypto_pwhash_argon2i_str(i2, "pw", 2, 3, 8192);
  printf("argon2i string %s: verify %d, needs_rehash(3, 8192) %d\n", i2,
         crypto_pwhash_str_verify(i2, "pw", 2), crypto_pwhash_str_needs_rehash(i2, 3, 8192));
  return 0;
}
