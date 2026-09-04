import { useEffect, useMemo, useRef, useState } from "react";
import { LANGUAGES, REPOSITORY_PUBLISH_LANGUAGE_CODES } from "../format/catalog";
import { authoredSteps, buildBundle, buildBundleFiles } from "../format/pack";
import type { Project } from "../format/project";
import type { Issue, WizardScreen } from "../format/validate";
import { storedZipByteLength } from "../format/zip";
import { PORTABLE_FILE_MIME, download } from "./media";

/** Where "Publish" hands the bundle over (see the repository's /publish receiver): the popup
 * runs on the repository's own origin, so the session cookie and the passkey ceremony stay
 * first-party — Compose only ever passes the built bytes across via postMessage. */
const REPO_ORIGIN = new URL(
  import.meta.env.VITE_REPO_ORIGIN ?? "https://prayers.prosary.app",
).origin;
const REPOSITORY_MAX_BUNDLE_BYTES = 8 * 1024 * 1024;
const REPOSITORY_LANGUAGE_SET = new Set(REPOSITORY_PUBLISH_LANGUAGE_CODES);

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
    | { kind: "idle" }
    | { kind: "waiting" }
    | { kind: "done"; id: string }
    | { kind: "blocked" }
    | { kind: "error"; message: string }
  >({ kind: "idle" });
  const publishCleanup = useRef<(() => void) | null>(null);
  useEffect(() => () => publishCleanup.current?.(), []);
  const ready = issues.length === 0;
  const stepCount = authoredSteps(project).length;

  const bundleFiles = useMemo(() => (ready ? buildBundleFiles(project) : null), [project, ready]);
  const publishIssues = useMemo(() => {
    if (!bundleFiles) return [];
    const messages: string[] = [];
    const unsupportedLanguages = project.languages.filter(
      (code) => !REPOSITORY_LANGUAGE_SET.has(code),
    );
    if (unsupportedLanguages.length > 0) {
      const names = unsupportedLanguages.map(
        (code) => LANGUAGES.find((language) => language.code === code)?.name ?? code,
      );
      messages.push(
        `${names.join(", ")} ${names.length === 1 ? "is" : "are"} available for downloaded bundles, but not community publishing yet.`,
      );
    }
    const byteLength = storedZipByteLength(bundleFiles);
    if (byteLength > REPOSITORY_MAX_BUNDLE_BYTES) {
      messages.push(
        `The community repository accepts bundles up to 8 MB; this one is about ${(byteLength / (1024 * 1024)).toFixed(1)} MB.`,
      );
    }
    return messages;
  }, [bundleFiles, project.languages]);
  const publishReady = ready && publishIssues.length === 0;

  /** Opens the repository's /publish receiver and hands the built bundle over. The receiver
   * re-announces readiness after any reload (e.g. signing in over there), and we answer every
   * announcement — so the handshake survives auth round-trips without special cases. */
  const publishBundle = () => {
    publishCleanup.current?.();
    const popup = window.open(`${REPO_ORIGIN}/publish`, "prosary-publish", "popup,width=560,height=760");
    if (!popup) {
      setPublishState({ kind: "blocked" });
      return;
    }

    let bytes: Uint8Array | null = null;
    let finished = false;
    let closePoll: number | undefined;
    const cleanup = () => {
      window.removeEventListener("message", onMessage);
      if (closePoll !== undefined) window.clearInterval(closePoll);
      if (publishCleanup.current === cleanup) publishCleanup.current = null;
    };
    const onMessage = (event: MessageEvent) => {
      if (event.origin !== REPO_ORIGIN || event.source !== popup) return;
      if (event.data?.type === "prosary-publish-ready" && bytes) {
        try {
          popup.postMessage(
            {
              type: "prosary-publish-bundle",
              name: project.id || "devotion",
              tags: project.tags,
              // Structured cloning preserves this owned buffer, so post-sign-in reloads can
              // request it again without an extra full-size pre-copy here.
              bytes: bytes.buffer as ArrayBuffer,
            },
            REPO_ORIGIN,
          );
        } catch {
          cleanup();
          setPublishState({
            kind: "error",
            message: "The devotion could not be sent to the publish window. Close it and try again.",
          });
        }
      } else if (event.data?.type === "prosary-publish-done" && typeof event.data.id === "string") {
        finished = true;
        setPublishState({ kind: "done", id: event.data.id });
        cleanup();
      }
    };
    window.addEventListener("message", onMessage);
    closePoll = window.setInterval(() => {
      if (!finished && popup.closed) {
        cleanup();
        setPublishState({
          kind: "error",
          message: "The publish window closed before the devotion was sent. Try again when you are ready.",
        });
      }
    }, 500);
    publishCleanup.current = cleanup;
    setPublishState({ kind: "waiting" });

    try {
      // Opening the popup above keeps this click's user activation intact even for a large bundle.
      bytes = buildBundle(project);
    } catch {
      cleanup();
      popup.close();
      setPublishState({
        kind: "error",
        message: "The devotion could not be prepared for publishing. Check its files and try again.",
      });
    }
  };

  const previews = useMemo(() => {
    if (!bundleFiles) return null;
    const decoder = new TextDecoder();
    const text = (name: string) => {
      const file = bundleFiles.find((f) => f.name === name);
      return file ? decoder.decode(file.data) : "";
    };
    return {
      names: bundleFiles.map((f) => f.name),
      manifest: text("manifest.json"),
      devotion: text("devotion.json"),
    };
  }, [bundleFiles]);

  const downloadBundle = () => {
    download(`${project.id}.prosaryprayer`, buildBundle(project), PORTABLE_FILE_MIME);
    setDownloaded(true);
  };

  return (
    <section className="editor-section" aria-labelledby="review-heading">
      <h2 id="review-heading">Finish</h2>
      {issues.length > 0 ? (
        <>
          <p className="help">A few things still need attention before the bundle can be created:</p>
          <ul className="issue-list" aria-label="Things to fix">
            {issues.map((issue, i) => (
              <li className="issue" key={`${issue.screen}:${i}`}>
                {issue.message}{" "}
                <button type="button" onClick={() => goTo(issue.screen)}>
                  Fix in {SCREEN_LABELS[issue.screen]}
                </button>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <p className="ok" role="status">Everything checks out — your devotion is ready.</p>
      )}

      <div className="card">
        <dl className="summary">
          <dt>{project.name || "Untitled devotion"}</dt>
          <dd>
            {project.devotionType === "days" &&
              `${project.days.length} day${project.days.length === 1 ? "" : "s"} · `}
            {project.variants.length > 0 && `${project.variants.length} forms · `}
            {stepCount} step{stepCount === 1 ? "" : "s"} ·{" "}
            {project.languages
              .map((code) => LANGUAGES.find((l) => l.code === code)?.name)
              .join(", ") || "no languages"}
            {project.images.length > 0 &&
              ` · ${project.images.length} illustration${project.images.length === 1 ? "" : "s"}`}
            {project.audio.length > 0 &&
              ` · ${project.audio.length} recording${project.audio.length === 1 ? "" : "s"}`}
          </dd>
        </dl>
        <div className="finish-actions">
          <button type="button" className="primary" disabled={!ready} onClick={downloadBundle}>
            Download {project.id || "devotion"}.prosaryprayer
          </button>
          <button
            type="button"
            className="secondary"
            disabled={!publishReady}
            aria-describedby={publishIssues.length > 0 ? "publish-limits" : undefined}
            onClick={publishBundle}
          >
            Publish to prayers.prosary.app…
          </button>
        </div>
        {ready && publishIssues.length > 0 && (
          <div id="publish-limits" className="callout">
            <p className="help">
              This devotion is ready to download, but it does not fit community publishing yet:
            </p>
            <ul className="issue-list">
              {publishIssues.map((message) => (
                <li className="issue" key={message}>{message}</li>
              ))}
            </ul>
          </div>
        )}
        <div aria-live="polite">
          {publishState.kind === "waiting" && (
            <p className="help">
              Finishing up in the prayers.prosary.app window — sign in there if asked; your
              bundle rides along.
            </p>
          )}
          {publishState.kind === "done" && (
            <p className="ok">
              Published as {publishState.id} — it&apos;s live in the{" "}
              <a href={REPO_ORIGIN} target="_blank" rel="noopener noreferrer">
                catalog
              </a>{" "}
              and in the apps&apos; Browse tab.
            </p>
          )}
          {publishState.kind === "blocked" && (
            <p className="issue" role="alert">
              The publish window was blocked — allow popups for this site and try again, or
              download the file and upload it at {REPO_ORIGIN}/submit.
            </p>
          )}
          {publishState.kind === "error" && (
            <p className="issue" role="alert">
              {publishState.message}
            </p>
          )}
        </div>
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
          <pre tabIndex={0}>{previews.manifest}</pre>
          <pre tabIndex={0}>{previews.devotion}</pre>
        </details>
      )}
    </section>
  );
}
