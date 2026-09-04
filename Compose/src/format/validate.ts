// Client-side port of the rules in Shared/tools/validate-devotion.py that apply to
// wizard-authored bundles (flat steps type), plus editor-level checks (missing uploads,
// reserved ids) the CLI validator expresses differently. Zero jargon in the messages — they
// are shown to non-technical authors.

import { LANGUAGES, RESERVED_IDS, commonPrayer } from "./catalog";
import { projectSteps } from "./project";
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
const LANGUAGE_CODE = /^[a-z]{2,3}(-x-[a-z0-9]+)?$/;

/** The liturgical families in canonical order — mirrors validate-devotion.py's TRADITION_RANK.
 * Because the first form is the default, tradition-named forms must be declared in this order:
 * latin, byzantine, west syriac, armenian, alexandrian, east syriac. */
const TRADITION_RANK: Record<string, number> = {
  latin: 0, roman: 0,
  byzantine: 1, greek: 1,
  westSyriac: 2, syriac: 2, antiochene: 2, maronite: 2,
  armenian: 3,
  alexandrian: 4, coptic: 4, geez: 4, ethiopian: 4,
  eastSyriac: 5, chaldean: 5, assyrian: 5,
};

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

  const languageNames = new Map(LANGUAGES.map((l) => [l.code, l.name] as const));

  if (project.devotionType === "days") {
    if (project.days.length === 0) {
      steps("Add at least one day.");
    }
    project.days.forEach((day, i) => {
      if (!day.name.trim()) steps(`Day ${i + 1} needs a name.`);
      if (day.steps.length === 0) steps(`${day.name || `Day ${i + 1}`} has no prayers in it yet.`);
    });
    if (project.dayProgression === "series") {
      if (project.suggestedStart && !/^\d{2}-\d{2}$/.test(project.suggestedStart)) {
        basics("The traditional start date must be written as MM-DD, like 11-29.");
      }
      if (
        project.suggestedReminderTime &&
        !/^([01]\d|2[0-3]):[0-5]\d$/.test(project.suggestedReminderTime)
      ) {
        basics("The suggested reminder time must be written as HH:mm, like 07:00.");
      }
      if (project.suggestedNext) {
        if (!ID_SHAPE.test(project.suggestedNext)) {
          basics("What to suggest afterwards must be a devotion identifier — letters and numbers.");
        } else if (project.suggestedNext === project.id) {
          basics("A devotion cannot suggest itself afterwards.");
        }
      }
    }
  } else if (project.variants.length > 0) {
    if (project.variants.length < 2) {
      steps("A devotion with alternate forms needs at least two — or go back to a single form.");
    }
    const claimed = new Set<string>();
    const seenIds = new Set<string>();
    let highestTradition = -1;
    project.variants.forEach((form, i) => {
      const where = form.name.trim() || `Form ${i + 1}`;
      if (!form.name.trim()) steps(`Form ${i + 1} needs a name.`);
      if (form.steps.length === 0) steps(`${where} has no prayers in it yet.`);
      const id = form.variantId.trim();
      if (id && !ID_SHAPE.test(id)) {
        steps(`${where}: the identifier must start with a lowercase letter and use only letters and numbers.`);
      }
      if (id) {
        if (seenIds.has(id)) steps(`${where}: another form already uses the identifier “${id}”.`);
        seenIds.add(id);
        const rank = TRADITION_RANK[id];
        if (rank !== undefined) {
          if (rank < highestTradition) {
            steps(
              `${where}: forms named for liturgical traditions go in their canonical order — Latin, Byzantine, West Syriac, Armenian, Alexandrian, East Syriac — because the first form is the default.`,
            );
          }
          highestTradition = Math.max(highestTradition, rank);
        }
      }
      form.defaultForLanguages.forEach((code) => {
        if (!LANGUAGE_CODE.test(code)) {
          steps(`${where}: “${code}” is not a language code — use codes like he, arc, or he-x-gamliel.`);
        } else if (claimed.has(code)) {
          steps(`${where}: another form already opens by default for “${code}”.`);
        }
        claimed.add(code);
      });
    });
    if (project.audio.length > 0) {
      audio("Recordings and alternate forms can't be combined yet — remove one or the other.");
    }
  } else if (project.steps.length === 0) {
    steps("Add at least one prayer step.");
  }

  /** Numbered the way the author sees them: within the day or form that holds them. */
  const stepLabel = (step: (typeof allSteps)[number]) => {
    if (project.devotionType === "days") {
      const day = project.days.find((d) => d.steps.includes(step));
      const within = (day?.steps.indexOf(step) ?? 0) + 1;
      return `${day?.name || "Day"}, step ${within}`;
    }
    if (project.variants.length > 0) {
      const form = project.variants.find((f) => f.steps.includes(step));
      const within = (form?.steps.indexOf(step) ?? 0) + 1;
      return `${form?.name || "Form"}, step ${within}`;
    }
    return `Step ${project.steps.indexOf(step) + 1}`;
  };

  const allSteps = projectSteps(project);
  allSteps.forEach((step) => {
    const where = stepLabel(step);
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
      if (!allSteps.some((s) => s.uid === chapter.stepUid)) {
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
