/* Throughput of the "fast" calls on large inputs: are they really microseconds? */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sodium.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(void) {
    if (sodium_init() < 0) return 1;
    size_t n = 256u << 20;
    unsigned char *b = calloc(n, 1), out[64];
    double t0 = now(); crypto_hash_sha256(out, b, n); double t1 = now();
    crypto_generichash(out, 32, b, n, NULL, 0); double t2 = now();
    randombytes_buf(b, 16u << 20); double t3 = now();
    printf("256 MiB: sha256 %.3fs, blake2b %.3fs; randombytes_buf 16 MiB %.3fs\n", t1 - t0, t2 - t1, t3 - t2);
    return 0;
}
