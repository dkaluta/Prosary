# Portability checks

For the optional keyboard, resize, resume-date, completion, save-failure, and
terminal-close checks against a real pseudo-terminal, run from `Terminal/`:

```sh
uv run --script tests/test_pty.py
```

That script uses only Python's standard library. It is not needed by `make` or
`make test`; the normal test suite compiles C test executables and runs a shell script.

The ordinary build needs a C99 compiler, `make`, and wide-character ncurses
headers/library. Docker is an optional way to reproduce the Linux checks from
another operating system:

```sh
sh tests/portability.sh
PROSARY_TEST_FRIBIDI=1 sh tests/portability.sh
```

The script uses a temporary Alpine Linux 3.23 container, mounts this directory
read-only, copies it to the container's temporary directory, and runs the same
build, engine/state/CLI tests, and curses startup/quit checks with GCC and TinyCC.
The test-only `script` utility supplies a pseudo-terminal for the curses check.
It removes its own container when finished and does not install host packages.
`PROSARY_TEST_IMAGE` may select a different Alpine image.

On Alpine, TinyCC needs all three packages `tcc`, `tcc-dev`, and
`tcc-libs-static`: the compiler package alone omits its headers and `libtcc1.a`.
The optional FriBidi run also installs `fribidi-dev` inside the container.

For a static TinyCC build on Alpine, install `ncurses-static` as well, then run:

```sh
make clean
make CC=tcc LDFLAGS=-static
make test CC=tcc LDFLAGS=-static
```

Static FriBidi builds additionally need `fribidi-static`; pass `FRIBIDI=1` and
`FRIBIDI_CFLAGS=-I/usr/include/fribidi` on each build/test command. Static linking
does not embed `data/content.json` or the system's terminal descriptions.

Alpine 3.23's AArch64 TinyCC identifies itself as 0.9.28rc, package version
`0.9.27_git20250619`. It defines `__WCHAR_TYPE__` as signed `int`, while the
AArch64 Linux ABI and musl headers use unsigned `int`. `src/compat.h` corrects
that compiler macro before system headers are included. Other compilers and
architectures are unaffected. This is necessary even for a minimal ncurses
program on that combination.

The curses smoke check establishes initialization and clean exit. It does not
establish visual layout, every keyboard interaction, or Arabic/Hebrew rendering
in a real terminal; those require a separate interactive check.

Verified on 2026-09-23 with Alpine 3.23 AArch64, musl 1.2.5, ncurses 6.5,
GCC 15.2.0, TinyCC 0.9.28rc, and optional FriBidi 1.0.16:

- GCC and TinyCC builds, using `-std=c99 -Wall -Wextra -Werror`, both with and
  without FriBidi; engine, state, text-layout, and CLI tests; curses startup/quit.
- Fully static TinyCC builds, with and without FriBidi; the same tests and curses
  startup/quit. ELF inspection confirmed no dynamic loader or dynamic section.
- A fresh container containing TinyCC as its only compiler (no GCC or Clang)
  passed both static configurations, including 247 prayer sessions, state/text/CLI
  tests, and Arabic curses startup/quit. The final baseline executable measured
  422,828 bytes without FriBidi, excluding content data. The final CLI regressions
  also passed in that minimal static build.
- FriBidi assertions for Hebrew visual order, Arabic joining and lam-alef shaping,
  and number order; Arabic interface/prayer curses startup/quit.
