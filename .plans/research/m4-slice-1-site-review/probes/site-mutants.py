import shutil, sys, os
base = 'build/m4s1-review-site/base'
root = 'build/m4s1-review-site/sm'
def edit(d, path, old, new, count=1):
    p = os.path.join(d, path)
    t = open(p, encoding='utf-8').read()
    assert t.count(old) == count, (path, old, t.count(old))
    open(p, 'w', encoding='utf-8').write(t.replace(old, new))
def append(d, path, text):
    with open(os.path.join(d, path), 'a', encoding='utf-8') as f: f.write(text)
M = {
 's1-label-pages-only': lambda d: edit(d, 'site/pages.sls', '("tokens.md" . "Tokens")', '("tokens.md" . "API keys")'),
 's2-label-readme-only': lambda d: edit(d, 'README.org', '[[file:docs/tokens.md][Tokens]]', '[[file:docs/tokens.md][Token]]'),
 's3-h1-only': lambda d: edit(d, 'docs/passwords.md', '# Passwords\n', '# Password\n'),
 's4-extra-page': lambda d: open(os.path.join(d, 'docs/extra.md'), 'w').write('# Extra\n\nx\n'),
 's5-drop-reference-nav-and-readme': lambda d: (edit(d, 'site/pages.sls', '\n      ("reference.md" . "Reference")))', '))'), edit(d, 'site/pages.sls', '("finding-libsodium.md" . "Finding libsodium")', '("finding-libsodium.md" . "Finding libsodium")'), edit(d, 'README.org', '- [[file:docs/reference.md][Reference]]: every name the library exports.\n', '')),
 's6-repo-link-missing': lambda d: append(d, 'docs/tokens.md', '\nSee [the notes](../NOTES.org).\n'),
 's7-repo-link-bad-fragment': lambda d: append(d, 'docs/tokens.md', '\nSee [the notes](../README.org#no-such-heading).\n'),
 's8-page-anchor-dangling': lambda d: append(d, 'docs/tokens.md', '\nSee [x](passwords.md#no-such).\n'),
 's9-swap-pages-and-readme': lambda d: (edit(d, 'site/pages.sls', '("passwords.md" . "Passwords")\n      ("tokens.md" . "Tokens")', '("tokens.md" . "Tokens")\n      ("passwords.md" . "Passwords")'), edit(d, 'README.org', '- [[file:docs/passwords.md][Passwords]]: hash and check passwords, and log users in safely.\n- [[file:docs/tokens.md][Tokens]]: make API keys, store them, and compare secrets.\n', '- [[file:docs/tokens.md][Tokens]]: make API keys, store them, and compare secrets.\n- [[file:docs/passwords.md][Passwords]]: hash and check passwords, and log users in safely.\n')),
 's10-js-link': lambda d: append(d, 'docs/tokens.md', '\n[click](javascript:alert(1)) <script>alert(2)</script> <b onclick="x()">b</b>\n\n<div onclick="y()">raw block</div>\n'),
 's11-dir-link': lambda d: append(d, 'docs/tokens.md', '\nSee [the source](../src/).\n'),
 's12-plans-link': lambda d: append(d, 'docs/tokens.md', '\nSee [the plan](../.plans/progress.md).\n'),
 's13-readme-second-list-line': lambda d: edit(d, 'README.org', 'The same pages are on the', '- [[file:docs/tokens.md][Tokens]] again.\n\nThe same pages are on the'),
}
name = sys.argv[1]
d = os.path.join(root, name)
if os.path.exists(d): shutil.rmtree(d)
shutil.copytree(base, d, symlinks=True)
M[name](d)
print(d)
