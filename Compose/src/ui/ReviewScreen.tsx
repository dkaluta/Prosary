import { useMemo, useState } from "react";
import { LANGUAGES } from "../format/catalog";
import { buildBundle, buildBundleFiles } from "../format/pack";
import type { Project } from "../format/project";
import type { Issue, WizardScreen } from "../format/validate";
import { download } from "./media";

interface Props {
  project: Project;
  issues: Issue[];
  goTo: (screen: WizardScreen) => void;
}

const SCREEN_LABELS: Record<WizardScreen, string> = {
  basics: "Basics",
  prayers: "Prayers",
  order: "Order",
  audio: "Audio",
  review: "Finish",
};

export function ReviewScreen({ project, issues, goTo }: Props) {
  const [downloaded, setDownloaded] = useState(false);
  const ready = issues.length === 0;

  const previews = useMemo(() => {
    if (!ready) return null;
    const decoder = new TextDecoder();
    const files = buildBundleFiles(project);
    const text = (name: string) => {
      const file = files.find((f) => f.name === name);
      return file ? decoder.decode(file.data) : "";
    };
    return {
      names: files.map((f) => f.name),
      manifest: text("manifest.json"),
      devotion: text("devotion.json"),
    };
  }, [project, ready]);

  const downloadBundle = () => {
    download(`${project.id}.prosaryprayer`, buildBundle(project), "application/zip");
    setDownloaded(true);
  };

  return (
    <section>
      <h2>Finish</h2>
      {issues.length > 0 ? (
        <>
          <p className="help">A few things still need attention before the bundle can be created:</p>
          {issues.map((issue, i) => (
            <p className="issue" key={i}>
              {issue.message}{" "}
              <button onClick={() => goTo(issue.screen)}>Fix in {SCREEN_LABELS[issue.screen]}</button>
            </p>
          ))}
        </>
      ) : (
        <p className="ok">Everything checks out — your devotion is ready.</p>
      )}

      <div className="card">
        <dl className="summary">
          <dt>{project.name || "Untitled devotion"}</dt>
          <dd>
            {project.prayers.length} prayer{project.prayers.length === 1 ? "" : "s"} ·{" "}
            {project.steps.length} step{project.steps.length === 1 ? "" : "s"} ·{" "}
            {project.languages
              .map((code) => LANGUAGES.find((l) => l.code === code)?.name)
              .join(", ") || "no languages"}
            {project.images.length > 0 &&
              ` · ${project.images.length} illustration${project.images.length === 1 ? "" : "s"}`}
            {project.audio.length > 0 &&
              ` · ${project.audio.length} recording${project.audio.length === 1 ? "" : "s"}`}
          </dd>
        </dl>
        <p>
          <button className="primary" disabled={!ready} onClick={downloadBundle}>
            Download {project.id || "devotion"}.prosaryprayer
          </button>
        </p>
        {downloaded && (
          <p className="help">
            To pray it: open Prosary on your phone or computer, go to <strong>Favorites</strong>, and
            choose <strong>Import Devotion Bundle</strong>. Share the file with anyone — it works the
            same for them.
          </p>
        )}
      </div>

      {previews && (
        <details className="json-preview">
          <summary>For the curious: what's inside the bundle</summary>
          <p className="help">{previews.names.join(" · ")}</p>
          <pre>{previews.manifest}</pre>
          <pre>{previews.devotion}</pre>
        </details>
      )}
    </section>
  );
}
