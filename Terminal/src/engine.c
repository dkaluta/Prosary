#include "engine.h"
#include "json.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdarg.h>

#define MAX_STEPS 4096
#define MAX_TEXT (1024u * 1024u)

struct ProsaryEngine { Json *root; const Json *packs; };
typedef struct {
    const ProsaryEngine *engine;
    const Json *pack;
    ProsarySession *session;
    const char *language;
    char *error;
    size_t error_size;
    int failed, season, step_fallback, step_mixed;
} Builder;
static const char *language_codes[] = {"en", "he", "ar", "ru", "tl", "fr", "it", "uk", "la", "es", "el", "arc", "he-x-gamliel"};
static const char *language_names[] = {"English", "עברית", "العربية", "Русский", "Filipino", "Français", "Italiano", "Українська", "Latina", "Español", "Ελληνικά", "ܐܪܡܐܝܬ / ארמית", "עברית — גמליאל"};
static const char *groups[] = {"joyful", "sorrowful", "glorious", "luminous"};

static int equal(const char *a, const char *b) { return a && b && !strcmp(a, b); }
static const char *normalized(const char *language) {
    if (!language || !*language) return "en";
    if (equal(language, "fil")) return "tl";
    if (equal(language, "iw")) return "he";
    return language;
}
static char *copy(const char *s) {
    size_t n;
    char *out;
    if (!s) s = "";
    n = strlen(s);
    if (n > MAX_TEXT) return NULL;
    out = (char *)malloc(n + 1);
    if (out) memcpy(out, s, n + 1);
    return out;
}
static void errorf(char *error, size_t size, const char *format, ...) {
    va_list ap;
    if (!error || !size) return;
    va_start(ap, format); vsnprintf(error, size, format, ap); va_end(ap);
}
static void build_error(Builder *b, const char *message, const char *detail) {
    if (!b->failed) errorf(b->error, b->error_size, "%s%s%s", message, detail ? ": " : "", detail ? detail : "");
    b->failed = 1;
}
static const Json *pack_by_id(const ProsaryEngine *e, const char *id) {
    const Json *p;
    if (!e || !id) return NULL;
    for (p = e->packs->child; p; p = p->next)
        if (equal(json_text(json_get(p, "manifest"), "id"), id)) return p;
    return NULL;
}
ProsaryEngine *engine_open(const char *dir, char *error, size_t error_size) {
    char path[4096];
    ProsaryEngine *e;
    const Json *p;
    int n;
    if (error && error_size) *error = '\0';
    if (!dir || !*dir) { errorf(error, error_size, "Missing content directory"); return NULL; }
    n = snprintf(path, sizeof(path), "%s/content.json", dir);
    if (n < 0 || (size_t)n >= sizeof(path)) { errorf(error, error_size, "Content path too long"); return NULL; }
    e = (ProsaryEngine *)calloc(1, sizeof(*e));
    if (!e) { errorf(error, error_size, "Out of memory"); return NULL; }
    e->root = json_read_file(path, 32u * 1024u * 1024u, error, error_size);
    if (!e->root) { free(e); return NULL; }
    e->packs = json_get(e->root, "packs");
    if (json_int(json_get(e->root, "schemaVersion"), 0) != 1 || !e->packs || e->packs->type != JSON_ARRAY || !json_count(e->packs) || json_count(e->packs) > 64 || !json_get(e->root, "common")) {
        errorf(error, error_size, "Unsupported terminal content format"); engine_close(e); return NULL;
    }
    for (p = e->packs->child; p; p = p->next) {
        const Json *other;
        const Json *manifest = json_get(p, "manifest");
        const char *id = json_text(manifest, "id");
        if (!id || !*id || strlen(id) > 120 || !json_text(manifest, "displayName") || !json_get(p, "devotion") || !json_get(p, "content")) {
            errorf(error, error_size, "Incomplete devotion metadata"); engine_close(e); return NULL;
        }
        for (other = p->next; other; other = other->next)
            if (equal(id, json_text(json_get(other, "manifest"), "id"))) {
                errorf(error, error_size, "Duplicate devotion ID: %s", id); engine_close(e); return NULL;
            }
    }
    return e;
}
void engine_close(ProsaryEngine *e) { if (e) { json_free(e->root); free(e); } }
size_t engine_catalog_count(const ProsaryEngine *e) { return e ? json_count(e->packs) : 0; }
const char *engine_catalog_id(const ProsaryEngine *e, size_t i) { return e ? json_text(json_get(json_at(e->packs, i), "manifest"), "id") : NULL; }
static const char *localized(const Json *object, const char *key, const char *language) {
    char field[128];
    const char *s;
    language = normalized(language);
    snprintf(field, sizeof(field), "%sByLanguage", key);
    s = json_text(json_get(object, field), language);
    if (!s && !strncmp(language, "he-", 3)) s = json_text(json_get(object, field), "he");
    return s ? s : json_text(object, key);
}
const char *engine_catalog_name(const ProsaryEngine *e, size_t i, const char *language) {
    return e ? localized(json_get(json_at(e->packs, i), "manifest"), "displayName", language) : NULL;
}
size_t engine_variant_count(const ProsaryEngine *e, const char *id) { return json_count(json_get(json_get(pack_by_id(e, id), "devotion"), "variants")); }
const char *engine_variant_name(const ProsaryEngine *e, const char *id, size_t i, const char *language) {
    return localized(json_at(json_get(json_get(pack_by_id(e, id), "devotion"), "variants"), i), "name", language);
}
size_t engine_day_count(const ProsaryEngine *e, const char *id) { return json_count(json_get(json_get(pack_by_id(e, id), "devotion"), "days")); }
const char *engine_day_name(const ProsaryEngine *e, const char *id, size_t i, const char *language) {
    return localized(json_at(json_get(json_get(pack_by_id(e, id), "devotion"), "days"), i), "name", language);
}
size_t engine_language_count(void) { return sizeof(language_codes) / sizeof(language_codes[0]); }
const char *engine_language_code(size_t i) { return i < engine_language_count() ? language_codes[i] : NULL; }
const char *engine_language_name(size_t i) { return i < engine_language_count() ? language_names[i] : NULL; }
int engine_language_is_rtl(const char *language) { language = normalized(language); return equal(language, "he") || !strncmp(language, "he-", 3) || equal(language, "ar") || equal(language, "arc"); }

/* The preview has a fixed, explicit sourced fallback: requested wording, generic
 * Hebrew and Vicariate where relevant, then Latin. It never synthesizes text. */
static size_t fallback_chain(const char *lang, const char **chain) {
    size_t n = 0;
    chain[n++] = lang;
    if (equal(lang, "he-x-gamliel")) chain[n++] = "he";
    if (equal(lang, "he") || equal(lang, "he-x-gamliel")) chain[n++] = "he-x-vicariate";
    if (!equal(lang, "la")) chain[n++] = "la";
    return n;
}
static const char *lookup_at(Builder *b, const char *lang, const char *key) {
    const Json *content = json_get(b->pack, "content");
    const Json *local;
    const char *s, *marked;
    int vicariate = equal(lang, "he-x-vicariate");
    local = json_get(content, vicariate ? "he" : lang);
    marked = json_text(json_get(local, "$prayerTraditionByKey"), key);
    s = json_text(json_get(local, "prayers"), key);
    if (equal(lang, "he") && equal(marked, "vicariate")) s = NULL;
    if (vicariate && !equal(marked, "vicariate")) s = NULL;
    if (s && *s) return s;
    s = json_text(json_get(json_get(b->engine->root, "common"), lang), key);
    return s && *s ? s : NULL;
}
static const char *prayer(Builder *b, const char *key, const char **actual) {
    const char *chain[5], *s;
    size_t n, i;
    if (!key) { if (actual) *actual = b->language; return ""; }
    if (equal(key, "signumCrucisFormB") && !equal(b->language, "arc")) key = "signumCrucis";
    n = fallback_chain(b->language, chain);
    for (i = 0; i < n; ++i) {
        s = lookup_at(b, chain[i], key);
        if (s) {
            const char *public_lang = equal(chain[i], "he-x-vicariate") ? "he" : chain[i];
            if (actual) *actual = public_lang;
            if (!equal(public_lang, b->language)) b->session->used_fallback = b->step_fallback = 1;
            return s;
        }
    }
    build_error(b, "Missing sourced prayer", key);
    if (actual) *actual = b->language;
    return "";
}
static const char *mystery(Builder *b, const char *key, const char *field, const char **actual, int required) {
    const char *chain[5], *s;
    size_t i, n = fallback_chain(b->language, chain);
    const Json *table = json_get(b->engine->root, "mysteries");
    for (i = 0; i < n; ++i) {
        s = json_text(json_get(json_get(table, chain[i]), key), field);
        if (s && *s) {
            if (actual) *actual = chain[i];
            if (!equal(chain[i], b->language)) b->session->used_fallback = b->step_fallback = 1;
            return s;
        }
    }
    if (required) build_error(b, "Missing sourced mystery field", key);
    if (actual) *actual = b->language;
    return "";
}
static char *joined(Builder *b, const char *left, const char *separator, const char *right) {
    size_t a = strlen(left), s = strlen(separator), c = strlen(right);
    char *out;
    if (a > MAX_TEXT || c > MAX_TEXT || a + s + c > MAX_TEXT) { build_error(b, "Prayer text too large", NULL); return NULL; }
    out = (char *)malloc(a + s + c + 1);
    if (!out) { build_error(b, "Out of memory", NULL); return NULL; }
    memcpy(out, left, a); memcpy(out + a, separator, s); memcpy(out + a + s, right, c + 1); return out;
}
static void append(Builder *b, const char *title, const char *body, const char *context,
                   const char *lang, int decade, int bead, int count, int ci, int ct) {
    ProsaryStep *step, *resized;
    if (b->failed) return;
    if (b->session->count >= MAX_STEPS) { build_error(b, "Devotion exceeds step limit", NULL); return; }
    resized = (ProsaryStep *)realloc(b->session->steps, (b->session->count + 1) * sizeof(*resized));
    if (!resized) { build_error(b, "Out of memory", NULL); return; }
    b->session->steps = resized;
    step = &resized[b->session->count++]; memset(step, 0, sizeof(*step));
    step->title = copy(title); step->body = copy(body); step->context = copy(context); step->language = copy(lang);
    step->used_fallback = b->step_fallback; step->mixed_languages = b->step_mixed;
    step->decade_index = decade; step->bead_index = bead; step->bead_count = count;
    step->counter_index = ci; step->counter_total = ct;
    if (!step->title || !step->body || !step->context || !step->language) build_error(b, "Out of memory or excessive text", NULL);
}
static const Json *option(Builder *b, const char *key) {
    const Json *options = json_get(json_get(b->pack, "options"), "options"), *item;
    for (item = options ? options->child : NULL; item; item = item->next)
        if (equal(json_text(item, "key"), key)) return json_get(item, "default");
    return NULL;
}
static int condition(Builder *b, const char *expression) {
    const char *p = expression;
    int answer = 1;
    if (!p) return 1;
    while (*p) {
        char key[128], expected[128];
        size_t n = 0;
        int negate = 0, truth;
        const Json *v;
        while (*p == ' ') ++p;
        if (*p == '!') { negate = 1; ++p; }
        while (*p && *p != ' ' && *p != '&' && *p != '=') {
            if (n + 1 >= sizeof(key)) { build_error(b, "Condition too long", NULL); return 0; }
            key[n++] = *p++;
        }
        key[n] = '\0';
        if (!n) { build_error(b, "Invalid condition", expression); return 0; }
        while (*p == ' ') ++p;
        v = option(b, key);
        truth = equal(key, "isLent") ? b->season == 1 : json_bool(v, 0);
        if (*p == '=') {
            ++p; n = 0;
            while (*p == ' ') ++p;
            while (*p && *p != ' ' && *p != '&') {
                if (n + 1 >= sizeof(expected)) { build_error(b, "Condition too long", NULL); return 0; }
                expected[n++] = *p++;
            }
            expected[n] = '\0'; truth = equal(json_string(v), expected);
        }
        if (negate) truth = !truth;
        if (!truth) answer = 0;
        while (*p == ' ') ++p;
        if (*p && *p++ != '&') { build_error(b, "Unsupported condition", expression); return 0; }
        if (!*p && p > expression && p[-1] == '&') { build_error(b, "Invalid condition", expression); return 0; }
    }
    return answer;
}
static void antiphon(Builder *b, const Json *entry) {
    const char *which = NULL, *lang, *component_lang, *title, *body, *verse, *response, *collect;
    const char *choice = json_text(entry, "optionKey");
    char key[128];
    char *a, *c, *d;
    int paschal;
    if (choice) which = json_string(option(b, choice));
    if (equal(which, "none")) return;
    if (!which || equal(which, "seasonal")) which = b->season == 1 ? "aveReginaCaelorum" : b->season == 2 ? "reginaCaeli" : b->season == 3 ? "almaRedemptorisMater" : "salveRegina";
    snprintf(key, sizeof(key), "%sTitle", which);
    title = prayer(b, key, NULL); body = prayer(b, which, &lang);
    if (equal(which, "subTuumPraesidium")) { append(b, title, body, "", lang, -1, 0, 0, 0, 0); return; }
    paschal = equal(which, "reginaCaeli");
    verse = prayer(b, paschal ? "versiculumPaschale" : "versiculumStandard", &component_lang);
    if (!equal(lang, component_lang)) b->step_mixed = 1;
    response = prayer(b, paschal ? "responsiumPaschale" : "responsiumStandard", &component_lang);
    if (!equal(lang, component_lang)) b->step_mixed = 1;
    collect = prayer(b, paschal ? "collectaPaschale" : "collectaStandard", &component_lang);
    if (!equal(lang, component_lang)) b->step_mixed = 1;
    a = joined(b, body, "\n\n", verse);
    c = a ? joined(b, a, "\n", response) : NULL;
    d = c ? joined(b, c, "\n\n", collect) : NULL;
    if (d) append(b, title, d, "", lang, -1, 0, 0, 0, 0);
    free(a); free(c); free(d);
}
static void entry(Builder *b, const Json *e, const char *context, int decade, int bead, int beads) {
    const char *title, *body, *subtitle, *lang, *key, *kind;
    char *composed = NULL;
    int repeat, i, ci, ct;
    b->step_fallback = b->step_mixed = 0;
    if (!e || e->type != JSON_OBJECT) { build_error(b, "Invalid prayer entry", NULL); return; }
    if (!condition(b, json_text(e, "if"))) return;
    kind = json_text(e, "kind");
    if (kind) {
        if (equal(kind, "marianAntiphon") || equal(kind, "seasonalMarianAntiphon")) antiphon(b, e);
        else build_error(b, "Unsupported prayer entry", kind);
        return;
    }
    key = json_text(e, "titleKey"); title = key ? prayer(b, key, NULL) : json_text(e, "title");
    body = prayer(b, json_text(e, "bodyKey"), &lang);
    key = json_text(e, "subtitleKey"); subtitle = key ? prayer(b, key, NULL) : json_text(e, "subtitle");
    if (!subtitle) subtitle = context ? context : "";
    key = json_text(e, "acclamationKey");
    if (key) {
        const char *component_lang, *acclamation = prayer(b, key, &component_lang);
        if (!equal(lang, component_lang)) b->step_mixed = 1;
        composed = joined(b, body, "\n\n", acclamation); if (composed) body = composed;
    }
    repeat = json_int(json_get(e, "repeat"), 1);
    if (repeat < 1 || repeat > MAX_STEPS) { free(composed); build_error(b, "Invalid repeat count", NULL); return; }
    for (i = 1; i <= repeat; ++i) {
        ci = repeat > 1 ? i : json_int(json_get(e, "counterIndex"), 0);
        ct = repeat > 1 ? repeat : json_int(json_get(e, "counterTotal"), 0);
        append(b, title ? title : "", body, subtitle, lang, decade, bead, beads, ci, ct);
    }
    free(composed);
}
static void entries(Builder *b, const Json *list, const char *context, int decade, int beads) {
    const Json *e;
    if (!list) return;
    if (list->type != JSON_ARRAY) { build_error(b, "Expected step list", NULL); return; }
    for (e = list->child; e && !b->failed; e = e->next) entry(b, e, context, decade, 0, beads);
}
static void rosary(Builder *b, const Json *form, int group) {
    const Json *decades = json_get(form, "decades"), *items = json_get(decades, "entries"), *item;
    const char *source = json_text(decades, "source"), *noun, *key;
    int count, beads, i;
    if (!decades || decades->type != JSON_OBJECT) { build_error(b, "Missing decades", NULL); return; }
    beads = json_int(json_get(decades, "minorCount"), 0);
    if (beads < 1 || beads > 100) { build_error(b, "Invalid bead count", NULL); return; }
    entries(b, json_get(form, "opening"), "", -1, 0);
    if (equal(source, "mysteryGroups")) items = json_get(json_get(b->pack, "catalog"), "mysteries");
    count = items ? (int)json_count(items) : json_int(json_get(decades, "count"), 0);
    if (count < 1 || count > 100) { build_error(b, "Invalid decade count", NULL); return; }
    key = json_text(decades, "ordinalNounKey"); noun = key ? prayer(b, key, NULL) : json_text(decades, "ordinalNoun");
    if (!noun) noun = "";
    for (i = 0; i < count && !b->failed; ++i) {
        const char *title = "", *body, *lang, *fruit, *fruit_lang;
        char ordinal[128];
        char *context, *body_with_fruit = NULL;
        int j, decade_index = i, number = i + 1;
        item = items ? json_at(items, (size_t)i) : NULL;
        if (source) {
            if (!equal(source, "mysteryGroups")) { build_error(b, "Unsupported decade source", source); return; }
            if (!equal(json_text(item, "group"), groups[group])) continue;
            number = json_int(json_get(item, "order"), 0); decade_index = number - 1;
            if (number < 1 || number > 5) { build_error(b, "Invalid mystery order", NULL); return; }
        }
        b->step_fallback = b->step_mixed = 0;
        key = item ? json_text(item, "imageKey") : json_text(decades, "fixedImageKey");
        if (json_bool(json_get(decades, "announceMystery"), 0)) title = mystery(b, key, "title", NULL, 1);
        snprintf(ordinal, sizeof(ordinal), "%s %d", noun, number);
        context = *title ? joined(b, ordinal, " — ", title) : copy(ordinal);
        if (!context) { build_error(b, "Out of memory", NULL); return; }
        entries(b, json_get(decades, "preAnnouncement"), context, -1, 0);
        if (json_bool(json_get(decades, "announceMystery"), 0)) {
            body = mystery(b, key, "description", &lang, 1);
            fruit = mystery(b, key, "fruit", &fruit_lang, 0);
            if (*fruit) {
                const char *label_lang, *label = prayer(b, "fructusMysteriiLabel", &label_lang);
                char *f = joined(b, label, ": ", fruit);
                if (!equal(lang, fruit_lang) || !equal(lang, label_lang)) b->step_mixed = 1;
                if (f) body_with_fruit = joined(b, body, "\n\n", f);
                free(f);
            }
            append(b, title, body_with_fruit ? body_with_fruit : body, context, lang, decade_index, 0, beads, 0, 0);
            free(body_with_fruit);
        }
        entry(b, json_get(decades, "majorStep"), context, decade_index, 0, beads);
        for (j = 1; j <= beads; ++j) entry(b, json_get(decades, "minorStep"), context, decade_index, j, beads);
        entries(b, json_get(decades, "postMinor"), context, decade_index, beads);
        free(context);
    }
    entries(b, json_get(form, "closing"), "", -1, 0);
}

static int leap(int year) { return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0); }
static int civil_day(int year, int month, int day) {
    static const int preceding[] = {0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334};
    int y = year - 1;
    return y * 365 + y / 4 - y / 100 + y / 400 + preceding[month - 1] + (month > 2 && leap(year)) + day - 1;
}
static int easter_day(int year) {
    int a = year % 19, b = year / 100, c = year % 100, d = b / 4, e = b % 4;
    int f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30;
    int i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7;
    int m = (a + 11 * h + 22 * l) / 451, value = h + l - 7 * m + 114;
    return civil_day(year, value / 31, value % 31 + 1);
}
static int calendar(Builder *b, const ProsarySelection *s, int *month, int *day) {
    static const int month_days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    int y = s->year, m = s->month, d = s->day_of_month, date, easter, advent, epiphany, weekday;
    if (!y && !m && !d) {
        time_t now = time(NULL); struct tm *today = localtime(&now);
        if (!today) { build_error(b, "Cannot determine local date", NULL); return 0; }
        y = today->tm_year + 1900; m = today->tm_mon + 1; d = today->tm_mday;
    }
    if (y < 1583 || y > 9999 || m < 1 || m > 12 || d < 1 || d > month_days[m - 1] + (m == 2 && leap(y))) {
        build_error(b, "Invalid Gregorian date", NULL); return 0;
    }
    *month = m; *day = d; date = civil_day(y, m, d); easter = easter_day(y);
    advent = civil_day(y, 11, 27); advent += (7 - (advent + 1) % 7) % 7;
    epiphany = civil_day(y, 1, 7); epiphany += (7 - (epiphany + 1) % 7) % 7;
    b->season = date >= easter - 46 && date < easter ? 1 : date >= easter && date < easter + 49 ? 2 :
        ((date >= advent && m == 12 && d < 25) || (date >= advent && m == 11) || (m == 12 && d >= 25) || date < epiphany) ? 3 : 0;
    weekday = (date + 1) % 7;
    return weekday == 1 || weekday == 6 ? 0 : weekday == 2 || weekday == 5 ? 1 : weekday == 4 ? 3 :
        weekday == 0 && b->season == 3 ? 0 : weekday == 0 && b->season == 1 ? 1 : 2;
}
ProsarySession *engine_build(const ProsaryEngine *e, const char *id, const ProsarySelection *selection, char *error, size_t error_size) {
    ProsarySelection defaults = {"en", -1, -1, -1, 0, 0, 0};
    Builder b;
    const Json *definition, *form, *variants, *days;
    const char *type;
    int group, month = 0, day = 0;
    size_t i;
    if (error && error_size) *error = '\0';
    memset(&b, 0, sizeof(b)); b.engine = e; b.error = error; b.error_size = error_size;
    b.pack = pack_by_id(e, id);
    if (!b.pack) { errorf(error, error_size, "Unknown devotion: %s", id ? id : ""); return NULL; }
    if (!selection) selection = &defaults;
    b.language = normalized(selection->language);
    for (i = 0; i < engine_language_count(); ++i) if (equal(b.language, language_codes[i])) break;
    if (i == engine_language_count()) { errorf(error, error_size, "Unsupported prayer language: %s", b.language); return NULL; }
    if (selection->group < -1 || selection->group > 3 || selection->variant < -1 || selection->day < -1) {
        errorf(error, error_size, "Invalid prayer selection"); return NULL;
    }
    b.session = (ProsarySession *)calloc(1, sizeof(*b.session));
    if (!b.session) { errorf(error, error_size, "Out of memory"); return NULL; }
    b.session->title = copy(localized(json_get(b.pack, "manifest"), "displayName", b.language));
    if (!b.session->title) build_error(&b, "Out of memory", NULL);
    group = calendar(&b, selection, &month, &day);
    b.session->group = selection->group < 0 ? group : selection->group;
    b.session->variant = -1; b.session->day = -1;
    definition = json_get(b.pack, "devotion"); form = definition;
    type = json_text(definition, "type"); variants = json_get(definition, "variants");
    if (variants) {
        size_t count = json_count(variants);
        int choice = selection->variant;
        if (!count || count > 64) build_error(&b, "Invalid variant list", NULL);
        if (choice < 0) {
            choice = 0;
            for (i = 0; i < count; ++i) {
                const Json *languages = json_get(json_at(variants, i), "defaultForLanguages"), *l;
                for (l = languages ? languages->child : NULL; l; l = l->next)
                    if (equal(json_string(l), b.language)) choice = (int)i;
            }
        }
        form = json_at(variants, (size_t)choice);
        if (!form) build_error(&b, "Variant is out of range", NULL);
        b.session->variant = choice;
    } else if (selection->variant >= 0) build_error(&b, "Devotion has no variants", NULL);
    if (!equal(type, "days") && selection->day > 0) build_error(&b, "Devotion has no daily sequence", NULL);
    if (!b.failed && equal(type, "steps")) {
        const Json *list = b.season == 2 ? json_get(form, "eastertideSteps") : NULL;
        entries(&b, list ? list : json_get(form, "steps"), "", -1, 0);
    } else if (!b.failed && equal(type, "days")) {
        int choice = selection->day;
        days = json_get(form, "days");
        if (choice < 0) choice = equal(id, "oAntiphons") && month == 12 && day >= 17 && day <= 23 ? day - 17 : 0;
        form = json_at(days, (size_t)choice);
        if (!form) build_error(&b, "Day is out of range", NULL);
        else entries(&b, json_get(form, "steps"), localized(form, "name", b.language), -1, 0);
        b.session->day = choice;
    } else if (!b.failed && equal(type, "rosary")) rosary(&b, form, b.session->group);
    else if (!b.failed) build_error(&b, "Unsupported devotion type", type);
    if (!b.failed && !b.session->count) build_error(&b, "Devotion produced no prayer steps", NULL);
    if (b.failed) { engine_session_free(b.session); return NULL; }
    return b.session;
}
void engine_session_free(ProsarySession *s) {
    size_t i;
    if (!s) return;
    for (i = 0; i < s->count; ++i) {
        free(s->steps[i].title); free(s->steps[i].body); free(s->steps[i].context); free(s->steps[i].language);
    }
    free(s->steps); free(s->title); free(s);
}
