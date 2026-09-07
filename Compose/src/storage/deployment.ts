/** Only compare valid production entries. A missing version file, offline response or preview
 * HTML must never force an author to abandon the currently usable editor. */
export function hasNewDeployment(currentEntry: string, payload: unknown): boolean {
  if (!payload || typeof payload !== "object" || !("entry" in payload)) return false;
  const entry = payload.entry;
  return typeof entry === "string" && /^assets\/[\w.-]+\.js$/.test(entry)
    && /^\/assets\/[\w.-]+\.js$/.test(currentEntry) && `/${entry}` !== currentEntry;
}

/** Keep navigation after a successful durable save. A quota/storage failure leaves the draft
 * on screen so the author can use Save project instead. */
export async function saveBeforeReload(save: () => Promise<void>, reload: () => void): Promise<void> {
  await save();
  reload();
}
