// Client-side port of the rules in Shared/tools/validate-devotion.py that apply to
// wizard-authored bundles (flat steps type), plus editor-level checks (missing uploads,
// reserved ids) the CLI validator expresses differently. Zero jargon in the messages — they
// are shown to non-technical authors.

import { LANGUAGES, RESERVED_IDS, commonPrayer } from "./catalog";
import type { Project } from "./project";

export type WizardScreen = "basics" | "steps" | "audio" | "review";

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

export function validateProject(project: Project): Issue[] {
  const issues: Issue[] = [];
  const basics = (message: string) => issues.push({ screen: "basics", message });
  const steps = (message: string) => issues.push({ screen: "steps", message });
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

  if (project.steps.length === 0) steps("Add at least one prayer step.");
  const languageNames = new Map(LANGUAGES.map((l) => [l.code, l.name] as const));
  project.steps.forEach((step, i) => {
    const where = `Step ${i + 1}`;
    if (step.kind === "common") {
      if (!step.commonKey || !commonPrayer(step.commonKey)) {
        steps(`${where}: pick which common prayer this is.`);
      }
    } else {
      for (const language of project.languages) {
        const name = languageNames.get(language);
        if (!step.titleByLanguage[language]?.trim()) {
          steps(`${where}: the step name is missing in ${name}.`);
        }
        if (!step.bodyByLanguage[language]?.trim()) {
          steps(`${where}: the prayer text is missing in ${name}.`);
        }
      }
    }
    if (step.repeat !== undefined && (!Number.isInteger(step.repeat) || step.repeat < 2)) {
      steps(`${where}: “pray n times” must be a whole number of 2 or more.`);
    }
    const image = step.image;
    if (image?.kind === "upload" && !project.images.some((img) => img.uid === image.uid)) {
      steps(`${where}: its artwork was removed — pick another image.`);
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
