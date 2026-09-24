#include "engine.h"
#include "json.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>

static void parse_tests(void) {
    char error[256];
    Json *j;
    const char *valid = "{\"unicode\":\"\\u05e9\\u05dc\\u05d5\\u05dd \\ud83d\\ude00\",\"number\":-12,\"array\":[true,null,\"x\"]}";
    const char *invalid[] = {"", "{", "[1,]", "{\"x\":1,\"x\":2}", "01", "1.", "1e", "1e9999", "true false", "\"\\ud800\"", "\"\\udc00\"", "\"\\u0000\"", "\"\\x00\"", "\"\300\200\"", "\"\355\240\200\"", "\"\364\220\200\200\""};
    size_t i;
    j = json_parse(valid, strlen(valid), error, sizeof(error)); assert(j);
    assert(!strcmp(json_text(j, "unicode"), "שלום 😀"));
    assert(json_int(json_get(j, "number"), 0) == -12);
    assert(json_count(json_get(j, "array")) == 3);
    assert(json_bool(json_at(json_get(j, "array"), 0), 0));
    json_free(j);
    /* French locales use comma decimals; JSON always uses a period. */
    (void)setlocale(LC_NUMERIC, "fr_FR.UTF-8");
    j = json_parse("[1.25e-2,0.000001,-0.0,2147483647,-2147483648]", 46, error, sizeof(error));
    assert(j);
    assert(json_at(j, 0)->number > 0.012499 && json_at(j, 0)->number < 0.012501);
    assert(json_at(j, 1)->number > 0.000000999 && json_at(j, 1)->number < 0.000001001);
    assert(json_int(json_at(j, 3), 0) == 2147483647);
    assert(json_int(json_at(j, 4), 0) == (-2147483647 - 1));
    json_free(j); (void)setlocale(LC_NUMERIC, "C");
    for (i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        j = json_parse(invalid[i], strlen(invalid[i]), error, sizeof(error));
        if (j) fprintf(stderr, "Accepted invalid JSON: %s\n", invalid[i]);
        assert(!j && *error);
    }
    { char deep[160]; memset(deep, '[', 79); deep[79] = '0'; memset(deep + 80, ']', 79); deep[159] = 0;
      assert(!json_parse(deep, strlen(deep), error, sizeof(error))); }
    /* json_parse is length-bounded; callers need not supply a NUL terminator. */
    { const char short_input[] = {'[', '1', ']'}; j = json_parse(short_input, sizeof(short_input), error, sizeof(error)); assert(j); json_free(j); }
}
static ProsarySession *build(ProsaryEngine *e, const char *id, ProsarySelection *selection) {
    char error[512];
    ProsarySession *s = engine_build(e, id, selection, error, sizeof(error));
    if (!s) fprintf(stderr, "%s/%s: %s\n", id, selection->language, error);
    assert(s); return s;
}
int main(int argc, char **argv) {
    char error[512];
    const char *data = argc > 1 ? argv[1] : "data";
    ProsaryEngine *e;
    ProsarySelection selection = {"en", 0, -1, 0, 2026, 9, 23};
    ProsarySession *s;
    size_t i, l, cases = 0, fallback_cases = 0, mixed_steps = 0;
    static const size_t expected[] = {79, 7, 63, 90, 69, 18, 17, 6, 5, 16};
    parse_tests();
    e = engine_open(data, error, sizeof(error));
    if (!e) { fprintf(stderr, "%s\n", error); return 1; }
    assert(engine_catalog_count(e) == 10);
    for (i = 0; i < engine_catalog_count(e); ++i) {
        s = build(e, engine_catalog_id(e, i), &selection);
        printf("%s: %lu steps\n", engine_catalog_id(e, i), (unsigned long)s->count);
        if (s->count != expected[i]) fprintf(stderr, "Expected %lu steps\n", (unsigned long)expected[i]);
        assert(s->count == expected[i]); engine_session_free(s);
    }
    /* Every language, variant and day must render real sourced text, never raw keys. */
    for (l = 0; l < engine_language_count(); ++l) {
        selection.language = engine_language_code(l);
        for (i = 0; i < engine_catalog_count(e); ++i) {
            const char *id = engine_catalog_id(e, i);
            size_t v, d, variants = engine_variant_count(e, id), days = engine_day_count(e, id);
            for (v = 0; v < (variants ? variants : 1); ++v) for (d = 0; d < (days ? days : 1); ++d) {
                size_t step;
                selection.variant = variants ? (int)v : -1; selection.day = (int)d;
                s = build(e, id, &selection);
                for (step = 0; step < s->count; ++step) {
                    assert(*s->steps[step].title); assert(*s->steps[step].body); assert(*s->steps[step].language);
                    assert(s->steps[step].bead_index <= s->steps[step].bead_count);
                    mixed_steps += s->steps[step].mixed_languages != 0;
                    if (s->steps[step].used_fallback) assert(s->used_fallback);
                }
                ++cases; fallback_cases += s->used_fallback != 0; engine_session_free(s);
            }
        }
    }
    selection.language = "en"; selection.variant = -1; selection.day = 0;
    for (i = 0; i < 4; ++i) {
        size_t j, beads = 0; selection.group = (int)i; s = build(e, "rosary", &selection);
        for (j = 0; j < s->count; ++j) if (s->steps[j].bead_index) ++beads;
        assert(beads == 50); assert(s->group == (int)i); engine_session_free(s);
    }
    selection.group = -1; selection.year = 2026; selection.month = 4; selection.day_of_month = 5;
    s = build(e, "angelus", &selection); assert(s->count == 1); engine_session_free(s);
    s = build(e, "rosary", &selection); assert(s->group == 2); engine_session_free(s);
    selection.month = 5; selection.day_of_month = 23;
    s = build(e, "angelus", &selection); assert(s->count == 1); engine_session_free(s);
    selection.day_of_month = 24; /* Pentecost is excluded by the existing native calendar. */
    s = build(e, "angelus", &selection); assert(s->count == 7); engine_session_free(s);
    selection.month = 3; selection.day_of_month = 1;
    s = build(e, "rosary", &selection); assert(s->group == 1); engine_session_free(s);
    selection.month = 11; selection.day_of_month = 29;
    s = build(e, "rosary", &selection); assert(s->group == 0); engine_session_free(s);
    selection.month = 12; selection.day_of_month = 20; selection.day = -1;
    s = build(e, "oAntiphons", &selection); assert(s->day == 3); engine_session_free(s);
    selection.language = "arc"; s = build(e, "trisagion", &selection); assert(s->variant == 1); engine_session_free(s);
    selection.language = "en"; selection.variant = 0;
    assert(!engine_build(e, "angelus", &selection, error, sizeof(error)));
    selection.variant = -1; selection.day = 1;
    assert(!engine_build(e, "rosary", &selection, error, sizeof(error)));
    selection.day = -1; selection.variant = 99;
    assert(!engine_build(e, "trisagion", &selection, error, sizeof(error)));
    selection.variant = -1; selection.month = 2; selection.day_of_month = 30;
    assert(!engine_build(e, "rosary", &selection, error, sizeof(error)));
    assert(!engine_build(e, "not-a-devotion", &selection, error, sizeof(error)));
    selection.month = 9; selection.day_of_month = 23; selection.language = "bogus";
    assert(!engine_build(e, "rosary", &selection, error, sizeof(error)));
    selection.language = "en";
    s = build(e, "angelus", &selection); engine_close(e); assert(strstr(s->steps[0].body, "Angel")); engine_session_free(s);
    printf("Passed parser checks and %lu sourced prayer sessions (%lu with explicit fallback; %lu mixed-language steps).\n", (unsigned long)cases, (unsigned long)fallback_cases, (unsigned long)mixed_steps);
    return 0;
}
