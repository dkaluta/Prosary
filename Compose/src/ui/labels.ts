import { commonPrayer } from "../format/catalog";
import type { LanguageCode } from "../format/catalog";
import type { EditorStep, Project } from "../format/project";
import { prayerLabel } from "../format/validate";

/** The display label for a step: the common prayer's name, or its library prayer's name
 * (preferring `language` when given, e.g. the audio screen labeling in the track's language). */
export function stepLabel(project: Project, step: EditorStep, language?: LanguageCode): string {
  if (step.kind === "common") {
    return commonPrayer(step.commonKey ?? "")?.label ?? "Common prayer";
  }
  const index = project.prayers.findIndex((p) => p.uid === step.prayerUid);
  const prayer = project.prayers[index];
  if (!prayer) return "(removed prayer)";
  const localized = language ? prayer.titleByLanguage[language]?.trim() : undefined;
  return localized || prayerLabel(prayer, index);
}
