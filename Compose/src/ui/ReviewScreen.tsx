import { useEffect, useMemo, useRef, useState } from "react";
import { LANGUAGES } from "../format/catalog";
import { buildBundle, buildBundleFiles } from "../format/pack";
import type { Project } from "../format/project";
import type { Issue, WizardScreen } from "../format/validate";
import { download } from "./media";

/** Where "Publish" hands the bundle over (see the repository's /publish receiver): the popup
 * runs on the repository's own origin, so the session cookie and the passkey ceremony stay
 * first-party — Compose only ever passes the built bytes across via postMessage. */
const REPO_ORIGIN = import.meta.env.VITE_REPO_ORIGIN ?? "https://prayers.prosary.app";

interface Props {
  project: Project;
  issues: Issue[];
  goTo: (screen: WizardScreen) => void;
}

const SCREEN_LABELS: Record<WizardScreen, string> = {
  basics: "Basics",
  steps: "Prayers",
  audio: "Audio",
  review: "Finish",
};

export function ReviewScreen({ project, issues, goTo }: Props) {
  const [downloaded, setDownloaded] = useState(false);
  const [publishState, setPublishState] = useState<
    { kind: "idle" } | { kind: "waiting" } | { kind: "done"; id: string } | { kind: "blocked" }
  >({ kind: "idle" });
  const publishCleanup = useRef<(() => void) | null>(null);
  useEffect(() => () => publishCleanup.current?.(), []);
  const ready = issues.length === 0;

  /** Opens the repository's /publish receiver and hands the built bundle over. The receiver
   * re-announces readiness after any reload (e.g. signing in over there), and we answer every
   * announcement — so the handshake survives auth round-trips without special cases. */
  const publishBundle = () => {
    const bytes = buildBundle(project);
    const popup = window.open(`${REPO_ORIGIN}/publish`, "prosary-publish", "popup,width=560,height=760");
    if (!popup) {
      setPublishState({ kind: "blocked" });
      return;
    }
    publishCleanup.current?.();
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== REPO_ORIGIN) return;
      if (event.data?.type === "prosary-publish-ready") {
        popup.postMessage(
          {
            type: "prosary-publish-bundle",
            name: project.id || "devotion",
            tags: project.tags,
            // A fresh copy per send: the buffer is structured-cloned, never transferred, so
            // repeated ready-announcements (post-sign-in reloads) can be answered again.
            bytes: bytes.slice().buffer,
          },
          REPO_ORIGIN,
        );
      } else if (event.data?.type === "prosary-publish-done" && typeof event.data.id === "string") {
        setPublishState({ kind: "done", id: event.data.id });
        publishCleanup.current?.();
      }
    };
    window.addEventListener("message", onMessage);
    publishCleanup.current = () => {
      window.removeEventListener("message", onMessage);
      publishCleanup.current = null;
    };
    setPublishState({ kind: "waiting" });
  };

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
          </button>{" "}
          <button className="secondary" disabled={!ready} onClick={publishBundle}>
            Publish to prayers.prosary.app…
          </button>
        </p>
        {publishState.kind === "waiting" && (
          <p className="help">
            Finishing up in the prayers.prosary.app window — sign in there if asked; your
            bundle rides along.
          </p>
        )}
        {publishState.kind === "done" && (
          <p className="ok">
            Published as {publishState.id} — it&apos;s live in the{" "}
            <a href={REPO_ORIGIN} target="_blank" rel="noreferrer">
              catalog
            </a>{" "}
            and in the apps&apos; Browse tab.
          </p>
        )}
        {publishState.kind === "blocked" && (
          <p className="issue">
            The publish window was blocked — allow popups for this site and try again, or
            download the file and upload it at {REPO_ORIGIN}/submit.
          </p>
        )}
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
