import type { Dispatch, SetStateAction } from "react";
import { COMMON_PRAYERS } from "../format/catalog";
import type { CommonPrayerKey } from "../format/catalog";
import type { EditorStep, Project } from "../format/project";
import { newUid } from "../format/project";
import { prayerLabel } from "../format/validate";
import { stepLabel } from "./labels";
import { imageToSquareJpeg, pickFile } from "./media";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
  goToPrayers: () => void;
}

export function OrderScreen({ project, setProject, goToPrayers }: Props) {
  const updateStep = (uid: string, patch: Partial<EditorStep>) =>
    setProject((p) => ({
      ...p,
      steps: p.steps.map((step) => (step.uid === uid ? { ...step, ...patch } : step)),
    }));

  const addCommon = (key: CommonPrayerKey) =>
    setProject((p) => ({
      ...p,
      steps: [...p.steps, { uid: newUid(), kind: "common", commonKey: key }],
    }));

  const addOwn = (prayerUid: string) =>
    setProject((p) => ({
      ...p,
      steps: [...p.steps, { uid: newUid(), kind: "own", prayerUid }],
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
      <h2>The order of prayer</h2>
      <p className="help">
        Arrange the devotion as it is prayed, one screen at a time. Add common prayers straight
        from the list; your own prayers come from the{" "}
        <button className="subtle" onClick={goToPrayers} style={{ padding: "0 4px" }}>
          Prayers
        </button>{" "}
        page and can appear at as many points as you like.
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
        {project.prayers.length > 0 ? (
          <select
            className="tight"
            value=""
            onChange={(e) => {
              if (e.target.value) addOwn(e.target.value);
            }}
          >
            <option value="">+ Add one of your prayers…</option>
            {project.prayers.map((prayer, i) => (
              <option key={prayer.uid} value={prayer.uid}>
                {prayerLabel(prayer, i)}
              </option>
            ))}
          </select>
        ) : (
          <button className="secondary tight" onClick={goToPrayers}>
            Write your first prayer →
          </button>
        )}
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

  return (
    <div className="card">
      <header>
        <span className="title">
          {index + 1}. {stepLabel(project, step)}
          {step.kind === "own" && <span className="hint"> · yours</span>}
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
