/* OWASP gives argon2id memory in KiB (m=19456 is 19 MiB); libsodium's memlimit is in bytes.
   Is the KiB figure accepted as a byte count without complaint? */
#include <stdio.h>
#include <sodium.h>
int main(void) {
    char h[crypto_pwhash_STRBYTES];
    if (sodium_init() < 0) return 1;
    int r = crypto_pwhash_str(h, "pw", 2, 2, 19456);
    printf("crypto_pwhash_str(ops=2, memlimit=19456) -> %d  %s\n", r, h);
    printf("needs_rehash(h, 2, 19456) -> %d\n", crypto_pwhash_str_needs_rehash(h, 2, 19456));
    return 0;
}
