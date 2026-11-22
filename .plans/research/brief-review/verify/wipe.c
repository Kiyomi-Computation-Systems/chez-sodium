#include <sodium.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec+t.tv_nsec/1e9;}
int main(void){
  if (sodium_init()<0) return 1;
  size_t sizes[]={32,128,4096,1<<20,64<<20};
  for (int i=0;i<5;i++){ size_t n=sizes[i]; unsigned char *b=malloc(n); randombytes_buf(b,n);
    int reps = n<=4096 ? 1000000 : (n==(1<<20) ? 200 : 5);
    double t0=now(); for(int r=0;r<reps;r++) sodium_memzero(b,n); double t1=now();
    unsigned char h[32]; double t2=now(); for(int r=0;r<reps;r++) crypto_generichash(h,32,b,n,NULL,0); double t3=now();
    printf("%9zu bytes: memzero %10.1f ns   blake2b %12.1f ns\n", n, (t1-t0)/reps*1e9, (t3-t2)/reps*1e9); free(b); }
  return 0; }
