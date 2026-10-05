#!/bin/sh
# Translate the generated tamarin-unchained model to a stock-Tamarin model
# over the builtin xor theory, whose presentation coincides with eq.th
# equation for equation: replace the user-declared xor_ud/zero_ud by
# builtins: xor and drop their now-redundant declarations and equations.
#
# Usage:  ./to-builtin-xor.sh [tamarin-unchained-model.spthy]
# Output on stdout; fails if any _ud symbol survives the translation.
set -eu
in=${1:-tamarin-unchained-model.spthy}

out=$(sed \
    -e '/^begin$/a\builtins: xor' \
    -e '/xor_ud\/2 \[AC\],/d' \
    -e '/zero_ud\/0 ,/d' \
    -e '/xor_ud(x, x) = zero_ud,/d' \
    -e '/xor_ud(x, zero_ud) = x,/d' \
    -e '/xor_ud(x, xor_ud(x, y)) = y,/d' \
    -e 's/xor_ud(\([^,]*\), \([^)]*\))/(\1 XOR \2)/g' \
    "$in")

if printf '%s\n' "$out" | grep -q '_ud'; then
    echo "$0: untranslated _ud symbol remains" >&2
    exit 1
fi
printf '%s\n' "$out"
