#ifndef PROSARY_UI_H
#define PROSARY_UI_H

#include "app.h"
#include "engine.h"

/* Runs the single terminal screen. Calls save after every progress/settings change.
 * The caller owns engine/state and must initialize the process locale first. */
int ui_run(ProsaryEngine *engine, AppState *state, AppSave save, void *context);

#endif
