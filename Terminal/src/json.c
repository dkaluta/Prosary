#include "json.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <errno.h>
#include <float.h>

#define JSON_DEPTH_LIMIT 64
#define JSON_NODE_LIMIT 250000

typedef struct {
    const char *start, *p, *end;
    size_t nodes;
    char *error;
    size_t error_size;
    int failed;
} Parser;

static void fail(Parser *p, const char *message) {
    if (!p->failed && p->error && p->error_size)
        snprintf(p->error, p->error_size, "%s at byte %lu", message,
                 (unsigned long)(p->p - p->start));
    p->failed = 1;
}
static void space(Parser *p) {
    while (p->p < p->end && (*p->p == ' ' || *p->p == '\n' || *p->p == '\r' || *p->p == '\t')) ++p->p;
}
static int hex4(Parser *p, unsigned *out) {
    int i;
    unsigned n = 0;
    for (i = 0; i < 4; ++i) {
        unsigned c;
        if (p->p == p->end) { fail(p, "Truncated Unicode escape"); return 0; }
        c = (unsigned char)*p->p++;
        if (c >= '0' && c <= '9') c -= '0';
        else if (c >= 'a' && c <= 'f') c = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') c = c - 'A' + 10;
        else { fail(p, "Invalid Unicode escape"); return 0; }
        n = n * 16 + c;
    }
    *out = n; return 1;
}
static char *string_value(Parser *p) {
    const char *scan;
    char *s, *out;
    size_t capacity;
    if (p->p == p->end || *p->p++ != '"') { fail(p, "Expected string"); return NULL; }
    /* An encoded string cannot grow when escapes are decoded. */
    scan = p->p;
    while (scan < p->end) {
        if (*scan == '"') break;
        if (*scan++ == '\\' && scan < p->end) ++scan;
    }
    if (scan == p->end) { fail(p, "Unterminated string"); return NULL; }
    capacity = (size_t)(scan - p->p) + 1;
    s = (char *)malloc(capacity);
    if (!s) { fail(p, "Out of memory"); return NULL; }
    out = s;
    while (p->p < p->end) {
        unsigned c = (unsigned char)*p->p++;
        if (c == '"') { *out = '\0'; return s; }
        if (c < 0x20) { fail(p, "Control character in string"); break; }
        if (c == '\\') {
            if (p->p == p->end) { fail(p, "Truncated escape"); break; }
            c = (unsigned char)*p->p++;
            if (c == '"' || c == '\\' || c == '/') *out++ = (char)c;
            else if (c == 'b') *out++ = '\b';
            else if (c == 'f') *out++ = '\f';
            else if (c == 'n') *out++ = '\n';
            else if (c == 'r') *out++ = '\r';
            else if (c == 't') *out++ = '\t';
            else if (c == 'u') {
                unsigned n, low;
                if (!hex4(p, &n)) break;
                if (n >= 0xd800 && n <= 0xdbff) {
                    if (p->end - p->p < 2 || p->p[0] != '\\' || p->p[1] != 'u') { fail(p, "Unpaired surrogate"); break; }
                    p->p += 2;
                    if (!hex4(p, &low)) break;
                    if (low < 0xdc00 || low > 0xdfff) { fail(p, "Unpaired surrogate"); break; }
                    n = 0x10000 + (n - 0xd800) * 1024 + low - 0xdc00;
                } else if (n >= 0xdc00 && n <= 0xdfff) { fail(p, "Unpaired surrogate"); break; }
                if (n == 0) { fail(p, "NUL in string"); break; }
                if (n < 0x80) *out++ = (char)n;
                else if (n < 0x800) { *out++ = (char)(0xc0 | (n >> 6)); *out++ = (char)(0x80 | (n & 63)); }
                else if (n < 0x10000) { *out++ = (char)(0xe0 | (n >> 12)); *out++ = (char)(0x80 | ((n >> 6) & 63)); *out++ = (char)(0x80 | (n & 63)); }
                else { *out++ = (char)(0xf0 | (n >> 18)); *out++ = (char)(0x80 | ((n >> 12) & 63)); *out++ = (char)(0x80 | ((n >> 6) & 63)); *out++ = (char)(0x80 | (n & 63)); }
            } else { fail(p, "Invalid string escape"); break; }
        } else {
            /* Validate raw UTF-8; no overlong sequences, surrogate scalars or values > U+10FFFF. */
            int remaining = 0, i;
            unsigned scalar = c, minimum = 0;
            if (c >= 0x80) {
                if (c >= 0xc2 && c <= 0xdf) { remaining = 1; scalar = c & 31; minimum = 0x80; }
                else if (c >= 0xe0 && c <= 0xef) { remaining = 2; scalar = c & 15; minimum = 0x800; }
                else if (c >= 0xf0 && c <= 0xf4) { remaining = 3; scalar = c & 7; minimum = 0x10000; }
                else { fail(p, "Invalid UTF-8"); break; }
            }
            *out++ = (char)c;
            for (i = 0; i < remaining; ++i) {
                if (p->p == p->end || ((unsigned char)*p->p & 0xc0) != 0x80) { fail(p, "Invalid UTF-8"); break; }
                c = (unsigned char)*p->p++; *out++ = (char)c;
                scalar = scalar * 64 + (c & 63);
            }
            if (p->failed) break;
            if (scalar < minimum || scalar > 0x10ffff || (scalar >= 0xd800 && scalar <= 0xdfff)) { fail(p, "Invalid UTF-8"); break; }
        }
    }
    free(s); return NULL;
}
void json_free(Json *j) {
    while (j) {
        Json *next = j->next;
        json_free(j->child); free(j->key); free(j->string); free(j); j = next;
    }
}
/* Convert already validated JSON numbers independently of LC_NUMERIC. */
static double decimal_number(Parser *p, const char *s, size_t length) {
    size_t i = 0;
    int negative = 0, fraction = 0, digits = 0, exponent = 0, explicit_exponent = 0, exponent_sign = 1;
    double n = 0;
    if (s[i] == '-') { negative = 1; ++i; }
    while (i < length && s[i] != 'e' && s[i] != 'E') {
        int digit;
        if (s[i] == '.') { fraction = 1; ++i; continue; }
        digit = s[i++] - '0';
        if (!digits && !digit) { if (fraction) --exponent; continue; }
        if (digits < 18) { n = n * 10 + digit; ++digits; if (fraction) --exponent; }
        else if (!fraction) ++exponent;
    }
    if (i < length) {
        ++i;
        if (i < length && (s[i] == '+' || s[i] == '-')) { if (s[i] == '-') exponent_sign = -1; ++i; }
        while (i < length) {
            if (explicit_exponent < 10000) explicit_exponent = explicit_exponent * 10 + s[i] - '0';
            ++i;
        }
        exponent += exponent_sign * explicit_exponent;
    }
    if (n == 0) return negative ? -0.0 : 0.0;
    if (exponent > 400 || exponent < -400) { fail(p, "Number out of range"); return 0; }
    while (exponent > 0) {
        if (n > DBL_MAX / 10) { fail(p, "Number out of range"); return 0; }
        n *= 10; --exponent;
    }
    while (exponent < 0) { n /= 10; ++exponent; }
    if (n == 0) fail(p, "Number out of range");
    return negative ? -n : n;
}
static Json *value(Parser *p, int depth) {
    Json *j, **tail;
    const char *number_start;
    space(p);
    if (depth > JSON_DEPTH_LIMIT || ++p->nodes > JSON_NODE_LIMIT) { fail(p, "JSON complexity limit exceeded"); return NULL; }
    if (p->p == p->end) { fail(p, "Expected value"); return NULL; }
    j = (Json *)calloc(1, sizeof(*j));
    if (!j) { fail(p, "Out of memory"); return NULL; }
    if (*p->p == '"') { j->type = JSON_STRING; j->string = string_value(p); }
    else if (*p->p == '{' || *p->p == '[') {
        char close = *p->p++ == '{' ? '}' : ']';
        j->type = close == '}' ? JSON_OBJECT : JSON_ARRAY;
        tail = &j->child; space(p);
        if (p->p < p->end && *p->p == close) ++p->p;
        else for (;;) {
            char *key = NULL;
            Json *child;
            if (j->type == JSON_OBJECT) {
                key = string_value(p);
                if (!key) break;
                if (json_get(j, key)) { free(key); fail(p, "Duplicate object key"); break; }
                space(p);
                if (p->p == p->end || *p->p++ != ':') { free(key); fail(p, "Expected colon"); break; }
            }
            child = value(p, depth + 1);
            if (!child) { free(key); break; }
            child->key = key; *tail = child; tail = &child->next;
            space(p);
            if (p->p == p->end) { fail(p, "Unterminated container"); break; }
            if (*p->p == close) { ++p->p; break; }
            if (*p->p++ != ',') { fail(p, "Expected comma"); break; }
            space(p);
        }
    } else if (p->end - p->p >= 4 && !memcmp(p->p, "null", 4)) { j->type = JSON_NULL; p->p += 4; }
    else if (p->end - p->p >= 4 && !memcmp(p->p, "true", 4)) { j->type = JSON_BOOL; j->number = 1; p->p += 4; }
    else if (p->end - p->p >= 5 && !memcmp(p->p, "false", 5)) { j->type = JSON_BOOL; p->p += 5; }
    else {
        size_t n;
        j->type = JSON_NUMBER; number_start = p->p;
        if (*p->p == '-') ++p->p;
        if (p->p == p->end) fail(p, "Invalid number");
        else if (*p->p == '0') ++p->p;
        else if (*p->p >= '1' && *p->p <= '9') while (p->p < p->end && *p->p >= '0' && *p->p <= '9') ++p->p;
        else fail(p, "Invalid value");
        if (!p->failed && p->p < p->end && *p->p == '.') {
            ++p->p;
            if (p->p == p->end || *p->p < '0' || *p->p > '9') fail(p, "Invalid fraction");
            while (p->p < p->end && *p->p >= '0' && *p->p <= '9') ++p->p;
        }
        if (!p->failed && p->p < p->end && (*p->p == 'e' || *p->p == 'E')) {
            ++p->p;
            if (p->p < p->end && (*p->p == '+' || *p->p == '-')) ++p->p;
            if (p->p == p->end || *p->p < '0' || *p->p > '9') fail(p, "Invalid exponent");
            while (p->p < p->end && *p->p >= '0' && *p->p <= '9') ++p->p;
        }
        n = (size_t)(p->p - number_start);
        if (n >= 128) fail(p, "Number too long");
        if (!p->failed) j->number = decimal_number(p, number_start, n);
    }
    if (p->failed) { json_free(j); return NULL; }
    return j;
}
Json *json_parse(const char *text, size_t length, char *error, size_t error_size) {
    Parser p;
    Json *j;
    if (error && error_size) *error = '\0';
    if (!text || length > 32u * 1024u * 1024u) { if (error && error_size) snprintf(error, error_size, "JSON input missing or too large"); return NULL; }
    p.start = p.p = text; p.end = text + length; p.nodes = 0;
    p.error = error; p.error_size = error_size; p.failed = 0;
    j = value(&p, 0); space(&p);
    if (j && p.p != p.end) { fail(&p, "Trailing JSON data"); json_free(j); return NULL; }
    return j;
}
Json *json_read_file(const char *path, size_t limit, char *error, size_t error_size) {
    FILE *f = fopen(path, "rb");
    long size;
    char *buffer;
    Json *j;
    if (!f) { if (error && error_size) snprintf(error, error_size, "Cannot open %s: %s", path, strerror(errno)); return NULL; }
    if (fseek(f, 0, SEEK_END) || (size = ftell(f)) < 0 || (unsigned long)size > limit || fseek(f, 0, SEEK_SET)) {
        fclose(f); if (error && error_size) snprintf(error, error_size, "Invalid or oversized JSON file: %s", path); return NULL;
    }
    buffer = (char *)malloc((size_t)size + 1);
    if (!buffer) { fclose(f); if (error && error_size) snprintf(error, error_size, "Out of memory"); return NULL; }
    if (fread(buffer, 1, (size_t)size, f) != (size_t)size || ferror(f)) {
        free(buffer); fclose(f); if (error && error_size) snprintf(error, error_size, "Cannot read %s", path); return NULL;
    }
    fclose(f); buffer[size] = '\0'; j = json_parse(buffer, (size_t)size, error, error_size); free(buffer); return j;
}
const Json *json_get(const Json *j, const char *key) {
    const Json *c;
    if (!j || j->type != JSON_OBJECT || !key) return NULL;
    for (c = j->child; c; c = c->next) if (c->key && !strcmp(c->key, key)) return c;
    return NULL;
}
const Json *json_at(const Json *j, size_t index) {
    const Json *c;
    if (!j || j->type != JSON_ARRAY) return NULL;
    for (c = j->child; c && index; c = c->next) --index;
    return c;
}
size_t json_count(const Json *j) { size_t n = 0; const Json *c; if (!j || (j->type != JSON_ARRAY && j->type != JSON_OBJECT)) return 0; for (c = j->child; c; c = c->next) ++n; return n; }
const char *json_string(const Json *j) { return j && j->type == JSON_STRING ? j->string : NULL; }
const char *json_text(const Json *j, const char *key) { return json_string(json_get(j, key)); }
int json_int(const Json *j, int fallback) { return j && j->type == JSON_NUMBER && j->number >= INT_MIN && j->number <= INT_MAX && j->number == (int)j->number ? (int)j->number : fallback; }
int json_bool(const Json *j, int fallback) { return j && j->type == JSON_BOOL ? j->number != 0 : fallback; }
