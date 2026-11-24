/* RFC 7693 Appendix E's blake2b_selftest, through libsodium. The inner hashes
   are crypto_generichash (the verb M2 binds); the grand hash over them is
   libsodium's streaming crypto_generichash_init/_update/_final at 32 bytes,
   standing in for the RFC's blake2b_ctx (the streaming calls are used here
   only, never bound). argv[1] picks a variant:
     ok        the published parameters
     size      md_len[1] = 33 instead of 32
     inlen     in_len[2] = 127 instead of 128
     keylen    the keyed hash passes outlen-1 as key length
     oneshot   the grand hash as ONE crypto_generichash over the concatenated results
     nokey     the keyed hash drops its key (key NULL, length 0)  */
#include <sodium.h>
#include <stdio.h>
#include <string.h>
static void selftest_seq(uint8_t *out, size_t len, uint32_t seed)
{
  size_t i; uint32_t t, a, b;
  a = 0xDEAD4BAD * seed; b = 1;
  for (i = 0; i < len; i++) { t = a + b; a = b; b = t; out[i] = (t >> 24) & 0xFF; }
}
int main(int argc, char **argv)
{
  const char *variant = argc > 1 ? argv[1] : "ok";
  static const uint8_t res[32] = {
    0xC2,0x3A,0x78,0x00,0xD9,0x81,0x23,0xBD,0x10,0xF5,0x06,0xC6,0x1E,0x29,0xDA,0x56,
    0x03,0xD7,0x63,0xB8,0xBB,0xAD,0x2E,0x73,0x7F,0x5E,0x76,0x5A,0x7B,0xCC,0xD4,0x75 };
  size_t md_len[4] = { 20, 32, 48, 64 };
  size_t in_len[6] = { 0, 3, 128, 129, 255, 1024 };
  uint8_t in[1024], md[64], key[64], grand[32];
  crypto_generichash_state st;
  static uint8_t cat[4096]; size_t catlen = 0;
  int oneshot = !strcmp(variant, "oneshot");
  size_t i, j, outlen, inlen;
  if (sodium_init() < 0) return 2;
  if (!strcmp(variant, "size")) md_len[1] = 33;
  if (!strcmp(variant, "inlen")) in_len[2] = 127;
  crypto_generichash_init(&st, NULL, 0, 32);
  for (i = 0; i < 4; i++) {
    outlen = md_len[i];
    for (j = 0; j < 6; j++) {
      inlen = in_len[j];
      selftest_seq(in, inlen, (uint32_t) inlen);
      if (crypto_generichash(md, outlen, in, inlen, NULL, 0)) { printf("refused unkeyed outlen %zu\n", outlen); return 3; }
      crypto_generichash_update(&st, md, outlen); memcpy(cat + catlen, md, outlen); catlen += outlen;
      selftest_seq(key, outlen, (uint32_t) outlen);
      if (!strcmp(variant, "nokey")) {
        if (crypto_generichash(md, outlen, in, inlen, NULL, 0)) return 3;
      } else {
        size_t klen = !strcmp(variant, "keylen") ? outlen - 1 : outlen;
        if (crypto_generichash(md, outlen, in, inlen, key, klen)) { printf("refused keyed outlen %zu klen %zu\n", outlen, klen); return 3; }
      }
      crypto_generichash_update(&st, md, outlen); memcpy(cat + catlen, md, outlen); catlen += outlen;
    }
  }
  crypto_generichash_final(&st, grand, 32);
  if (oneshot) { if (crypto_generichash(grand, 32, cat, catlen, NULL, 0)) return 3; printf("(%zu bytes concatenated) ", catlen); }
  printf("%-7s %s  grand hash ", variant, sodium_version_string());
  for (i = 0; i < 32; i++) printf("%02x", grand[i]);
  printf("  %s\n", memcmp(grand, res, 32) ? "FAIL" : "OK");
  return 0;
}
