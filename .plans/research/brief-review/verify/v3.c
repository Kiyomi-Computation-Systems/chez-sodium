#include <sodium.h>
#include <stdio.h>
#include <errno.h>
int main(int argc,char**argv){
  if (sodium_init()<0) return 1;
  if (argc==1){ char h[crypto_pwhash_STRBYTES];
    if (crypto_pwhash_str(h,"pw",2,1,268435456)!=0) return 2; puts(h); return 0; }
  errno=0; int r=crypto_pwhash_str_verify(argv[1],"pw",2); printf("verify(right password) -> %d errno=%d\n", r, errno); return 0;
}
