package com.dkaluta.prosary.content

/** Only complete, recognized procession clauses are edited. No other occurrence of Son,
 * including the Creed's worship clause, belongs to this preference. */
object NiceneCreedText {
    private data class Clause(val included: String, val omitted: String, val bracketed: String? = null)
    private val keys = setOf("symbolumNicaenum", "symbolumApostolorum")
    private val clauses = listOf(
        Clause("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב"),
        Clause("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב"),
        Clause("הנובע מהאב ומהבן", "הנובע מהאב", "הנובע מהאב [ומהבן]"),
        Clause("אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן", "אֲשֶׁר נֶאֱצַל מִן הָאָב", "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)"),
        Clause("הַו דּמֶן אַבָא ובא ננפֶק", "הַו דּמֶן אַבָא ננפֶק"),
        Clause("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ"),
        Clause("qui ex Patre Filioque procedit", "qui ex Patre procedit"),
    )

    fun applyingPolicy(key: String, text: String, policy: CreedPolicy?): String {
        if (key !in keys || policy?.filioque !in setOf("absent", "bracketed", "unbracketed")) return text
        val forms = listOf(
            Triple("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב", "הַנּוֹבֵעַ מֵהָאָב [וּמֵהַבֵּן]"),
            Triple("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב", "הַנּוֹבֵעַ מֵהָאָב [וּמֵהַבֵּן]"),
            Triple("הנובע מהאב ומהבן", "הנובע מהאב", "הנובע מהאב [ומהבן]"),
            Triple("אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן", "אֲשֶׁר נֶאֱצַל מִן הָאָב", "אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]"),
            Triple("הַו דּמֶן אַבָא ובא ננפֶק", "הַו דּמֶן אַבָא ננפֶק", "הַו דּמֶן אַבָא [ובא] ננפֶק"),
            Triple("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ"),
            Triple("qui ex Patre Filioque procedit", "qui ex Patre procedit", "qui ex Patre [Filioque] procedit"),
            Triple("що від Отця і Сина ісходить", "що від Отця ісходить", "що від Отця [і Сина] ісходить"),
        )
        var result = text
        for ((included, omitted, bracketed) in forms) {
            val replacement = when (policy?.filioque) { "absent" -> omitted; "bracketed" -> bracketed; else -> included }
            val parenthesized = bracketed.replace('[', '(').replace(']', ')')
            // An omitted source stays omitted: there is no authority to invent a clause.
            result = result.replace(bracketed, replacement).replace(parenthesized, replacement).replace(included, replacement)
        }
        return result
    }

    fun statusQuo(key: String, text: String): Boolean? {
        if (key !in keys) return null
        // Included wording must be considered before omitted prefixes: both supported
        // niqqud combining orders share the same procession prefix.
        for (clause in clauses) {
            if (text.contains(clause.included) || clause.bracketed?.let(text::contains) == true) return true
        }
        if (clauses.any { text.contains(it.omitted) }) return false
        // This Greek source contains no supplied Filioque wording; the preference never
        // inserts a translation that the source does not provide.
        if (text.contains("τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον")) return false
        return null
    }

    fun applying(key: String, text: String, include: Boolean): String {
        if (key !in keys) return text
        var result = text
        for (clause in clauses) {
            val replacement = if (include) clause.included else clause.omitted
            clause.bracketed?.let { result = result.replace(it, replacement) }
            // Omitted clauses must never gain a phrase absent from their source. The shipped
            // sources carry the included phrase; toggling back resolves that original again.
            result = result.replace(clause.included, replacement)
        }
        return result
    }
}
