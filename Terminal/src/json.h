#ifndef PROSARY_JSON_H
#define PROSARY_JSON_H
#include "compat.h"

#include <stddef.h>
typedef enum { JSON_NULL, JSON_BOOL, JSON_NUMBER, JSON_STRING, JSON_ARRAY, JSON_OBJECT } JsonType;
typedef struct Json {
    JsonType type;
    char *key;
    char *string;
    double number;
    struct Json *child;
    struct Json *next;
} Json;
Json *json_parse(const char *text, size_t length, char *error, size_t error_size);
Json *json_read_file(const char *path, size_t limit, char *error, size_t error_size);
void json_free(Json *value);
const Json *json_get(const Json *object, const char *key);
const Json *json_at(const Json *array, size_t index);
size_t json_count(const Json *array);
const char *json_string(const Json *value);
const char *json_text(const Json *object, const char *key);
int json_int(const Json *value, int fallback);
int json_bool(const Json *value, int fallback);
#endif
