package com.dkaluta.prosary.ui.readings

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.staticCompositionLocalOf

/** Focus belongs to the current reader window, never to saved app preferences. */
internal val LocalBibleReadingChrome = staticCompositionLocalOf<MutableState<Boolean>?> { null }
