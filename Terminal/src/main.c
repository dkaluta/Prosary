#include "app.h"
#include "engine.h"
#include "ui.h"

#include <errno.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef PROSARY_DATADIR
#define PROSARY_DATADIR "/usr/local/share/prosary"
#endif

static void usage(FILE *out)
{
    fputs("Prosary terminal 0.1\n"
          "Usage: prosary [options]\n\n"
          "  --pray ID              Open a devotion (default: resume last prayer)\n"
          "  --language CODE        Prayer language, e.g. en, la, he, ar\n"
          "  --ui-language CODE     Interface: en, he, ar, ru, tl, fr, it, uk\n"
          "  --group GROUP          today, joyful, sorrowful, glorious, luminous\n"
          "  --variant N            Devotion form (1-based; 0 = language default)\n"
          "  --day N                Day of a multi-day devotion (1-based)\n"
          "  --restart              Begin the selected prayer again\n"
          "  --list                 List available devotions without opening curses\n"
          "  --dump ID              Print a prayer sequence without opening curses\n"
          "  --data DIR             Read the checked-in content.json from DIR\n"
          "  --state FILE           Read/write resume state at FILE\n"
          "  --no-state             Do not read or write resume state\n"
          "  --version              Print version\n"
          "  --help                 Show this help\n\n"
          "In a prayer: Left/Right move between steps; Up/Down scroll.\n"
          "Tab changes focus; Enter selects; Esc returns; F1 helps; q quits.\n",
          out);
}

static int copy_argument(char *dest, size_t size, const char *source)
{
    size_t length = strlen(source);
    if (length == 0 || length >= size) return -1;
    memcpy(dest, source, length + 1);
    return 0;
}

static int number(const char *text, int minimum, int maximum, int *result)
{
    char *end;
    long value;
    errno = 0;
    value = strtol(text, &end, 10);
    if (errno || end == text || *end || value < minimum || value > maximum) return -1;
    *result = (int)value;
    return 0;
}

static int valid_ui_language(const char *language)
{
    static const char *codes[] = {"en", "he", "ar", "ru", "tl", "fr", "it", "uk"};
    size_t i;
    for (i = 0; i < sizeof(codes) / sizeof(codes[0]); ++i)
        if (!strcmp(language, codes[i])) return 1;
    return 0;
}

static int valid_prayer_language(const char *language)
{
    size_t i;
    for (i = 0; i < engine_language_count(); ++i)
        if (!strcmp(language, engine_language_code(i))) return 1;
    return 0;
}

static const char *language_alias(const char *language)
{
    if (!strcmp(language, "fil")) return "tl";
    if (!strcmp(language, "iw")) return "he";
    return language;
}

static int has_content(const char *directory)
{
    char path[4096];
    int n = snprintf(path, sizeof(path), "%s/content.json", directory);
    return n > 0 && (size_t)n < sizeof(path) && access(path, R_OK) == 0;
}

static int data_next_to_executable(const char *program, char *directory, size_t size)
{
    char executable[4096], candidate[4096], *slash;
    const char *path, *end;
    size_t length;
    int n;
    if (strchr(program, '/')) {
        if (copy_argument(executable, sizeof(executable), program)) return 0;
    } else {
        path = getenv("PATH");
        if (!path) return 0;
        executable[0] = '\0';
        while (*path) {
            end = strchr(path, ':');
            length = end ? (size_t)(end - path) : strlen(path);
            n = snprintf(candidate, sizeof(candidate), "%.*s%s%s", (int)length, path,
                         length ? "/" : "./", program);
            if (n > 0 && (size_t)n < sizeof(candidate) && !access(candidate, X_OK)) {
                strcpy(executable, candidate);
                break;
            }
            if (!end) break;
            path = end + 1;
        }
        if (!executable[0]) return 0;
    }
    slash = strrchr(executable, '/');
    if (!slash) return 0;
    *slash = '\0';
    n = snprintf(directory, size, "%s/data", executable);
    if (n > 0 && (size_t)n < size && has_content(directory)) return 1;
    n = snprintf(directory, size, "%s/../share/prosary", executable);
    return n > 0 && (size_t)n < size && has_content(directory);
}

static ProsaryEngine *open_engine(const char *explicit_dir, const char *program,
                                  char *error, size_t size)
{
    const char *environment;
    char directory[4096];
    if (explicit_dir) return engine_open(explicit_dir, error, size);
    environment = getenv("PROSARY_DATA_DIR");
    if (environment && environment[0]) return engine_open(environment, error, size);
    if (data_next_to_executable(program, directory, sizeof(directory)))
        return engine_open(directory, error, size);
    if (has_content(PROSARY_DATADIR)) return engine_open(PROSARY_DATADIR, error, size);
    if (has_content("data")) return engine_open("data", error, size);
    if (has_content("Terminal/data")) return engine_open("Terminal/data", error, size);
    snprintf(error, size, "Cannot find content.json; use --data DIR or PROSARY_DATA_DIR.");
    return NULL;
}

static int save_state(const AppState *state, void *context)
{
    return app_state_save(state, (const char *)context);
}

int main(int argc, char **argv)
{
    AppState state;
    ProsaryEngine *engine;
    ProsarySession *session;
    ProsarySelection selection;
    const char *data_dir = NULL, *dump_id = NULL, *value;
    const char *group_names[] = {"joyful", "sorrowful", "glorious", "luminous"};
    char state_path[4096] = "", error[512];
    int i, j, use_state = 1, state_disabled = 0, explicit_prayer = 0, list = 0, reset = 0, result;
    int variant_override = -2, day_override = -2;
    size_t index;

    app_state_defaults(&state);
    if (app_state_path(state_path, sizeof(state_path))) use_state = 0;
    /* Locate state first so explicit command-line selections always override it. */
    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--help") || !strcmp(argv[i], "-h")) { usage(stdout); return 0; }
        if (!strcmp(argv[i], "--version")) { puts("Prosary terminal 0.1"); return 0; }
        if (!strcmp(argv[i], "--no-state")) state_disabled = 1;
        else if (!strcmp(argv[i], "--state") && i + 1 < argc) {
            if (copy_argument(state_path, sizeof(state_path), argv[++i])) goto bad_value;
            use_state = 1;
        }
    }
    if (state_disabled) use_state = 0;
    if (use_state && app_state_load(&state, state_path) < 0)
        fputs("Prosary: resume state could not be read; starting with defaults.\n", stderr);

    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--no-state")) continue;
        if (!strcmp(argv[i], "--list")) { list = 1; continue; }
        if (!strcmp(argv[i], "--restart")) { reset = 1; continue; }
        if (i + 1 >= argc) { fprintf(stderr, "Prosary: missing value or unknown option: %s\n", argv[i]); return 2; }
        value = argv[++i];
        if (!strcmp(argv[i - 1], "--state")) continue;
        else if (!strcmp(argv[i - 1], "--data")) data_dir = value;
        else if (!strcmp(argv[i - 1], "--dump")) dump_id = value;
        else if (!strcmp(argv[i - 1], "--pray")) {
            explicit_prayer = 1;
            if (strcmp(state.devotion_id, value)) {
                state.variant = state.day = -1; reset = 1;
            }
            if (copy_argument(state.devotion_id, sizeof(state.devotion_id), value)) goto bad_value;
        } else if (!strcmp(argv[i - 1], "--language")) {
            value = language_alias(value);
            if (strcmp(state.language, value)) { state.variant = -1; reset = 1; }
            if (copy_argument(state.language, sizeof(state.language), value)) goto bad_value;
        } else if (!strcmp(argv[i - 1], "--ui-language")) {
            if (copy_argument(state.ui_language, sizeof(state.ui_language), language_alias(value))) goto bad_value;
        } else if (!strcmp(argv[i - 1], "--group")) {
            if (!strcmp(value, "today")) state.group = -1;
            else {
                for (j = 0; j < 4 && strcmp(value, group_names[j]); ++j) {}
                if (j == 4) goto bad_value;
                state.group = j;
            }
            reset = 1;
        } else if (!strcmp(argv[i - 1], "--variant")) {
            if (number(value, 0, 1000, &variant_override)) goto bad_value;
            --variant_override; reset = 1;
        } else if (!strcmp(argv[i - 1], "--day")) {
            if (number(value, 1, 1000, &day_override)) goto bad_value;
            --day_override; reset = 1;
        } else {
            fprintf(stderr, "Prosary: unknown option: %s\n", argv[i - 1]);
            return 2;
        }
    }
    /* Saved form/day belong to one devotion. Explicit options apply after all
     * implicit resets, independently of their position on the command line. */
    if (dump_id && strcmp(dump_id, state.devotion_id)) state.variant = state.day = -1;
    if (variant_override != -2) state.variant = variant_override;
    if (day_override != -2) state.day = day_override;
    if (reset) {
        state.step = 0; state.completed = 0;
        state.year = state.month = state.day_of_month = 0;
    }
    if (!valid_prayer_language(state.language) || !valid_ui_language(state.ui_language)) {
        fputs("Prosary: unsupported language code.\n", stderr);
        return 2;
    }
    engine = open_engine(data_dir, argv[0], error, sizeof(error));
    if (!engine) { fprintf(stderr, "Prosary: %s\n", error); return 1; }
    if (explicit_prayer) {
        for (index = 0; index < engine_catalog_count(engine); ++index)
            if (!strcmp(engine_catalog_id(engine, index), state.devotion_id)) break;
        if (index == engine_catalog_count(engine)) {
            fprintf(stderr, "Prosary: unknown devotion: %s\n", state.devotion_id);
            engine_close(engine);
            return 2;
        }
    }
    if (list) {
        for (index = 0; index < engine_catalog_count(engine); ++index)
            printf("%-24s %s\n", engine_catalog_id(engine, index),
                   engine_catalog_name(engine, index, state.language));
        engine_close(engine);
        return 0;
    }
    if (dump_id) {
        memset(&selection, 0, sizeof(selection));
        selection.language = state.language;
        selection.group = state.group;
        selection.variant = state.variant;
        selection.day = state.day;
        session = engine_build(engine, dump_id, &selection, error, sizeof(error));
        if (!session) { fprintf(stderr, "Prosary: %s\n", error); engine_close(engine); return 1; }
        printf("%s (%lu steps)\n", session->title, (unsigned long)session->count);
        for (index = 0; index < session->count; ++index) {
            ProsaryStep *step = &session->steps[index];
            printf("\n%lu. %s [%s%s]\n", (unsigned long)index + 1, step->title, step->language,
                   step->mixed_languages ? "; mixed source languages" :
                   step->used_fallback ? "; sourced fallback" : "");
            if (step->context && step->context[0]) printf("%s\n", step->context);
            printf("\n%s\n", step->body);
        }
        if (session->used_fallback)
            fputs("Prosary: some text uses sourced fallback; affected steps are annotated.\n", stderr);
        result = ferror(stdout) ? 1 : 0;
        engine_session_free(session);
        engine_close(engine);
        return result;
    }
    if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO)) {
        fputs("Prosary: the interface needs a terminal. Use --list or --dump ID for plain text.\n", stderr);
        engine_close(engine);
        return 1;
    }
    if (!setlocale(LC_ALL, "") || MB_CUR_MAX <= 1) {
        fputs("Prosary: cannot use the configured locale; select an installed UTF-8 locale.\n", stderr);
        engine_close(engine);
        return 1;
    }
    result = ui_run(engine, &state, save_state, use_state ? state_path : NULL);
    if (result == 2) fputs("Prosary: progress could not be saved. Check the state file location.\n", stderr);
    else if (result) fputs("Prosary: could not start the terminal interface. Check TERM and your UTF-8 locale.\n", stderr);
    engine_close(engine);
    return result;
bad_value:
    fprintf(stderr, "Prosary: invalid option value near %s.\n", i < argc ? argv[i] : "end of command");
    return 2;
}
