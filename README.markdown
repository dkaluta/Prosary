# Prosary

A prayer companion for Holy Land Christian communities — the Rosary, the Angelus, the Stations
of the Cross, the Via Lucis, the Divine Mercy Chaplet, the Franciscan Crown, the Seven Sorrows,
the Trisagion, novenas and other multi-day devotions, the Jesus Prayer, and the basic prayers on
their own. Latin is the default prayer language, alongside English, Arabic, Hebrew, Russian,
Tagalog, Spanish, Greek, and Classical Syriac (Aramaic, in both the Hebrew and Syriac scripts).
Hebrew comes in the communities' own uses: the St James Vicariate's wording (נוסח הנציגות) and
the Mission of St. Gamaliel's Aramaic-rite recension — a devotion can even open in a different
form per rite, the way the Mission's Trisagion opens Syriac.

Three native apps, one format, one repo:

| | |
|---|---|
| [`iOS/`](iOS/) | SwiftUI — iPhone, Mac, iPad, Vision Pro. See its [README](iOS/README.markdown). |
| [`Android/`](Android/) | Jetpack Compose port, feature parity with iOS. |
| [`Windows/`](Windows/) | WinUI 3 port, feature parity with iOS. |
| [`Shared/`](Shared/) | The canonical cross-platform ground: the `.prosaryprayer` bundle format and its content ([`ARCHITECTURE.md`](Shared/ARCHITECTURE.md)), schema docs, tools, and the [prosary.app](https://prosary.app) website. |
| [`Compose/`](Compose/) | [compose.prosary.app](https://compose.prosary.app) — a fully client-side wizard for authoring `.prosaryprayer` bundles, no technical knowledge needed. |
| [`Repository/`](Repository/) | [prayers.prosary.app](https://prayers.prosary.app) — the community bundle repository the apps' Browse tab reads. |

Both mobile apps are in closed testing — see [prosary.app](https://prosary.app) to join.

## The bundle format

Every devotion the apps pray is a `.prosaryprayer` bundle — a zip of JSON declaring the steps,
per-language content (rites ride as overlay files), options, alternate forms with per-rite
defaults, multi-day structure, artwork, and narrated audio. The apps carry no per-devotion
code; [`Shared/ARCHITECTURE.md`](Shared/ARCHITECTURE.md) is the spec, and
`Shared/tools/validate-devotion.py` is its enforcement.

## Tooling

The Python tools in [`Shared/tools/`](Shared/tools/) run with [uv](https://docs.astral.sh/uv/) —
each is a self-contained uv script, so there is nothing to install beyond uv itself:

```sh
uv run --script Shared/tools/validate-devotion.py Shared/content/rosary   # validate a bundle source
Shared/tools/make-prosaryprayer.sh Shared/content/rosary                  # pack it (validates first)
uv run --script Shared/tools/test-validate-devotion.py                    # the validator's own test suite
uv run --script Shared/tools/import-scripture.py --check                  # Aramaic/Greek/Spanish scripture, from checkable editions
uv run --script Shared/tools/bump-version.py --check                      # one version across all three platforms
uv run --script Shared/tools/reflow-prayers.py --check                    # canonical prayer line breaks
```

`make-prosaryprayer.sh` is twinned with `Make-ProsaryPrayer.ps1` for the Windows machine.

CI runs the format suite, the Android and Windows test suites, and the Compose/Repository
builds on every branch push; iOS tests run on Xcode Cloud.

## License

The apps' original source code is licensed under the BSD 2-Clause License — see
[`iOS/LICENSE`](iOS/LICENSE). Bundled third-party assets (fonts, artwork, scripture editions)
retain their own licenses, attributed in each app's About screen.
