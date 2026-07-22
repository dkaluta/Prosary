// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    // AGP 9's built-in Kotlin support replaces the separate org.jetbrains.kotlin.android plugin —
    // applying it alongside built-in Kotlin fails with a duplicate 'kotlin' extension error.
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}