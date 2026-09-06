# Litany of Loreto — source record

This built-in prayer has two exclusive forms with the same first fifteen steps:

- Opening it directly uses `standard`, ending only with **Concede nos famulos**.
- Continuing from a completed Rosary uses `afterRosary`, ending only with **Deus cuius
  Unigenitus**. This context applies to the session, without changing an existing favorite.

The app chooses the ending from the entry context. It does not display both collects or offer
a manual form switch for this built-in devotion. Each of the ten declared languages contains
both complete forms, and each final collect has its own source or translation credit.

## Published texts

| Language | Litany and standalone collect | Rosary collect |
| --- | --- | --- |
| Hebrew | Erez / `stgamliel-il`, [gallery prayer](https://prayers.prosary.app/api/download/repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin), updated 9 August 2026 | The same contribution explicitly supplies a separate collect for use after the Rosary. |
| Latin | [Salesian Bulletin / Don Bosco](https://donbosco.press/en/litany-of-the-blessed-virgin-mary/); invocation order cross-checked against the [Latin/French parallel text](https://www.peuterey-editions.com/191-nouvelles-les-litanies-de-lorette.html) and the [2020 Vatican letter](https://press.vatican.va/content/salastampa/it/bollettino/pubblico/2020/06/20/0350/00805.html). | The app's existing Latin Rosary collect, as published in the Vatican Compendium. |
| English | [Vatican Litany of Loreto](https://www.vatican.va/special/rosary/documents/litanie-lauretane_en.html) | The app's existing published Rosary collect. |
| French | [Vatican Litany](https://www.vatican.va/special/rosary/documents/litanie-lauretane_fr.html), transcription cross-check with [AMDG](https://www.amdg.asso.fr/ressources/litanies_ste_vierge.htm) | [Vatican Compendium](https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_fr.html), already used by the Rosary. |
| Italian | [Vatican Litany](https://www.vatican.va/special/rosary/documents/litanie-lauretane_it.html) | [Vatican Compendium](https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_it.html), already used by the Rosary. |
| Spanish | [Vatican Litany](https://www.vatican.va/special/rosary/documents/litanie-lauretane_sp.html) | [Vatican Compendium, Oración tras el rosario](https://www.vatican.va/archive/compendium_ccc/documents/archive_2005_compendium-ccc_sp.html) |
| Russian | [Normative 2023 Russian Catholic bishops' text](https://catholic-russia.ru/wp-content/uploads/2023/03/litania-lauretana-lat-rus.pdf), including the standalone collect; [approval notice](https://catholic-russia.ru/2023/loretanskaya-litaniya-utverzhden-novyj-perevod/). | [Vatican Russian Compendium](https://www.vatican.va/archive/compendium_ccc/documents/archive_compendium-ccc_ru.pdf), printed page 204. |
| Arabic | [Peniche Catholic parish's Arabic prayer page](https://paroquiapeniche.pt/ar/recursos/devocionario/rosario/), supplemented by the three additions in [Vatican News Arabic](https://www.vaticannews.va/ar/vatican-city/news/2020-06/papa-francesco-tre-nuove-invocazioni-litanie-lauretane-roche.html). This is a parish publication, not claimed to be a normative episcopal translation. | [Institute of the Incarnate Word, Marian month prayerbook](https://iveinarabic.org/wp-content/uploads/2019/11/الشهر-المريمي.pdf), printed page 3. The booklet prints the Rosary collect before its Rosary; Prosary places it after the litany as requested. |
| Tagalog | Litany: [Carmel of Lipa's 2021 prayerbook](https://ourladymarymediatrixofallgrace.com/wp-content/uploads/2024/06/Novena-in-Honor-of-Our-Lady-Mary-Mediatrix-of-All-Grace-English%E2%80%A2Filipino%E2%80%A2Cebuano-1.pdf), printed pages 40–43. Prepared by Fr Roland D. Mactal OP; Filipino translation John Jack Wigley PhD; proofreader Fr Felix F. delos Reyes Jr OP. Imprimatur Bishop Jose Colin Bagaforo; nihil obstat Fr Virgilio A. Ojoy OP. Standalone collect: **Prosary translation from the Latin original**, not a published liturgical translation. | [Our Lady of Remedies parish Rosary booklet, hosted by CBCP Laiko](https://www.cbcplaiko.org/wp-content/uploads/2019/08/Banal-na-Santo-Rosaryo_Misteryo-ng-Tuwa.pdf), printed page 14. |
| Greek | Litany: [Greek Catholic Synodal Commission for Divine Worship, 2024](https://icen.gr/λιτανικές-ικεσίες-στην-παναγία-2024/). Standalone collect: **Prosary translation from the Latin original**, not a published liturgical translation. | The same [2024 Synodal Commission PDF](https://icen.gr/wp-content/uploads/2024/06/Λιτανικές-Ικεσίες-στην-Παναγία-2024.pdf). |

The Greek and Tagalog standalone translation status is disclosed in every platform's About
screen in all seven interface languages. It is not presented as episcopally approved wording.

## Transcription decisions

- Erez's raw Hebrew contribution is retained in `sources/erez-he.json`. Only alignment spaces,
  indentation and pointing of יהוה are normalized in displayed text. The original instructions
  selecting between the two collects become app behavior, not extra prayer text. His older
  form has 51 Marian invocations and lacks the three 2020 additions. Those Hebrew invocations
  have not been invented or machine-translated.
- The published Greek 2024 form has 53 Marian invocations, includes the three 2020 additions,
  and omits `Virgo clemens`. Its wording and order are preserved. Other complete editions have
  54 Marian invocations. Different source editions are not silently forced to identical text.
- Repeated responses are expanded after each invocation. Page line wraps are normalized;
  response marks are presentation. The Hebrew words and both collects are compared against
  the supplied original by `Shared/tools/test-litany-content.py`.
- The Vatican French page repeats “Christ, écoute-nous” and mislabels three Virgin invocations
  as Mother invocations. The five short corrections follow published parallel French forms:
  `exauce-nous`, `Vierge très prudente`, `Vierge digne d'honneur`, `Vierge digne de louange`,
  plus the grammatical plural `tristesses`. Duplicate punctuation is removed.
- Italian's duplicated opening Lord-have-mercy line is removed. Latin's duplicated
  `Mater misericordiae` is removed and `Regina familiae` retained from the complete parallel
  Latin source. The 2020 invocations remain in their published positions.
- Arabic hamzas and punctuation are normalized. In the printed Rosary collect, the erroneous
  demonstrative in `في هذه أسرار الوردية` is removed; the remainder is the source prayer.
- Tagalog's printed `Partriyarka` is corrected to `Patriyarka`. Its family/peace invocation
  order follows the canonical sequence, and the Rosary collect retains its `Siya nawa`.

## Syriac / Aramaic gap

A complete, verifiable Syriac Litany of Loreto with both collects has not yet been located.
The [Beith Morounoye 2019 catechism and devotions](https://beith-morounoye.org/forum/index.php?topic=7.0)
contains a referenced Syriac litany, but its public preview exposes only sample/contents pages.
The [Christian Musicological Society of India](https://www.thecmsindia.org/encyclopedia-of-syriac-chants/k/kuriyelaison-litany)
explicitly publishes only musically relevant extracts. Neither supplies a complete source.
The user has been asked whether Erez can provide the missing text. Until it is provided, the bundle
does not falsely declare an Aramaic translation; the app's normal language fallback applies.
