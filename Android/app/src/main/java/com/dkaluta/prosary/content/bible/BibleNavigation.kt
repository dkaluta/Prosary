package com.dkaluta.prosary.content.bible

import com.dkaluta.prosary.content.today.ReadingVerse

/** Navigation uses the edition's available source coordinates, never arithmetic guesses. */
object BibleNavigation {
    data class Position(val book: String, val chapter: Int)
    fun verseIndex(verses: List<ReadingVerse>, number: Int): Int =
        verses.indexOfFirst { number >= it.verse && number <= it.lastVerse }
    fun sourceLabel(verse: ReadingVerse, displayChapter: Int, number: (Int) -> String = Int::toString): String {
        val range = number(verse.verse) + if (verse.lastVerse != verse.verse) "–${number(verse.lastVerse)}" else ""
        return if (verse.chapter == displayChapter) range else "${number(verse.chapter)}:$range"
    }
    fun resolve(edition: BibleEdition, book: String?, chapter: Int?): Position {
        val selectedBook = edition.books.firstOrNull { it.id == book } ?: edition.books.first()
        val selectedChapter = selectedBook.chapters.firstOrNull { it.number == chapter } ?: selectedBook.chapters.first()
        return Position(selectedBook.id, selectedChapter.number)
    }
    fun neighbor(edition: BibleEdition, position: Position, direction: Int): Position? {
        require(direction == -1 || direction == 1)
        val positions = edition.books.flatMap { book -> book.chapters.map { Position(book.id, it.number) } }
        val index = positions.indexOf(position)
        return if (index < 0) null else positions.getOrNull(index + direction)
    }
}
