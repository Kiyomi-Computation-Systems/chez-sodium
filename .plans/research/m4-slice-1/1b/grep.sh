#!/bin/sh
# build/m4s1-1b/grep.sh: builder 1b's text greps over its five files. Run on
# the host from the repository root, or from a copy: sh build/m4s1-1b/grep.sh
# Each check prints ok or FAIL with the lines it found; exit 1 on any FAIL.
pages="docs/quickstart.md docs/passwords.md docs/tokens.md docs/finding-libsodium.md"
fails=0
check() { # check NAME OUTPUT-OF-OFFENDERS
  if [ -z "$2" ]; then echo "ok: $1"; else echo "FAIL: $1"; echo "$2" | sed 's/^/    /'; fails=$((fails + 1)); fi
}

check "no page holds either floor's version text" \
  "$(grep -n -F -e 1.0.18 -e 10.4.0 $pages)"
check "README.org holds a floor only in its two Requirements lines" \
  "$(grep -n -F -e 1.0.18 -e 10.4.0 README.org | grep -v -x -e '[0-9]*:- Chez Scheme 10.4.0 or later, built with threads' -e '[0-9]*:- libsodium 1.0.18 or later')"
check "no page quotes a refusal's version text or a soname's releases" \
  "$(grep -n -i -e 'older than chez-sodium' -e "chez-sodium's floor is" -e 'chez-sodium needs Chez' -e 'so\.23` for' -e '\.so\.23 for' $pages README.org)"
check "no banned word: ADR-, TODO, yet, unreleased, slice, .plans, a date" \
  "$(grep -n -i -E 'ADR-|TODO|\byet\b|unreleased|slice|\.plans|[0-9]{4}-[0-9]{2}-[0-9]{2}' $pages README.org)"
check "README.org holds no stale word: will, next, so far" \
  "$(grep -n -i -w -E 'will|next|so far' README.org)"
check "every word holding CHEZ_ is CHEZ_SODIUM_LIBRARY" \
  "$(grep -n -o -E '[A-Za-z0-9_]*CHEZ_[A-Za-z0-9_]*' $pages README.org | grep -v ':CHEZ_SODIUM_LIBRARY$')"
check "every CHEZ_SODIUM_LIBRARY= at a line's start or after a blank sets an absolute path" \
  "$(grep -n -E '(^|[[:space:]])CHEZ_SODIUM_LIBRARY=' $pages README.org | grep -v -E '(^|[[:space:]])CHEZ_SODIUM_LIBRARY=/')"
check "every line holding git clone is exactly the clone line" \
  "$(grep -n 'git clone' $pages README.org | grep -v -E ':[[:space:]]*git clone https://github.com/Kiyomi-Computation-Systems/chez-sodium.git$')"
check "README.org and the quick start hold one clone line each, the other pages none" \
  "$(for f in README.org $pages; do n=$(grep -c 'git clone' "$f"); case $f in README.org|docs/quickstart.md) [ "$n" = 1 ] || echo "$f: $n";; *) [ "$n" = 0 ] || echo "$f: $n";; esac; done)"
check "no absolute home path, and no host distribution named" \
  "$(grep -n -i -E '/home/|/root/' $pages README.org)"
check "no hash string is called printable ASCII" \
  "$(grep -n -i 'printable' $pages README.org)"
check "no link into .plans" \
  "$(grep -n -F -e '.plans/' -e 'file:.plans' $pages README.org)"
check "a link to README.org takes no anchor" \
  "$(grep -n -F 'README.org#' $pages)"
echo "failures: $fails"
[ "$fails" = 0 ]
