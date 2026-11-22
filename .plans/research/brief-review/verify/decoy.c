#include <sodium.h>
#include <stdio.h>
int crypto_pwhash_str(char out[crypto_pwhash_STRBYTES], const char * const passwd,
                      unsigned long long passwdlen, unsigned long long opslimit, size_t memlimit) {
  fprintf(stderr, "crypto_pwhash_str out=%s passwd=%s\n", out ? "p" : "NULL", passwd ? "p" : "NULL");
  return -1;
}
