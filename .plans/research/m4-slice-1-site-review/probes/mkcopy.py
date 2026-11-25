import shutil, sys, os
src = os.getcwd()
dst = sys.argv[1]
if os.path.exists(dst):
    shutil.rmtree(dst)
def ign(d, names):
    if os.path.abspath(d) == src:
        return [n for n in names if n in ('build', '.git')]
    return []
shutil.copytree(src, dst, symlinks=True, ignore=ign)
os.makedirs(os.path.join(dst, 'build'))
shutil.copytree(os.path.join(src, 'build/akku'), os.path.join(dst, 'build/akku'), symlinks=True)
print('copied', dst)
