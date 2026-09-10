# Scripture numbering tables

These are unmodified SIL Scripture tables from
[libpalaso commit bb9d36de](https://github.com/sillsdev/libpalaso/tree/bb9d36de70ed7fd6c3e62f0c86c1001f0009eb50/SIL.Scripture/Resources),
retrieved on 10 September 2026. Their bytes were checked against the same files
downloaded from `master` during the readings import. `sources.json` pins each
immutable source URL and SHA-256, including the original [MIT license](LICENSE).
Copyright (c) 2007–2025 SIL Global. This license covers these third-party tables;
Prosary's own code remains covered by the repository's canonical license.

`reading_versification.py` loads these files offline, verifies every checksum,
and maps each supported verse through SIL's Original system. The table headers
identify Original as BHS for the Old Testament and UBS GNT for the New Testament;
the other tables describe English, Vulgate and Russian Orthodox numbering.

The helper accepts the 66 common book identifiers. Deuterocanonical book mapping
is withheld: some tables explicitly have no mapping for a book or use a different
textual source. Vulgate Esther is also withheld because this table describes
Greek Esther under `EST`, with unrepresented verse segments.

Only a unique, reversible mapping of a whole verse is returned. Merged verses,
split verses, superscriptions at verse zero and unsupported segments are unavailable.
Notes about unresolved splits are sometimes only comments in the source tables;
the helper excludes those affected verses too. Stale rows that exceed a declared
chapter cause the affected references to be withheld, never repaired by inference.

Before using an edition's text, callers must check its actual chapter keys with
`chapter_matches(system, book, chapter, verse_numbers)`. The source declaration is
a **maximum verse number**, so comparing only a dictionary's size or its largest
key would miss gaps and duplicate numbering. Matching keys are necessary evidence,
not proof that an edition follows the table in every textual detail. Establish an
edition's numbering independently and withhold known discrepancies.

Likewise, an appointment's language or rite is not a numbering declaration. Where
the calendar's numbering is unresolved, the readings generator requires all its
candidate systems to map the citation to the same target references. A missing or
disagreeing interpretation makes that passage unavailable. The helper does not
parse lectionary citations, choose a calendar, trim subverses or translate text.

Run the offline checks from the repository root:

```sh
uv run --script Shared/tools/reading_versification.py
uv run --script Shared/tools/test-reading-versification.py
```

The tests cover Hebrew Torah chapter boundaries, Vulgate and Synodal merges,
New Testament differences, unsupported or missing references, exact chapter-key
validation, checksum drift, and round trips for every accepted pair of systems.
