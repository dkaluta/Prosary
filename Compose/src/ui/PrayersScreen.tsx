import { useEffect } from "react";
import type { Dispatch, SetStateAction } from "react";
import { LANGUAGES, isRtl } from "../format/catalog";
import type { EditorPrayer, Project } from "../format/project";
import { newUid } from "../format/project";
import { prayerLabel } from "../format/validate";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
  goToOrder: () => void;
}

export function PrayersScreen({ project, setProject, goToOrder }: Props) {
  // An empty library must not greet the author with a bare button — open with a blank
  // prayer card so the text fields are immediately on screen. Idempotent (checks inside the
  // updater), so StrictMode's double-run and re-visits add nothing extra; a deliberately
  // emptied library stays empty until the author acts.
  useEffect(() => {
    setProject((p) =>
      p.prayers.length === 0
        ? {
            ...p,
            prayers: [{ uid: newUid(), titleByLanguage: {}, bodyByLanguage: {}, isScripture: false }],
          }
        : p,
    );
  }, [setProject]);

  const updatePrayer = (uid: string, patch: Partial<EditorPrayer>) =>
    setProject((p) => ({
      ...p,
      prayers: p.prayers.map((prayer) => (prayer.uid === uid ? { ...prayer, ...patch } : prayer)),
    }));

  const addPrayer = () =>
    setProject((p) => ({
      ...p,
      prayers: [...p.prayers, { uid: newUid(), titleByLanguage: {}, bodyByLanguage: {}, isScripture: false }],
    }));

  const usageCount = (uid: string) =>
    project.steps.filter((step) => step.kind === "own" && step.prayerUid === uid).length;

  const removePrayer = (uid: string) => {
    const used = usageCount(uid);
    if (
      used > 0 &&
      !window.confirm(
        `This prayer is prayed at ${used} point${used === 1 ? "" : "s"} of the order — removing it removes those steps too.`,
      )
    ) {
      return;
    }
    setProject((p) => ({
      ...p,
      prayers: p.prayers.filter((prayer) => prayer.uid !== uid),
      steps: p.steps.filter((step) => step.prayerUid !== uid),
    }));
  };

  const addToOrder = (uid: string) =>
    setProject((p) => ({
      ...p,
      steps: [...p.steps, { uid: newUid(), kind: "own", prayerUid: uid }],
    }));

  return (
    <section>
      <h2>Your prayers</h2>
      <p className="help">
        Write each prayer here, once per language — this is the devotion's library. On the next
        page you arrange the order of prayer, where the same prayer can appear as many times as
        you like. Common prayers (the Our Father, the Hail Mary…) are already in the app; you add
        those directly on the Order page.
      </p>

      {project.prayers.map((prayer, index) => {
        const used = usageCount(prayer.uid);
        return (
          <div className="card" key={prayer.uid}>
            <header>
              <span className="title">{prayerLabel(prayer, index)}</span>
              <span className="hint">
                {used === 0 ? "not in the order yet" : `prayed ${used} time${used === 1 ? "" : "s"}`}
              </span>
              <button className="subtle" onClick={() => addToOrder(prayer.uid)}>
                Add to the order
              </button>
              <button className="subtle" onClick={() => removePrayer(prayer.uid)} aria-label="Remove prayer">
                ✕
              </button>
            </header>
            {project.languages.map((code) => {
              const language = LANGUAGES.find((l) => l.code === code)!;
              const dir = isRtl(code) ? "rtl" : "ltr";
              return (
                <div className="lang-block" key={code}>
                  <div className="lang-name">{language.name}</div>
                  <label className="field">
                    <span>Name of the prayer</span>
                    <input
                      type="text"
                      dir={dir}
                      value={prayer.titleByLanguage[code] ?? ""}
                      onChange={(e) =>
                        updatePrayer(prayer.uid, {
                          titleByLanguage: { ...prayer.titleByLanguage, [code]: e.target.value },
                        })
                      }
                    />
                  </label>
                  <label className="field">
                    <span>Text</span>
                    <textarea
                      dir={dir}
                      value={prayer.bodyByLanguage[code] ?? ""}
                      onChange={(e) =>
                        updatePrayer(prayer.uid, {
                          bodyByLanguage: { ...prayer.bodyByLanguage, [code]: e.target.value },
                        })
                      }
                    />
                  </label>
                </div>
              );
            })}
            <label className="field">
              <input
                type="checkbox"
                checked={prayer.isScripture}
                onChange={(e) => updatePrayer(prayer.uid, { isScripture: e.target.checked })}
              />{" "}
              This text is a Bible reading (the app shows it in the Scripture typeface)
            </label>
          </div>
        );
      })}

      <div className="row">
        <button className="secondary tight" onClick={addPrayer}>
          + Write a prayer
        </button>
        {project.prayers.length > 0 && (
          <button className="subtle tight" onClick={goToOrder}>
            Arrange the order →
          </button>
        )}
      </div>
    </section>
  );
}
