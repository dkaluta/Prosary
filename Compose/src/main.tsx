import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { clearAutosave, loadAutosave } from "./storage/autosave";
import { ErrorBoundary } from "./ui/ErrorBoundary";
import "./styles.css";

const root = createRoot(document.getElementById("root")!);

async function start(): Promise<void> {
  const savedProject = await loadAutosave();
  root.render(
    <StrictMode>
      <ErrorBoundary
        onReset={() => {
          void clearAutosave().finally(() => location.reload());
        }}
      >
        <App initialProject={savedProject ?? undefined} />
      </ErrorBoundary>
    </StrictMode>,
  );
}

void start();
