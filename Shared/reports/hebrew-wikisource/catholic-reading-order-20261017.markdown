# Hebrew Catholic reading-order review — 2026-10-17

The requested Hebrew browsing sequence is Tanakh, deuterocanon, then New Testament.
The Masoretic section follows the Torah/Prophets/Writings navigation of
[tanach.us](https://www.tanach.us/Pages/CitationSyntax.html), retaining all 39 split
source book IDs. The 12 separately sourced deuterocanonical works follow the
relative [USCCB Catholic book sequence](https://www.usccb.org/offices/new-american-bible/books-bible):
Tobit, Judith, Esther additions, 1–2 Maccabees, Wisdom, Sirach, Baruch, Letter of
Jeremiah, Prayer of Azariah and Song of the Three, Susanna, Bel and the Dragon.
The 27 New Testament books follow. No book is added, omitted, merged or renamed.

## Internal sequences verified against NABRE

The table lists **printed source labels**, not newly assigned NABRE citations.
The reviewed Hebrew units were compared directly with the Catholic NABRE published
by the USCCB. Only complete source units move. Their exact wording, vowel points,
notes, bracketed damage and combined boundaries remain unchanged.

| Source sequence | Generated sequence | Clause evidence |
| --- | --- | --- |
| 3:26,27,25 | 3:25,26,27 | The pupil/light and knowledge/wisdom proverb precedes the stubborn-heart sayings. [Sirach 3](https://bible.usccb.org/bible/sirach/3) |
| 10:3,2,4,5 | 10:2,3,5,4 | Judge/officials precedes the reckless king. Source 5's sovereignty over the earth corresponds to NABRE 4; source 4's sovereignty over individuals corresponds to NABRE 5. [Sirach 10](https://bible.usccb.org/bible/sirach/10) |
| 11:33 / 12:1 / 11:34 / 12:2 | 11:33,34 / 12:1,2 | The stranger/alienation warning closes chapter 11; chapter 12 opens with knowing whom to help, then helping the righteous. [Sirach 11](https://bible.usccb.org/bible/sirach/11), [Sirach 12](https://bible.usccb.org/bible/sirach/12) |
| 31:14,15 | 31:15,14 | NABRE itself puts the neighbor's feelings before the warning not to reach for the same dish. Independently compared by the parent review. [Sirach 31](https://bible.usccb.org/bible/sirach/31) |
| 33:28–29,27 | 33:27,28–29 | The yoke/restraint saying precedes the work/idleness saying; combined 28–29 remains one unit. [Sirach 33](https://bible.usccb.org/bible/sirach/33) |
| 36:26,24,25 | 36:24,25,26 | Palate/deceit and crooked-heart/experienced-person sayings precede the wife comparison. Source 25's additional damaged words remain attached. [Sirach 36](https://bible.usccb.org/bible/sirach/36) |
| 37:25,24 | 37:24,25 | The wise person's enjoyment precedes numbered human days versus Israel's countless days. The unnumbered people-wise couplet preceding both stays unnumbered. [Sirach 37](https://bible.usccb.org/bible/sirach/37) |
| 38:22,21 | 38:21,22 | The futility of recalling the dead precedes the reminder that the same fate awaits the living. [Sirach 38](https://bible.usccb.org/bible/sirach/38) |
| 48:8,7 | 48:7,8 | Hearing judgments at Sinai/Horeb precedes anointing and prophetic succession. [Sirach 48](https://bible.usccb.org/bible/sirach/48) |
| 50:3,2 | 50:2,3 | Temple-wall construction precedes reservoir excavation. [Sirach 50](https://bible.usccb.org/bible/sirach/50) |

These are bounded reading-order correspondences, not a complete NABRE verse
crosswalk or a claim that every clause agrees across recensions. Numeric sorting
would be wrong for both Sirach 10 and 31. NABRE 33 also has an interleaved
20a/21/20b sequence, which this review does not project onto an indivisible Hebrew
source unit.

## Deliberately unresolved

- **Sirach 31:19–22:** source primary 19 includes a clause corresponding to NABRE
  20; primary 22 includes NABRE's moderation clause plus damaged repeated material,
  while the second 22 witness contains the advice-listening clause. Whole-unit
  sorting cannot fully align these clauses. All remain in their existing source
  sequence, including both witnesses. The earlier 14/15 change is independent.
- **Sirach 42:23/25/24:** source 23 combines material corresponding to NABRE 23a
  and 25a; source 25 combines 25b with damaged material corresponding to 22b and
  23b. Reordering whole units cannot resolve that mixture. Independently checked
  against [Sirach 42](https://bible.usccb.org/bible/sirach/42).
- **Repeated/overlapping witnesses and unnumbered material:** source 41:14–16,
  repeated 51:13/19/20, the thanksgiving hymn and closing blessing are retained.
  No witness is dropped, and no unnumbered passage gains an invented verse.
- **Additions:** the existing Esther A/B/C/C/D/E/F section metadata and Daniel
  3/13/14 and Baruch 6 placements already follow the reviewed Catholic sequence.
  Their source IDs and verse divisions differ from NABRE; this review does not
  introduce a verse conversion or splice them into the Masoretic base.

## Projection and verification

`Shared/tools/hebrew-bible-presentation-reviews.json` pins the canonical Sirach
digest and individual moved-unit hashes and boundaries. The generator first loads
the approved source, then projects the explicit sequences onto a copy. Same-chapter
verse arrays and existing block arrays move together. Source 11:34 retains its
chapter/verse identity; returning its display block to chapter 11 removes its
obsolete route. All canonical source JSON remains unchanged by this projection.

Focused tests compare every full primary unit and block before and after, reject
changed hashes, unknown sequences, missing/duplicate units and invalid boundaries,
and retain all chapter completeness flags. Existing daily-reading reviews continue
to select their own exact source units and are not widened or reordered here.
Archive revisions incorporate the generated order; earlier content-addressed
archives remain intact. Other Bible editions keep their existing sequences.
