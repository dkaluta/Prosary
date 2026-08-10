import { useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import { COMMON_PRAYERS, LANGUAGES, commonPrayer, isRtl } from "../format/catalog";
import type { CommonPrayerKey } from "../format/catalog";
import type { EditorDay, EditorStep, EditorVariant, Project } from "../format/project";
import { newUid, slugify } from "../format/project";
import { imageToSquareJpeg, pickFile } from "./media";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
}

export function StepsScreen({ project, setProject }: Props) {
  const isDays = project.devotionType === "days";
  const hasForms = !isDays && project.variants.length > 0;
  const [openDayUid, setOpenDayUid] = useState<string | null>(null);
  const [openFormUid, setOpenFormUid] = useState<string | null>(null);
  // The open day may have been deleted, and a project that has just become a days project has
  // none chosen: fall back to the first rather than showing an empty editor, which reads as
  // data loss.
  const day = project.days.find((d) => d.uid === openDayUid) ?? project.days[0];
  const form = project.variants.find((f) => f.uid === openFormUid) ?? project.variants[0];
  const steps = isDays ? (day?.steps ?? []) : hasForms ? (form?.steps ?? []) : project.steps;

  /** Step edits land inside the open day or form, and in the flat list otherwise. */
  const editSteps = (edit: (steps: EditorStep[]) => EditorStep[]) =>
    setProject((p) => {
      if (p.devotionType === "days") {
        const target = p.days.find((d) => d.uid === day?.uid) ?? p.days[0];
        if (!target) return p;
        return {
          ...p,
          days: p.days.map((d) => (d.uid === target.uid ? { ...d, steps: edit(d.steps) } : d)),
        };
      }
      if (p.variants.length > 0) {
        const target = p.variants.find((f) => f.uid === form?.uid) ?? p.variants[0];
        if (!target) return p;
        return {
          ...p,
          variants: p.variants.map((f) =>
            f.uid === target.uid ? { ...f, steps: edit(f.steps) } : f,
          ),
        };
      }
      return { ...p, steps: edit(p.steps) };
    });

  const updateStep = (uid: string, patch: Partial<EditorStep>) =>
    editSteps((steps) => steps.map((step) => (step.uid === uid ? { ...step, ...patch } : step)));

  const addCommon = (key: CommonPrayerKey) =>
    editSteps((steps) => [
      ...steps,
      {
        uid: newUid(),
        kind: "common",
        commonKey: key,
        title: commonPrayer(key)?.label ?? "",
        titleByLanguage: {},
        bodyByLanguage: {},
        isScripture: false,
      },
    ]);

  const addCustom = () =>
    editSteps((steps) => [
      ...steps,
      {
        uid: newUid(),
        kind: "custom",
        title: "",
        titleByLanguage: {},
        bodyByLanguage: {},
        isScripture: false,
      },
    ]);

  const move = (uid: string, delta: -1 | 1) =>
    editSteps((steps) => {
      const index = steps.findIndex((s) => s.uid === uid);
      const target = index + delta;
      if (index < 0 || target < 0 || target >= steps.length) return steps;
      const moved = [...steps];
      [moved[index], moved[target]] = [moved[target], moved[index]];
      return moved;
    });

  const remove = (uid: string) => editSteps((steps) => steps.filter((s) => s.uid !== uid));

  const uploadArt = (uid: string) =>
    pickFile("image/*", async (file) => {
      const { jpeg, dataUrl } = await imageToSquareJpeg(file);
      const imageUid = newUid();
      setProject((p) => ({
        ...p,
        images: [...p.images, { uid: imageUid, label: file.name, jpeg, dataUrl }],
      }));
      updateStep(uid, { image: { kind: "upload", uid: imageUid } });
    });

  const startForms = () => {
    // The existing sequence becomes the first form, so nothing the author wrote is lost.
    const uid = newUid();
    setProject((p) => ({
      ...p,
      variants: [
        {
          uid,
          variantId: "",
          variantIdEdited: false,
          name: "",
          nameByLanguage: {},
          defaultForLanguages: [],
          steps: p.steps,
        },
        {
          uid: newUid(),
          variantId: "",
          variantIdEdited: false,
          name: "",
          nameByLanguage: {},
          defaultForLanguages: [],
          steps: [],
        },
      ],
      steps: [],
    }));
    setOpenFormUid(uid);
  };

  const addForm = () => {
    const uid = newUid();
    setProject((p) => ({
      ...p,
      variants: [
        ...p.variants,
        { uid, variantId: "", variantIdEdited: false, name: "", nameByLanguage: {}, defaultForLanguages: [], steps: [] },
      ],
    }));
    setOpenFormUid(uid);
  };

  const updateForm = (uid: string, patch: Partial<EditorVariant>) =>
    setProject((p) => ({
      ...p,
      variants: p.variants.map((f) => (f.uid === uid ? { ...f, ...patch } : f)),
    }));

  const moveForm = (uid: string, delta: -1 | 1) =>
    setProject((p) => {
      const index = p.variants.findIndex((f) => f.uid === uid);
      const target = index + delta;
      if (index < 0 || target < 0 || target >= p.variants.length) return p;
      const variants = [...p.variants];
      [variants[index], variants[target]] = [variants[target], variants[index]];
      return { ...p, variants };
    });

  const removeForm = (uid: string) => {
    const doomed = project.variants.find((f) => f.uid === uid);
    if (
      doomed?.steps.length &&
      !window.confirm(
        `Delete ${doomed.name || "this form"}? Its ${doomed.steps.length} step(s) go with it.`,
      )
    ) {
      return;
    }
    setProject((p) => {
      const variants = p.variants.filter((f) => f.uid !== uid);
      // Down to one form = back to a single-form devotion; its steps return to the flat list.
      if (variants.length === 1) {
        return { ...p, variants: [], steps: variants[0].steps };
      }
      return { ...p, variants };
    });
    if (uid === form?.uid) setOpenFormUid(null);
  };

  const addDay = () => {
    const uid = newUid();
    setProject((p) => ({
      ...p,
      days: [
        ...p.days,
        { uid, name: `Day ${p.days.length + 1}`, nameByLanguage: {}, steps: [] },
      ],
    }));
    setOpenDayUid(uid);
  };

  const updateDay = (uid: string, patch: Partial<EditorDay>) =>
    setProject((p) => ({
      ...p,
      days: p.days.map((d) => (d.uid === uid ? { ...d, ...patch } : d)),
    }));

  const moveDay = (uid: string, delta: -1 | 1) =>
    setProject((p) => {
      const index = p.days.findIndex((d) => d.uid === uid);
      const target = index + delta;
      if (index < 0 || target < 0 || target >= p.days.length) return p;
      const days = [...p.days];
      [days[index], days[target]] = [days[target], days[index]];
      return { ...p, days };
    });

  const removeDay = (uid: string) => {
    const doomed = project.days.find((d) => d.uid === uid);
    if (
      doomed?.steps.length &&
      !window.confirm(`Delete ${doomed.name}? Its ${doomed.steps.length} step(s) go with it.`)
    ) {
      return;
    }
    setProject((p) => ({ ...p, days: p.days.filter((d) => d.uid !== uid) }));
    if (uid === day?.uid) setOpenDayUid(null);
  };

  return (
    <section>
      <h2>The prayers</h2>
      <p className="help">
        {isDays
          ? "Each day is its own sequence of steps, prayed one screen at a time. Choose a day below, then build it."
          : "A devotion is a sequence of steps, prayed one screen at a time."}{" "} Common prayers (the Our
        Father, the Hail Mary…) are already in the app in every language — just add them. Your own
        prayers you write yourself, once per language.
      </p>
      {project.languages.length === 0 && (
        <p className="issue">
          The text fields appear once the devotion has languages — choose them on the Basics page
          first.
        </p>
      )}

      {!isDays && !hasForms && (
        <p className="help">
          Prays two ways — a shorter and a fuller form, or one form per tradition?{" "}
          <button className="subtle" onClick={startForms}>
            Give this devotion alternate forms…
          </button>
        </p>
      )}

      {hasForms && (
        <div className="card">
          <header>
            <span className="title">The forms</span>
            <button className="subtle" onClick={addForm}>
              + Add a form
            </button>
          </header>
          <p className="help">
            Each form is its own sequence of steps — the app shows a form menu and opens the
            first one unless a language below claims the session. Forms named for liturgical
            traditions (latin, byzantine, syriac…) go in their canonical order.
          </p>
          <div className="row wrap">
            {project.variants.map((f, i) => (
              <button
                key={f.uid}
                className={f.uid === form?.uid ? "tight" : "secondary tight"}
                onClick={() => setOpenFormUid(f.uid)}
              >
                {f.name || `Form ${i + 1}`}
              </button>
            ))}
          </div>
        </div>
      )}

      {hasForms && form && (
        <div className="card">
          <header>
            <span className="title">{form.name || "Untitled form"}</span>
            <button className="subtle" onClick={() => moveForm(form.uid, -1)} aria-label="Move form earlier">
              ↑
            </button>
            <button className="subtle" onClick={() => moveForm(form.uid, 1)} aria-label="Move form later">
              ↓
            </button>
            <button className="subtle" onClick={() => removeForm(form.uid)} aria-label="Remove form">
              ✕
            </button>
          </header>
          <label className="field">
            <span>
              Form name <span className="hint">— shown in the app's form menu ("Byzantine", "Fuller form")</span>
            </span>
            <input
              type="text"
              value={form.name}
              onChange={(e) =>
                updateForm(form.uid, {
                  name: e.target.value,
                  ...(form.variantIdEdited ? {} : { variantId: slugify(e.target.value) }),
                })
              }
            />
          </label>
          {project.languages.map((code) => {
            const language = LANGUAGES.find((l) => l.code === code)!;
            return (
              <label className="field" key={code}>
                <span>
                  Form name in {language.name} <span className="hint">— optional</span>
                </span>
                <input
                  type="text"
                  dir={isRtl(code) ? "rtl" : "ltr"}
                  value={form.nameByLanguage[code] ?? ""}
                  onChange={(e) =>
                    updateForm(form.uid, {
                      nameByLanguage: { ...form.nameByLanguage, [code]: e.target.value },
                    })
                  }
                />
              </label>
            );
          })}
          <label className="field">
            <span>
              Identifier <span className="hint">— fills in from the name; keep it stable once published</span>
            </span>
            <input
              type="text"
              value={form.variantId}
              onChange={(e) => updateForm(form.uid, { variantId: e.target.value, variantIdEdited: true })}
            />
          </label>
          <label className="field">
            <span>
              Opens by default for{" "}
              <span className="hint">
                — language codes, space-separated (he, arc, he-x-gamliel…); leave empty for none
              </span>
            </span>
            <input
              type="text"
              value={form.defaultForLanguages.join(" ")}
              onChange={(e) =>
                updateForm(form.uid, {
                  defaultForLanguages: e.target.value.split(/[,\s]+/).filter(Boolean),
                })
              }
            />
          </label>
        </div>
      )}

      {isDays && (
        <div className="card">
          <header>
            <span className="title">The days</span>
            <button className="subtle" onClick={addDay}>
              + Add a day
            </button>
          </header>
          {project.days.length === 0 ? (
            <p className="help">
              {project.dayProgression === "series"
                ? "A novena has nine days, a triduum three — add as many as this devotion asks for."
                : "Add one day for each prayer in the set."}
            </p>
          ) : (
            <div className="row wrap">
              {project.days.map((d) => (
                <button
                  key={d.uid}
                  className={d.uid === day?.uid ? "tight" : "secondary tight"}
                  onClick={() => setOpenDayUid(d.uid)}
                >
                  {d.name || "Untitled day"}
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {isDays && day && (
        <div className="card">
          <header>
            <span className="title">{day.name || "Untitled day"}</span>
            <button className="subtle" onClick={() => moveDay(day.uid, -1)} aria-label="Move day earlier">
              ↑
            </button>
            <button className="subtle" onClick={() => moveDay(day.uid, 1)} aria-label="Move day later">
              ↓
            </button>
            <button className="subtle" onClick={() => removeDay(day.uid)} aria-label="Remove day">
              ✕
            </button>
          </header>
          <label className="field">
            <span>
              Day name <span className="hint">— shown at the top of the day's prayers</span>
            </span>
            <input
              type="text"
              value={day.name}
              onChange={(e) => updateDay(day.uid, { name: e.target.value })}
            />
          </label>
          {project.languages.map((code) => {
            const language = LANGUAGES.find((l) => l.code === code)!;
            return (
              <label className="field" key={code}>
                <span>
                  Day name in {language.name} <span className="hint">— optional</span>
                </span>
                <input
                  type="text"
                  dir={isRtl(code) ? "rtl" : "ltr"}
                  value={day.nameByLanguage[code] ?? ""}
                  onChange={(e) =>
                    updateDay(day.uid, {
                      nameByLanguage: { ...day.nameByLanguage, [code]: e.target.value },
                    })
                  }
                />
              </label>
            );
          })}
        </div>
      )}

      {steps.map((step, index) => (
        <StepCard
          key={step.uid}
          project={project}
          step={step}
          index={index}
          onChange={(patch) => updateStep(step.uid, patch)}
          onMove={(delta) => move(step.uid, delta)}
          onRemove={() => remove(step.uid)}
          onUploadArt={() => uploadArt(step.uid)}
        />
      ))}

      <div className="row" hidden={(isDays && !day) || (hasForms && !form)}>
        <select
          className="tight"
          value=""
          onChange={(e) => {
            if (e.target.value) addCommon(e.target.value as CommonPrayerKey);
          }}
        >
          <option value="">+ Add a common prayer…</option>
          {COMMON_PRAYERS.map((prayer) => (
            <option key={prayer.key} value={prayer.key}>
              {prayer.label}
            </option>
          ))}
        </select>
        <button className="secondary tight" onClick={addCustom}>
          + Write your own prayer
        </button>
      </div>
    </section>
  );
}

function StepCard({
  project,
  step,
  index,
  onChange,
  onMove,
  onRemove,
  onUploadArt,
}: {
  project: Project;
  step: EditorStep;
  index: number;
  onChange: (patch: Partial<EditorStep>) => void;
  onMove: (delta: -1 | 1) => void;
  onRemove: () => void;
  onUploadArt: () => void;
}) {
  const stepImage = step.image;
  const uploaded =
    stepImage?.kind === "upload"
      ? project.images.find((image) => image.uid === stepImage.uid)
      : undefined;
  const label =
    step.kind === "common"
      ? commonPrayer(step.commonKey ?? "")?.label ?? "Common prayer"
      : step.titleByLanguage.en?.trim() ||
        Object.values(step.titleByLanguage).find((t) => t?.trim()) ||
        "Your prayer";

  return (
    <div className="card">
      <header>
        <span className="title">
          {index + 1}. {label}
        </span>
        <button className="subtle" onClick={() => onMove(-1)} aria-label="Move up">
          ↑
        </button>
        <button className="subtle" onClick={() => onMove(1)} aria-label="Move down">
          ↓
        </button>
        <button className="subtle" onClick={onRemove} aria-label="Remove step">
          ✕
        </button>
      </header>

      {step.kind === "common" ? (
        <label className="field">
          <span>Which prayer?</span>
          <select
            value={step.commonKey ?? ""}
            onChange={(e) => {
              const prayer = commonPrayer(e.target.value);
              onChange({ commonKey: e.target.value as CommonPrayerKey, title: prayer?.label ?? "" });
            }}
          >
            {COMMON_PRAYERS.map((prayer) => (
              <option key={prayer.key} value={prayer.key}>
                {prayer.label}
              </option>
            ))}
          </select>
        </label>
      ) : (
        <>
          {project.languages.map((code) => {
            const language = LANGUAGES.find((l) => l.code === code)!;
            const dir = isRtl(code) ? "rtl" : "ltr";
            return (
              <div className="lang-block" key={code}>
                <div className="lang-name">{language.name}</div>
                <label className="field">
                  <span>Step name</span>
                  <input
                    type="text"
                    dir={dir}
                    value={step.titleByLanguage[code] ?? ""}
                    onChange={(e) =>
                      onChange({ titleByLanguage: { ...step.titleByLanguage, [code]: e.target.value } })
                    }
                  />
                </label>
                <label className="field">
                  <span>Prayer text</span>
                  <textarea
                    dir={dir}
                    value={step.bodyByLanguage[code] ?? ""}
                    onChange={(e) =>
                      onChange({ bodyByLanguage: { ...step.bodyByLanguage, [code]: e.target.value } })
                    }
                  />
                </label>
                <label className="field">
                  <span>Transliteration (optional — the same prayer in another script, e.g. Hebrew letters for Tagalog)</span>
                  <textarea
                    rows={2}
                    value={step.transliterationByLanguage?.[code] ?? ""}
                    onChange={(e) =>
                      onChange({
                        transliterationByLanguage: {
                          ...step.transliterationByLanguage,
                          [code]: e.target.value,
                        },
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
              checked={step.isScripture}
              onChange={(e) => onChange({ isScripture: e.target.checked })}
            />{" "}
            This text is a Bible reading (the app shows it in the Scripture typeface)
          </label>
        </>
      )}

      <div className="row">
        <label className="field tight">
          <input
            type="checkbox"
            checked={step.repeat !== undefined}
            onChange={(e) => onChange({ repeat: e.target.checked ? 3 : undefined })}
          />{" "}
          Pray several times in a row
        </label>
        {step.repeat !== undefined && (
          <input
            className="tight"
            type="number"
            min={2}
            max={99}
            style={{ width: "5em" }}
            value={step.repeat}
            onChange={(e) => onChange({ repeat: parseInt(e.target.value, 10) || 2 })}
          />
        )}
      </div>

      <div className="row">
        {uploaded ? (
          <>
            <img className="art-thumb tight" src={uploaded.dataUrl} alt="" />
            <span className="hint">Your artwork (cropped square)</span>
            <button className="subtle tight" onClick={() => onChange({ image: undefined })}>
              Remove artwork
            </button>
          </>
        ) : (
          <>
            <span className="hint">
              {step.kind === "common"
                ? "Shown with its traditional artwork."
                : step.image?.kind === "shared"
                  ? "Shown with one of the app's illustrations."
                  : "Shown with a simple cross unless you add artwork."}
            </span>
            <button className="subtle tight" onClick={onUploadArt}>
              Add artwork…
            </button>
          </>
        )}
      </div>
    </div>
  );
}
