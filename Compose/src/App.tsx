import { useEffect, useMemo, useState } from "react";
import type { Project } from "./format/project";
import { deserializeProject, newProject, serializeProject } from "./format/project";
import { openBundle } from "./format/unpack";
import type { WizardScreen } from "./format/validate";
import { validateProject } from "./format/validate";
import { AudioScreen } from "./ui/AudioScreen";
import { BasicsScreen } from "./ui/BasicsScreen";
import { OrderScreen } from "./ui/OrderScreen";
import { PrayersScreen } from "./ui/PrayersScreen";
import { ReviewScreen } from "./ui/ReviewScreen";
import { download, pickFile, readFileBytes } from "./ui/media";

const AUTOSAVE_KEY = "prosary-compose-autosave";

function restoreAutosave(): Project | null {
  try {
    const saved = localStorage.getItem(AUTOSAVE_KEY);
    return saved ? deserializeProject(saved) : null;
  } catch {
    return null;
  }
}

const SCREENS: { id: WizardScreen; label: string }[] = [
  { id: "basics", label: "1 · Basics" },
  { id: "prayers", label: "2 · Prayers" },
  { id: "order", label: "3 · Order" },
  { id: "audio", label: "4 · Audio" },
  { id: "review", label: "5 · Finish" },
];

export function App() {
  const [project, setProject] = useState<Project>(() => restoreAutosave() ?? newProject());
  const [screen, setScreen] = useState<WizardScreen>("basics");
  const [openError, setOpenError] = useState<string | null>(null);

  // Everything stays on this device: the only persistence is a local autosave, so a closed
  // tab doesn't lose a technophobe's afternoon. Quota overflows (large artwork/audio) are
  // silently tolerated — the Save button is the durable path.
  useEffect(() => {
    const timer = setTimeout(() => {
      try {
        localStorage.setItem(AUTOSAVE_KEY, serializeProject(project));
      } catch {
        // Over quota — keep editing; "Save project" still works.
      }
    }, 500);
    return () => clearTimeout(timer);
  }, [project]);

  const issues = useMemo(() => validateProject(project), [project]);
  const issueCount = (target: WizardScreen) => issues.filter((i) => i.screen === target).length;

  const openFile = () => {
    setOpenError(null);
    pickFile(".prosaryprayer,.prosarycompose", async (file) => {
      try {
        const bytes = await readFileBytes(file);
        if (bytes[0] === 0x50 && bytes[1] === 0x4b) {
          setProject(await openBundle(bytes));
        } else {
          setProject(deserializeProject(new TextDecoder().decode(bytes)));
        }
        setScreen("basics");
      } catch (error) {
        setOpenError(error instanceof Error ? error.message : "Could not open that file.");
      }
    });
  };

  const saveProject = () => {
    download(
      `${project.id || "devotion"}.prosarycompose`,
      new TextEncoder().encode(serializeProject(project)),
      "application/json",
    );
  };

  const startOver = () => {
    if (!window.confirm("Start a new devotion? The current one is discarded unless you saved it.")) return;
    localStorage.removeItem(AUTOSAVE_KEY);
    setProject(newProject());
    setScreen("basics");
  };

  const screenIndex = SCREENS.findIndex((s) => s.id === screen);

  return (
    <>
      <header className="top">
        <h1>Prosary Compose</h1>
        <div className="spacer" />
        <button className="subtle" onClick={openFile}>
          Open…
        </button>
        <button className="subtle" onClick={saveProject}>
          Save project
        </button>
        <button className="subtle" onClick={startOver}>
          New
        </button>
      </header>
      <p className="tagline">
        Build a prayer devotion for the <a href="https://prosary.app">Prosary</a> app — no technical
        knowledge needed, and nothing leaves your device.
      </p>
      {openError && <p className="issue">{openError}</p>}

      <nav className="stepper">
        {SCREENS.map((s) => (
          <button
            key={s.id}
            className={s.id === screen ? "active" : ""}
            onClick={() => setScreen(s.id)}
          >
            {s.label}
            {s.id !== "review" && issueCount(s.id) > 0 && (
              <span className="badge">{issueCount(s.id)}</span>
            )}
          </button>
        ))}
      </nav>

      {screen === "basics" && <BasicsScreen project={project} setProject={setProject} />}
      {screen === "prayers" && (
        <PrayersScreen project={project} setProject={setProject} goToOrder={() => setScreen("order")} />
      )}
      {screen === "order" && (
        <OrderScreen project={project} setProject={setProject} goToPrayers={() => setScreen("prayers")} />
      )}
      {screen === "audio" && <AudioScreen project={project} setProject={setProject} />}
      {screen === "review" && (
        <ReviewScreen project={project} issues={issues} goTo={setScreen} />
      )}

      <div className="footer-nav">
        {screenIndex > 0 ? (
          <button className="secondary" onClick={() => setScreen(SCREENS[screenIndex - 1].id)}>
            ← {SCREENS[screenIndex - 1].label.slice(4)}
          </button>
        ) : (
          <span />
        )}
        {screenIndex < SCREENS.length - 1 && (
          <button className="primary" onClick={() => setScreen(SCREENS[screenIndex + 1].id)}>
            {SCREENS[screenIndex + 1].label.slice(4)} →
          </button>
        )}
      </div>
    </>
  );
}
