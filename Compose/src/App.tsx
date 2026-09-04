import { lazy, Suspense, useCallback, useEffect, useMemo, useState } from "react";
import type { Dispatch, SetStateAction } from "react";
import type { Project } from "./format/project";
import { newProject, pruneUnusedImages } from "./format/project";
import type { WizardScreen } from "./format/validate";
import { validateProject } from "./format/validate";
import { BasicsScreen } from "./ui/BasicsScreen";
import { download, pickFile, readFileBytes } from "./ui/media";
import { clearAutosave, saveAutosave } from "./storage/autosave";

const StepsScreen = lazy(() =>
  import("./ui/StepsScreen").then((module) => ({ default: module.StepsScreen })),
);
const AudioScreen = lazy(() =>
  import("./ui/AudioScreen").then((module) => ({ default: module.AudioScreen })),
);
const ReviewScreen = lazy(() =>
  import("./ui/ReviewScreen").then((module) => ({ default: module.ReviewScreen })),
);

const SCREENS: { id: WizardScreen; label: string }[] = [
  { id: "basics", label: "1 · Basics" },
  { id: "steps", label: "2 · Prayers" },
  { id: "audio", label: "3 · Audio" },
  { id: "review", label: "4 · Finish" },
];

interface Props {
  initialProject?: Project;
}

export function App({ initialProject }: Props) {
  const [project, setProjectState] = useState<Project>(() => initialProject ?? newProject());
  const [screen, setScreen] = useState<WizardScreen>("basics");
  const [openError, setOpenError] = useState<string | null>(null);
  const [autosaveError, setAutosaveError] = useState(false);
  const [fileAction, setFileAction] = useState<"idle" | "opening" | "saving">("idle");

  // Keep media state normalized at the boundary shared by every screen. Screen-specific edits
  // cannot accidentally leave detached uploads in memory or in the next autosave.
  const setProject: Dispatch<SetStateAction<Project>> = useCallback((update) => {
    setProjectState((current) =>
      pruneUnusedImages(typeof update === "function" ? update(current) : update),
    );
  }, []);

  // IndexedDB stores binary uploads separately from the frequently-changing metadata. Typing
  // therefore schedules one small native transaction instead of base64-encoding all media.
  useEffect(() => {
    let current = true;
    const timer = setTimeout(() => {
      void saveAutosave(project).then(
        () => current && setAutosaveError(false),
        () => current && setAutosaveError(true),
      );
    }, 500);
    return () => {
      current = false;
      clearTimeout(timer);
    };
  }, [project]);

  const issues = useMemo(() => validateProject(project), [project]);
  const issueCounts = useMemo(() => {
    const counts: Record<WizardScreen, number> = { basics: 0, steps: 0, audio: 0, review: 0 };
    for (const issue of issues) counts[issue.screen] += 1;
    return counts;
  }, [issues]);

  const openFile = () => {
    setOpenError(null);
    pickFile(".prosaryprayer,.prosarycompose", async (file) => {
      setFileAction("opening");
      try {
        const bytes = await readFileBytes(file);
        if (bytes[0] === 0x50 && bytes[1] === 0x4b) {
          const { openBundle } = await import("./format/unpack");
          setProject(await openBundle(bytes));
        } else {
          const { deserializeProject } = await import("./format/projectFile");
          setProject(deserializeProject(new TextDecoder().decode(bytes)));
        }
        setScreen("basics");
      } catch (error) {
        setOpenError(error instanceof Error ? error.message : "Could not open that file.");
      } finally {
        setFileAction("idle");
      }
    });
  };

  const saveProject = async () => {
    setOpenError(null);
    setFileAction("saving");
    try {
      const { serializeProject } = await import("./format/projectFile");
      download(
        `${project.id || "devotion"}.prosarycompose`,
        new TextEncoder().encode(serializeProject(project)),
        "application/json",
      );
    } catch (error) {
      setOpenError(error instanceof Error ? error.message : "Could not save that project.");
    } finally {
      setFileAction("idle");
    }
  };

  const startOver = async () => {
    if (!window.confirm("Start a new devotion? The current one is discarded unless you saved it.")) return;
    try {
      await clearAutosave();
    } finally {
      setProject(newProject());
      setScreen("basics");
    }
  };

  const screenIndex = SCREENS.findIndex((s) => s.id === screen);

  return (
    <>
      <a className="skip-link" href="#editor">
        Skip to editor
      </a>
      <header className="top">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">✣</span>
          <h1>Prosary Compose</h1>
        </div>
        <nav className="top-actions" aria-label="Project actions">
          <button type="button" className="subtle" onClick={openFile} disabled={fileAction !== "idle"}>
            {fileAction === "opening" ? "Opening…" : "Open…"}
          </button>
          <button type="button" className="subtle" onClick={saveProject} disabled={fileAction !== "idle"}>
            {fileAction === "saving" ? "Saving…" : "Save project"}
          </button>
          <button
            type="button"
            className="subtle"
            onClick={startOver}
            disabled={fileAction !== "idle"}
          >
            New
          </button>
        </nav>
      </header>
      <p className="tagline">
        Build a prayer devotion for the{" "}
        <a href="https://prosary.app" target="_blank" rel="noopener noreferrer">
          Prosary
        </a>{" "}
        app — no technical knowledge needed, and nothing leaves your device.
      </p>
      <p className={autosaveError ? "autosave-status issue" : "autosave-status"} role="status">
        {autosaveError
          ? "Autosave is unavailable in this browser — use Save project to keep a copy."
          : "Your work autosaves privately on this device."}
      </p>
      {openError && (
        <p className="issue callout" role="alert">
          {openError}
        </p>
      )}

      <main id="editor" tabIndex={-1} aria-labelledby={`${screen}-heading`}>
        <nav className="stepper" aria-label="Devotion builder steps">
          {SCREENS.map((item) => (
            <button
              type="button"
              key={item.id}
              className={item.id === screen ? "active" : ""}
              aria-current={item.id === screen ? "step" : undefined}
              onClick={() => setScreen(item.id)}
            >
              {item.label}
              {item.id !== "review" && issueCounts[item.id] > 0 && (
                <span className="badge" aria-label={`${issueCounts[item.id]} issues`}>
                  {issueCounts[item.id]}
                </span>
              )}
            </button>
          ))}
        </nav>
        <p className="visually-hidden" role="status">
          Step {screenIndex + 1} of {SCREENS.length}: {SCREENS[screenIndex].label.slice(4)}
        </p>

        <Suspense
          fallback={
            <p className="loading" role="status">
              Opening this step…
            </p>
          }
        >
          {screen === "basics" && <BasicsScreen project={project} setProject={setProject} />}
          {screen === "steps" && <StepsScreen project={project} setProject={setProject} />}
          {screen === "audio" && <AudioScreen project={project} setProject={setProject} />}
          {screen === "review" && (
            <ReviewScreen project={project} issues={issues} goTo={setScreen} />
          )}
        </Suspense>

        <nav className="footer-nav" aria-label="Wizard navigation">
          {screenIndex > 0 ? (
            <button
              type="button"
              className="secondary"
              onClick={() => setScreen(SCREENS[screenIndex - 1].id)}
            >
              ← {SCREENS[screenIndex - 1].label.slice(4)}
            </button>
          ) : (
            <span aria-hidden="true" />
          )}
          {screenIndex < SCREENS.length - 1 && (
            <button
              type="button"
              className="primary"
              onClick={() => setScreen(SCREENS[screenIndex + 1].id)}
            >
              {SCREENS[screenIndex + 1].label.slice(4)} →
            </button>
          )}
        </nav>
      </main>
    </>
  );
}
