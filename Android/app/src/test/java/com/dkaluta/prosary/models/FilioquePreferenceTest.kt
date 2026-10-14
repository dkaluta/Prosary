package com.dkaluta.prosary.models

import org.junit.Assert.assertNull
import org.junit.Test

class FilioquePreferenceTest {
    @Test fun languageSelectionAndRenderingHaveNoPersistentFilioqueChoice() {
        for (language in listOf("", "la", "el", "he", "he-x-gamliel", "arc", "uk")) {
            AppSettings.initializeFilioqueFromSelection(language)
            AppSettings.initializeFilioqueFromSource(true)
            AppSettings.includeFilioque = false
            assertNull(AppSettings.includeFilioqueChoice)
        }
    }
}
