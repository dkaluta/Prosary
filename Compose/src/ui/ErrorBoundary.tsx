import { Component } from "react";
import type { ErrorInfo, ReactNode } from "react";

/**
 * Last line of defence around the wizard.
 *
 * React unmounts the entire tree when a render throws, so before this existed one bad field in a
 * restored project meant a white page and nothing else — no message, no way back, and the bad
 * state sitting in IndexedDB waiting to do it again on reload. For an audience the tagline
 * promises needs "no technical knowledge", that is the worst failure the app can produce.
 *
 * The autosave is both the usual culprit and the only thing that persists, so the escape hatch
 * is to clear it. That discards unsaved work, which is why it is a deliberate second button and
 * not something that happens on its own.
 */
interface Props {
  children: ReactNode;
  onReset: () => void;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error("Compose hit an unexpected error:", error, info.componentStack);
  }

  render(): ReactNode {
    const { error } = this.state;
    if (!error) return this.props.children;

    return (
      <div className="crash" role="alert">
        <h2>Something went wrong</h2>
        <p>
          Compose ran into a problem and stopped. Your work is saved on this device, so trying
          again is usually enough.
        </p>
        <div className="footer-nav">
          <button type="button" className="primary" onClick={() => this.setState({ error: null })}>
            Try again
          </button>
          <button
            type="button"
            className="secondary"
            onClick={() => {
              if (window.confirm("Start a new devotion and discard the saved copy on this device?")) {
                this.props.onReset();
              }
            }}
          >
            Start a new devotion
          </button>
        </div>
        <p className="hint">
          If it keeps happening, “Start a new devotion” clears what is stored here — that does
          discard anything unsaved, so use “Save project” first if you can get back to it.
        </p>
        <details className="technical-error">
          <summary>Technical details</summary>
          <pre className="issue">{error.message}</pre>
        </details>
      </div>
    );
  }
}
