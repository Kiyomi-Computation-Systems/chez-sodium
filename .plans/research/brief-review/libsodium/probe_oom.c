/* crypto_pwhash_str / _str_verify at a given memlimit: does a memory shortage come back as -1, or kill the process? */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sodium.h>
int main(int argc, char **argv) {
    size_t mem = strtoull(argv[1], NULL, 10);
    char h[crypto_pwhash_STRBYTES];
    if (sodium_init() < 0) return 2;
    errno = 0;
    int r = crypto_pwhash_str(h, "pw", 2, 1, mem);
    printf("crypto_pwhash_str(mem=%zu) -> %d errno=%d (%s)\n", mem, r, errno, strerror(errno));
    fflush(stdout);
    if (argc > 2) { /* verify a hash string whose m= is given in KiB */
        char s[256];
        snprintf(s, sizeof s, "$argon2id$v=19$m=%s,t=1,p=1$JN6Oe0S6FZF8z4jzZjgmVw$B85bTaNhyG0W0xTMuIqecfHDWgnZ9v2MfXKvWTVH3uU", argv[2]);
        errno = 0;
        r = crypto_pwhash_str_verify(s, "pw", 2);
        printf("crypto_pwhash_str_verify(m=%s KiB) -> %d errno=%d (%s)\n", argv[2], r, errno, strerror(errno));
    }
    return 0;
}
