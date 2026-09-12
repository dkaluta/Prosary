# NABRE numeric reference metadata

The snapshot reviewed on September 12, 2026 covers all 73 books, all 1,328 chapter
pages listed by the [official USCCB Bible](https://bible.usccb.org/bible), and
35,519 published verse labels. Every label has a whole-verse correspondence in
`reading_nabre_mapping.py`. This is reference correspondence, not a claim of
identical wording across editions. Split verses and differing clause boundaries
can require a wider passage; the mapper reports that with its envelope flag.

No NABRE Scripture wording is stored in these files or included in the app.
`structure.json` contains labels, published order, omitted markers, and source
URLs. Its browser-source hashes cover normalized numeric observations, **not**
the page's Scripture text. `word-counts.json` contains 61 numeric measurements
needed by STEP's comparative-length predicates, tied to the exact inventory
file and its chapter provenance. `boundary-reviews.json` records 24 additional
reviewed groups with source-page pins and applicable original STEP line numbers.
Psalm boundary reviews are documented in `reading_psalm_mapping.py`.

The mapping rules and their CC BY 4.0 attribution are pinned separately under
`../step`. Official NABRE source links identify the published reference structure;
they do not license redistribution of the translation. See the root
[Prosary license](../../../../LICENSE) for first-party tools.

## Refresh and validate

The HTTP scraper constructs numeric records without writing fetched page bodies:

```sh
uv run --script Shared/tools/fetch-nabre-versification.py --fetch --refresh
uv run --script Shared/tools/fetch-nabre-versification.py --check
uv run --script Shared/tools/reading_nabre_mapping.py
uv run --script Shared/tools/test-reading-nabre-mapping.py
```

If HTTP requests are unavailable, the scraper's `--import-browser observations.json`
accepts numeric DOM observations. Preserve each book's published page order,
cross-page chapter fragments, lettered Esther chapters, and suffix labels. Do not
save HTML, page snapshots containing Scripture, or verse strings as an intermediate
file. A changed inventory invalidates the old count pin; remeasure the requested
references before replacing it.

To regenerate the 61 measurements, group `word-counts.json` measurements by their
observed official chapter URL. Open each page in the browser and call the function
below with `{code, c, vs, url}`, where chapter `c` is a string and `vs` contains the
requested verse numbers. Use only the returned references, integer word counts,
official URLs, and marker counts. Require exactly one marker for every requested
reference. In the pinned measurement shape, remove `markers`, replace `urls` with
the matching `sourcePages` records from `structure.json`, and set `structureSHA256`
to the SHA-256 of the inventory file's exact bytes. `load_word_counts` validates
that shape and rejects extra fields, missing references, and stale provenance.

The method is `whitespace-delimited-verse-body-tokens-v1`: follow rendered DOM
order through the next verse marker, including continuation paragraphs, poetry
lines, and table cells. Exclude verse numbers, notes, annotation links, headings,
and scripts. Preserve inline adjacency and separate block boundaries. Do not
count only the first `.verse` or `.txt` container: several official verses continue
outside it. The temporary strings below never leave the page evaluation.

```javascript
async function countWhole(tab, job) {
  return await tab.playwright.evaluate((job) => {
    const root = document.querySelector('.contentarea');
    let chapter = job.c, active = null;
    const bodies = {}, markers = {};
    const skip = 'sup,.fn,.en,.footnote,.footnotes,a.fnref,a.enref,script,style';
    const add = s => { if (active) bodies[active] = (bodies[active] || '') + s; };
    function walk(n) {
      if (n.nodeType === 3) { add(n.textContent); return; }
      if (n.nodeType !== 1) return;
      if (n.matches(skip)) return;
      if (n.matches('h1,h2,h3,h4,h5,h6,.chapterhead')) { active = null; return; }
      if (n.matches('b,strong') && !n.closest('.verse,.txt')) return;
      if (n.matches('a[name]')) {
        const a = n.getAttribute('name');
        if (/^\d{8}$/.test(a)) chapter = String(Number(a.slice(2,5)));
      }
      if (n.matches('.bcv')) {
        const label = n.textContent.trim().replace(/[.]/g, '');
        const m = label.match(/^(?:(\d+):)?(\d+[a-z]?)$/);
        if (m) {
          active = (m[1] || chapter) + ':' + m[2];
          markers[active] = (markers[active] || 0) + 1;
          bodies[active] = (bodies[active] || '') + ' ';
        } else active = null;
        return;
      }
      const block = /^(P|DIV|TR|TD|LI|BR)$/.test(n.tagName);
      if (block) add(' ');
      for (const c of n.childNodes) walk(c);
      if (block) add(' ');
    }
    walk(root);
    return job.vs.map(v => {
      const k = job.c + ':' + v;
      return {
        reference: [job.code, job.c, String(v)],
        words: (bodies[k] || '').trim().split(/\s+/u).filter(Boolean).length,
        urls: [job.url],
        markers: markers[k] || 0
      };
    });
  }, job);
}
```

## Reviewed exceptional boundaries

The numeric review file records 1 Samuel 20:42–21:1, Acts 10:48–49, and the
rearranged Sirach parts in chapters 33, 41, and 47. The labels were checked against
their official page bodies and the corresponding whole STEP Standard verses,
including the public-domain [KJV Sirach 41](https://ebible.org/eng-kjv/SIR41.htm).
These are explicit reviewed groups, not a rule that all suffixes can be discarded.
STEP also omits the internal Sirach 33 corrections. That whole chapter was
checked against [KJV Sirach 33](https://ebible.org/eng-kjv/SIR33.htm): for example,
NABRE 20a+20b corresponds to Standard 19, and NABRE 31–33 covers Standard 30–31.
The DRA target adapter has its own reviewed chapter graph so these corrections
remain consistent in both directions.

The official [Sirach 36 note](https://bible.usccb.org/bible/sirach/36) explains why
13 and 16 form a complete unit even though labels 14–15 are unused. STEP's detailed
rows map those two parts to Standard 36:11. In Sirach 44, STEP's concatenation row
24517 includes verse 24 while its own condition says verse 23 is last; the mapper
uses the agreeing detailed rows for the two actually published verses instead.

Inventory completeness also does not prove that a lectionary uses NABRE numbering.
Appointment adoption remains separately governed by exact source-numbering
reviews in `reading-source-numbering-reviews.json`.
