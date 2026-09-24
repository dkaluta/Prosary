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
labels, configuration options, the explicitly non-Scripture fourth Sorrow narrative, and the
fourteen short traditional Stations scene descriptions are Prosary's editorial translations.
The latter describe the scenes; they are not the longer meditations by St Alphonsus.

The repeated Via Lucis acclamation follows the twenty-word excerpt from the same prayerbook
published by [CREDO](https://credo.pro/2014/01/109413), accessed on 19 September 2026. The
prayerbook's local recension is retained, with reader/assembly initials replaced by response
emphasis.

The standard Rosary closing collect, also used by the Franciscan Crown and the Loreto
“after the Rosary” option, follows the published prose text from the
[Ukrainian Information Center MIR Medjugorje](https://medjugorje.com.ua/media/video/molytvy/6220-6-den-novenna-do-bozhoyi-matery-fatymskoyi17-bereznya-25-bereznya-2022.html).
The source page explicitly permits publication with a link to the site: «Публікація
матеріалів дозволена тільки з посиланням на сайт.» This is an attribution condition, not a
public-domain or Creative Commons claim. The text is retained exactly, including its
published invocation and conclusion. The page was checked on 19 September 2026; its URL
contains 2022 while the displayed article date is 9 May 2026. The same prayer is also
published in the Ukrainian Legion of Mary's Tessera; that independent witness is not the
permission source.

`Shared/tools/fixtures/ukrainian-source-excerpts.json` retains nineteen selected source
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

The following **four distinct keys remain unavailable in the bundle**. They are deliberately absent from
`uk.json`, and incomplete bundles are not described as fully translated. None is substituted
with a newly composed prayer or another author's text under the original author's name.

| Bundle | Remaining keys |
| --- | --- |
| Rosary | `almaRedemptorisMater`, `aveReginaCaelorum` |
| Stations of the Cross | `stationsOpeningPrayer`, `stationsClosingPrayer` |

The Franciscan Crown also uses the same two shared Marian-antiphon keys listed under
Rosary, so it has the same optional closing fallbacks. All fourteen scriptural Stations
have sourced Ukrainian passages, and the traditional scene descriptions are Ukrainian editorial
translations. The Via Lucis readings, full Regina Caeli closing and repeated acclamation are
Ukrainian. The format validator's scoped allowlists document the
non-fixed missing keys; the coverage audit additionally catches the shared fixed-key gaps.

## Located Marian antiphons

Published Ukrainian versions of both missing antiphons have been located and checked against
the printed scores in *Вгору серця: Церковний співник Римо-Католицької Церкви* (Kyiv, 2006):

| Prayer | Number and Ukrainian title | Credited translator from Latin | Printed source |
| --- | --- | --- | --- |
| Ave Regina Caelorum | 457, «Радуйся, Царице неба» | І. Волоцька | [Score](https://www2.truechristianity.info/img/vgoru_sertsya/vgoru_sertsya_457.png) |
| Alma Redemptoris Mater | 458, «Рідна Спасителя Мати» | О. Сартаков | [Score](https://www2.truechristianity.info/img/vgoru_sertsya/vgoru_sertsya_458.png) |

The [book's contents and publication credits](https://www2.truechristianity.info/ua/books/tserkovny_spivnyk_rymo-katolytskoyi_tserkvy/vgoru_sertsya_content.php)
give Bishop Stanislav Shyrokoradiuk's imprimatur, the censor Sr Maria Marta Ryk OSU,
compiler/music editor Kostiantyn Babenko and literary editor Mykola Lutsiuk. The numbers above
are song numbers, not a claimed pagination. An independent
[2012 Hnivan songbook transcription](https://pisennyk-osppe.blogspot.com/2012/10/blog-post_4846.html)
reproduces them as numbers 902 and 904 and explicitly lists *Вгору серця*, Kyiv 2006, among
its sources. That transcription differs slightly from the printed score, so the scan is the
wording authority.

These two gaps are **sources found, reuse unresolved**. Their ancient Latin originals do not
establish a public-domain status for the credited modern Ukrainian translations. No publisher
reuse statement for these versions was located, and RKC Ukraine's permission for its own
prayerbook is not extended to this separate songbook. The full texts have therefore not been
copied into the bundles or fixtures. The two Stations keys still need a matching published
Ukrainian form; no newly composed prayer is supplied in their place.

The renewed source review on 19 September 2026 also checked the Ukrainian entries in
[Divinum Officium](https://github.com/DivinumOfficium/divinum-officium) at revision
`5e27a65f632350719c697960e5416001a9e77a5c`, the Ukrainian Marian-antiphon references on Vatican
News, and Catholic Stations publications. The open-source Ukrainian office corpus does not
yet contain these two Marian antiphons. Vatican News identifies them but the inspected
pages do not print their Ukrainian bodies. The public-domain 1921
[Хрестна Дорога](https://uk.wikisource.org/wiki/Хрестна_Дорога) and the published
[Stations for souls in purgatory](https://kyrios.org.ua/literature/books/261-misjats-dush-chistilischnih.html)
contain different opening and closing prayers; those are not silently substituted for the
existing texts. These are the limits of the verified sources, not a claim that Ukrainian
translations cannot exist.
