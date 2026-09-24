#ifndef PROSARY_ENGINE_H
#define PROSARY_ENGINE_H

#include "compat.h"

#include <stddef.h>

typedef struct ProsaryEngine ProsaryEngine;

typedef struct {
    char *title;
    char *body;
    char *context;
    char *language; /* Language of the body; may differ after sourced fallback. */
    int used_fallback;
    int mixed_languages; /* Composite body contains more than one source language. */
    int decade_index; /* Zero based; -1 outside a decade. */
    int bead_index;   /* One based; 0 for non-minor steps. */
    int bead_count;
    int counter_index;
    int counter_total;
} ProsaryStep;

typedef struct {
    char *title;
    ProsaryStep *steps;
    size_t count;
    int group; /* Effective Rosary group: 0 joyful, 1 sorrowful, 2 glorious, 3 luminous. */
    int variant;
    int day;
    int used_fallback;
} ProsarySession;

typedef struct {
    const char *language; /* NULL means English; fil and iw aliases accepted. */
    int group;   /* -1 means today's mysteries; otherwise 0..3. */
    int variant; /* -1 means language-specific default; otherwise zero based. */
    int day;     /* Zero based for daily devotions; -1 selects today when applicable. */
    int year, month, day_of_month; /* All zero means local today. */
} ProsarySelection;

ProsaryEngine *engine_open(const char *data_dir, char *error, size_t error_size);
void engine_close(ProsaryEngine *engine);
size_t engine_catalog_count(const ProsaryEngine *engine);
const char *engine_catalog_id(const ProsaryEngine *engine, size_t index);
const char *engine_catalog_name(const ProsaryEngine *engine, size_t index,
                                const char *language);
size_t engine_variant_count(const ProsaryEngine *engine, const char *devotion_id);
const char *engine_variant_name(const ProsaryEngine *engine, const char *devotion_id,
                                size_t index, const char *language);
size_t engine_day_count(const ProsaryEngine *engine, const char *devotion_id);
const char *engine_day_name(const ProsaryEngine *engine, const char *devotion_id,
                            size_t index, const char *language);
size_t engine_language_count(void);
const char *engine_language_code(size_t index);
const char *engine_language_name(size_t index);
int engine_language_is_rtl(const char *language);
/* Returned sessions own all strings and survive engine_close. NULL reports an error. */
ProsarySession *engine_build(const ProsaryEngine *engine, const char *devotion_id,
                             const ProsarySelection *selection,
                             char *error, size_t error_size);
void engine_session_free(ProsarySession *session);

#endif
