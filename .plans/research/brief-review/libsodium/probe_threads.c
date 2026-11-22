/* Sanity check (not a proof): Tier 1 calls from 8 OS threads at once, plus sodium_init racing from each thread. */
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sodium.h>
static int bad[8], inits[8][3];
static void *work(void *arg) {
    int id = (int)(long) arg;
    int r = sodium_init();
    inits[id][r + 1]++;
    for (int i = 0; i < 20; i++) {
        char h[crypto_pwhash_STRBYTES];
        unsigned char pw[16], o1[32], o2[32];
        randombytes_buf(pw, sizeof pw);
        if (crypto_pwhash_str(h, (char *) pw, sizeof pw, 1, 1 << 20) != 0) bad[id]++;
        if (crypto_pwhash_str_verify(h, (char *) pw, sizeof pw) != 0) bad[id]++;
        if (crypto_pwhash_str_needs_rehash(h, 1, 1 << 20) != 0) bad[id]++;
        crypto_generichash(o1, 32, pw, sizeof pw, NULL, 0);
        crypto_generichash(o2, 32, pw, sizeof pw, NULL, 0);
        if (sodium_memcmp(o1, o2, 32) != 0) bad[id]++;
    }
    return NULL;
}
int main(void) {
    pthread_t t[8];
    for (long i = 0; i < 8; i++) pthread_create(&t[i], NULL, work, (void *) i);
    for (int i = 0; i < 8; i++) pthread_join(t[i], NULL);
    int b = 0, z = 0, one = 0, neg = 0;
    for (int i = 0; i < 8; i++) { b += bad[i]; neg += inits[i][0]; z += inits[i][1]; one += inits[i][2]; }
    printf("8 threads x 20 rounds: failures=%d; sodium_init answers: 0 x%d, 1 x%d, -1 x%d\n", b, z, one, neg);
    return 0;
}
