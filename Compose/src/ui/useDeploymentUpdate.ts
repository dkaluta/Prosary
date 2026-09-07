import { useEffect, useState } from "react";
import { hasNewDeployment } from "../storage/deployment";

export function useDeploymentUpdate(): boolean {
  const [available, setAvailable] = useState(false);
  useEffect(() => {
    const script = document.querySelector<HTMLScriptElement>('script[type="module"][src]');
    if (!script) return;
    const currentEntry = new URL(script.src).pathname;
    if (!currentEntry.startsWith("/assets/")) return;
    const abort = new AbortController();
    let checking = false;
    const check = async () => {
      if (checking) return;
      checking = true;
      try {
        const response = await fetch("/version.json", { cache: "no-store", signal: abort.signal });
        if (response.ok && hasNewDeployment(currentEntry, await response.json())) setAvailable(true);
      } catch {
        // Offline authors can keep writing and downloading with the version already open.
      } finally {
        checking = false;
      }
    };
    void check();
    const interval = window.setInterval(() => {
      if (document.visibilityState !== "hidden") void check();
    }, 5 * 60 * 1000);
    window.addEventListener("focus", check);
    document.addEventListener("visibilitychange", check);
    return () => {
      abort.abort();
      window.clearInterval(interval);
      window.removeEventListener("focus", check);
      document.removeEventListener("visibilitychange", check);
    };
  }, []);
  return available;
}
