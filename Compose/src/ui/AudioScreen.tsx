import { useMemo, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import { LANGUAGES, commonPrayer } from "../format/catalog";
import type { LanguageCode } from "../format/catalog";
import type { EditorAudioTrack, EditorStep, Project } from "../format/project";
import { newUid, projectSteps, replaceAudioTrackMedia } from "../format/project";
import { isOggOpus } from "../format/validate";
import { MEDIA_LIMITS, formatTime, parseTime, pickFile, readFileBytes } from "./media";
import { useObjectUrl } from "./useObjectUrl";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
}

export function AudioScreen({ project, setProject }: Props) {
  const [mediaError, setMediaError] = useState<string | null>(null);
  const steps = useMemo(
    () => projectSteps(project),
    [project.days, project.devotionType, project.steps, project.variants],
  );
  const updateTrack = (uid: string, patch: Partial<EditorAudioTrack>) =>
    setProject((p) => ({
      ...p,
      audio: p.audio.map((track) => (track.uid === uid ? { ...track, ...patch } : track)),
    }));

  const chooseTrack = (uid?: string) =>
    pickFile(".opus,audio/ogg", async (file) => {
      setMediaError(null);
      try {
        const bytes = await readFileBytes(file, MEDIA_LIMITS.audioBytes, "recording");
        setProject((p) => {
          if (uid) {
            return replaceAudioTrackMedia(p, uid, file.name, bytes);
          }
          const steps = projectSteps(p);
          return {
            ...p,
            audio: [
              ...p.audio,
              {
                uid: newUid(),
                language: p.languages[0] ?? "la",
                fileName: file.name,
                bytes,
                chapters: steps.length > 0 ? [{ start: 0, stepUid: steps[0].uid }] : [],
              },
            ],
          };
        });
      } catch (error) {
        setMediaError(
          error instanceof Error ? error.message : "Could not read that recording.",
        );
      }
    });

  return (
    <section className="editor-section" aria-labelledby="audio-heading">
      <h2 id="audio-heading">Audio (optional)</h2>
      <p className="help">
        You can include a narrated recording of the whole devotion, one per language. Recordings
        must be Opus files (<code>.opus</code>) — free tools like Audacity export them. Chapters
        mark where each step begins so listeners can skip around. The prayer text from the
        previous page remains the recording&apos;s readable transcript.
      </p>
      {mediaError && (
        <p className="issue callout" role="alert">
          {mediaError}
        </p>
      )}

      {project.audio.map((track, index) => (
        <TrackCard
          key={track.uid}
          project={project}
          steps={steps}
          track={track}
          index={index}
          onChange={(patch) => updateTrack(track.uid, patch)}
          onReplace={() => chooseTrack(track.uid)}
          onRemove={() =>
            setProject((p) => ({ ...p, audio: p.audio.filter((t) => t.uid !== track.uid) }))
          }
        />
      ))}

      <button type="button" className="secondary" onClick={() => chooseTrack()}>
        + Add a recording…
      </button>
    </section>
  );
}

function TrackCard({
  project,
  steps,
  track,
  index,
  onChange,
  onReplace,
  onRemove,
}: {
  project: Project;
  steps: EditorStep[];
  track: EditorAudioTrack;
  index: number;
  onChange: (patch: Partial<EditorAudioTrack>) => void;
  onReplace: () => void;
  onRemove: () => void;
}) {
  const stepLabels = useMemo(
    () =>
      new Map(
        steps.map((step, stepIndex) => {
          const name =
            step.kind === "common"
              ? commonPrayer(step.commonKey ?? "")?.label ?? "Common prayer"
              : step.titleByLanguage[track.language]?.trim() ||
                step.titleByLanguage.en?.trim() ||
                "Your prayer";
          return [step.uid, `${stepIndex + 1}. ${name}`] as const;
        }),
      ),
    [steps, track.language],
  );

  const oneChapterPerStep = () =>
    onChange({
      chapters: steps.map((step, i) => ({
        start: track.chapters[i]?.start ?? (i === 0 ? 0 : Number.NaN),
        stepUid: step.uid,
      })),
    });

  return (
    <div className="card">
      <header>
        <h3 className="title">
          Recording {index + 1} · {track.fileName} ({Math.round(track.bytes.length / 1024)} KB)
        </h3>
        <button type="button" className="subtle" onClick={onReplace}>
          Replace file…
        </button>
        <button
          type="button"
          className="subtle icon-button danger-action"
          onClick={onRemove}
          aria-label={`Remove ${track.fileName}`}
        >
          ✕
        </button>
      </header>
      {!isOggOpus(track.bytes) && (
        <p className="issue" role="alert">
          This file is not an Opus recording — export it as .opus and replace it.
        </p>
      )}
      <div className="row">
        <label className="field tight">
          <span>Language</span>
          <select
            value={track.language}
            onChange={(e) => onChange({ language: e.target.value as LanguageCode })}
          >
            {project.languages.map((code) => (
              <option key={code} value={code}>
                {LANGUAGES.find((l) => l.code === code)?.name}
              </option>
            ))}
          </select>
        </label>
        <OpusPlayer bytes={track.bytes} label={`Preview ${track.fileName}`} />
      </div>

      <div className="table-scroll" tabIndex={0}>
        <table className="chapters">
          <caption className="visually-hidden">Chapters for {track.fileName}</caption>
          <thead>
            <tr>
              <th scope="col">Chapter begins at</th>
              <th scope="col">Step</th>
              <th scope="col"><span className="visually-hidden">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            {track.chapters.map((chapter, i) => (
              <tr key={i}>
                <td>
                  <ChapterTime
                    key={`${i}:${chapter.start}`}
                    index={i}
                    value={chapter.start}
                    onCommit={(start) =>
                      onChange({
                        chapters: track.chapters.map((c, j) => (j === i ? { ...c, start } : c)),
                      })
                    }
                  />
                </td>
                <td>
                  <select
                    aria-label={`Step for chapter ${i + 1}`}
                    value={chapter.stepUid}
                    onChange={(e) =>
                      onChange({
                        chapters: track.chapters.map((c, j) =>
                          j === i ? { ...c, stepUid: e.target.value } : c,
                        ),
                      })
                    }
                  >
                    {steps.map((step) => (
                      <option key={step.uid} value={step.uid}>
                        {stepLabels.get(step.uid)}
                      </option>
                    ))}
                  </select>
                </td>
                <td>
                  <button
                    type="button"
                    className="subtle icon-button danger-action"
                    onClick={() =>
                      onChange({ chapters: track.chapters.filter((_, j) => j !== i) })
                    }
                    aria-label={`Remove chapter ${i + 1}`}
                  >
                    ✕
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="row">
        <button
          type="button"
          className="subtle tight"
          disabled={steps.length === 0}
          onClick={() =>
            onChange({
              chapters: [
                ...track.chapters,
                {
                  start: Number.NaN,
                  stepUid: steps[track.chapters.length]?.uid ?? steps[0]?.uid ?? "",
                },
              ],
            })
          }
        >
          + Add chapter
        </button>
        {steps.length > 0 && (
          <button type="button" className="subtle tight" onClick={oneChapterPerStep}>
            One chapter per step
          </button>
        )}
      </div>
    </div>
  );
}

function ChapterTime({
  index,
  value,
  onCommit,
}: {
  index: number;
  value: number;
  onCommit: (seconds: number) => void;
}) {
  return (
    <input
      type="text"
      inputMode="decimal"
      aria-label={`Start time for chapter ${index + 1}`}
      placeholder="m:ss"
      defaultValue={Number.isNaN(value) ? "" : formatTime(value)}
      onBlur={(e) => {
        const parsed = parseTime(e.target.value);
        onCommit(parsed ?? Number.NaN);
      }}
    />
  );
}

function OpusPlayer({ bytes, label }: { bytes: Uint8Array; label: string }) {
  const url = useObjectUrl(bytes, "audio/ogg");
  return <audio controls preload="metadata" src={url} aria-label={label} />;
}
