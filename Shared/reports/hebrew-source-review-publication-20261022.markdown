# Publishing the Hebrew source review

The source-note review through integration pass 157 is complete. Canonical texts,
approval records, comparison reports, integration reports and priority queues remain
in Git. The full raw evidence and repeated baselines are published separately as
[the 0.23.0 review-evidence archive](https://github.com/dkaluta/Prosary/releases/download/v0.23.0/prosary-0.23.0-review-evidence.tar.zst).

The archive contains 40,597 files (4,392,939,149 uncompressed bytes). Its compressed
size is 1,775,525,214 bytes and SHA-256 is
`3f737a83e451116f87867d8e066b73141cb5876356c7fa3d89dcd0b13e9c2d8a`.
Every archived member was read back and checked against its original size and hash.
The exact source files remain intact locally; no historical evidence was rewritten.

The [compact inventory](hebrew-source-review-evidence-20261022.json) records every
original path, size and SHA-256. The archive also contains `evidence-contents.json`.
After checking the archive hash, extract it at the repository root to restore the
original evidence paths. For example, with zstd installed:

```sh
zstd -dc prosary-0.23.0-review-evidence.tar.zst | tar -xf -
```

The archive includes the full `hebrew-wikisource` report tree, scratch source
captures and immutable Bible download revisions. Previously tracked evidence
remains tracked. New raw evidence and scratch captures are excluded from Git;
only the currently referenced new Bible download is required in the release tree.
Checks requiring raw historical evidence must restore the archive first. Ordinary
application builds and tests use canonical content and generated application assets.

The [final integration report](hebrew-wikisource/source-note-integration-20261022-exhaustion.markdown)
retains the documented historical reference mismatch and unresolved source ambiguities.
Completion of the review does not mean those uncertain readings were resolved.
