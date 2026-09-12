import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { clearAutosave, loadAutosave } from "./storage/autosave";
import { ErrorBoundary } from "./ui/ErrorBoundary";
import { prepareProjectArtwork } from "./ui/media";
import "./styles.css";

const root = createRoot(document.getElementById("root")!);

async function start(): Promise<void> {
  let savedProject = await loadAutosave();
  let initialArtworkError: string | undefined;
  if (savedProject) {
    try { savedProject = await prepareProjectArtwork(savedProject); }
    catch { initialArtworkError = "Some saved artwork could not be prepared. Replace or remove it before exporting your prayer pack."; }
  }
  root.render(
    <StrictMode>
      <ErrorBoundary
        onReset={() => {
          void clearAutosave().finally(() => location.reload());
        }}
      >
        <App initialProject={savedProject ?? undefined} initialArtworkError={initialArtworkError} />
      </ErrorBoundary>
    </StrictMode>,
  );
}

void start();
