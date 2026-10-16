#pragma once
#include <stdint.h>

// Main-looper only. Payloads are base64 UTF-8 JSON (never JNI modified UTF-8).
// The caller owns the returned string and releases it with ada_studio_free.
char *ada_studio_call(const char *action, const char *payload, int64_t request);
void ada_studio_free(char *value);
