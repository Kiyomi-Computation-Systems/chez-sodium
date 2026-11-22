#include <sodium.h>
#include <stdio.h>
int main(void){if(sodium_init()<0)return 1;printf("strprefix=%s alg_default=%d argon2id13=%d interactive=(%zu,%zu) moderate=(%zu,%zu) sensitive=(%zu,%zu) passwd=(%zu,%zu)\n",crypto_pwhash_strprefix(),crypto_pwhash_alg_default(),crypto_pwhash_alg_argon2id13(),crypto_pwhash_opslimit_interactive(),crypto_pwhash_memlimit_interactive(),crypto_pwhash_opslimit_moderate(),crypto_pwhash_memlimit_moderate(),crypto_pwhash_opslimit_sensitive(),crypto_pwhash_memlimit_sensitive(),crypto_pwhash_passwd_min(),crypto_pwhash_passwd_max());return 0;}
