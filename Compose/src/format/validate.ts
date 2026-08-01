// Client-side port of the rules in Shared/tools/validate-devotion.py that apply to
// wizard-authored bundles (flat steps type), plus editor-level checks (missing uploads,
// reserved ids) the CLI validator expresses differently. Zero jargon in the messages — they
// are shown to non-technical authors.

import { LANGUAGES, RESERVED_IDS, commonPrayer } from "./catalog";
import type { EditorPrayer, Project } from "./project";

export type WizardScreen = "basics" | "prayers" | "order" | "audio" | "review";

export interface Issue {
  screen: WizardScreen;
  message: string;
}

export function isOggOpus(bytes: Uint8Array): boolean {
  const ascii = (offset: number, text: string) =>
    [...text].every((ch, i) => bytes[offset + i] === ch.charCodeAt(0));
  return bytes.length >= 36 && ascii(0, "OggS") && ascii(28, "OpusHead");
}

const HEX_COLOR = /^#[0-9a-fA-F]{6}$/;
const ID_SHAPE = /^[a-z][a-zA-Z0-9]*$/;

/** The label the wizard shows for a library prayer. */
export function prayerLabel(prayer: EditorPrayer, index: number): string {
  const named = Object.values(prayer.titleByLanguage).find((t) => t?.trim());
  return named?.trim() || `Prayer ${index + 1}`;
}

export function validateProject(project: Project): Issue[] {
  const issues: Issue[] = [];
  const basics = (message: string) => issues.push({ screen: "basics", message });
  const prayers = (message: string) => issues.push({ screen: "prayers", message });
  const order = (message: string) => issues.push({ screen: "order", message });
  const audio = (message: string) => issues.push({ screen: "audio", message });

  if (!project.name.trim()) basics("Give your devotion a name.");
  if (!project.id) {
    basics("The devotion needs a short identifier — it fills in automatically from the name.");
  } else if (!ID_SHAPE.test(project.id)) {
    basics("The identifier must start with a lowercase letter and use only letters and numbers.");
  } else if (RESERVED_IDS.includes(project.id)) {
    basics(`“${project.id}” is already used by a devotion built into the app — pick another identifier.`);
  }
  if (project.languages.length === 0) basics("Choose at least one language.");
  for (const [field, value] of [
    ["light", project.accentColorHex],
    ["dark", project.accentColorDarkHex],
  ] as const) {
    if (!HEX_COLOR.test(value)) basics(`The ${field} accent color must be a hex color like #7A1F3D.`);
  }

  const languageNames = new Map(LANGUAGES.map((l) => [l.code, l.name] as const));

  // Only prayers the sequence actually prays must be complete — unfinished drafts in the
  // library are fine and simply don't ship.
  const usedUids = new Set(
    project.steps.filter((s) => s.kind === "own" && s.prayerUid).map((s) => s.prayerUid!),
  );
  project.prayers.forEach((prayer, i) => {
    if (!usedUids.has(prayer.uid)) return;
    const label = `“${prayerLabel(prayer, i)}”`;
    for (const language of project.languages) {
      const name = languageNames.get(language);
      if (!prayer.titleByLanguage[language]?.trim()) {
        prayers(`${label}: the prayer's name is missing in ${name}.`);
      }
      if (!prayer.bodyByLanguage[language]?.trim()) {
        prayers(`${label}: the prayer text is missing in ${name}.`);
      }
    }
  });

  if (project.steps.length === 0) order("Add at least one step to the order of prayer.");
  project.steps.forEach((step, i) => {
    const where = `Step ${i + 1}`;
    if (step.kind === "common") {
      if (!step.commonKey || !commonPrayer(step.commonKey)) {
        order(`${where}: pick which common prayer this is.`);
      }
    } else if (!step.prayerUid || !project.prayers.some((p) => p.uid === step.prayerUid)) {
      order(`${where}: the prayer it prayed was removed — pick another.`);
    }
    if (step.repeat !== undefined && (!Number.isInteger(step.repeat) || step.repeat < 2)) {
      order(`${where}: “pray n times” must be a whole number of 2 or more.`);
    }
    const image = step.image;
    if (image?.kind === "upload" && !project.images.some((img) => img.uid === image.uid)) {
      order(`${where}: its artwork was removed — pick another image.`);
    }
  });

  project.audio.forEach((track, i) => {
    const where = project.audio.length === 1 ? "The recording" : `Recording ${i + 1}`;
    const name = languageNames.get(track.language);
    if (!project.languages.includes(track.language)) {
      audio(`${where} is in ${name}, but the devotion doesn't include that language.`);
    }
    if (!isOggOpus(track.bytes)) {
      audio(`${where} is not an Opus file (.opus) — export it as Opus and upload again.`);
    }
    if (track.chapters.length === 0) {
      audio(`${where} needs at least one chapter so listeners can follow along.`);
    }
    track.chapters.forEach((chapter, j) => {
      if (!project.steps.some((s) => s.uid === chapter.stepUid)) {
        audio(`${where}: chapter ${j + 1} points at a step that was removed.`);
      }
      if (chapter.start < 0 || Number.isNaN(chapter.start)) {
        audio(`${where}: chapter ${j + 1} needs a start time.`);
      }
      if (j === 0 && chapter.start !== 0) {
        audio(`${where}: the first chapter must start at 0:00.`);
      }
      if (j > 0 && chapter.start <= track.chapters[j - 1].start) {
        audio(`${where}: chapter ${j + 1} must start after chapter ${j}.`);
      }
    });
  });

  return issues;
}
