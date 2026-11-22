#include <sodium.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <time.h>
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
int main(int argc,char**argv){
  if (sodium_init()<0) return 1;
  char h[crypto_pwhash_STRBYTES];
  if (argc>1){ /* make a 256 MiB hash string by hand-editing a min one, then verify under ulimit */
    const char *s="$argon2id$v=19$m=262144,t=1,p=1$c29tZXNhbHRzb21lc2FsdA$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    errno=0; int r=crypto_pwhash_str_verify(s,"pw",2); printf("verify(m=256MiB) under limit -> %d errno=%d (%s)\n", r, errno, strerror(errno));
    errno=0; r=crypto_pwhash_str(h,"pw",2,1,268435456); printf("str(mem=256MiB) under limit -> %d errno=%d\n", r, errno);
    return 0; }
  double t0=now(); int r=crypto_pwhash_str(h,"pw",2,crypto_pwhash_opslimit_interactive(),crypto_pwhash_memlimit_interactive()); double t1=now();
  int v=crypto_pwhash_str_verify(h,"pw",2); double t2=now();
  printf("interactive: str=%d %.3fs verify=%d %.3fs\n", r, t1-t0, v, t2-t1);
  return 0;
}
