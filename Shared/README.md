# Shared/

The canonical cross-platform ground of the Prosary monorepo — everything that is true for all
three apps lives here once, and the apps carry copies.

| | |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | The spec: the `.prosaryprayer` bundle format, the language/rite model, the engines' shared behavior. The single source of truth the three ports are verified against. |
| [`content/`](content/) | The authored sources of every shipped devotion bundle — `manifest.json`, `devotion.json`, per-language `content/<code>.json` (rites ride as overlay files), options, artwork references. |
| [`dist/`](dist/) | The packed `.prosaryprayer` bundles built from `content/`, copied into each platform (`iOS/Prosary/PrayerPacks`, `Android/app/src/main/assets`, `Windows/Prosary/PrayerPacks`). |
| [`data/`](data/) | Generated offline Today data: the calendar registry, per-calendar feast and citation tables, and authored Pope intentions. The selected calendar chooses both its feast file and its `readingsFile`. |
| [`schema/`](schema/) | Machine-readable shape docs — the prose spec's companion; see its [README](schema/README.md). |
| [`tools/`](tools/) | The tooling: `validate-devotion.py` (the format's enforcement), `make-prosaryprayer.sh` / `Make-ProsaryPrayer.ps1` (packers), `fetch-feasts.py` and `fetch-readings.py` (calendar-specific Today data, with `--sync` for all ports), `import-scripture.py` (Aramaic/Greek/Spanish scripture from checkable editions), Erez's deterministic `aramaic_script_converter.py`, `bump-version.py`, `reflow-prayers.py`, `audit-content.py`. Every runnable Python tool is a self-contained [uv](https://docs.astral.sh/uv/) script — `uv run --script tools/<name>.py`. |
| [`website/`](website/) | The [prosary.app](https://prosary.app) landing page (Astro), deployed to GitHub Pages. |
| `Images/`, fonts | The canonical artwork and typefaces. Platforms keep **physical copies** rather than live references — each app builds standalone — so an asset change here must be re-copied into every platform that uses it. |

The rule that keeps this directory honest: content and schema change **in the same commit** as
the platform change they describe, and a bundle edit is only done here — `content/` is
authored, `dist/` is generated, the platform copies are copied. Never edit downstream.
