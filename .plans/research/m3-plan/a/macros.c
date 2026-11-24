/* Item 4: the header macros against the functions' answers. */
#include <sodium.h>
#include <stdio.h>
#include <string.h>
#define M(NAME, mac, fn) printf("%-34s macro %-14llu function %-14zu %s\n", NAME, (unsigned long long)(mac), fn(), (size_t)(mac) == fn() ? "agree" : "DIFFER")
int main(void)
{
  M("STRBYTES", crypto_pwhash_STRBYTES, crypto_pwhash_strbytes);
  M("PASSWD_MIN", crypto_pwhash_PASSWD_MIN, crypto_pwhash_passwd_min);
  M("PASSWD_MAX", crypto_pwhash_PASSWD_MAX, crypto_pwhash_passwd_max);
  M("OPSLIMIT_MIN", crypto_pwhash_OPSLIMIT_MIN, crypto_pwhash_opslimit_min);
  M("OPSLIMIT_MAX", crypto_pwhash_OPSLIMIT_MAX, crypto_pwhash_opslimit_max);
  M("OPSLIMIT_INTERACTIVE", crypto_pwhash_OPSLIMIT_INTERACTIVE, crypto_pwhash_opslimit_interactive);
  M("OPSLIMIT_MODERATE", crypto_pwhash_OPSLIMIT_MODERATE, crypto_pwhash_opslimit_moderate);
  M("OPSLIMIT_SENSITIVE", crypto_pwhash_OPSLIMIT_SENSITIVE, crypto_pwhash_opslimit_sensitive);
  M("MEMLIMIT_MIN", crypto_pwhash_MEMLIMIT_MIN, crypto_pwhash_memlimit_min);
  M("MEMLIMIT_MAX", crypto_pwhash_MEMLIMIT_MAX, crypto_pwhash_memlimit_max);
  M("MEMLIMIT_INTERACTIVE", crypto_pwhash_MEMLIMIT_INTERACTIVE, crypto_pwhash_memlimit_interactive);
  M("MEMLIMIT_MODERATE", crypto_pwhash_MEMLIMIT_MODERATE, crypto_pwhash_memlimit_moderate);
  M("MEMLIMIT_SENSITIVE", crypto_pwhash_MEMLIMIT_SENSITIVE, crypto_pwhash_memlimit_sensitive);
  printf("STRPREFIX macro %s, function %s, %s\n", crypto_pwhash_STRPREFIX, crypto_pwhash_strprefix(),
         strcmp(crypto_pwhash_STRPREFIX, crypto_pwhash_strprefix()) == 0 ? "agree" : "DIFFER");
  return 0;
}
