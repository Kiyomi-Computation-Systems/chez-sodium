/* Probe libsodium's password-hashing behaviour that the chez-sodium brief relies on.
 * Build: see run_probes.sh. Links against whichever libsodium is given. */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sodium.h>

#define OPS crypto_pwhash_opslimit_min()
#define MEM crypto_pwhash_memlimit_min()

static void show(const char *what, int r) { printf("%-70s -> %d\n", what, r); }

static double now(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

int main(void) {
    char h[crypto_pwhash_STRBYTES];
    char buf[512];
    int r;

    printf("version %s (%d.%d)\n", sodium_version_string(),
           sodium_library_version_major(), sodium_library_version_minor());

    /* 1. randombytes_buf before sodium_init, and size 0 */
    unsigned char rb[8] = {0};
    randombytes_buf(rb, 8);
    randombytes_buf(NULL, 0);
    printf("randombytes_buf before sodium_init and with (NULL,0): no crash\n");

    /* 2. sodium_init return codes */
    show("sodium_init() first", sodium_init());
    show("sodium_init() second", sodium_init());

    /* 3. limits */
    printf("strbytes=%zu passwd_min=%zu passwd_max=%zu\n", crypto_pwhash_strbytes(),
           crypto_pwhash_passwd_min(), crypto_pwhash_passwd_max());
    printf("opslimit min=%zu max=%zu int=%zu mod=%zu sens=%zu\n",
           crypto_pwhash_opslimit_min(), crypto_pwhash_opslimit_max(),
           crypto_pwhash_opslimit_interactive(), crypto_pwhash_opslimit_moderate(),
           crypto_pwhash_opslimit_sensitive());
    printf("memlimit min=%zu max=%zu int=%zu mod=%zu sens=%zu\n",
           crypto_pwhash_memlimit_min(), crypto_pwhash_memlimit_max(),
           crypto_pwhash_memlimit_interactive(), crypto_pwhash_memlimit_moderate(),
           crypto_pwhash_memlimit_sensitive());
    printf("argon2i opslimit_min=%zu (argon2id %zu)\n", crypto_pwhash_argon2i_opslimit_min(),
           crypto_pwhash_argon2id_opslimit_min());

    /* 4. hash, verify */
    r = crypto_pwhash_str(h, "pw", 2, OPS, MEM);
    show("crypto_pwhash_str(pw, min limits)", r);
    printf("  hash = %s (strlen %zu)\n", h, strlen(h));
    show("str_verify(h, pw)", crypto_pwhash_str_verify(h, "pw", 2));
    show("str_verify(h, pX)", crypto_pwhash_str_verify(h, "pX", 2));
    show("str_verify(\"garbage\", pw)", crypto_pwhash_str_verify("garbage", "pw", 2));
    show("str_verify(\"\", pw)", crypto_pwhash_str_verify("", "pw", 2));

    /* 5. embedded NUL and trailing data */
    memset(buf, 0, sizeof buf);
    strcpy(buf, h);
    memcpy(buf + strlen(h) + 1, "junk", 5);
    show("str_verify(h \"\\0junk\", pw)  [C sees h only]", crypto_pwhash_str_verify(buf, "pw", 2));
    snprintf(buf, sizeof buf, "%sjunk", h);
    show("str_verify(h \"junk\", pw)  [trailing non-NUL data]", crypto_pwhash_str_verify(buf, "pw", 2));
    snprintf(buf, sizeof buf, "%s\n", h);
    show("str_verify(h \"\\n\", pw)", crypto_pwhash_str_verify(buf, "pw", 2));
    snprintf(buf, sizeof buf, " %s", h);
    show("str_verify(\" \" h, pw)", crypto_pwhash_str_verify(buf, "pw", 2));

    /* 6. password with NUL inside, empty password */
    char h0[crypto_pwhash_STRBYTES];
    crypto_pwhash_str(h0, "a\0b", 3, OPS, MEM);
    show("str_verify(hash(\"a\\0b\"), \"a\\0b\",3)", crypto_pwhash_str_verify(h0, "a\0b", 3));
    show("str_verify(hash(\"a\\0b\"), \"a\",1)", crypto_pwhash_str_verify(h0, "a", 1));
    char he[crypto_pwhash_STRBYTES];
    show("crypto_pwhash_str(\"\",0)", crypto_pwhash_str(he, "", 0, OPS, MEM));
    show("str_verify(hash(\"\"), \"\",0)", crypto_pwhash_str_verify(he, "", 0));
    show("str_verify(hash(\"\"), \"x\",1)", crypto_pwhash_str_verify(he, "x", 1));

    /* 7. needs_rehash semantics */
    show("needs_rehash(h, same)", crypto_pwhash_str_needs_rehash(h, OPS, MEM));
    show("needs_rehash(h, ops+1)", crypto_pwhash_str_needs_rehash(h, OPS + 1, MEM));
    show("needs_rehash(h, mem*2)", crypto_pwhash_str_needs_rehash(h, OPS, MEM * 2));
    show("needs_rehash(h(ops=3), ops=1)  [limits LOWERED]", 0);
    {
        char h3[crypto_pwhash_STRBYTES];
        crypto_pwhash_str(h3, "pw", 2, 3, MEM);
        show("  -> needs_rehash(h3, 1, MEM)", crypto_pwhash_str_needs_rehash(h3, 1, MEM));
    }
    show("needs_rehash(h, OPS, MEM+1023)  [memlimit compared in KiB]",
         crypto_pwhash_str_needs_rehash(h, OPS, MEM + 1023));
    show("needs_rehash(\"garbage\")", crypto_pwhash_str_needs_rehash("garbage", OPS, MEM));
    memset(buf, 0, sizeof buf);
    strcpy(buf, h);
    memcpy(buf + strlen(h) + 1, "junk", 5);
    show("needs_rehash(h \"\\0junk\", same)", crypto_pwhash_str_needs_rehash(buf, OPS, MEM));

    /* memlimit not a multiple of 1024: what does the string say? */
    {
        char hm[crypto_pwhash_STRBYTES];
        crypto_pwhash_str(hm, "pw", 2, OPS, MEM + 1000);
        printf("  str with memlimit=%zu: %.40s...\n", (size_t)(MEM + 1000), hm);
    }

    /* 8. argon2i hash vs default argon2id */
    {
        char hi[crypto_pwhash_STRBYTES];
        r = crypto_pwhash_str_alg(hi, "pw", 2, 3, MEM, crypto_pwhash_ALG_ARGON2I13);
        show("crypto_pwhash_str_alg(argon2i, ops=3)", r);
        printf("  argon2i hash = %s\n", hi);
        show("str_verify(argon2i hash, pw)  [generic verify]", crypto_pwhash_str_verify(hi, "pw", 2));
        show("needs_rehash(argon2i hash, 3, MEM)  [default alg is argon2id]",
             crypto_pwhash_str_needs_rehash(hi, 3, MEM));
        show("argon2id_str_needs_rehash(argon2i hash, 3, MEM)",
             crypto_pwhash_argon2id_str_needs_rehash(hi, 3, MEM));
    }

    /* 9. older/other hash strings */
    {
        /* strip "$v=19" to make a v1.0-style (pre-versioned) string */
        char old[256];
        const char *p = strstr(h, "$v=19");
        size_t pre = (size_t)(p - h);
        memcpy(old, h, pre);
        strcpy(old + pre, p + 5);
        printf("  no-version string = %s\n", old);
        show("str_verify(no-$v= string)", crypto_pwhash_str_verify(old, "pw", 2));
        show("needs_rehash(no-$v= string)", crypto_pwhash_str_needs_rehash(old, OPS, MEM));
        char v16[256];
        snprintf(v16, sizeof v16, "%.*s$v=16%s", (int) pre, h, p + 5);
        show("str_verify($v=16 string)", crypto_pwhash_str_verify(v16, "pw", 2));
        char d[256];
        snprintf(d, sizeof d, "$argon2d%s", h + strlen("$argon2id"));
        show("str_verify($argon2d$ string)", crypto_pwhash_str_verify(d, "pw", 2));
    }

    /* 10. a valid hash string of >= STRBYTES chars: argon2id, 64-byte tag, built by hand */
    {
        unsigned char salt[crypto_pwhash_SALTBYTES], tag[64];
        char s64[64], t64[128], longh[512];
        randombytes_buf(salt, sizeof salt);
        r = crypto_pwhash(tag, sizeof tag, "pw", 2, salt, OPS, MEM, crypto_pwhash_ALG_ARGON2ID13);
        sodium_bin2base64(s64, sizeof s64, salt, sizeof salt, sodium_base64_VARIANT_ORIGINAL_NO_PADDING);
        sodium_bin2base64(t64, sizeof t64, tag, sizeof tag, sodium_base64_VARIANT_ORIGINAL_NO_PADDING);
        snprintf(longh, sizeof longh, "$argon2id$v=19$m=%zu,t=%zu,p=1$%s$%s",
                 (size_t)(MEM / 1024), (size_t) OPS, s64, t64);
        printf("  long hash (strlen %zu, STRBYTES %zu) = %s\n", strlen(longh),
               crypto_pwhash_strbytes(), longh);
        show("str_verify(long valid hash, pw)", crypto_pwhash_str_verify(longh, "pw", 2));
        show("str_verify(long valid hash, pX)", crypto_pwhash_str_verify(longh, "pX", 2));
        show("needs_rehash(long valid hash, same)", crypto_pwhash_str_needs_rehash(longh, OPS, MEM));

        /* 32-byte salt, 32-byte tag, not producible via crypto_pwhash (fixed 16-byte salt),
           so only the decode path is exercised: a wrong tag must give -1 for mismatch */
    }

    /* 11. parallelism p=4 in a stored string: does verify accept it, and does needs_rehash notice? */
    {
        char p4[256], h64[crypto_pwhash_STRBYTES];
        crypto_pwhash_str(h64, "pw", 2, OPS, 65536);
        const char *q = strstr(h64, ",p=1$");
        snprintf(p4, sizeof p4, "%.*s,p=4$%s", (int)(q - h64), h64, q + 5);
        printf("  p=4 string (tag is for p=1, so verify must be -1): %s\n", p4);
        show("str_verify(p=4 string)  [decoded, recomputed, mismatched]", crypto_pwhash_str_verify(p4, "pw", 2));
        show("needs_rehash(p=4 string, same t,m)  [p not compared?]", crypto_pwhash_str_needs_rehash(p4, OPS, 65536));
    }

    /* 12. hash string controls verify's cost */
    {
        char big[256];
        const char *q = strstr(h, "$m=");
        const char *after = strchr(q + 1, ',');
        snprintf(big, sizeof big, "%.*s$m=4294967295%s", (int)(q - h), h, after);
        double t0 = now();
        errno = 0;
        r = crypto_pwhash_str_verify(big, "pw", 2);
        printf("%-70s -> %d (errno %d %s) in %.3fs\n", "str_verify(m=4294967295 KiB i.e. 4 TiB)", r,
               errno, strerror(errno), now() - t0);
        snprintf(big, sizeof big, "%.*s$m=262144%s", (int)(q - h), h, after);
        t0 = now();
        r = crypto_pwhash_str_verify(big, "pw", 2);
        printf("%-70s -> %d in %.3fs  [attacker-chosen cost]\n", "str_verify(m=262144 KiB i.e. 256 MiB, t=1)", r, now() - t0);
    }

    /* 13. out-of-range limits */
    char hk[crypto_pwhash_STRBYTES];
    memcpy(hk, h, sizeof hk);
    show("needs_rehash(saved h, ops=2^32)", crypto_pwhash_str_needs_rehash(hk, 4294967296ULL, MEM));
    show("needs_rehash(saved h, ops=0)  [below min, not checked by C]", crypto_pwhash_str_needs_rehash(hk, 0, MEM));
    show("needs_rehash(saved h, mem=0)  [below min, not checked by C]", crypto_pwhash_str_needs_rehash(hk, OPS, 0));
    errno = 0;
    show("crypto_pwhash_str(ops=0)", crypto_pwhash_str(h, "pw", 2, 0, MEM));
    printf("  errno=%d\n", errno);
    errno = 0;
    show("crypto_pwhash_str(mem=MEM-1)", crypto_pwhash_str(h, "pw", 2, OPS, MEM - 1));
    printf("  errno=%d\n", errno);
    errno = 0;
    show("crypto_pwhash_str(ops=2^32)", crypto_pwhash_str(h, "pw", 2, 4294967296ULL, MEM));
    printf("  errno=%d\n", errno);
    printf("  after failed crypto_pwhash_str, out buffer strlen = %zu (zeroed)\n", strlen(h));
    return 0;
}
