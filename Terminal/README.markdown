# Prosary in a terminal

An experimental C99 / ncurses port: one terminal screen, a prayer library at the
left, and a text reader at the right. Move through a devotion with the arrow keys.
There are no images, graphical bead tracks, separate windows, or background services.

## Build and run

You need a C99 compiler, make, a POSIX shell, and the wide-character ncurses headers
and library. The normal build does not download anything or run a package manager,
Python, a code generator, CMake, or autoconf.

```sh
cd Terminal
make
./prosary
make test
```

The Makefile uses the system wide-character ncurses on macOS and `-lncursesw` on
Linux/BSD. Override `CURSES_CFLAGS` and `CURSES_LIBS` for a different installation.
For example, to use MacPorts ncurses:

```sh
make clean
make CURSES_CFLAGS=-I/opt/local/include CURSES_LIBS='-L/opt/local/lib -lncurses'
```

TinyCC is supported as a compiler choice, including with musl libc:

```sh
make clean
make CC=tcc
make test CC=tcc
```

A fully static musl/TinyCC build also works. With Alpine's `ncurses-static`
package installed, run `make clean` and `make CC=tcc LDFLAGS=-static`.
The executable still uses the content file and terminal descriptions at runtime.

On Alpine, install `make musl-dev ncurses-dev tcc tcc-dev tcc-libs-static` first. The last
package supplies TinyCC's compiler runtime. A narrowly scoped compatibility header
corrects the AArch64 Linux TinyCC snapshot's `wchar_t` type to match the platform
ABI; it has no effect on other compilers. See [portability checks](tests/README.markdown)
for the optional container verification. Docker is not a build dependency.

To install:

```sh
make PREFIX="$HOME/.local"
make install PREFIX="$HOME/.local"
```

The executable and its data are separate: `bin/prosary` and
`share/prosary/content.json`. `DESTDIR` is supported for packaging. Content discovery
checks `--data`, then `PROSARY_DATA_DIR`, then data beside the executable / its install
prefix, the compiled data directory, and the current checkout.

## Keyboard

| Key | Action |
| --- | --- |
| Left / Right | Previous / next prayer step (reversed for Hebrew/Arabic interface); change a settings value |
| Space | Advance the focused prayer reader |
| Up / Down | Scroll prayer text, or select a list/settings row |
| Page Up / Page Down | Scroll a page of prayer text |
| Tab / Shift-Tab | Switch focus between the library and content |
| Enter | Open the highlighted devotion, advance the reader, or activate a setting |
| Esc | Return to the library |
| F1 | Show help in the same screen |
| q | Save progress and quit |

Progress is textual. Completing the last step shows a completion message; it does
not wrap silently to the beginning. Terminal resizing keeps the current step.
On narrow terminals the interface shows one pane at a time; Tab switches panes.

Settings has independent arrow navigation and Space advance switches, both on by
default. They affect only the prayer reader. Enter still advances and Backspace
goes back when the shortcuts are off. Toggling either switch preserves progress.
The terminal emulator sends input only to its active terminal. Traditional terminal
input does not distinguish held-key repeats from separate presses.

Prayer language and interface language are independent. Settings also select the
Rosary mystery group, a devotion's form, and its day where applicable. Changing
prayer configuration starts that sequence at its first step. Current progress and
the effective group/form/day and liturgical date are saved atomically after changes,
and restored on the next launch. State lives at `$XDG_STATE_HOME/prosary/state`, or
`$HOME/.local/state/prosary/state`; it never touches the native apps' settings.
Only the active prayer is bookmarked in this prototype.

Useful commands:

```sh
./prosary --list
./prosary --pray rosary --group joyful --language en
./prosary --dump angelus --language la
./prosary --restart
./prosary --no-state
./prosary --help
```

`--list` and `--dump` work without a terminal and never save state. `--variant` and
`--day` use one-based indexes; `--variant 0` selects the language's default form.

## Text, languages, and scope

The snapshot includes all ten built-in stepped devotions, their sourced prayer
languages, Rosary mysteries, alternate forms, and multi-day content. The terminal
engine uses the existing default option values. This is a prayer-reader prototype,
not full feature parity: it has no community downloads or ZIP import, readings,
notifications, audio, prayer editing, a transliteration toggle, or per-option editor.
Fallback order is fixed (requested language, applicable Hebrew tradition, then
Latin), rather than independently configurable. The counter-only Jesus
Prayer is not part of the bundle catalog.

The interface has English, Hebrew, Arabic, Russian, Filipino, French, Italian, and
Ukrainian strings. Prayer text comes from the existing source material; missing
translations follow a sourced fallback and the reader identifies the body language.

Use a UTF-8 locale and a terminal/font with the required scripts. The minimal build
does not implement bidirectional layout itself and explicitly labels RTL text as
logical order. For Hebrew/Arabic visual ordering and Arabic shaping, enable the
optional FriBidi library:

```sh
make clean
make FRIBIDI=1 FRIBIDI_CFLAGS=-I/usr/include/fribidi
```

`FRIBIDI_CFLAGS` and `FRIBIDI_LIBS` are overridable. Terminal fonts, combining marks,
and complex-script rendering still need validation on the target terminal; a
successful compile is not certification of every script's appearance.

## Content maintenance

`data/content.json` is a generated, checked-in text snapshot. It contains the
canonical `Shared/content` definitions and translations, plus existing native
base prayer tables extracted with the shared coverage audit's parser. Source file
hashes record exactly what was copied. This avoids another hand-maintained prayer
translation table. The file contains no artwork or audio payloads.

Only maintainers refreshing content need uv:

```sh
uv run --script Terminal/tools/sync-content.py
uv run --script Terminal/tools/sync-content.py --check
```

Run those commands from the repository root. Never edit the snapshot's prayer text
directly. Source attribution remains in the canonical devotion manifests and source
notes included or referenced by the snapshot. The [root license](../LICENSE)
covers this port; third-party prayer and Scripture texts retain their source terms.
