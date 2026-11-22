/* What does crypto_pwhash_str_needs_rehash answer for printable-ASCII
   strings that are not valid hashes? The brief (section 3.4, docs) says -1. */
#include <sodium.h>
#include <stdio.h>
#include <string.h>
static void row(const char *name, const char *s) {
  printf("%-44s needs_rehash %2d  verify %2d\n", name,
         crypto_pwhash_str_needs_rehash(s, 1, 8192), crypto_pwhash_str_verify(s, "pw", 2));
}
int main(void) {
  if (sodium_init() < 0) return 1;
  char good[crypto_pwhash_STRBYTES], t[crypto_pwhash_STRBYTES];
  if (crypto_pwhash_str(good, "pw", 2, 1, 8192) != 0) return 1;
  row("good", good);
  strcpy(t, good); t[30] = '!'; row("salt char replaced by '!'", t);
  strcpy(t, good); t[strlen(t) - 5] = '!'; row("hash char replaced by '!'", t);
  strcpy(t, good); t[strlen(t) - 10] = 0; row("hash part truncated by 10", t);
  strcpy(t, good); { char *d = strrchr(t, '$'); *d = 0; } row("hash part removed (ends at salt)", t);
  row("empty string", "");
  row("$argon2id$", "$argon2id$");
  row("$argon2id$v=19$m=8,t=1,p=1$", "$argon2id$v=19$m=8,t=1,p=1$");
  row("$argon2id$v=19$m=8,t=1,p=1$$", "$argon2id$v=19$m=8,t=1,p=1$$");
  row("$argon2id$v=19$m=8,t=1,p=1$c2FsdA$aGFzaA", "$argon2id$v=19$m=8,t=1,p=1$c2FsdA$aGFzaA");
  row("$argon2id$v=18$m=8,t=1,p=1$... (version 18)", "$argon2id$v=18$m=8,t=1,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
  row("$argon2d$... (argon2d prefix)", "$argon2d$v=19$m=8,t=1,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
  row("$scrypt$ / $7$ string", "$7$C6..../....SodiumChloride$kBGj9fHznVYFQMEn/qDCfrDevf9YDtcDdKvEqHJLV8D");
  return 0;
}
