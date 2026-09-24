.POSIX:

CC = cc
CFLAGS = -O2
CPPFLAGS =
LDFLAGS =
LDLIBS =
PREFIX = /usr/local
DESTDIR =
DATADIR = $(PREFIX)/share/prosary
CURSES_CFLAGS =
# Empty selects macOS's wide-character ncurses or ncursesw on other systems.
CURSES_LIBS =
FRIBIDI = 0
FRIBIDI_CFLAGS =
FRIBIDI_LIBS = -lfribidi

BASEFLAGS = -std=c99 -D_XOPEN_SOURCE=700 -D_DARWIN_C_SOURCE -DNCURSES_WIDECHAR=1 -Isrc
OBJECTS = build/main.o build/state.o build/engine.o build/json.o build/ui.o

all: prosary

prosary: $(OBJECTS)
	@curses='$(CURSES_LIBS)'; bidi=''; \
	if test -z "$$curses"; then \
	  case `uname -s` in Darwin) curses=-lncurses;; *) curses=-lncursesw;; esac; \
	fi; \
	if test '$(FRIBIDI)' = 1; then bidi='$(FRIBIDI_LIBS)'; fi; \
	set -x; $(CC) $(LDFLAGS) -o $@ $(OBJECTS) $$curses $$bidi $(LDLIBS)

build/.dir:
	mkdir -p build
	touch build/.dir

build/main.o: src/main.c src/app.h src/ui.h src/engine.h src/compat.h build/.dir
	$(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) '-DPROSARY_DATADIR="$(DATADIR)"' -c src/main.c -o $@

build/state.o: src/state.c src/app.h src/compat.h build/.dir
	$(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) -c src/state.c -o $@

build/engine.o: src/engine.c src/engine.h src/json.h src/compat.h build/.dir
	$(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) -c src/engine.c -o $@

build/json.o: src/json.c src/json.h src/compat.h build/.dir
	$(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) -c src/json.c -o $@

build/ui.o: src/ui.c src/ui.h src/ui_strings.h src/engine.h src/app.h src/compat.h build/.dir
	@bidi=''; if test '$(FRIBIDI)' = 1; then bidi='-DUSE_FRIBIDI=1 $(FRIBIDI_CFLAGS)'; fi; \
	set -x; $(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) $(CURSES_CFLAGS) $$bidi -c src/ui.c -o $@

build/test-engine: tests/test_engine.c build/engine.o build/json.o
	$(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ tests/test_engine.c build/engine.o build/json.o $(LDLIBS)

build/test-state: tests/test_state.c build/state.o
	$(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -o $@ tests/test_state.c build/state.o $(LDLIBS)

build/test-ui-text: tests/test_ui_text.c src/ui.c src/ui_strings.h src/ui.h src/app.h src/compat.h build/engine.o build/json.o build/state.o
	@curses='$(CURSES_LIBS)'; bidi=''; bidi_flags=''; \
	if test -z "$$curses"; then \
	  case `uname -s` in Darwin) curses=-lncurses;; *) curses=-lncursesw;; esac; \
	fi; \
	if test '$(FRIBIDI)' = 1; then bidi='$(FRIBIDI_LIBS)'; bidi_flags='-DUSE_FRIBIDI=1 $(FRIBIDI_CFLAGS)'; fi; \
	set -x; $(CC) $(BASEFLAGS) $(CPPFLAGS) $(CFLAGS) $(CURSES_CFLAGS) $$bidi_flags $(LDFLAGS) -o $@ tests/test_ui_text.c build/engine.o build/json.o build/state.o $$curses $$bidi $(LDLIBS)

test: build/test-engine build/test-state build/test-ui-text prosary
	./build/test-engine data
	./build/test-state
	./build/test-ui-text
	sh tests/test_cli.sh

install: prosary
	mkdir -p "$(DESTDIR)$(PREFIX)/bin" "$(DESTDIR)$(DATADIR)"
	cp prosary "$(DESTDIR)$(PREFIX)/bin/prosary"
	cp -R data/. "$(DESTDIR)$(DATADIR)/"

clean:
	rm -f prosary build/*.o build/test-engine build/test-state build/test-ui-text

# Content is already checked in. Regeneration is a maintainer task documented in README.
