package com.dkaluta.prosary.content.today

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class ReadingDisplayOrderTest {
    @Test fun gospelFirstChangesPresentationAndKeepsCanonicalAppointmentsIntact() {
        val first = ReadingCitation("reading", "Is 1", "Isaiah 1:1–5", sourceText = "Is1:1-5", sourceGroup = "Day Mass", readingDatasetId = "fixture")
        val psalm = ReadingCitation("psalm", "Ps 2", "Psalm 2:1–3", sourceText = "Ps2:1-3", sourceGroup = "Day Mass", readingDatasetId = "fixture")
        val gospel = ReadingCitation("gospel", "Jn 3", "John 3:16–18", sourceText = "Jn3:16-18", sourceGroup = "Day Mass", readingDatasetId = "fixture")
        val source = listOf(first, psalm, gospel)
        assertEquals(source, ReadingCitation.displayOrder(source, false))
        assertEquals(listOf(gospel, psalm, first), ReadingCitation.displayOrder(source, true))
        assertEquals(listOf(first, psalm, gospel), source)
        assertSame(gospel, ReadingCitation.displayOrder(source, true).first())
    }

    @Test fun duplicateCitationRowsRetainTheirOriginalExpansionIdentityWhenReversed() {
        val vigil = ReadingCitation("gospel", "Jn 3", "John 3:16–18", sourceGroup = "Vigil Mass")
        val day = vigil.copy(sourceGroup = "Day Mass")
        val canonical = listOf(vigil, day)
        val displayed = ReadingCitation.indexedDisplayOrder(canonical, true)
        assertEquals(listOf(1, 0), displayed.map { it.index })
        assertSame(day, displayed[0].value)
        assertSame(vigil, displayed[1].value)
        assertEquals(listOf(0, 1), ReadingCitation.indexedDisplayOrder(canonical, false).map { it.index })
    }
}
