#include "engine.h"
#include "json.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <unistd.h>

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
static void angelus_ending(const ProsarySession *session, size_t count) {
    size_t i;
    assert(session->count == count);
    for (i = count - 4; i < count - 1; ++i) {
        assert(!strcmp(session->steps[i].title, "Glory Be"));
        assert(strstr(session->steps[i].body, "Glory be to the Father"));
        assert(session->steps[i].counter_index == (int)(i - (count - 4) + 1));
        assert(session->steps[i].counter_total == 3);
    }
    assert(!strcmp(session->steps[count - 1].title, "For the Faithful Departed"));
    assert(strstr(session->steps[count - 1].body, "Eternal rest"));
}
static void creed_source_tests(ProsaryEngine *e, const char *directory) {
    char path[4096], error[512];
    Json *snapshot;
    const Json *pack, *content = NULL, *source;
    ProsarySelection selection = {"uk", 0, -1, 0, 2026, 9, 23, 0, 0, 0};
    ProsarySession *s;
    snprintf(path, sizeof(path), "%s/content.json", directory);
    snapshot = json_read_file(path, 32u * 1024u * 1024u, error, sizeof(error)); assert(snapshot);
    for (pack = json_get(snapshot, "packs")->child; pack; pack = pack->next)
        if (!strcmp(json_text(json_get(pack, "manifest"), "id"), "rosary")) content = json_get(pack, "content");
    assert(content);
    s = build(e, "rosary", &selection); source = json_get(json_get(content, "uk"), "prayers");
    assert(!strcmp(s->steps[1].body, json_text(source, "symbolumNicaenum")));
    assert(!strcmp(s->steps[1].title, json_text(source, "symbolumNicaenumTitle")));
    assert(strcmp(s->steps[1].body, json_text(source, "symbolumApostolorum")));
    assert(strstr(s->steps[1].body, "що від Отця [і Сина] ісходить")); engine_session_free(s);
    selection.language = "arc"; s = build(e, "rosary", &selection);
    assert(strstr(s->steps[1].body, "הַו דּמֶן אַבָא [ובא] ננפֶק"));
    assert(!strstr(s->steps[1].body, "הַו דּמֶן אַבָא ובא ננפֶק")); engine_session_free(s);
    selection.language = "he-x-gamliel"; s = build(e, "rosary", &selection);
    assert(strstr(s->steps[1].body, "אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]"));
    assert(!strstr(s->steps[1].body, "(וּמִן הַבֵּן)")); engine_session_free(s);
    selection.language = "el"; s = build(e, "rosary", &selection); source = json_get(json_get(content, "el"), "prayers");
    assert(!strcmp(s->steps[1].body, json_text(source, "symbolumNicaenum"))); engine_session_free(s);
    selection.language = "la"; s = build(e, "rosary", &selection);
    source = json_get(json_get(snapshot, "common"), "la");
    assert(!strcmp(s->steps[1].body, json_text(source, "symbolumApostolorum"))); engine_session_free(s);
    selection.language = "he"; s = build(e, "rosary", &selection); source = json_get(json_get(snapshot, "common"), "he-x-vicariate");
    assert(!strcmp(s->steps[1].body, json_text(source, "symbolumApostolorum"))); engine_session_free(s);
    /* The generated source remains unchanged after all runtime presentations. */
    assert(strstr(json_text(json_get(json_get(content, "arc"), "prayers"), "symbolumNicaenum"), "הַו דּמֶן אַבָא ובא ננפֶק"));
    json_free(snapshot);
}
static void creed_policy_fixture_tests(void) {
    static const char fixture[] =
        "{\"schemaVersion\":1,\"common\":{},\"packs\":[{\"manifest\":{\"id\":\"rosary\",\"displayName\":\"Fixture\"},"
        "\"devotion\":{\"type\":\"steps\",\"steps\":[{\"titleKey\":\"symbolumApostolorumTitle\",\"bodyKey\":\"symbolumApostolorum\"},"
        "{\"titleKey\":\"symbolumNicaenumTitle\",\"bodyKey\":\"symbolumNicaenum\"}]},\"content\":{"
        "\"arc\":{\"$creedPolicy\":{\"apostlesCreed\":false,\"filioque\":\"bracketed\"},\"prayers\":{"
        "\"symbolumNicaenumTitle\":\"Source Creed\",\"symbolumNicaenum\":\"ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ\"}},"
        "\"la\":{\"$creedPolicy\":{\"apostlesCreed\":true,\"filioque\":\"unbracketed\"},\"prayers\":{"
        "\"symbolumApostolorumTitle\":\"Latin source\",\"symbolumApostolorum\":\"qui ex Patre [Filioque] procedit\","
        "\"symbolumNicaenumTitle\":\"Latin source\",\"symbolumNicaenum\":\"qui ex Patre (Filioque) procedit. Qui cum Patre et Filio\"}},"
        "\"en\":{\"prayers\":{\"symbolumApostolorumTitle\":\"Untagged source\",\"symbolumApostolorum\":\"qui ex Patre [Filioque] procedit\"}},"
        "\"ar\":{\"$creedPolicy\":{\"apostlesCreed\":false,\"filioque\":\"absent\"},\"prayers\":{"
        "\"symbolumNicaenumTitle\":\"Source Creed\",\"symbolumNicaenum\":\"qui ex Patre Filioque procedit. Qui cum Patre et Filio\"}},"
        "\"it\":{\"$creedPolicy\":{\"apostlesCreed\":false,\"filioque\":\"unbracketed\"},\"prayers\":{"
        "\"symbolumNicaenumTitle\":\"Source Creed\",\"symbolumNicaenum\":\"τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον\"}},"
        "\"he\":{\"$creedPolicy\":{\"apostlesCreed\":true,\"filioque\":\"unbracketed\"},\"$prayerTraditionByKey\":{"
        "\"symbolumApostolorum\":\"vicariate\",\"symbolumApostolorumTitle\":\"vicariate\","
        "\"symbolumNicaenum\":\"vicariate\",\"symbolumNicaenumTitle\":\"vicariate\"},\"prayers\":{"
        "\"symbolumApostolorumTitle\":\"Vicariate source\",\"symbolumApostolorum\":\"Vicariate Apostles body\","
        "\"symbolumNicaenumTitle\":\"Vicariate source\",\"symbolumNicaenum\":\"הַנּוֹבֵעַ מֵהָאָב [וּמֵהַבֵּן]\"}},"
        "\"fr\":{\"$creedPolicy\":{\"apostlesCreed\":true,\"filioque\":\"bracketed\"},\"prayers\":{}},"
        "\"el\":{\"$creedPolicy\":{\"apostlesCreed\":false,\"filioque\":\"absent\"},\"prayers\":{"
        "\"symbolumApostolorumTitle\":\"Retained historical title\",\"symbolumApostolorum\":\"Retained historical body\"}}}},"
        "{\"manifest\":{\"id\":\"other\",\"displayName\":\"Other devotion\"},\"content\":{},"
        "\"devotion\":{\"type\":\"steps\",\"steps\":[{\"titleKey\":\"symbolumApostolorumTitle\",\"bodyKey\":\"symbolumApostolorum\"}]}}]}";
    char temporary[] = "/tmp/prosary-creed.XXXXXX", path[4096], error[512];
    FILE *file;
    ProsaryEngine *e;
    ProsarySession *s;
    ProsarySelection selection = {"en", 0, -1, 0, 2026, 9, 23, 0, 0, 0};
    assert(mkdtemp(temporary)); snprintf(path, sizeof(path), "%s/content.json", temporary);
    file = fopen(path, "wb"); assert(file);
    assert(fwrite(fixture, 1, sizeof(fixture) - 1, file) == sizeof(fixture) - 1); assert(!fclose(file));
    e = engine_open(temporary, error, sizeof(error)); assert(e);
    s = build(e, "rosary", &selection);
    assert(!strcmp(s->steps[0].body, "qui ex Patre [Filioque] procedit")); /* Untagged text is exact. */
    assert(!strcmp(s->steps[1].body, "qui ex Patre Filioque procedit. Qui cum Patre et Filio"));
    assert(s->steps[1].used_fallback); assert(!strcmp(s->steps[1].language, "la")); engine_session_free(s);
    selection.language = "fr"; s = build(e, "rosary", &selection);
    assert(!strcmp(s->steps[0].body, "qui ex Patre Filioque procedit")); /* Actual Latin owner, not requested French tag. */
    engine_session_free(s);
    selection.language = "ar"; s = build(e, "rosary", &selection);
    assert(!strcmp(s->steps[0].body, "qui ex Patre procedit. Qui cum Patre et Filio")); engine_session_free(s);
    selection.language = "it"; s = build(e, "rosary", &selection);
    assert(!strcmp(s->steps[0].body, "τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον")); engine_session_free(s);
    selection.language = "he"; s = build(e, "rosary", &selection);
    assert(!strcmp(s->steps[0].body, "Vicariate Apostles body"));
    assert(!strcmp(s->steps[1].body, "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן"));
    assert(!s->steps[1].used_fallback); engine_session_free(s);
    selection.language = "el";
    assert(!engine_build(e, "rosary", &selection, error, sizeof(error)));
    assert(strstr(error, "Missing same-source Nicene Creed")); /* No Latin leak. */
    selection.language = "arc"; s = build(e, "other", &selection); engine_close(e);
    assert(!strcmp(s->steps[0].title, "Source Creed"));
    assert(!strcmp(s->steps[0].body, "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ"));
    engine_session_free(s); assert(!unlink(path)); assert(!rmdir(temporary));
}
int main(int argc, char **argv) {
    char error[512];
    const char *data = argc > 1 ? argv[1] : "data";
    ProsaryEngine *e;
    ProsarySelection selection = {"en", 0, -1, 0, 2026, 9, 23, 0, 0, 0};
    ProsarySession *s;
    size_t i, l, cases = 0, fallback_cases = 0, mixed_steps = 0;
    static const size_t expected[] = {80, 11, 63, 90, 69, 18, 17, 6, 5, 16};
    parse_tests(); creed_policy_fixture_tests();
    e = engine_open(data, error, sizeof(error));
    if (!e) { fprintf(stderr, "%s\n", error); return 1; }
    assert(engine_catalog_count(e) == 10);
    creed_source_tests(e, data);
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
    selection.variant = -1; selection.day = 0;
    for (l = 0; l < engine_language_count(); ++l) {
        int litany, collect, season;
        selection.language = engine_language_code(l);
        for (season = 0; season < 2; ++season) {
            selection.month = season ? 4 : 9; selection.day_of_month = season ? 5 : 23;
            for (litany = 0; litany <= 1; ++litany) for (collect = 0; collect <= 1; ++collect) {
                ProsarySession *standalone;
                size_t j, matches = 0;
                selection.include_litany_of_loreto = litany; selection.omit_rosary_collect = !collect;
                s = build(e, "rosary", &selection);
                standalone = build(e, "litanyOfLoreto", &selection);
                assert(standalone->count == 16);
                assert(s->count == (size_t)(79 + (litany || collect) + litany * 15));
                if (litany || collect) {
                    const char *body = s->steps[s->count - 2].body;
                    for (j = 0; j < s->count; ++j) if (!strcmp(body, s->steps[j].body)) ++matches;
                    assert(matches == 1);
                }
                if (litany) {
                    size_t start = s->count - 17;
                    for (j = 0; j < 15; ++j) {
                        assert(!strcmp(s->steps[start + j].body, standalone->steps[j].body));
                        assert(!strcmp(s->steps[start + j].title, standalone->steps[j].title));
                        if (!strcmp(selection.language, "arc")) {
                            assert(!strcmp(s->steps[start + j].language, "la"));
                            assert(s->steps[start + j].used_fallback);
                        }
                    }
                    assert(strcmp(s->steps[s->count - 2].body, standalone->steps[15].body));
                }
                engine_session_free(standalone); engine_session_free(s);
            }
        }
    }
    selection.include_litany_of_loreto = selection.omit_rosary_collect = 0;
    selection.month = 9; selection.day_of_month = 23;
    selection.language = "en"; selection.variant = -1; selection.day = 0;
    for (i = 0; i < 4; ++i) {
        size_t j, beads = 0; selection.group = (int)i; s = build(e, "rosary", &selection);
        for (j = 0; j < s->count; ++j) if (s->steps[j].bead_index) ++beads;
        assert(beads == 50); assert(s->group == (int)i); engine_session_free(s);
        selection.skip_fifth_decade = 1;
        s = build(e, "rosary", &selection); beads = 0;
        for (j = 0; j < s->count; ++j) {
            if (s->steps[j].bead_index) ++beads;
        }
        assert(beads == 50); /* Retired saved flags cannot remove the fifth decade. */
        assert(s->steps[s->count - 1].decade_index == -1);
        assert(strstr(s->steps[s->count - 1].body, "Father"));
        engine_session_free(s);
        selection.skip_fifth_decade = 0;
    }
    selection.group = -1; selection.year = 2026; selection.month = 4; selection.day_of_month = 5;
    s = build(e, "angelus", &selection); angelus_ending(s, 5); engine_session_free(s);
    s = build(e, "rosary", &selection); assert(s->group == 2); engine_session_free(s);
    selection.month = 5; selection.day_of_month = 23;
    s = build(e, "angelus", &selection); angelus_ending(s, 5); engine_session_free(s);
    selection.day_of_month = 24; /* Pentecost is excluded by the existing native calendar. */
    s = build(e, "angelus", &selection); angelus_ending(s, 11); engine_session_free(s);
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
