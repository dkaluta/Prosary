import { useEffect, useMemo } from "react";
import type { Dispatch, SetStateAction } from "react";
import { LANGUAGES } from "../format/catalog";
import type { LanguageCode } from "../format/catalog";
import type { EditorAudioTrack, Project } from "../format/project";
import { newUid } from "../format/project";
import { isOggOpus } from "../format/validate";
import { stepLabel } from "./labels";
import { formatTime, parseTime, pickFile, readFileBytes } from "./media";

interface Props {
  project: Project;
  setProject: Dispatch<SetStateAction<Project>>;
}

export function AudioScreen({ project, setProject }: Props) {
  const updateTrack = (uid: string, patch: Partial<EditorAudioTrack>) =>
    setProject((p) => ({
      ...p,
      audio: p.audio.map((track) => (track.uid === uid ? { ...track, ...patch } : track)),
    }));

  const addTrack = () =>
    pickFile(".opus,audio/ogg", async (file) => {
      const bytes = await readFileBytes(file);
      setProject((p) => ({
        ...p,
        audio: [
          ...p.audio,
          {
            uid: newUid(),
            language: p.languages[0] ?? "la",
            fileName: file.name,
            bytes,
            chapters: p.steps.length > 0 ? [{ start: 0, stepUid: p.steps[0].uid }] : [],
          },
        ],
      }));
    });

  return (
    <section>
      <h2>Audio (optional)</h2>
      <p className="help">
        You can include a narrated recording of the whole devotion, one per language. Recordings
        must be Opus files (<code>.opus</code>) — free tools like Audacity export them. Chapters
        mark where each step begins so listeners can skip around.
      </p>

      {project.audio.map((track, index) => (
        <TrackCard
          key={track.uid}
          project={project}
          track={track}
          index={index}
          onChange={(patch) => updateTrack(track.uid, patch)}
          onRemove={() =>
            setProject((p) => ({ ...p, audio: p.audio.filter((t) => t.uid !== track.uid) }))
          }
        />
      ))}

      <button className="secondary" onClick={addTrack}>
        + Add a recording…
      </button>
    </section>
  );
}

function TrackCard({
  project,
  track,
  index,
  onChange,
  onRemove,
}: {
  project: Project;
  track: EditorAudioTrack;
  index: number;
  onChange: (patch: Partial<EditorAudioTrack>) => void;
  onRemove: () => void;
}) {
  const rowLabel = (uid: string) => {
    const stepIndex = project.steps.findIndex((s) => s.uid === uid);
    const step = project.steps[stepIndex];
    if (!step) return "(removed step)";
    return `${stepIndex + 1}. ${stepLabel(project, step, track.language)}`;
  };

  const oneChapterPerStep = () =>
    onChange({
      chapters: project.steps.map((step, i) => ({
        start: track.chapters[i]?.start ?? (i === 0 ? 0 : Number.NaN),
        stepUid: step.uid,
      })),
    });

  return (
    <div className="card">
      <header>
        <span className="title">
          Recording {index + 1} · {track.fileName} ({Math.round(track.bytes.length / 1024)} KB)
        </span>
        <button className="subtle" onClick={onRemove} aria-label="Remove recording">
          ✕
        </button>
      </header>
      {!isOggOpus(track.bytes) && (
        <p className="issue">This file is not an Opus recording — export it as .opus and re-add it.</p>
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
        <OpusPlayer bytes={track.bytes} />
      </div>

      <table className="chapters">
        <thead>
          <tr>
            <th>Chapter begins at</th>
            <th>Step</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {track.chapters.map((chapter, i) => (
            <tr key={i}>
              <td>
                <ChapterTime
                  key={`${i}:${chapter.start}`}
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
                  value={chapter.stepUid}
                  onChange={(e) =>
                    onChange({
                      chapters: track.chapters.map((c, j) =>
                        j === i ? { ...c, stepUid: e.target.value } : c,
                      ),
                    })
                  }
                >
                  {project.steps.map((step) => (
                    <option key={step.uid} value={step.uid}>
                      {rowLabel(step.uid)}
                    </option>
                  ))}
                </select>
              </td>
              <td>
                <button
                  className="subtle"
                  onClick={() => onChange({ chapters: track.chapters.filter((_, j) => j !== i) })}
                  aria-label="Remove chapter"
                >
                  ✕
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className="row">
        <button
          className="subtle tight"
          onClick={() =>
            onChange({
              chapters: [
                ...track.chapters,
                {
                  start: Number.NaN,
                  stepUid: project.steps[track.chapters.length]?.uid ?? project.steps[0]?.uid ?? "",
                },
              ],
            })
          }
        >
          + Add chapter
        </button>
        {project.steps.length > 0 && (
          <button className="subtle tight" onClick={oneChapterPerStep}>
            One chapter per step
          </button>
        )}
      </div>
    </div>
  );
}

function ChapterTime({ value, onCommit }: { value: number; onCommit: (seconds: number) => void }) {
  return (
    <input
      type="text"
      placeholder="m:ss"
      defaultValue={Number.isNaN(value) ? "" : formatTime(value)}
      onBlur={(e) => {
        const parsed = parseTime(e.target.value);
        onCommit(parsed ?? Number.NaN);
      }}
    />
  );
}

function OpusPlayer({ bytes }: { bytes: Uint8Array }) {
  const url = useMemo(
    () => URL.createObjectURL(new Blob([bytes as BlobPart], { type: "audio/ogg" })),
    [bytes],
  );
  useEffect(() => () => URL.revokeObjectURL(url), [url]);
  // eslint-disable-next-line jsx-a11y/media-has-caption
  return <audio controls src={url} style={{ maxWidth: "100%" }} />;
}
