/* Probe generichash, memcmp, randombytes, SHA-256/HMAC-SHA256 state, and AWS SigV4 key derivation. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdalign.h>
#include <sodium.h>

static void hex(const char *label, const unsigned char *b, size_t n) {
    printf("%s", label);
    for (size_t i = 0; i < n; i++) printf("%02x", b[i]);
    printf("\n");
}
static void show(const char *what, int r) { printf("%-66s -> %d\n", what, r); }

static void hmac(unsigned char out[32], const unsigned char *k, size_t kl,
                 const char *msg) {
    crypto_auth_hmacsha256_state *st = malloc(crypto_auth_hmacsha256_statebytes());
    crypto_auth_hmacsha256_init(st, k, kl);
    crypto_auth_hmacsha256_update(st, (const unsigned char *) msg, strlen(msg));
    crypto_auth_hmacsha256_final(st, out);
    free(st);
}

int main(void) {
    unsigned char out[64], key[64];
    int r;
    if (sodium_init() < 0) return 1;

    printf("generichash bytes=%zu min=%zu max=%zu keybytes=%zu min=%zu max=%zu\n",
           crypto_generichash_bytes(), crypto_generichash_bytes_min(),
           crypto_generichash_bytes_max(), crypto_generichash_keybytes(),
           crypto_generichash_keybytes_min(), crypto_generichash_keybytes_max());

    for (int i = 0; i < 64; i++) key[i] = (unsigned char) i;

    /* sizes C accepts vs the published minimums */
    show("generichash(outlen=1)  [< BYTES_MIN 16]", crypto_generichash(out, 1, (const unsigned char *) "abc", 3, NULL, 0));
    show("generichash(outlen=15)", crypto_generichash(out, 15, (const unsigned char *) "abc", 3, NULL, 0));
    show("generichash(outlen=0)", crypto_generichash(out, 0, (const unsigned char *) "abc", 3, NULL, 0));
    show("generichash(outlen=65)", crypto_generichash(out, 65, (const unsigned char *) "abc", 3, NULL, 0));
    show("generichash(keylen=1)  [< KEYBYTES_MIN 16]", crypto_generichash(out, 32, (const unsigned char *) "abc", 3, key, 1));
    show("generichash(keylen=65)", crypto_generichash(out, 32, (const unsigned char *) "abc", 3, key, 64 + 0) );
    {
        unsigned char k65[65] = {0};
        show("generichash(keylen=65 real)", crypto_generichash(out, 32, (const unsigned char *) "abc", 3, k65, 65));
    }
    /* empty key == no key */
    unsigned char a[32], b[32];
    crypto_generichash(a, 32, (const unsigned char *) "abc", 3, NULL, 0);
    crypto_generichash(b, 32, key, 0, key, 0); /* in=key with inlen 0 is "" : wrong input, so recompute */
    crypto_generichash(b, 32, (const unsigned char *) "abc", 3, key, 0);
    show("generichash(abc, key=non-NULL len 0) == unkeyed", memcmp(a, b, 32) == 0);
    /* empty input with non-NULL pointer and with NULL pointer */
    crypto_generichash(a, 32, (const unsigned char *) "", 0, NULL, 0);
    crypto_generichash(b, 32, NULL, 0, NULL, 0);
    show("generichash(\"\" ptr) == generichash(NULL,0)", memcmp(a, b, 32) == 0);

    /* outputs for cross-check against Python hashlib.blake2b */
    crypto_generichash(out, 64, (const unsigned char *) "abc", 3, NULL, 0);
    hex("b2b-512(abc)              = ", out, 64);
    crypto_generichash(out, 32, (const unsigned char *) "abc", 3, NULL, 0);
    hex("b2b-256(abc)              = ", out, 32);
    crypto_generichash(out, 16, (const unsigned char *) "abc", 3, NULL, 0);
    hex("b2b-128(abc)              = ", out, 16);
    crypto_generichash(out, 32, (const unsigned char *) "abc", 3, key, 32);
    hex("b2b-256(abc, key=00..1f)  = ", out, 32);
    crypto_generichash(out, 64, (const unsigned char *) "", 0, key, 64);
    hex("b2b-512(\"\", key=00..3f)   = ", out, 64);

    /* sodium_memcmp */
    show("sodium_memcmp(len 0)", sodium_memcmp(a, b, 0));
    show("sodium_memcmp(equal)", sodium_memcmp("abcd", "abcd", 4));
    show("sodium_memcmp(differ in last byte)", sodium_memcmp("abcd", "abce", 4));
    show("sodium_memcmp(differ in first byte)", sodium_memcmp("xbcd", "abcd", 4));

    /* randombytes */
    randombytes_buf(out, 0);
    printf("randombytes_buf(out, 0): ok; implementation = %s\n", randombytes_implementation_name());

    /* SHA-256 / HMAC state sizes and alignment needs */
    printf("crypto_hash_sha256_statebytes=%zu sizeof=%zu alignof=%zu\n",
           crypto_hash_sha256_statebytes(), sizeof(crypto_hash_sha256_state),
           alignof(crypto_hash_sha256_state));
    printf("crypto_auth_hmacsha256_statebytes=%zu sizeof=%zu alignof=%zu keybytes=%zu\n",
           crypto_auth_hmacsha256_statebytes(), sizeof(crypto_auth_hmacsha256_state),
           alignof(crypto_auth_hmacsha256_state), crypto_auth_hmacsha256_keybytes());
    printf("crypto_generichash_statebytes=%zu alignof=%zu  (not in scope; shown for contrast)\n",
           crypto_generichash_statebytes(), alignof(crypto_generichash_state));

    /* Does final wipe the HMAC state? */
    {
        crypto_auth_hmacsha256_state *st = malloc(crypto_auth_hmacsha256_statebytes());
        unsigned char zero[sizeof *st];
        memset(zero, 0, sizeof zero);
        crypto_auth_hmacsha256_init(st, key, 44);
        crypto_auth_hmacsha256_update(st, (const unsigned char *) "x", 1);
        show("HMAC state is all zero after init+update", memcmp(st, zero, sizeof *st) == 0);
        crypto_auth_hmacsha256_final(st, out);
        show("HMAC state is all zero after final", memcmp(st, zero, sizeof *st) == 0);
        free(st);
    }

    /* AWS SigV4 signing-key derivation, AWS's published example:
       secret wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY, 20120215, us-east-1, iam
       expected kSigning f4780e2d9f65fa895f9c67b32ce1baf0b0d8a43505a000a1a9e090d414db404d */
    {
        const char *secret = "AWS4wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY";
        unsigned char kd[32], kr[32], ks[32], kg[32];
        printf("SigV4 kSecret length = %zu bytes\n", strlen(secret));
        hmac(kd, (const unsigned char *) secret, strlen(secret), "20120215");
        hmac(kr, kd, 32, "us-east-1");
        hmac(ks, kr, 32, "iam");
        hmac(kg, ks, 32, "aws4_request");
        hex("SigV4 kSigning = ", kg, 32);
        printf("expected       = f4780e2d9f65fa895f9c67b32ce1baf0b0d8a43505a000a1a9e090d414db404d\n");
    }
    return 0;
}
