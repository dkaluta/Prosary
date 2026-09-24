#include "app.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

void app_state_defaults(AppState *state)
{
    memset(state, 0, sizeof(*state));
    strcpy(state->devotion_id, "rosary");
    strcpy(state->language, "en");
    strcpy(state->ui_language, "en");
    state->group = state->variant = state->day = -1;
    state->keyboard_arrow_navigation_enabled = 1;
    state->keyboard_space_advance_enabled = 1;
}

int app_state_set_today(AppState *state)
{
    time_t now = time(NULL);
    struct tm *today = localtime(&now);
    if (!today) return -1;
    state->year = today->tm_year + 1900;
    state->month = today->tm_mon + 1;
    state->day_of_month = today->tm_mday;
    return 0;
}

static int valid_date(const AppState *state)
{
    static const int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int leap;
    if (!state->year && !state->month && !state->day_of_month) return 1;
    if (state->year < 1583 || state->year > 9999 || state->month < 1 || state->month > 12) return 0;
    leap = state->year % 4 == 0 && (state->year % 100 != 0 || state->year % 400 == 0);
    return state->day_of_month >= 1 &&
        state->day_of_month <= days[state->month - 1] + (state->month == 2 && leap);
}

static int safe_word(const char *text, size_t capacity)
{
    size_t i;
    if (!text[0]) return 0;
    for (i = 0; i < capacity && text[i]; ++i) {
        unsigned char c = (unsigned char)text[i];
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '-' || c == '_')) return 0;
    }
    return i < capacity;
}

static int valid_state(const AppState *state)
{
    return safe_word(state->devotion_id, sizeof(state->devotion_id)) &&
        safe_word(state->language, sizeof(state->language)) &&
        safe_word(state->ui_language, sizeof(state->ui_language)) &&
        state->step < 100000 && state->group >= -1 && state->group <= 3 &&
        state->variant >= -1 && state->variant < 1000 &&
        state->day >= -1 && state->day < 1000 &&
        (state->completed == 0 || state->completed == 1) &&
        (state->keyboard_arrow_navigation_enabled == 0 || state->keyboard_arrow_navigation_enabled == 1) &&
        (state->keyboard_space_advance_enabled == 0 || state->keyboard_space_advance_enabled == 1) &&
        valid_date(state);
}

int app_state_load(AppState *state, const char *path)
{
    FILE *file;
    AppState next;
    char line[256], key[64], value[160], tail;
    unsigned long step;
    int number;
    unsigned int fields = 0;
    if (!path || !path[0]) return 0;
    file = fopen(path, "r");
    if (!file) return errno == ENOENT ? 0 : -1;
    app_state_defaults(&next);
    if (!fgets(line, sizeof(line), file) || strcmp(line, "prosary-terminal-state 1\n")) {
        fclose(file);
        return -1;
    }
    while (fgets(line, sizeof(line), file)) {
        unsigned int field = 0;
        if (!strchr(line, '\n') || sscanf(line, "%63s %159s %c", key, value, &tail) != 2) goto invalid;
        if (!strcmp(key, "devotion")) {
            if (strlen(value) >= sizeof(next.devotion_id)) goto invalid;
            strcpy(next.devotion_id, value); field = 1;
        } else if (!strcmp(key, "defaultLanguageCode")) {
            if (strlen(value) >= sizeof(next.language)) goto invalid;
            strcpy(next.language, value); field = 2;
        } else if (!strcmp(key, "interfaceLanguageCode")) {
            if (strlen(value) >= sizeof(next.ui_language)) goto invalid;
            strcpy(next.ui_language, value); field = 4;
        } else if (!strcmp(key, "step")) {
            char *end;
            errno = 0;
            step = strtoul(value, &end, 10);
            if (errno || *end || value[0] == '-' || step >= 100000) goto invalid;
            next.step = (size_t)step; field = 8;
        } else {
            char *end;
            long parsed;
            errno = 0;
            parsed = strtol(value, &end, 10);
            if (errno || *end || parsed < -1 || parsed > 9999) goto invalid;
            number = (int)parsed;
            if (!strcmp(key, "group")) { next.group = number; field = 16; }
            else if (!strcmp(key, "variant")) { next.variant = number; field = 32; }
            else if (!strcmp(key, "day")) { next.day = number; field = 64; }
            else if (!strcmp(key, "completed")) { next.completed = number; field = 128; }
            else if (!strcmp(key, "year")) { next.year = number; field = 256; }
            else if (!strcmp(key, "month")) { next.month = number; field = 512; }
            else if (!strcmp(key, "dayOfMonth")) { next.day_of_month = number; field = 1024; }
            else if (!strcmp(key, "keyboardArrowNavigationEnabled")) { next.keyboard_arrow_navigation_enabled = number; field = 2048; }
            else if (!strcmp(key, "keyboardSpaceAdvanceEnabled")) { next.keyboard_space_advance_enabled = number; field = 4096; }
            else goto invalid;
        }
        if (fields & field) goto invalid;
        fields |= field;
    }
    /* Older state files omit the optional keyboard preferences and inherit defaults. */
    if (ferror(file) || (fields & 2047) != 2047 || !valid_state(&next)) goto invalid;
    fclose(file);
    *state = next;
    return 1;
invalid:
    fclose(file);
    return -1;
}

/* mkdir each missing parent, accepting existing directories but never chmod'ing them. */
static int make_parents(const char *path)
{
    char *copy, *at;
    struct stat st;
    copy = malloc(strlen(path) + 1);
    if (!copy) return -1;
    strcpy(copy, path);
    for (at = copy + 1; *at; ++at) {
        if (*at != '/') continue;
        *at = '\0';
        if (mkdir(copy, 0700) != 0 &&
            (errno != EEXIST || stat(copy, &st) != 0 || !S_ISDIR(st.st_mode))) {
            free(copy); return -1;
        }
        *at = '/';
    }
    free(copy);
    return 0;
}

int app_state_save(const AppState *state, const char *path)
{
    char *temporary;
    FILE *file;
    int fd, failed;
    if (!path || !path[0]) return 0;
    if (!valid_state(state) || make_parents(path)) return -1;
    temporary = malloc(strlen(path) + 16);
    if (!temporary) return -1;
    sprintf(temporary, "%s.tmp.XXXXXX", path);
    fd = mkstemp(temporary);
    if (fd < 0) { free(temporary); return -1; }
    file = fdopen(fd, "w");
    if (!file) { close(fd); unlink(temporary); free(temporary); return -1; }
    failed = fprintf(file,
        "prosary-terminal-state 1\n"
        "devotion %s\ndefaultLanguageCode %s\ninterfaceLanguageCode %s\n"
        "step %lu\ngroup %d\nvariant %d\nday %d\ncompleted %d\n"
        "year %d\nmonth %d\ndayOfMonth %d\n"
        "keyboardArrowNavigationEnabled %d\nkeyboardSpaceAdvanceEnabled %d\n",
        state->devotion_id, state->language, state->ui_language,
        (unsigned long)state->step, state->group, state->variant,
        state->day, state->completed, state->year, state->month, state->day_of_month,
        state->keyboard_arrow_navigation_enabled, state->keyboard_space_advance_enabled) < 0;
    if (fflush(file) || fsync(fd)) failed = 1;
    if (fclose(file)) failed = 1;
    if (!failed && rename(temporary, path)) failed = 1;
    if (failed) unlink(temporary);
    free(temporary);
    return failed ? -1 : 0;
}

int app_state_path(char *path, size_t size)
{
    const char *base = getenv("XDG_STATE_HOME");
    int length;
    if (base && base[0] == '/')
        length = snprintf(path, size, "%s/prosary/state", base);
    else {
        base = getenv("HOME");
        if (!base || base[0] != '/') return -1;
        length = snprintf(path, size, "%s/.local/state/prosary/state", base);
    }
    return length < 0 || (size_t)length >= size ? -1 : 0;
}
