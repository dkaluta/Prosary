package com.dkaluta.prosary.typography

/** Display-only treatment for Hebrew headings. Canonical prayer and Scripture text remains
 * pointed; headings are easier to scan without niqqud or cantillation and match the rest of the
 * app's Hebrew chrome. Hebrew punctuation (maqaf, sof pasuq, nun hafukha) is deliberately kept. */
object HebrewDisplayText {
    fun unpoint(text: String): String = buildString(text.length) {
        for (character in text) {
            if (!character.isHebrewMark()) append(character)
        }
    }

    private fun Char.isHebrewMark(): Boolean =
        code in 0x0591..0x05BD ||
            code == 0x05BF ||
            code in 0x05C1..0x05C2 ||
            code in 0x05C4..0x05C5 ||
            code == 0x05C7
}
