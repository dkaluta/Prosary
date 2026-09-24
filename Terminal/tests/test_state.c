#include "app.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int main(void)
{
    char directory[] = "/tmp/prosary-state-test.XXXXXX", path[256];
    AppState saved, loaded, original;
    struct stat st;
    FILE *file;
    assert(mkdtemp(directory));
    assert(snprintf(path, sizeof(path), "%s/nested/state", directory) > 0);
    app_state_defaults(&saved);
    assert(saved.keyboard_arrow_navigation_enabled && saved.keyboard_space_advance_enabled);
    assert(app_state_load(&saved, path) == 0);
    saved.step = 34;
    saved.group = 2;
    saved.variant = 1;
    saved.day = 3;
    saved.year = 2026; saved.month = 9; saved.day_of_month = 23;
    strcpy(saved.language, "uk");
    strcpy(saved.ui_language, "he");
    assert(app_state_save(&saved, path) == 0);
    assert(stat(path, &st) == 0 && (st.st_mode & 0777) == 0600);
    app_state_defaults(&loaded);
    assert(app_state_load(&loaded, path) == 1);
    assert(!strcmp(loaded.devotion_id, saved.devotion_id));
    assert(!strcmp(loaded.language, "uk") && !strcmp(loaded.ui_language, "he"));
    assert(loaded.step == 34 && loaded.group == 2 && loaded.variant == 1 && loaded.day == 3);
    assert(loaded.year == 2026 && loaded.month == 9 && loaded.day_of_month == 23);

    saved.completed = 1;
    saved.step = 75;
    saved.keyboard_arrow_navigation_enabled = 0;
    saved.keyboard_space_advance_enabled = 0;
    assert(app_state_save(&saved, path) == 0);
    assert(app_state_load(&loaded, path) == 1 && loaded.completed && loaded.step == 75);
    assert(!loaded.keyboard_arrow_navigation_enabled && !loaded.keyboard_space_advance_enabled);
    original = loaded;

    file = fopen(path, "a"); assert(file);
    fputs("step 13\n", file); fclose(file);
    assert(app_state_load(&loaded, path) == -1);
    assert(!memcmp(&loaded, &original, sizeof(loaded)));

    file = fopen(path, "w"); assert(file);
    fputs("prosary-terminal-state 1\ndevotion rosary\n", file); fclose(file);
    assert(app_state_load(&loaded, path) == -1);
    assert(loaded.step == 75);
    file = fopen(path, "w"); assert(file);
    fputs("prosary-terminal-state 1\ndevotion rosary\ndefaultLanguageCode en\n"
          "interfaceLanguageCode en\nstep 5\ngroup 0\nvariant 0\nday 0\ncompleted 0\n"
          "year 2026\nmonth 9\ndayOfMonth 23\n", file); fclose(file);
    assert(app_state_load(&loaded, path) == 1 && loaded.step == 5);
    assert(loaded.keyboard_arrow_navigation_enabled && loaded.keyboard_space_advance_enabled);
    file = fopen(path, "a"); assert(file);
    fputs("keyboardSpaceAdvanceEnabled 2\n", file); fclose(file);
    assert(app_state_load(&loaded, path) == -1 && loaded.step == 5);
    saved.step = (size_t)-1;
    assert(app_state_save(&saved, path) == -1);
    saved.step = 1;
    saved.month = 2; saved.day_of_month = 30;
    assert(app_state_save(&saved, path) == -1);
    assert(app_state_set_today(&saved) == 0);
    assert(saved.year >= 1583 && saved.month >= 1 && saved.month <= 12);
    strcpy(saved.language, "en\nstep 9");
    assert(app_state_save(&saved, path) == -1);
    assert(app_state_save(&saved, NULL) == 0);

    assert(setenv("XDG_STATE_HOME", directory, 1) == 0);
    assert(app_state_path(path, sizeof(path)) == 0);
    assert(strstr(path, "/prosary/state"));
    assert(app_state_path(path, 2) == -1);
    snprintf(path, sizeof(path), "%s/nested/state", directory);
    assert(unlink(path) == 0);
    snprintf(path, sizeof(path), "%s/nested", directory);
    assert(rmdir(path) == 0);
    assert(rmdir(directory) == 0);
    puts("State tests passed: resume, atomic replacement, permissions, invalid input.");
    return 0;
}
