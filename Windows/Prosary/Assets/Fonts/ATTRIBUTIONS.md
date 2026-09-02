# Fonts — Attributions & Licensing

| File | Font | License | Used for |
|---|---|---|---|
| OpenSans-Regular.ttf / OpenSans-Semibold.ttf | Open Sans | Apache 2.0 | (legacy; no longer applied anywhere by default) |
| FrankRuhlLibre-Variable.ttf | Frank Ruhl Libre | SIL OFL 1.1 | Hebrew prayers (non-Scripture) |
| DavidLibre-Regular.ttf | David Libre | SIL OFL 1.1 | Optional Hebrew serif prayer face |
| NotoSansHebrew-Variable.ttf | Noto Sans Hebrew (Google) | SIL OFL 1.1 | Android fallback for the optional Roboto prayer face |
| Roboto-Variable.ttf | Roboto (Google) | SIL OFL 1.1 | Android-only optional sans-serif prayer face |
| ShofarRegular.ttf | Shofar (Culmus Project, Yoram Gnat) | GPL v2 **with font-embedding exception** | Hebrew Scripture (mystery meditations) |
| StamAshkenazCLM.ttf | Stam Ashkenaz CLM (Culmus Project, Yoram Gnat) | GPL v2 **with font-embedding exception** | Optional Ashkenazi Torah-script Scripture face |
| StamSefaradCLM.ttf | Stam Sefarad CLM (Culmus Project, Yoram Gnat) | GPL v2 **with font-embedding exception** | Optional Sephardi Torah-script Scripture face |
| NotoRashiHebrew-Variable.ttf | Noto Rashi Hebrew (Google) | SIL OFL 1.1 | Optional Rashi-style Hebrew Scripture face |
| Amiri-Regular.ttf | Amiri | SIL OFL 1.1 | Arabic prayers (non-Scripture) |
| ScheherazadeNew-Regular.ttf | Scheherazade New (SIL) | SIL OFL 1.1 | Arabic Scripture (mystery meditations) |
| Cardo-Regular.ttf | Cardo (David J. Perry) | SIL OFL 1.1 | Latin/English Scripture (mystery meditations) |
| NotoSansSyriac-Variable.ttf | Noto Sans Syriac (Google) | SIL OFL 1.1 | Aramaic in Syriac letters (the script toggle only) |
| NotoSansSyriacWestern-Variable.ttf | Noto Sans Syriac Western (Google) | SIL OFL 1.1 | Optional Western Aramaic Syriac-script face |
| NotoSansSyriacEastern-Variable.ttf | Noto Sans Syriac Eastern (Google) | SIL OFL 1.1 | Optional Eastern Aramaic Syriac-script face |

## Why a Syriac face at all

No language in the catalogue writes its own text in Syriac letters: `arc` is Aramaic *in Hebrew
script*, which is what the Aramaic-rite Hebrew Catholic communities read. The Syriac face exists
purely for the prayer flow's script toggle, which shows the same Aramaic text in the alphabet the
Peshitta itself is written in. None of the non-Syriac faces covers the Syriac block — checked
against their OS/2 Unicode ranges, not assumed — so without this one the toggle would draw a row
of tofu, which is worse than not offering it.

## Why not the original "Frank Ruehl CLM"?

The Culmus Project's `FrankRuehlCLM-*.ttf` (by Maxim Iorsh) is licensed under plain GPL v2
**without** the font-embedding exception that most other Culmus fonts carry — verified directly
against the project's `LICENSE` file. Embedding a GPL-only font (no exception) in an app raises a
real question about whether the app itself is a "combined work" subject to the GPL. To avoid that,
Hebrew prayer text uses **Frank Ruhl Libre** instead — a from-scratch open-source revival of the
same classic Frank Rühl typeface, released under the OFL, which explicitly permits embedding in
any application (open or closed source) without copyleft implications.

Shofar (also Culmus Project, but by Yoram Gnat) **does** carry the exception — its LICENSE file
states: "if you create a document which uses this font, and embed this font ... into the document,
this font does not by itself cause the resulting document to be covered by the GNU General Public
License." Confirmed safe to embed as-is.

The two optional Stam faces carry the same exception and are embedded unmodified. Their supplied
copyright and exception notices are preserved here verbatim:

> Stam Ashkenaz font is copyright 2007-2010 by Yoram Gnat (yoram.gnat@gmail.com).
> As a special exception, if you create a document which uses this font, and
> embed this font or unaltered portions of this font into the document, this
> font does not by itself cause the resulting document to be covered by the
> GNU General Public License. This exception does not however invalidate any
> other reasons why the document might be covered by the GNU General Public
> License. If you modify this font, you may extend this exception to your
> version of the font, but you are not obligated to do so. If you do not wish
> to do so, delete this exception statement from your version.

> Stam Sefarad font is copyright 2008-2010 by Yoram Gnat (yoram.gnat@gmail.com).
> As a special exception, if you create a document which uses this font, and
> embed this font or unaltered portions of this font into the document, this
> font does not by itself cause the resulting document to be covered by the
> GNU General Public License. This exception does not however invalidate any
> other reasons why the document might be covered by the GNU General Public
> License. If you modify this font, you may extend this exception to your
> version of the font, but you are not obligated to do so. If you do not wish
> to do so, delete this exception statement from your version.

## Scripture vs. prayer typography

Scripture quotations (the mystery-announcement step) use a dedicated typeface distinct from
ordinary prayer text, uniformly across platforms — Cardo and Scheherazade New were both designed
for classical/Biblical typesetting, the same reasoning already applied to Hebrew (Shofar vs. Frank
Ruhl Libre). Both are plain SIL OFL 1.1, same as Frank Ruhl Libre and Amiri — no font-embedding
exception needed since OFL already permits embedding in any application.

## Latin-script prayers (non-Scripture)

- **iOS / Mac Catalyst**: uses Apple's system "New York" serif design (via `UIFontDescriptor`
  with `.serif` design) at runtime — not embedded, since Apple's system fonts may not be
  redistributed in third-party app bundles. See `Fonts/SystemSerifLabel.*.cs`.
- **Android**: uses the generic `serif` font family, which Android resolves to its system serif
  (Noto Serif) automatically — no embedding needed.
- **Windows**: uses "Cambria", which ships with Windows by default — no embedding needed.
