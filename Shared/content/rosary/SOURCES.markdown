# Vicariate Hail Mary wording

The default Hebrew fixed Hail Mary retains the St. James Vicariate prayer book's
**מְלֵאַת הַחֶסֶד**. The optional Jaffa wording is **בְּרוּכַת הַחֶסֶד**.

On 6 September 2026, the user supplied the Jaffa wording and reported that the congregation's
pastor, **Fr. Apolinary Tadeusz Szwed, OFM**, had verified it and personally prays this way.
The user subsequently confirmed the rendering with vowel points. This attribution records
user-supplied pastoral testimony; it is not a claim of independent verification or a published
edition. The exact source pair and attribution are recorded in
[`vicariate-wording.json`](../../tools/vicariate-wording.json).

The app-wide `useJaffaHailMaryWording` preference is off by default. When enabled, it substitutes
the phrase only after a Vicariate prayer has won text resolution, including explicitly marked
Vicariate repository content. Pointed prayer text uses the pointed replacement; an exact
unpointed phrase in a marked prayer stays unpointed. Mission wording, unmarked shared Hebrew,
and Scripture retain their own texts. The setting also applies when Vicariate is reached
through the user's fallback order, without changing that order.

The source prayer text is never rewritten by the preference. No corresponding reading aid
was supplied for the Jaffa wording, so an affected prayer's original aid is omitted while
the substitution is enabled. Unaffected prayers retain their aids.
