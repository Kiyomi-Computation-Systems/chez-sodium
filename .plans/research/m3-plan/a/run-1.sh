#!/bin/sh
# Item 1: declarations and macros quoted from both releases' headers, and their diff.
#   sh build/m3-plan/a/run-1.sh > build/m3-plan/a/headers-decls.txt
cd "$(dirname "$0")/.." || exit 2
for v in 1.0.18 1.0.22; do
  d=../slice5/prefix-$v/include/sodium
  echo "######## $v: crypto_pwhash.h"
  awk '/^#define crypto_pwhash_(PASSWD_M|STRBYTES|STRPREFIX|OPSLIMIT_|MEMLIMIT_)/ {print FILENAME":"FNR": "$0} 
       /^(size_t |const char \*|int )crypto_pwhash_(passwd_|strbytes|strprefix|opslimit_|memlimit_|str\(|str_verify|str_needs_rehash)/ {p=1} 
       p {print FILENAME":"FNR": "$0} p && /;/ {p=0}' $d/crypto_pwhash.h
  echo "######## $v: crypto_pwhash_argon2id.h (macros the above expand to)"
  grep -n -A1 -E '^#define crypto_pwhash_argon2id_(PASSWD_M|STRBYTES|STRPREFIX|OPSLIMIT_|MEMLIMIT_)' $d/crypto_pwhash_argon2id.h
done | sed -e 's#\.\./slice5/prefix-[0-9.]*/include/##'
echo "######## diff of crypto_pwhash.h and crypto_pwhash_argon2id.h, 1.0.18 -> 1.0.22"
for f in crypto_pwhash.h crypto_pwhash_argon2id.h; do
  echo "--- $f"; diff ../slice5/prefix-1.0.18/include/sodium/$f ../slice5/prefix-1.0.22/include/sodium/$f
done
