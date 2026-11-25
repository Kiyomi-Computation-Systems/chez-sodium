#!/bin/sh
# Run on the host from <repo>'s root: the container has no cmark-gfm. Copies
# <sibling>'s generator, check-site and its fetched chez-cmark-gfm into
# build/m4-plan/a/render, renames chez-sqlite3 to chez-sodium in the copy,
# puts this directory's two stub pages and pages.sls in, and renders them
# twice, SITE_REF=main and v0.1.0. Then check-site against README.org, the
# README handed to cmark-gfm as Markdown, and the slug of every export.
# CHEZ is the host's Chez; the cmark-gfm libraries are the ones the pin
# b532aa7 gives, by absolute path.
set -eu
S=../chez-sqlite3
P=.plans/research/m4-plan/a/render
R=build/m4-plan/a/render
rm -rf "$R"
mkdir -p "$R/site" "$R/docs" "$R/akku" "$R/out-main" "$R/out-tag"
cp "$S/build-site.sps" "$S/tests/check-site.sps" "$R/"
cp "$S"/site/*.sls "$S/site/style.css" "$R/site/"
cp -r "$S/build/akku/chez-cmark-gfm" "$R/akku/"
cp README.org "$R/"
cp "$P/pages.sls" "$R/site/pages.sls"
cp "$P"/docs/*.md "$R/docs/"
cp "$P/readme-as-md.sps" "$P/slugs.sps" "$R/"
sed -i 's#Kiyomi-Computation-Systems/chez-sqlite3#Kiyomi-Computation-Systems/chez-sodium#g' "$R/site/links.sls" "$R/site/template.sls"
sed -i 's#(href "index.html")) "chez-sqlite3")#(href "index.html")) "chez-sodium")#; s#SQLite bindings for Chez Scheme#libsodium bindings for Chez Scheme#; s#sqlite sqlite3 database sql scheme chez r6rs#libsodium sodium argon2 blake2b scheme chez r6rs#' "$R/site/template.sls"
L=/gnu/store/prn4x0x9i2m8mjxqyiyabay820j1snmd-cmark-gfm-0.29.0.gfm.13/lib
export CHEZ_CMARK_GFM_LIBS="$L/libcmark-gfm.so:$L/libcmark-gfm-extensions.so"
CHEZ=${CHEZ:-scheme}
cd "$R"
"$CHEZ" --version
SITE_REF=main SITE_OUT=out-main "$CHEZ" --libdirs .:akku/chez-cmark-gfm/src --program build-site.sps
SITE_REF=v0.1.0 SITE_OUT=out-tag "$CHEZ" --libdirs .:akku/chez-cmark-gfm/src --program build-site.sps
cp site/style.css out-main/ && cp site/style.css out-tag/
ls out-main out-tag
echo "== links, SITE_REF=main"; grep -o 'href="[^"]*"' out-main/index.html | sort -u
echo "== links, SITE_REF=v0.1.0"; grep -o 'href="[^"]*"' out-tag/index.html | sort -u
echo "== the code block and the callout, as rendered"
grep -o '<pre><code class="[^"]*">' out-tag/index.html
grep -o '<pre><code class="language-scheme">[^<]*' out-tag/index.html | head -1
grep -o '<div class="callout warning">' out-tag/index.html | head -1
echo "== check-site"
SITE_REF=main "$CHEZ" --libdirs .:akku/chez-cmark-gfm/src --program check-site.sps || echo "check-site exit $?"
echo "== README.org as Markdown, its first 12 lines of HTML"
"$CHEZ" --libdirs .:akku/chez-cmark-gfm/src --program readme-as-md.sps | head -12
echo "== slugs"
"$CHEZ" --libdirs . --program slugs.sps
