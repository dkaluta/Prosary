#ifndef PROSARY_APP_H
#define PROSARY_APP_H

#include "compat.h"
#include <stddef.h>

/* Small, versioned state file; no native app's settings are read or changed. */
typedef struct {
    char devotion_id[80];
    char language[32];
    char ui_language[16];
    size_t step;
    int group;       /* -1 means automatic until a session is first started. */
    int variant;    /* -1 means language default. */
    int day;        /* -1 means automatic. */
    int completed;
    int keyboard_arrow_navigation_enabled;
    int keyboard_space_advance_enabled;
    int year, month, day_of_month; /* The session's liturgical date; zero before starting. */
} AppState;

/* Return zero on success (including intentionally disabled saving), nonzero on failure. */
typedef int (*AppSave)(const AppState *state, void *context);

void app_state_defaults(AppState *state);
int app_state_set_today(AppState *state);
int app_state_load(AppState *state, const char *path);
int app_state_save(const AppState *state, const char *path);
int app_state_path(char *path, size_t size);

#endif
