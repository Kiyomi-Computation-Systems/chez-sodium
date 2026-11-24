/* Item 6: does a verify that failed for lack of memory differ from a wrong password, by answer or errno?
   usage: oom CASE [FILE]   (FILE holds a 64 MiB hash string; make it first, without a limit: CASE mk FILE) */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sodium.h>
static void report(const char *what, int r) { printf("%-62s -> %d errno=%d (%s)\n", what, r, errno, strerror(errno)); }
static void read_file(const char *path, char *buf, size_t n)
{
  FILE *f = fopen(path, "r");
  if (!f || !fgets(buf, (int) n, f)) { puts("cannot read file"); exit(2); }
  buf[strcspn(buf, "\n")] = 0; fclose(f);
}
int main(int argc, char **argv)
{
  char h[crypto_pwhash_STRBYTES], big[512];
  const char *c = argv[1];
  if (sodium_init() < 0) return 2;
  if (!strcmp(c, "mk")) {  /* run without a limit */
    if (crypto_pwhash_str(h, "pw", 2, 1, 67108864) != 0) return 1;
    FILE *f = fopen(argv[2], "w"); fprintf(f, "%s\n", h); fclose(f); return 0;
  }
  errno = 0;
  if (!strcmp(c, "str64")) { int r = crypto_pwhash_str(h, "pw", 2, 1, 67108864); report("crypto_pwhash_str, 64 MiB", r); }
  else if (!strcmp(c, "str-small")) { int r = crypto_pwhash_str(h, "pw", 2, 1, 8192); report("crypto_pwhash_str, 8 KiB (control)", r); }
  else if (!strcmp(c, "verify-big-right")) { read_file(argv[2], big, sizeof big); errno = 0; int r = crypto_pwhash_str_verify(big, "pw", 2); report("verify, right password, 64 MiB hash", r); }
  else if (!strcmp(c, "verify-big-wrong")) { read_file(argv[2], big, sizeof big); errno = 0; int r = crypto_pwhash_str_verify(big, "pX", 2); report("verify, wrong password, 64 MiB hash", r); }
  else if (!strcmp(c, "verify-small-wrong")) {
    if (crypto_pwhash_str(h, "pw", 2, 1, 8192) != 0) { puts("small hash failed"); return 3; }
    errno = 0; int r = crypto_pwhash_str_verify(h, "pX", 2); report("verify, wrong password, 8 KiB hash", r); }
  else if (!strcmp(c, "verify-small-right")) {
    if (crypto_pwhash_str(h, "pw", 2, 1, 8192) != 0) { puts("small hash failed"); return 3; }
    errno = 0; int r = crypto_pwhash_str_verify(h, "pw", 2); report("verify, right password, 8 KiB hash (control)", r); }
  else if (!strcmp(c, "verify-garbage")) { strcpy(big, "garbage"); errno = 0; int r = crypto_pwhash_str_verify(big, "pw", 2); report("verify, \"garbage\"", r); }
  else if (!strcmp(c, "verify-m-huge")) { /* m=4 TiB in the string: argon2 refuses or cannot allocate */
    snprintf(big, sizeof big, "$argon2id$v=19$m=4294967295,t=1,p=1$JN6Oe0S6FZF8z4jzZjgmVw$B85bTaNhyG0W0xTMuIqecfHDWgnZ9v2MfXKvWTVH3uU");
    errno = 0; int r = crypto_pwhash_str_verify(big, "pw", 2); report("verify, m=4294967295 KiB in the string", r); }
  else if (!strcmp(c, "verify-decode-fail")) { /* argon2id prefix, string cut short: the dispatcher passes it on, decode refuses */
    strcpy(big, "$argon2id$v=19$m=8,t=1,p=1$JN6Oe0S6FZF8z4jzZjgmVw"); errno = 0; int r = crypto_pwhash_str_verify(big, "pw", 2); report("verify, argon2id prefix, tag missing (decode fails)", r); }
  else return 4;
  return 0;
}
