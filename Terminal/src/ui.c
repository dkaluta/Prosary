#include "compat.h"
#include "ui.h"
#include "ui_strings.h"

#include <curses.h>
#include <errno.h>
#include <limits.h>
#include <locale.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>
#include <unistd.h>
#ifdef USE_FRIBIDI
#include <fribidi/fribidi.h>
#endif

/* All layout positions are terminal cells, not UTF-8 bytes. Text is decoded
 * before wrapping, and ncurses receives complete wide characters only. */
typedef struct { wchar_t **line; size_t count, capacity; } Lines;
typedef struct {
    ProsaryEngine *engine;
    ProsarySession *session;
    AppState *state;
    AppSave save;
    void *save_context;
    int locale, focus, view, setting, scroll, sidebar_top, page_height;
    size_t selected;
    int save_failed;
    char error[256];
} Ui;

enum { VIEW_PRAYER, VIEW_SETTINGS, VIEW_HELP };
enum { SET_INTERFACE, SET_LANGUAGE, SET_GROUP, SET_VARIANT, SET_DAY, SET_KEYBOARD_ARROWS, SET_KEYBOARD_SPACE, SET_COUNT };
static volatile sig_atomic_t ui_stopped;

static void stop_ui(int sig) { (void)sig; ui_stopped = 1; }
static const char *tr(const Ui *ui, enum UiText key) { return ui_text[key][ui->locale]; }
static int locale_index(const char *code)
{
    size_t i;
    if (!strcmp(code, "fil")) code = "tl";
    if (!strcmp(code, "iw")) code = "he";
    for (i = 0; i < sizeof(ui_codes) / sizeof(ui_codes[0]); ++i)
        if (!strcmp(code, ui_codes[i])) return (int)i;
    return 0;
}
static void copy_string(char *dst, size_t size, const char *src)
{
    if (size) snprintf(dst, size, "%s", src ? src : "");
}

/* Invalid sequences consume one byte; terminal escape/control sequences never
 * reach curses. Combining marks stay with their preceding display character. */
static wchar_t *decode_text(const char *text)
{
    size_t pos = 0, used = 0, len = strlen(text ? text : "");
    wchar_t *out;
    if (len > ((size_t)-1 / sizeof(wchar_t)) - 1) return NULL;
    out = malloc((len + 1) * sizeof(*out));
    if (!out) return NULL;
    while (pos < len) {
        unsigned char c = (unsigned char)text[pos];
        unsigned long cp = c;
        size_t bytes = 1, j;
        int valid = 1;
        if (c == '*' && pos + 1 < len && text[pos + 1] == '*') { pos += 2; continue; }
        if (c >= 0xc2 && c <= 0xdf) { bytes = 2; cp = c & 31; }
        else if (c >= 0xe0 && c <= 0xef) { bytes = 3; cp = c & 15; }
        else if (c >= 0xf0 && c <= 0xf4) { bytes = 4; cp = c & 7; }
        else if (c >= 0x80) valid = 0;
        if (pos + bytes > len) valid = 0;
        if (valid) for (j = 1; j < bytes; ++j) {
            unsigned char next = (unsigned char)text[pos + j];
            if ((next & 0xc0) != 0x80) { valid = 0; break; }
            cp = (cp << 6) | (next & 63);
        }
        if (valid && ((bytes == 2 && cp < 0x80) || (bytes == 3 && cp < 0x800) ||
                      (bytes == 4 && cp < 0x10000) || cp > 0x10ffff ||
                      (cp >= 0xd800 && cp <= 0xdfff))) valid = 0;
        if (!valid) { cp = 0xfffd; bytes = 1; }
        pos += bytes;
        if (cp == '\r') continue;
        if (cp == '\t') cp = ' ';
        if ((cp < 32 && cp != '\n') || (cp >= 0x7f && cp < 0xa0)) continue;
        if (cp > (unsigned long)WCHAR_MAX) cp = '?';
        if (cp != '\n' && wcwidth((wchar_t)cp) < 0) cp = '?';
        out[used++] = (wchar_t)cp;
    }
    out[used] = 0;
    return out;
}
static void free_lines(Lines *lines)
{
    size_t i;
    for (i = 0; i < lines->count; ++i) free(lines->line[i]);
    free(lines->line);
    memset(lines, 0, sizeof(*lines));
}
static int append_line(Lines *lines, const wchar_t *start, size_t length)
{
    wchar_t *line;
    if (lines->count == lines->capacity) {
        size_t cap = lines->capacity ? lines->capacity * 2 : 16;
        wchar_t **items;
        if (cap < lines->capacity || cap > (size_t)-1 / sizeof(*items)) return 0;
        items = realloc(lines->line, cap * sizeof(*items));
        if (!items) return 0;
        lines->line = items;
        lines->capacity = cap;
    }
    if (length > ((size_t)-1 / sizeof(*line)) - 1) return 0;
    line = malloc((length + 1) * sizeof(*line));
    if (!line) return 0;
    memcpy(line, start, length * sizeof(*line));
    line[length] = 0;
    lines->line[lines->count++] = line;
    return 1;
}
static int wrap_text(Lines *lines, const char *text, int width)
{
    wchar_t *decoded = decode_text(text ? text : "");
    size_t start = 0, pos = 0, last_space = (size_t)-1;
    int cells = 0;
    memset(lines, 0, sizeof(*lines));
    if (!decoded || width < 1) { free(decoded); return 0; }
    while (decoded[pos]) {
        int w;
        if (decoded[pos] == L'\n') {
            if (!append_line(lines, decoded + start, pos - start)) goto fail;
            start = ++pos; cells = 0; last_space = (size_t)-1;
            continue;
        }
        w = wcwidth(decoded[pos]);
        if (w < 0) w = 1;
        if (w > width) { decoded[pos] = L'?'; w = 1; }
        if (cells + w > width && pos > start) {
            size_t end = pos, next = pos;
            if (decoded[pos] == L' ') {
                next = pos + 1;
                while (decoded[next] == L' ') ++next;
            } else if (last_space != (size_t)-1 && last_space > start) {
                end = last_space; next = last_space + 1;
                while (decoded[next] == L' ') ++next;
            }
            if (!append_line(lines, decoded + start, end - start)) goto fail;
            start = pos = next; cells = 0; last_space = (size_t)-1;
            continue;
        }
        if (decoded[pos] == L' ') last_space = pos;
        cells += w;
        ++pos;
    }
    if (pos > start || !lines->count)
        if (!append_line(lines, decoded + start, pos - start)) goto fail;
    free(decoded);
    return 1;
fail:
    free(decoded);
    free_lines(lines);
    return 0;
}

static int wide_width(const wchar_t *text)
{
    int cells = 0;
    while (*text) {
        int w = wcwidth(*text++);
        if (w > 0 && cells <= INT_MAX - w) cells += w;
    }
    return cells;
}
#ifdef USE_FRIBIDI
static wchar_t *bidi_text(const wchar_t *logical, int rtl)
{
    wchar_t *visual = NULL;
    size_t i, length = wcslen(logical);
    FriBidiChar *in = NULL, *out = NULL;
    FriBidiParType base = rtl ? FRIBIDI_PAR_RTL : FRIBIDI_PAR_ON;
    if (length && length < INT_MAX) {
        in = malloc((length + 1) * sizeof(*in));
        out = malloc((length + 1) * sizeof(*out));
        visual = malloc((length + 1) * sizeof(*visual));
        if (in && out && visual) {
            for (i = 0; i < length; ++i) in[i] = (FriBidiChar)logical[i];
            if (fribidi_log2vis(in, (FriBidiStrIndex)length, &base, out, NULL, NULL, NULL)) {
                size_t used = 0;
                for (i = 0; i < length; ++i) {
                    /* Zero-width bidi controls are layout instructions, not glyphs. */
                    if ((out[i] >= 0x202a && out[i] <= 0x202e) ||
                        (out[i] >= 0x2066 && out[i] <= 0x2069) ||
                        out[i] == 0x200e || out[i] == 0x200f || out[i] == 0xfeff) continue;
                    visual[used++] = (wchar_t)out[i];
                }
                visual[used] = 0;
            } else { free(visual); visual = NULL; }
        } else { free(visual); visual = NULL; }
    }
    free(in); free(out);
    return visual;
}
#endif
static void draw_wide(int row, int column, int width, const wchar_t *logical,
                      int rtl, int attributes)
{
    const wchar_t *text = logical;
    wchar_t *visual = NULL;
    size_t i, length;
    int cells = 0;
#ifdef USE_FRIBIDI
    visual = bidi_text(logical, rtl);
    if (visual) text = visual;
#endif
    length = wcslen(text);
    if (width < 1 || row < 0 || row >= LINES || column < 0 || column >= COLS) {
        free(visual); return;
    }
    if (width > COLS - column) width = COLS - column;
    /* Leave the terminal's bottom-right cell untouched: writing it scrolls on
     * some curses implementations even with scrolling disabled. */
    if (row == LINES - 1 && column + width == COLS) --width;
    if (width <= 0) { free(visual); return; }
    if (rtl) {
        int content_width = wide_width(text);
        if (content_width < width) column += width - content_width;
    }
    attrset(attributes);
    for (i = 0; i < length; ++i) {
        int w = wcwidth(text[i]);
        if (w < 0) continue;
        if (cells + w > width) break;
        cells += w;
    }
    if (i) mvaddnwstr(row, column, text, (int)i);
    attrset(A_NORMAL);
    free(visual);
}
static void draw_text(int row, int column, int width, const char *text,
                      int rtl, int attributes)
{
    wchar_t *wide = decode_text(text ? text : "");
    if (wide) {
        size_t i;
        for (i = 0; wide[i]; ++i) if (wide[i] == L'\n') wide[i] = L' ';
        draw_wide(row, column, width, wide, rtl, attributes);
        free(wide);
    }
}
static void rule(int row, int column, int width)
{
    int i;
    for (i = 0; i < width && column + i < COLS; ++i) mvaddch(row, column + i, '-');
}
static int ui_rtl(const Ui *ui) { return ui->locale == 1 || ui->locale == 2; }
static void save_state(Ui *ui)
{
    if (ui->save) ui->save_failed = ui->save(ui->state, ui->save_context) != 0;
}
static int rebuild(Ui *ui, const char *id, int resume)
{
    ProsarySelection selection;
    ProsarySession *session;
    char error[192] = "";
    if ((!resume || !ui->state->year) && app_state_set_today(ui->state) != 0) {
        copy_string(ui->error, sizeof(ui->error), tr(ui, U_LOAD_ERROR));
        return 0;
    }
    memset(&selection, 0, sizeof(selection));
    selection.language = ui->state->language;
    selection.group = ui->state->group;
    selection.variant = ui->state->variant;
    selection.day = ui->state->day;
    selection.year = ui->state->year;
    selection.month = ui->state->month;
    selection.day_of_month = ui->state->day_of_month;
    session = engine_build(ui->engine, id, &selection, error, sizeof(error));
    if (!session || !session->count) {
        engine_session_free(session);
        snprintf(ui->error, sizeof(ui->error), "%s: %s", tr(ui, U_LOAD_ERROR), error);
        return 0;
    }
    engine_session_free(ui->session);
    ui->session = session;
    copy_string(ui->state->devotion_id, sizeof(ui->state->devotion_id), id);
    ui->state->group = session->group;
    ui->state->variant = session->variant;
    ui->state->day = session->day;
    if (!resume) { ui->state->step = 0; ui->state->completed = 0; }
    if (ui->state->step >= session->count) ui->state->step = session->count - 1;
    ui->scroll = 0;
    ui->error[0] = 0;
    save_state(ui);
    return 1;
}
static void open_selected(Ui *ui)
{
    size_t count = engine_catalog_count(ui->engine);
    if (ui->selected == count) { ui->view = VIEW_SETTINGS; ui->setting = 0; }
    else if (ui->selected == count + 1) { ui->view = VIEW_HELP; ui->scroll = 0; }
    else if (ui->selected < count) {
        const char *id = engine_catalog_id(ui->engine, ui->selected);
        int same = !strcmp(id, ui->state->devotion_id);
        AppState previous = *ui->state;
        if (!same) { ui->state->variant = -1; ui->state->day = -1; }
        if (!rebuild(ui, id, same && !ui->state->completed)) {
            *ui->state = previous; return;
        }
        ui->view = VIEW_PRAYER;
    }
    ui->focus = 1;
}
static void draw_sidebar(Ui *ui, int x, int width, int top, int height)
{
    size_t count = engine_catalog_count(ui->engine), total = count + 2;
    int i, slots = height - 2;
    char buffer[320];
    draw_text(top, x, width, tr(ui, U_PRAYERS), ui_rtl(ui), A_BOLD);
    if (slots < 1) return;
    if ((int)ui->selected < ui->sidebar_top) ui->sidebar_top = (int)ui->selected;
    if ((int)ui->selected >= ui->sidebar_top + slots)
        ui->sidebar_top = (int)ui->selected - slots + 1;
    for (i = 0; i < slots && (size_t)(i + ui->sidebar_top) < total; ++i) {
        size_t index = (size_t)(i + ui->sidebar_top);
        int active = index < count && !strcmp(engine_catalog_id(ui->engine, index), ui->state->devotion_id);
        const char *name = index < count
            ? engine_catalog_name(ui->engine, index, ui->state->ui_language)
            : tr(ui, index == count ? U_SETTINGS : U_HELP);
        int attr = ui->focus == 0 && index == ui->selected ? A_REVERSE : A_NORMAL;
        snprintf(buffer, sizeof(buffer), "%c %s", active ? '*' : ' ', name ? name : "");
        if (attr == A_REVERSE) {
            int c;
            attrset(A_REVERSE);
            for (c = 0; c < width; ++c) mvaddch(top + 2 + i, x + c, ' ');
            attrset(A_NORMAL);
        }
        draw_text(top + 2 + i, x, width, buffer, ui_rtl(ui), attr);
    }
}
static void draw_paragraph(Ui *ui, const char *body, int x, int y, int width,
                           int height, int rtl)
{
    Lines lines;
    size_t i;
    if (height < 1 || width < 1 || !wrap_text(&lines, body, width)) return;
    ui->page_height = height;
    if (ui->scroll > (int)lines.count - height) ui->scroll = (int)lines.count - height;
    if (ui->scroll < 0) ui->scroll = 0;
    for (i = 0; i < (size_t)height && i + (size_t)ui->scroll < lines.count; ++i)
        draw_wide(y + (int)i, x, width, lines.line[i + (size_t)ui->scroll], rtl, A_NORMAL);
    if (lines.count > (size_t)height && !ui->save_failed && !ui->error[0]) {
        char position[120];
        size_t end = (size_t)ui->scroll + (size_t)height;
        if (end > lines.count) end = lines.count;
        snprintf(position, sizeof(position), "%s %d-%lu / %lu", tr(ui, U_SCROLL),
                 ui->scroll + 1, (unsigned long)end, (unsigned long)lines.count);
        draw_text(LINES - 3, x, width, position, ui_rtl(ui), A_DIM);
    }
    free_lines(&lines);
}
static void draw_prayer(Ui *ui, int x, int width, int top, int height)
{
    const ProsaryStep *step;
    char progress[320];
    int rtl, y = top;
    if (!ui->session) {
        draw_text(y, x, width, tr(ui, U_SELECT_HINT), ui_rtl(ui), A_NORMAL); return;
    }
    step = &ui->session->steps[ui->state->step];
    rtl = engine_language_is_rtl(step->language);
    draw_text(y++, x, width, ui->session->title, engine_language_is_rtl(ui->state->language), A_BOLD);
    snprintf(progress, sizeof(progress), "%s %lu / %lu%s%s", tr(ui, U_STEP),
             (unsigned long)ui->state->step + 1, (unsigned long)ui->session->count,
             ui->state->completed ? " - " : "", ui->state->completed ? tr(ui, U_COMPLETE) : "");
    draw_text(y++, x, width, progress, ui_rtl(ui), A_DIM);
    if (y < top + height) rule(y++, x, width);
    if (ui->state->completed) {
        if (y < top + height)
            draw_paragraph(ui, tr(ui, U_COMPLETE_HINT), x, y, width, top + height - y, ui_rtl(ui));
        return;
    }
    if (y < top + height) draw_text(y++, x, width, step->title, rtl, A_BOLD);
    if (step->context && step->context[0] && y < top + height)
        draw_text(y++, x, width, step->context, rtl, A_DIM);
    if (step->mixed_languages && y < top + height) {
        draw_text(y++, x, width, tr(ui, U_MIXED), ui_rtl(ui), A_DIM);
    } else if (step->language && strcmp(step->language, ui->state->language) && y < top + height) {
        snprintf(progress, sizeof(progress), "%s: %s", tr(ui, U_FALLBACK), step->language);
        draw_text(y++, x, width, progress, ui_rtl(ui), A_DIM);
    } else if (step->used_fallback && y < top + height) {
        draw_text(y++, x, width, tr(ui, U_FALLBACK_TEXT), ui_rtl(ui), A_DIM);
    }
    if (y < top + height - 1) ++y;
    if (y < top + height)
        draw_paragraph(ui, step->body && step->body[0] ? step->body : tr(ui, U_NO_TEXT),
                       x, y, width, top + height - y, rtl);
}
static int settings_list(Ui *ui, int *items)
{
    int count = 0;
    items[count++] = SET_INTERFACE;
    items[count++] = SET_LANGUAGE;
    if (!strcmp(ui->state->devotion_id, "rosary")) items[count++] = SET_GROUP;
    if (engine_variant_count(ui->engine, ui->state->devotion_id) > 1) items[count++] = SET_VARIANT;
    if (engine_day_count(ui->engine, ui->state->devotion_id) > 1) items[count++] = SET_DAY;
    items[count++] = SET_KEYBOARD_ARROWS;
    items[count++] = SET_KEYBOARD_SPACE;
    return count;
}
static size_t language_index(const char *code)
{
    size_t i;
    for (i = 0; i < engine_language_count(); ++i)
        if (!strcmp(code, engine_language_code(i))) return i;
    return 0;
}
static void draw_settings(Ui *ui, int x, int width, int top, int height)
{
    int items[SET_COUNT], count = settings_list(ui, items), i, first = 0, slots = (height - 3) / 2;
    draw_text(top, x, width, tr(ui, U_SETTINGS), ui_rtl(ui), A_BOLD);
    if (slots < 1) slots = 1;
    if (ui->setting >= count) ui->setting = count - 1;
    if (ui->setting >= slots) first = ui->setting - slots + 1;
    for (i = first; i < count && i < first + slots; ++i) {
        const char *label = "", *value = "";
        char line[512];
        switch (items[i]) {
        case SET_INTERFACE: label = tr(ui, U_INTERFACE); value = ui_names[ui->locale]; break;
        case SET_LANGUAGE: label = tr(ui, U_LANGUAGE); value = engine_language_name(language_index(ui->state->language)); break;
        case SET_GROUP: label = tr(ui, U_MYSTERIES); value = tr(ui, (enum UiText)(U_JOYFUL + (ui->state->group < 0 ? 0 : ui->state->group % 4))); break;
        case SET_VARIANT: label = tr(ui, U_FORM); value = engine_variant_name(ui->engine, ui->state->devotion_id, (size_t)(ui->state->variant < 0 ? 0 : ui->state->variant), ui->state->ui_language); break;
        case SET_DAY: label = tr(ui, U_DAY); value = engine_day_name(ui->engine, ui->state->devotion_id, (size_t)(ui->state->day < 0 ? 0 : ui->state->day), ui->state->ui_language); break;
        case SET_KEYBOARD_ARROWS: label = tr(ui, U_KEYBOARD_ARROWS); value = tr(ui, ui->state->keyboard_arrow_navigation_enabled ? U_ON : U_OFF); break;
        case SET_KEYBOARD_SPACE: label = tr(ui, U_KEYBOARD_SPACE); value = tr(ui, ui->state->keyboard_space_advance_enabled ? U_ON : U_OFF); break;
        }
        snprintf(line, sizeof(line), "%s: %s", label, value ? value : "");
        draw_text(top + 2 + (i - first) * 2, x, width, line, ui_rtl(ui),
                  ui->focus && i == ui->setting ? A_REVERSE : A_NORMAL);
    }
    if (top + 2 + (count - first) * 2 < top + height - 1)
        draw_text(top + height - 1, x, width, tr(ui, U_SETTINGS_HINT), ui_rtl(ui), A_DIM);
}
static void change_setting(Ui *ui, int direction)
{
    int items[SET_COUNT], count = settings_list(ui, items);
    AppState previous = *ui->state;
    int item;
    if (ui->setting >= count) return;
    item = items[ui->setting];
    if (item == SET_KEYBOARD_ARROWS || item == SET_KEYBOARD_SPACE) {
        int *enabled = item == SET_KEYBOARD_ARROWS ?
            &ui->state->keyboard_arrow_navigation_enabled : &ui->state->keyboard_space_advance_enabled;
        *enabled = !*enabled;
        save_state(ui);
        return;
    }
    if (item == SET_INTERFACE) {
        ui->locale = (ui->locale + direction + 8) % 8;
        copy_string(ui->state->ui_language, sizeof(ui->state->ui_language), ui_codes[ui->locale]);
        save_state(ui);
        return;
    }
    if (item == SET_LANGUAGE) {
        int total = (int)engine_language_count();
        int index = (int)language_index(ui->state->language);
        if (!total) return;
        index = (index + direction + total) % total;
        copy_string(ui->state->language, sizeof(ui->state->language), engine_language_code((size_t)index));
        ui->state->variant = -1;
    } else if (item == SET_GROUP) {
        ui->state->group = (ui->state->group + direction + 4) % 4;
    } else if (item == SET_VARIANT) {
        int total = (int)engine_variant_count(ui->engine, ui->state->devotion_id);
        ui->state->variant = (ui->state->variant + direction + total) % total;
    } else if (item == SET_DAY) {
        int total = (int)engine_day_count(ui->engine, ui->state->devotion_id);
        ui->state->day = (ui->state->day + direction + total) % total;
    }
    /* engine_build receives id from state; keep it separate from the destination
     * buffer to avoid overlapping snprintf in rebuild. */
    if (!rebuild(ui, previous.devotion_id, 0)) *ui->state = previous;
}
static int has_rtl_warning(const Ui *ui)
{
#ifdef USE_FRIBIDI
    (void)ui;
    return 0;
#else
    return ui_rtl(ui) || (ui->session && engine_language_is_rtl(ui->session->steps[ui->state->step].language));
#endif
}
static void render(Ui *ui)
{
    int split = COLS >= 64, sidebar_width = COLS / 3, x = 1, width = COLS - 2;
    int top = 2, height = LINES - 6, rtl_warning = has_rtl_warning(ui);
    enum UiText footer = ui->focus == 0 ? U_FOOT_LIBRARY :
        ui->view == VIEW_SETTINGS ? U_FOOT_SETTINGS : ui->view == VIEW_HELP ? U_FOOT_HELP : U_FOOT_PRAYER;
    erase();
    if (COLS < 24 || LINES < 8) {
        draw_text(0, 0, COLS, tr(ui, U_SMALL), ui_rtl(ui), A_BOLD);
        refresh(); return;
    }
    draw_text(0, 1, COLS - 2, "Prosary", 0, A_BOLD);
    rule(1, 0, COLS);
    if (sidebar_width > 31) sidebar_width = 31;
    if (split) {
        int row;
        for (row = 2; row < LINES - 3; ++row) mvaddch(row, sidebar_width, '|');
        draw_sidebar(ui, 1, sidebar_width - 2, top, height);
        x = sidebar_width + 2; width = COLS - x - 1;
    } else if (!ui->focus) {
        draw_sidebar(ui, x, width, top, height);
    }
    if (split || ui->focus) {
        if (rtl_warning && height > 3) {
            Lines warning;
            int n;
            if (wrap_text(&warning, tr(ui, U_RTL_LIMIT), width)) {
                int max = height > 9 ? 3 : 1;
                for (n = 0; n < max && n < (int)warning.count; ++n)
                    draw_wide(top + n, x, width, warning.line[n], ui_rtl(ui), A_BOLD);
                top += n + 1; height -= n + 1;
                free_lines(&warning);
            }
        }
        if (ui->view == VIEW_PRAYER) draw_prayer(ui, x, width, top, height);
        else if (ui->view == VIEW_SETTINGS) draw_settings(ui, x, width, top, height);
        else {
            draw_text(top, x, width, tr(ui, U_HELP), ui_rtl(ui), A_BOLD);
            draw_paragraph(ui, tr(ui, U_HELP_BODY), x, top + 2, width, height - 2, ui_rtl(ui));
        }
    }
    if (ui->save_failed) draw_text(LINES - 3, 1, COLS - 2, tr(ui, U_SAVE_ERROR), ui_rtl(ui), A_BOLD);
    else if (ui->error[0]) draw_text(LINES - 3, 1, COLS - 2, ui->error, ui_rtl(ui), A_BOLD);
    rule(LINES - 2, 0, COLS);
    draw_text(LINES - 1, 1, COLS - 2, tr(ui, footer), ui_rtl(ui), A_NORMAL);
    refresh();
}
static void prayer_move(Ui *ui, int direction)
{
    if (!ui->session) return;
    if (ui->state->completed) {
        if (direction < 0) ui->state->completed = 0;
    } else if (direction > 0) {
        if (ui->state->step + 1 < ui->session->count) ++ui->state->step;
        else ui->state->completed = 1;
    } else if (ui->state->step > 0) --ui->state->step;
    ui->scroll = 0;
    save_state(ui);
}
static void handle_key(Ui *ui, wint_t key)
{
    size_t count = engine_catalog_count(ui->engine);
    if (key == '\t' || key == KEY_BTAB) { ui->focus = !ui->focus; return; }
    if (key == 27) { ui->view = VIEW_PRAYER; ui->focus = 0; ui->scroll = 0; return; }
    if (key == KEY_F(1) || key == '?') { ui->view = VIEW_HELP; ui->focus = 1; ui->scroll = 0; return; }
    if (!ui->focus) {
        if (key == KEY_UP || key == 'k') { if (ui->selected) --ui->selected; }
        else if (key == KEY_DOWN || key == 'j') { if (ui->selected < count + 1) ++ui->selected; }
        else if (key == KEY_HOME) ui->selected = 0;
        else if (key == KEY_END) ui->selected = count + 1;
        else if (key == '\n' || key == '\r' || key == KEY_ENTER || key == KEY_RIGHT) open_selected(ui);
        return;
    }
    if (ui->view == VIEW_SETTINGS) {
        int items[SET_COUNT], n = settings_list(ui, items);
        if (key == KEY_UP || key == 'k') { if (ui->setting > 0) --ui->setting; }
        else if (key == KEY_DOWN || key == 'j') { if (ui->setting + 1 < n) ++ui->setting; }
        else if (key == KEY_LEFT) change_setting(ui, -1);
        else if (key == KEY_RIGHT || key == '\n' || key == '\r') change_setting(ui, 1);
        return;
    }
    if (ui->view == VIEW_PRAYER) {
        if (key == KEY_BACKSPACE || key == 127) { prayer_move(ui, -1); return; }
        if ((key == KEY_LEFT || key == KEY_RIGHT) && ui->state->keyboard_arrow_navigation_enabled) {
            int direction = key == KEY_RIGHT ? 1 : -1;
            prayer_move(ui, ui_rtl(ui) ? -direction : direction);
            return;
        }
        if (key == ' ' && ui->state->keyboard_space_advance_enabled) { prayer_move(ui, 1); return; }
        /* Enter remains an explicit primary action even if both shortcuts are off. */
        if (key == '\n' || key == '\r' || key == KEY_ENTER) { prayer_move(ui, 1); return; }
    }
    if (key == KEY_UP || key == 'k') { if (ui->scroll) --ui->scroll; }
    else if (key == KEY_DOWN || key == 'j') { if (ui->scroll < INT_MAX - 1) ++ui->scroll; }
    else if (key == KEY_PPAGE) { ui->scroll -= ui->page_height > 1 ? ui->page_height - 1 : 1; if (ui->scroll < 0) ui->scroll = 0; }
    else if (key == KEY_NPAGE) { if (ui->scroll < INT_MAX - ui->page_height - 1) ui->scroll += ui->page_height > 1 ? ui->page_height - 1 : 1; }
    else if (key == KEY_HOME) ui->scroll = 0;
    else if (key == KEY_END) ui->scroll = INT_MAX / 2;
}
int ui_run(ProsaryEngine *engine, AppState *state, AppSave save, void *context)
{
    Ui ui;
    SCREEN *screen;
    size_t i, count = engine_catalog_count(engine);
    void (*old_int)(int), (*old_term)(int), (*old_hup)(int);
    int result = 0;
    memset(&ui, 0, sizeof(ui));
    ui.engine = engine; ui.state = state; ui.save = save; ui.save_context = context;
    ui.locale = locale_index(state->ui_language); ui.page_height = 1;
    if (!count || MB_CUR_MAX <= 1) return 1;
    for (i = 0; i < count; ++i)
        if (!strcmp(engine_catalog_id(engine, i), state->devotion_id)) { ui.selected = i; break; }
    if (i == count) {
        copy_string(state->devotion_id, sizeof(state->devotion_id), engine_catalog_id(engine, 0));
        state->step = 0; state->completed = 0; state->variant = -1; state->day = -1;
    }
    {
        char id[sizeof(state->devotion_id)];
        copy_string(id, sizeof(id), state->devotion_id);
        if (rebuild(&ui, id, 1)) ui.focus = 1;
    }
    screen = newterm(NULL, stdout, stdin);
    if (!screen) { engine_session_free(ui.session); return 1; }
    set_term(screen);
    cbreak(); noecho(); nonl(); keypad(stdscr, TRUE); intrflush(stdscr, FALSE);
    curs_set(0);
#ifdef NCURSES_VERSION
    set_escdelay(35);
#endif
    ui_stopped = 0;
    old_int = signal(SIGINT, stop_ui);
    old_term = signal(SIGTERM, stop_ui);
    old_hup = signal(SIGHUP, stop_ui);
    timeout(200);
    while (!ui_stopped) {
        wint_t key;
        int input;
        render(&ui);
        errno = 0;
        input = get_wch(&key);
        if (input == ERR) {
            struct pollfd fd;
            fd.fd = STDIN_FILENO; fd.events = POLLIN; fd.revents = 0;
            if (feof(stdin) || ferror(stdin) || errno == EIO || errno == EBADF ||
                (poll(&fd, 1, 0) > 0 && (fd.revents & (POLLHUP | POLLERR | POLLNVAL)))) break;
            continue;
        }
        /* No free-text fields: ignore literal non-ASCII characters, whose code
         * points may coincide with curses's KEY_* integer constants. */
        if (input == OK && key > 127) continue;
        if (key == 'q' || key == 'Q') break;
        if (key == KEY_RESIZE) { clearok(stdscr, TRUE); continue; }
        handle_key(&ui, key);
    }
    save_state(&ui);
    if (ui.save_failed) result = 2;
    endwin();
    delscreen(screen);
    signal(SIGINT, old_int); signal(SIGTERM, old_term); signal(SIGHUP, old_hup);
    engine_session_free(ui.session);
    return result;
}
