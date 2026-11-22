/* RFC 7693 Appendix E's BLAKE2b self-test, done with one-shot crypto_generichash only
   (the hash of hashes taken over the concatenated digests), as a Scheme test of generic-hash could. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <sodium.h>
static void selftest_seq(uint8_t *out, size_t len, uint32_t seed) {
    uint32_t t, a = 0xDEAD4BAD * seed, b = 1;
    for (size_t i = 0; i < len; i++) { t = a + b; a = b; b = t; out[i] = (t >> 24) & 0xFF; }
}
int main(void) {
    const uint8_t res[32] = {0xC2,0x3A,0x78,0x00,0xD9,0x81,0x23,0xBD,0x10,0xF5,0x06,0xC6,0x1E,0x29,0xDA,0x56,
                             0x03,0xD7,0x63,0xB8,0xBB,0xAD,0x2E,0x73,0x7F,0x5E,0x76,0x5A,0x7B,0xCC,0xD4,0x75};
    const size_t md_len[4] = {20, 32, 48, 64}, in_len[6] = {0, 3, 128, 129, 255, 1024};
    uint8_t in[1024], md[64], key[64], all[4 * 6 * 2 * 64], out[32];
    size_t n = 0;
    if (sodium_init() < 0) return 1;
    for (int i = 0; i < 4; i++) for (int j = 0; j < 6; j++) {
        size_t ol = md_len[i], il = in_len[j];
        selftest_seq(in, il, il);
        if (crypto_generichash(md, ol, in, il, NULL, 0) != 0) return 2;
        memcpy(all + n, md, ol); n += ol;
        selftest_seq(key, ol, ol);
        if (crypto_generichash(md, ol, in, il, key, ol) != 0) return 3;
        memcpy(all + n, md, ol); n += ol;
    }
    crypto_generichash(out, 32, all, n, NULL, 0);
    printf("RFC 7693 Appendix E self-test via one-shot crypto_generichash: %s\n",
           memcmp(out, res, 32) == 0 ? "PASS" : "FAIL");
    return 0;
}
