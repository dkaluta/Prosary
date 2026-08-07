import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App, AUTOSAVE_KEY } from "./App";
import { ErrorBoundary } from "./ui/ErrorBoundary";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ErrorBoundary
      onReset={() => {
        localStorage.removeItem(AUTOSAVE_KEY);
        location.reload();
      }}
    >
      <App />
    </ErrorBoundary>
  </StrictMode>,
);
