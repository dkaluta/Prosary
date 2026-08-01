package com.dkaluta.prosary.content.repository

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pins the prayers.prosary.app /index.json contract (prosaryRepository: 1) without a network. */
class RepositoryClientTest {
    private val fixture = """
        {"prosaryRepository": 1, "bundles": [
          {"id": "repo.dkaluta.kyrie", "name": "Kyrie", "author": "dkaluta",
           "languages": ["la", "en"], "tags": ["short"],
           "description": "A one-minute devotion.", "file": "/api/download/repo.dkaluta.kyrie"}
        ]}
    """.trimIndent()

    @Test
    fun parsesTheVersionedCatalog() {
        val bundles = RepositoryClient.parseCatalog(fixture)
        assertEquals(1, bundles.size)
        assertEquals("repo.dkaluta.kyrie", bundles[0].id)
        assertEquals("dkaluta", bundles[0].author)
        assertEquals(listOf("la", "en"), bundles[0].languages)
        assertEquals(listOf("short"), bundles[0].tags)
        assertEquals("/api/download/repo.dkaluta.kyrie", bundles[0].file)
    }

    @Test
    fun rejectsANewerCatalogVersion() {
        val result = runCatching { RepositoryClient.parseCatalog("""{"prosaryRepository": 2, "bundles": []}""") }
        assertTrue(result.exceptionOrNull() is RepositoryClient.UnsupportedCatalogException)
    }
}
