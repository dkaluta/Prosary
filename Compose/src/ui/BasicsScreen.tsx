import type { Dispatch, SetStateAction } from "react";
import { ICONS, LANGUAGES, isRtl } from "../format/catalog";
import type { LanguageCode } from "../format/catalog";
import type { Project } from "../format/project";
import { slugify } from "../format/project";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
}

export function BasicsScreen({ project, setProject }: Props) {
  const update = (patch: Partial<Project>) => setProject((p) => ({ ...p, ...patch }));

  const toggleLanguage = (code: LanguageCode) =>
    setProject((p) => ({
      ...p,
      languages: p.languages.includes(code)
        ? p.languages.filter((l) => l !== code)
        : LANGUAGES.map((l) => l.code).filter((l) => l === code || p.languages.includes(l)),
    }));

  return (
    <section>
      <h2>The basics</h2>
      <p className="help">
        What is this devotion called, and which languages will you write it in? People pray in the
        language they chose in the app, so every language you tick here needs its own text later.
      </p>

      <div className="card">
        <label className="field">
          <span>Name of the devotion</span>
          <input
            type="text"
            value={project.name}
            placeholder="e.g. Litany of Humility"
            onChange={(e) =>
              setProject((p) => ({
                ...p,
                name: e.target.value,
                id: p.idEdited ? p.id : slugify(e.target.value),
              }))
            }
          />
        </label>
        <label className="field">
          <span>
            Identifier <span className="hint">— fills in by itself; only needs changing if the app says the name is taken</span>
          </span>
          <input
            type="text"
            value={project.id}
            onChange={(e) => update({ id: e.target.value, idEdited: true })}
          />
        </label>
      </div>

      <div className="card">
        <fieldset>
          <legend>Languages</legend>
          <div className="choices">
            {LANGUAGES.map((language) => (
              <label key={language.code}>
                <input
                  type="checkbox"
                  checked={project.languages.includes(language.code)}
                  onChange={() => toggleLanguage(language.code)}
                />
                {language.name}
              </label>
            ))}
          </div>
        </fieldset>
        {project.languages.filter((l) => l !== "en").length > 0 && (
          <fieldset>
            <legend>
              Name in each language <span className="hint">— optional; shown on the app's Home screen</span>
            </legend>
            {project.languages
              .filter((l) => l !== "en")
              .map((code) => {
                const language = LANGUAGES.find((l) => l.code === code)!;
                return (
                  <label className="field" key={code}>
                    <span className="hint">{language.name}</span>
                    <input
                      type="text"
                      dir={isRtl(code) ? "rtl" : "ltr"}
                      value={project.nameByLanguage[code] ?? ""}
                      onChange={(e) =>
                        setProject((p) => ({
                          ...p,
                          nameByLanguage: { ...p.nameByLanguage, [code]: e.target.value },
                        }))
                      }
                    />
                  </label>
                );
              })}
          </fieldset>
        )}
      </div>

      <div className="card">
        <fieldset>
          <legend>Accent color</legend>
          <div className="row">
            <span className="color-swatch tight">
              <input
                type="color"
                value={project.accentColorHex}
                onChange={(e) => update({ accentColorHex: e.target.value.toUpperCase() })}
              />
              in light mode
            </span>
            <span className="color-swatch tight">
              <input
                type="color"
                value={project.accentColorDarkHex}
                onChange={(e) => update({ accentColorDarkHex: e.target.value.toUpperCase() })}
              />
              in dark mode
            </span>
          </div>
        </fieldset>
        <label className="field">
          <span>
            Tags <span className="hint">— optional, comma-separated; used for browsing by category</span>
          </span>
          <input
            type="text"
            placeholder="marian, evening, litany"
            value={project.tags.join(", ")}
            onChange={(e) =>
              update({
                tags: e.target.value
                  .split(",")
                  .map((t) => t.trim().toLowerCase())
                  .filter(Boolean)
                  .slice(0, 8),
              })
            }
          />
        </label>
        <fieldset>
          <legend>Icon</legend>
          <div className="choices">
            {ICONS.map((icon) => (
              <label key={icon.systemName} title={icon.label}>
                <input
                  type="radio"
                  name="icon"
                  checked={!project.iconGlyph && project.iconSystemName === icon.systemName}
                  onChange={() => update({ iconSystemName: icon.systemName, iconGlyph: "" })}
                />
                <span className="icon-choice">{icon.glyph}</span> {icon.label}
              </label>
            ))}
            <label title="Any letter or emoji of your own">
              <input
                type="radio"
                name="icon"
                checked={project.iconGlyph !== ""}
                onChange={() => update({ iconGlyph: project.iconGlyph || "✣" })}
              />
              <span className="icon-choice">{project.iconGlyph || "✣"}</span> Your own:
              <input
                type="text"
                className="glyph-input"
                value={project.iconGlyph}
                placeholder="✣"
                aria-label="Custom icon — one letter or emoji"
                onChange={(e) => {
                  // Exactly one grapheme cluster: the keyboard types freely (emoji arrive as
                  // several code units), and we keep only the LAST cluster typed.
                  const clusters = [
                    ...new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(
                      e.target.value,
                    ),
                  ];
                  update({ iconGlyph: clusters.at(-1)?.segment ?? "" });
                }}
              />
            </label>
          </div>
        </fieldset>
      </div>
    </section>
  );
}
