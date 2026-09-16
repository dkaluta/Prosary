package com.dkaluta.prosary.models

/** App languages are the shipped interface locales; prayer-only languages stay in their picker. */
object InterfaceLanguage {
    const val preferenceKey = "interfaceLanguageCode"
    val codes = listOf("en", "he", "ar", "ru", "tl", "fr", "it", "uk")

    fun normalized(raw: String): String {
        val base = LanguageCatalog.uiLanguageCode(raw).substringBefore('-')
        return base.takeIf { it in codes }.orEmpty()
    }

    fun effective(preferred: List<String>): String =
        preferred.firstNotNullOfOrNull { normalized(it).takeIf(String::isNotEmpty) } ?: "en"

    fun platformCode(code: String): String = normalized(code).let { if (it == "tl") "fil" else it }
    fun nativeName(code: String): String = LanguageCatalog.pickerLanguageName(normalized(code))
}
