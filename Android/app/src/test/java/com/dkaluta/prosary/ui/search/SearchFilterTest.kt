package com.dkaluta.prosary.ui.search

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchFilterTest {
    @Test fun arbitraryLocalAndCommunityTagsRemainDiscoverable() {
        assertEquals(listOf("community-tag", "daily", "other", "rare-devotion"),
            SearchFilter.categories(listOf(listOf("daily", "rare-devotion"), listOf("daily", "community-tag"), emptyList())))
    }

    @Test fun selectedCategoryAndQueryMustBothMatch() {
        assertFalse(SearchFilter.matches("Mary", "mercy", listOf("marian"), listOf("Mary prayer")) { it })
        assertFalse(SearchFilter.matches("unrelated", "marian", listOf("marian"), listOf("Mary prayer")) { it })
        assertTrue(SearchFilter.matches("  MARY  ", "marian", listOf("marian"), listOf("Mary prayer")) { it })
    }

    @Test fun localizedCategorySearchDoesNotChangeTheStableTag() {
        assertTrue(SearchFilter.matches("Мариан", "marian", listOf("marian"), listOf("Prayer")) { "Марианские" })
        assertFalse(SearchFilter.matches("", "mari", listOf("marian"), listOf("Prayer")) { it })
    }

    @Test fun otherIncludesOnlyUntaggedPrayersAndAllClearsTheCategoryConstraint() {
        assertTrue(SearchFilter.matches("", "other", emptyList(), listOf("Prayer")) { it })
        assertFalse(SearchFilter.matches("", "other", listOf("daily"), listOf("Prayer")) { it })
        assertTrue(SearchFilter.matches("author", null, listOf("daily"), listOf("Title", "Author")) { it })
    }
}
