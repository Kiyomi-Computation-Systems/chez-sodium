#!/bin/sh
# Does a tag name, handed to make as SITE_REF in the environment, reach the
# recipe's shell as code? Run inside the container from the copy's root.
cd build/m4s1-review-site/base || exit 2
bt='v0.1.0`echo INJECTED-BACKTICK >&2`'
dd='v0.1.0$$(echo INJECTED-DOLLAR >&2)'
echo "-- backtick: $bt"
SITE_REF=$bt make site 2>&1 | grep -E 'INJECTED|wrote'
echo "-- doubled dollar: $dd"
SITE_REF=$dd make site 2>&1 | grep -E 'INJECTED|wrote'
