package com.dkaluta.prosary.ui.shared

import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.unit.LayoutDirection
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.prosary.models.AppSettings

/** Bluetooth, USB and built-in alphabetic keyboards count; IMEs, remotes and gamepads do not. */
@Composable
fun rememberHardwareKeyboardAvailable(): Boolean {
    val context = LocalContext.current
    val manager = remember(context) { context.getSystemService(InputManager::class.java) }
    fun queryAvailability() = manager.inputDeviceIds.any { id ->
        manager.getInputDevice(id)?.let { !it.isVirtual && it.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC } == true
    }
    var available by remember(manager) { mutableStateOf(queryAvailability()) }
    DisposableEffect(manager) {
        val listener = object : InputManager.InputDeviceListener {
            override fun onInputDeviceAdded(deviceId: Int) { available = queryAvailability() }
            override fun onInputDeviceRemoved(deviceId: Int) { available = queryAvailability() }
            override fun onInputDeviceChanged(deviceId: Int) { available = queryAvailability() }
        }
        manager.registerInputDeviceListener(listener, Handler(Looper.getMainLooper()))
        available = queryAvailability()
        onDispose { manager.unregisterInputDeviceListener(listener) }
    }
    return available
}

internal enum class PrayerKeyboardAction { Ignore, Consume, Previous, Next }

/** Kept independent of Compose dispatch so focus, modifiers and repeat rules are testable. */
internal fun prayerKeyboardAction(
    keyCode: Int,
    isKeyDown: Boolean,
    repeatCount: Int,
    hasModifiers: Boolean,
    readerActive: Boolean,
    arrowsEnabled: Boolean,
    spaceEnabled: Boolean,
    rightToLeft: Boolean,
    canGoBack: Boolean,
): PrayerKeyboardAction {
    if (!readerActive || hasModifiers) return PrayerKeyboardAction.Ignore
    val action = when (keyCode) {
        KeyEvent.KEYCODE_DPAD_LEFT -> if (arrowsEnabled) {
            if (rightToLeft) PrayerKeyboardAction.Next else PrayerKeyboardAction.Previous
        } else return PrayerKeyboardAction.Ignore
        KeyEvent.KEYCODE_DPAD_RIGHT -> if (arrowsEnabled) {
            if (rightToLeft) PrayerKeyboardAction.Previous else PrayerKeyboardAction.Next
        } else return PrayerKeyboardAction.Ignore
        KeyEvent.KEYCODE_SPACE -> if (spaceEnabled) PrayerKeyboardAction.Next else return PrayerKeyboardAction.Ignore
        else -> return PrayerKeyboardAction.Ignore
    }
    // Consume an enabled shortcut's release/repeat without navigating again or moving focus.
    if (!isKeyDown || repeatCount != 0 || action == PrayerKeyboardAction.Previous && !canGoBack) {
        return PrayerKeyboardAction.Consume
    }
    return action
}

/** Attached to the scrollable reader, never to the whole Activity or a global key monitor. */
@Composable
internal fun prayerKeyboardNavigationModifier(
    sessionActive: Boolean,
    interfaceDirection: LayoutDirection,
    canGoBack: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
): Modifier {
    val keyboardAvailable = rememberHardwareKeyboardAvailable()
    val window = LocalWindowInfo.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val focusRequester = remember { FocusRequester() }
    var readerFocused by remember { mutableStateOf(false) }
    LaunchedEffect(keyboardAvailable, sessionActive) {
        if (keyboardAvailable && sessionActive) focusRequester.requestFocus()
    }
    return Modifier
        .focusRequester(focusRequester)
        .onFocusChanged { readerFocused = it.isFocused }
        // LazyColumn already owns a focus target for scrolling. Make that target available
        // even for short prayers without adding a second target that would swallow Page keys.
        .focusProperties { canFocus = keyboardAvailable }
        .onPreviewKeyEvent { event ->
            val native = event.nativeKeyEvent
            val action = prayerKeyboardAction(
                keyCode = native.keyCode,
                isKeyDown = native.action == KeyEvent.ACTION_DOWN,
                repeatCount = native.repeatCount,
                hasModifiers = native.isShiftPressed || native.isAltPressed || native.isCtrlPressed ||
                    native.isMetaPressed || native.isSymPressed || native.isFunctionPressed,
                readerActive = keyboardAvailable && sessionActive && readerFocused && window.isWindowFocused &&
                    lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED),
                arrowsEnabled = AppSettings.keyboardArrowNavigationEnabled,
                spaceEnabled = AppSettings.keyboardSpaceAdvanceEnabled,
                rightToLeft = interfaceDirection == LayoutDirection.Rtl,
                canGoBack = canGoBack,
            )
            when (action) {
                PrayerKeyboardAction.Previous -> onBack()
                PrayerKeyboardAction.Next -> onNext()
                else -> Unit
            }
            action != PrayerKeyboardAction.Ignore
        }
}
