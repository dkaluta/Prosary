package com.dkaluta.prosary.ui.search

/** The same category + query rules apply to installed prayers and the community catalog. */
internal object SearchFilter {
    fun categories(tagLists: Iterable<List<String>>): List<String> =
        tagLists.flatMap(::effectiveTags).distinct().sorted()

    fun matches(
        query: String,
        selectedCategory: String?,
        tags: List<String>,
        searchableText: List<String>,
        categoryLabel: (String) -> String,
    ): Boolean {
        val categories = effectiveTags(tags)
        if (selectedCategory != null && selectedCategory !in categories) return false
        val needle = query.trim()
        return needle.isEmpty() || (searchableText + categories + categories.map(categoryLabel))
            .any { it.contains(needle, ignoreCase = true) }
    }

    private fun effectiveTags(tags: List<String>): List<String> =
        tags.filter(String::isNotBlank).ifEmpty { listOf("other") }
}
