# Ukrainian prayer content

Ukrainian (`uk`) is an available prayer language on all three platforms. Its ten built-in
overlays contain real Ukrainian text; availability does **not** mean every optional prayer
body has been translated. Missing bodies continue through the user's saved language order.
The independent `audit-prayer-coverage.py` report preserves these gaps instead of counting
fallback text as Ukrainian.

## Published prayers

The principal source is the [Roman Catholic Church in Ukraine prayerbook](https://rkc.org.ua/duhovnist/molytovnyk/),
*Щоденно з Богом*. The publisher says these texts have been approved by its Liturgical
Commission and permits full or partial reuse with a link to https://rkc.org.ua/.
This permission is not represented as public domain or a Creative Commons license.
Every platform's About screen and the canonical files retain the required attribution.

The six Basic Prayers, Jesus Prayer, Fatima prayer, Saint Michael prayer, Anima Christi,
Sub Tuum Praesidium, Salve Regina, Regina Caeli, Angelus, Divine Mercy prayers, Loreto
invocations and ordinary collect, seven O Antiphons, and Seven Sorrows closing follow the
published Ukrainian Catholic wording. The source's Ukrainian recension is retained when
its phrasing differs from the English or Latin counterpart. In particular, the O Antiphons
follow the publisher's shorter Ukrainian liturgical form; the Seven Sorrows closing uses
the contiguous closing of its third, shortened version.

Line breaks, bold responses, and the app's cross cue are presentation changes. Rubrics such
as “three times” are omitted where the prayer engine performs that repetition. The Loreto
collect joins the source's line-break artifact “Пре- святої” as “Пресвятої”. A prayer's
wording is never filled by a machine translation. Titles, fruits of mysteries, intention
labels, configuration options, and the explicitly non-Scripture fourth Sorrow narrative are
Prosary's translations of editorial metadata.

`Shared/tools/fixtures/ukrainian-source-excerpts.json` retains seventeen selected source
excerpts, their original page URLs and page SHA-256 fingerprints, including all six Basic
Prayers and every O Antiphon. `test-ukrainian-content.py` checks these independently of
formatting, including the complete four-line Regina Caeli and its separate versicle,
response, and collect.

## Scripture

All 63 Scripture passages are imported from the
[Kulish, Nechui-Levytsky and Puluj Bible (1905), eBible.org `ukr1871`](https://ebible.org/find/details.php?id=ukr1871),
which the distributor explicitly identifies as public domain. This historical edition is
distinct from the modern Catholic prayerbook; its spelling is preserved and its name
appears in every Scripture citation. The source is not identified as the Khomenko Catholic
translation. The selected passages do not require deuterocanonical books.

`Shared/tools/import-scripture.py --language uk` imports the actual verse-per-line archive;
`--check` verifies the result without writing. The verse text inside that regularly rebuilt
ZIP is pinned by SHA-256 `1d2230822492a230c04fbea34f1b5ede7073a9d19c23a461d9738c87b85c2ec1`.
Changed wording fails until separately reviewed. The archive contains Matthew, Mark, Luke,
John, Acts, Revelation and Isaiah; Isaiah's darkness-and-light passage is 9:2 in this edition,
so the Crampon/Septuagint 9:1 offset must not be applied. Twelve independent verse excerpts
cover all nine imported Isaiah verses, the Annunciation, scourging and Revelation.

## Remaining fallback bodies

The following **21 distinct keys remain untranslated**. They are deliberately absent from
`uk.json`, and incomplete bundles are not described as fully translated. None is substituted
with a newly composed prayer or another author's text under the original author's name.

| Bundle | Remaining keys |
| --- | --- |
| Rosary | `almaRedemptorisMater`, `aveReginaCaelorum`, `collectaStandard` |
| Loreto | `collectAfterRosary` |
| Stations of the Cross | `stationsOpeningPrayer`, `stationsClosingPrayer`, `station01Body`, `station02Body`, `station03Body`, `station04Body`, `station05Body`, `station06Body`, `station07Body`, `station08Body`, `station09Body`, `station10Body`, `station11Body`, `station12Body`, `station13Body`, `station14Body` |
| Via Lucis | `viaLucisAcclamation` |

The Franciscan Crown also uses the same three shared Marian-antiphon keys listed under
Rosary, so it has the same optional closing fallbacks. All fourteen scriptural Stations
have sourced Ukrainian passages; the traditional St Alphonsus meditations remain fallback
text. The Via Lucis readings and full Regina Caeli closing are Ukrainian, while its repeated
acclamation remains fallback text. The format validator's scoped allowlists document the
non-fixed missing keys; the coverage audit additionally catches the shared fixed-key gaps.
