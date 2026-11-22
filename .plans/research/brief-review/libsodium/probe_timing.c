/* Wall time of crypto_pwhash_str at each preset, and of verifying the result. */
#include <stdio.h>
#include <time.h>
#include <sodium.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(void) {
    if (sodium_init() < 0) return 1;
    struct { const char *n; unsigned long long o; size_t m; } p[] = {
        {"min", crypto_pwhash_opslimit_min(), crypto_pwhash_memlimit_min()},
        {"interactive", crypto_pwhash_opslimit_interactive(), crypto_pwhash_memlimit_interactive()},
        {"moderate", crypto_pwhash_opslimit_moderate(), crypto_pwhash_memlimit_moderate()},
        {"sensitive", crypto_pwhash_opslimit_sensitive(), crypto_pwhash_memlimit_sensitive()}};
    for (int i = 0; i < 4; i++) {
        char h[crypto_pwhash_STRBYTES];
        double t0 = now();
        int r = crypto_pwhash_str(h, "pw", 2, p[i].o, p[i].m);
        double t1 = now();
        int v = crypto_pwhash_str_verify(h, "pw", 2);
        printf("%-12s hash=%d %.3fs verify=%d %.3fs  %s\n", p[i].n, r, t1 - t0, v, now() - t1, h);
    }
    return 0;
}
