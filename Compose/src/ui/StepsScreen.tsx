import type { Dispatch, SetStateAction } from "react";
import { COMMON_PRAYERS, LANGUAGES, commonPrayer, isRtl } from "../format/catalog";
import type { CommonPrayerKey } from "../format/catalog";
import type { EditorStep, Project } from "../format/project";
import { newUid } from "../format/project";
import { imageToSquareJpeg, pickFile } from "./media";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
}

export function StepsScreen({ project, setProject }: Props) {
  const updateStep = (uid: string, patch: Partial<EditorStep>) =>
    setProject((p) => ({
      ...p,
      steps: p.steps.map((step) => (step.uid === uid ? { ...step, ...patch } : step)),
    }));

  const addCommon = (key: CommonPrayerKey) =>
    setProject((p) => ({
      ...p,
      steps: [
        ...p.steps,
        {
          uid: newUid(),
          kind: "common",
          commonKey: key,
          title: commonPrayer(key)?.label ?? "",
          titleByLanguage: {},
          bodyByLanguage: {},
          isScripture: false,
        },
      ],
    }));

  const addCustom = () =>
    setProject((p) => ({
      ...p,
      steps: [
        ...p.steps,
        {
          uid: newUid(),
          kind: "custom",
          title: "",
          titleByLanguage: {},
          bodyByLanguage: {},
          isScripture: false,
        },
      ],
    }));

  const move = (uid: string, delta: -1 | 1) =>
    setProject((p) => {
      const index = p.steps.findIndex((s) => s.uid === uid);
      const target = index + delta;
      if (index < 0 || target < 0 || target >= p.steps.length) return p;
      const steps = [...p.steps];
      [steps[index], steps[target]] = [steps[target], steps[index]];
      return { ...p, steps };
    });

  const remove = (uid: string) =>
    setProject((p) => ({ ...p, steps: p.steps.filter((s) => s.uid !== uid) }));

  const uploadArt = (uid: string) =>
    pickFile("image/*", async (file) => {
      const { jpeg, dataUrl } = await imageToSquareJpeg(file);
      const imageUid = newUid();
      setProject((p) => ({
        ...p,
        images: [...p.images, { uid: imageUid, label: file.name, jpeg, dataUrl }],
        steps: p.steps.map((step) =>
          step.uid === uid ? { ...step, image: { kind: "upload", uid: imageUid } } : step,
        ),
      }));
    });

  return (
    <section>
      <h2>The prayers</h2>
      <p className="help">
        A devotion is a sequence of steps, prayed one screen at a time. Common prayers (the Our
        Father, the Hail Mary…) are already in the app in every language — just add them. Your own
        prayers you write yourself, once per language.
      </p>

      {project.steps.map((step, index) => (
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

      <div className="row">
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
