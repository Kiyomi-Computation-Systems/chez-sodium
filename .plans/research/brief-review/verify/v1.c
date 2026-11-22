#include <sodium.h>
#include <stdio.h>
#include <string.h>
static void hex(const unsigned char *b, size_t n){for(size_t i=0;i<n;i++)printf("%02x",b[i]);printf("\n");}
int main(void){
  printf("init=%d init2=%d version=%s lib=%d.%d\n", sodium_init(), sodium_init(), sodium_version_string(),
         sodium_library_version_major(), sodium_library_version_minor());
  unsigned long long ops=crypto_pwhash_opslimit_min(); size_t mem=crypto_pwhash_memlimit_min();
  char h[crypto_pwhash_STRBYTES]; const char *pw="pw";
  if (crypto_pwhash_str(h,pw,2,ops,mem)!=0) return 1;
  printf("hash=%s len=%zu strbytes=%zu\n", h, strlen(h), crypto_pwhash_strbytes());
  /* F1: bytes after the hash, no NUL right after it */
  char buf[256]; size_t n=strlen(h); memcpy(buf,h,n); memcpy(buf+n,"junk",5);
  printf("F1 verify(hash+junk)=%d verify(hash)=%d\n", crypto_pwhash_str_verify(buf,pw,2), crypto_pwhash_str_verify(h,pw,2));
  /* NUL inside: hash\0junk verifies as hash */
  memcpy(buf,h,n); buf[n]=0; memcpy(buf+n+1,"junk",5);
  printf("NUL verify(hash\\0junk)=%d\n", crypto_pwhash_str_verify(buf,pw,2));
  /* F3: memlimit in KiB mistaken for bytes */
  char h2[crypto_pwhash_STRBYTES];
  printf("F3 str(ops=2,mem=19456)=%d -> %s\n", crypto_pwhash_str(h2,pw,2,2,19456), h2);
  printf("F3 needs_rehash(h2,2,19456)=%d\n", crypto_pwhash_str_needs_rehash(h2,2,19456));
  /* F6: lowered limits; argon2i hash at matching limits */
  char h3[crypto_pwhash_STRBYTES];
  crypto_pwhash_str(h3,pw,2,3,mem);
  printf("F6 needs_rehash(ops3 hash, ops1)=%d same=%d\n", crypto_pwhash_str_needs_rehash(h3,1,mem), crypto_pwhash_str_needs_rehash(h3,3,mem));
  char hi[crypto_pwhash_STRBYTES];
  crypto_pwhash_argon2i_str(hi,pw,2,3,mem);
  printf("F6 argon2i hash=%.20s... needs_rehash(default fn, same limits)=%d verify=%d\n", hi, crypto_pwhash_str_needs_rehash(hi,3,mem), crypto_pwhash_str_verify(hi,pw,2));
  /* F5: BLAKE2b-256 and -512 of "abc" */
  unsigned char o[64];
  crypto_generichash(o,32,(const unsigned char*)"abc",3,NULL,0); printf("F5 b2b-256(abc)="); hex(o,32);
  crypto_generichash(o,64,(const unsigned char*)"abc",3,NULL,0); printf("F5 b2b-512(abc)="); hex(o,64);
  /* F8: empty non-NULL key equals unkeyed; outlen 1 accepted */
  unsigned char a[32],b[32]; unsigned char k[1]={0};
  crypto_generichash(a,32,(const unsigned char*)"x",1,NULL,0); crypto_generichash(b,32,(const unsigned char*)"x",1,k,0);
  printf("F8 emptykey==unkeyed %d outlen1=%d\n", memcmp(a,b,32)==0, crypto_generichash(o,1,(const unsigned char*)"x",1,NULL,0));
  return 0;
}
