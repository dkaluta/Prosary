/* Exercise the actual display decoder/wrapper without opening a terminal. */
#include "../src/ui.c"
#include <assert.h>

static void check_wrap(const char *source, int width, size_t expected)
{
    Lines lines;
    size_t i;
    assert(wrap_text(&lines, source, width));
    assert(lines.count == expected);
    for (i = 0; i < lines.count; ++i) assert(wide_width(lines.line[i]) <= width);
    free_lines(&lines);
}
static void check_keyboard_navigation(void)
{
    Ui ui;
    AppState state;
    char error[256];
    int items[SET_COUNT], count;
    memset(&ui, 0, sizeof(ui));
    app_state_defaults(&state);
    ui.state = &state;
    ui.engine = engine_open("data", error, sizeof(error));
    assert(ui.engine);
    assert(rebuild(&ui, "rosary", 0));
    ui.focus = 1;
    handle_key(&ui, KEY_RIGHT); assert(state.step == 1);
    handle_key(&ui, ' '); assert(state.step == 2);
    state.keyboard_arrow_navigation_enabled = 0;
    handle_key(&ui, KEY_RIGHT); handle_key(&ui, KEY_LEFT); assert(state.step == 2);
    handle_key(&ui, ' '); assert(state.step == 3);
    state.keyboard_space_advance_enabled = 0;
    handle_key(&ui, ' '); assert(state.step == 3);
    handle_key(&ui, '\r'); assert(state.step == 4);
    handle_key(&ui, KEY_BACKSPACE); assert(state.step == 3);
    state.keyboard_arrow_navigation_enabled = 1;
    handle_key(&ui, KEY_LEFT); assert(state.step == 2);
    handle_key(&ui, KEY_DOWN); assert(state.step == 2 && ui.scroll == 1);
    ui.locale = 1;
    handle_key(&ui, KEY_LEFT); assert(state.step == 3);
    handle_key(&ui, KEY_RIGHT); assert(state.step == 2);
    ui.focus = 0;
    handle_key(&ui, ' '); handle_key(&ui, KEY_LEFT); assert(state.step == 2);
    ui.focus = 1; ui.view = VIEW_HELP;
    handle_key(&ui, ' '); handle_key(&ui, KEY_RIGHT); assert(state.step == 2);
    ui.view = VIEW_SETTINGS;
    count = settings_list(&ui, items);
    assert(count <= SET_COUNT && items[count - 2] == SET_KEYBOARD_ARROWS);
    ui.setting = count - 2;
    handle_key(&ui, KEY_RIGHT);
    assert(!state.keyboard_arrow_navigation_enabled && !state.keyboard_space_advance_enabled && state.step == 2);
    handle_key(&ui, KEY_DOWN); handle_key(&ui, KEY_RIGHT);
    assert(!state.keyboard_arrow_navigation_enabled && state.keyboard_space_advance_enabled && state.step == 2);
    ui.view = VIEW_PRAYER;
    state.step = ui.session->count - 1;
    handle_key(&ui, ' '); assert(state.completed);
    handle_key(&ui, KEY_BACKSPACE); assert(!state.completed);
    engine_session_free(ui.session);
    engine_close(ui.engine);
    puts("Terminal keyboard: independent switches, RTL, focus, scrolling, completion, and unchanged progress passed");
}
int main(void)
{
    wchar_t *text;
    Lines lines;
    size_t i, j;
    const char *cases[] = {
        "ABC XYZ", "one two three", "שלום אבג", "العربية", "e\xcc\x81" "e\xcc\x81" "e\xcc\x81",
        "中文\xe7\x94\xbb", "\xf0\x9f\x99\x82\xf0\x9f\x99\x82", "a\n\nb", "   abc   def   ",
        "\xe0\x80\x80\xf0\x80\x80\x80\xed\xa0\x80\xf4\x90\x80\x80\x80"
    };
    assert(setlocale(LC_ALL, ""));
    assert(MB_CUR_MAX > 1);
    check_keyboard_navigation();
    text = decode_text("**Hail Mary**\t\033[2J\001\177\r\n");
    assert(text && !wcscmp(text, L"Hail Mary [2J\n"));
    free(text);
    text = decode_text("\xf0\x9f\x99\x82\xe2\x82");
    assert(text && text[0] == 0x1f642 && text[1] == 0xfffd && text[2] == 0xfffd && !text[3]);
    free(text);
    check_wrap("one two three", 7, 2);
    check_wrap("a\n\nb", 3, 3);
    check_wrap("", 2, 1);
    check_wrap("abc", 1, 3);
    check_wrap("中文", 1, 2);
    assert(wrap_text(&lines, "e\xcc\x81" "e\xcc\x81", 1));
    assert(lines.count == 2 && wcslen(lines.line[0]) == 2 && wcslen(lines.line[1]) == 2);
    free_lines(&lines);
    for (i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        int width;
        for (width = 1; width < 25; ++width) {
            assert(wrap_text(&lines, cases[i], width));
            for (j = 0; j < lines.count; ++j) {
                assert(wide_width(lines.line[j]) <= width);
                assert(!wcschr(lines.line[j], L'\n'));
            }
            free_lines(&lines);
        }
    }
    for (i = 0; i < sizeof(ui_text) / sizeof(ui_text[0]); ++i)
        for (j = 0; j < 8; ++j) assert(ui_text[i][j] && ui_text[i][j][0]);
#ifdef USE_FRIBIDI
    text = bidi_text(L"שלום 123", 1);
    assert(text && !wcscmp(text, L"123 םולש"));
    free(text);
    text = bidi_text(L"سلام 123", 1);
    assert(text && !wcscmp(text, L"123 \ufee1\ufefc\ufeb3"));
    free(text);
    puts("FriBidi: Hebrew visual order, Arabic joining/lam-alef shaping, and number order passed");
#endif
    puts("Terminal text: Unicode widths, combining marks, controls, wrapping, and eight locales passed");
    return 0;
}
