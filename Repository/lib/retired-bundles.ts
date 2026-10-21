// Keep this exact identity in step with the native pack loaders. The built-in
// litanyOfLoreto and other authors' prayers remain available.
export const RETIRED_BUNDLE_IDS: readonly string[] = [
  "repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin",
];

export function isRetiredBundle(id: string): boolean {
  return RETIRED_BUNDLE_IDS.includes(id);
}
