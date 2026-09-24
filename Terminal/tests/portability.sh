#!/bin/sh
# Optional maintainer check. Docker is not an application build dependency.
set -eu

terminal_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
image=${PROSARY_TEST_IMAGE:-alpine:3.23}
with_fribidi=${PROSARY_TEST_FRIBIDI:-0}

command -v docker >/dev/null 2>&1 || {
    printf '%s\n' 'Docker is needed only for this optional container check.' >&2
    exit 1
}

docker run --rm \
    -v "$terminal_dir:/source:ro" \
    -e "PROSARY_TEST_FRIBIDI=$with_fribidi" \
    "$image" sh -eu -c '
    apk add --no-cache make gcc musl-dev ncurses-dev tcc tcc-dev tcc-libs-static util-linux-misc
    if test "$PROSARY_TEST_FRIBIDI" = 1; then
        apk add --no-cache fribidi-dev
    fi
    work=$(mktemp -d)
    cp -R /source/. "$work/"
    cd "$work"
    for compiler in cc tcc; do
        printf "\nChecking %s against musl\n" "$compiler"
        "$compiler" -v
        make clean
        make CC="$compiler" CFLAGS="-O2 -Wall -Wextra -Werror"
        make test CC="$compiler" CFLAGS="-O2 -Wall -Wextra -Werror"
        # Exercise curses setup and teardown too; q exits without saving state.
        printf "q\n" | TERM=xterm timeout 10 script -q -e \
            -c "./prosary --no-state" /dev/null > /tmp/prosary-curses.log
        if test "$PROSARY_TEST_FRIBIDI" = 1; then
            make clean
            make CC="$compiler" CFLAGS="-O2 -Wall -Wextra -Werror" \
                FRIBIDI=1 FRIBIDI_CFLAGS=-I/usr/include/fribidi
            make test CC="$compiler" CFLAGS="-O2 -Wall -Wextra -Werror" \
                FRIBIDI=1 FRIBIDI_CFLAGS=-I/usr/include/fribidi
            printf "q\n" | TERM=xterm timeout 10 script -q -e \
                -c "./prosary --no-state" /dev/null > /tmp/prosary-curses-bidi.log
        fi
    done
    printf "\nBoth compiler checks passed.\n"
'
