// Generates the prayers.prosary.app repository's seed bundle (repo.dkaluta.kyrie) through the
// same pack code the Compose webapp runs — proving repository bundles are ordinary
// .prosaryprayer files whose only specialness is the `repo.<username>.<name>` id (see
// Shared/ARCHITECTURE.markdown § User-installed bundles). Run via
// `npx vite build --ssr scripts/make-repo-seed.ts --outDir dist-e2e && node dist-e2e/make-repo-seed.js <out>`.

import { writeFileSync } from "node:fs";
import { buildBundle } from "../src/format/pack";
import type { EditorStep } from "../src/format/project";
import { newProject, newUid } from "../src/format/project";

const project = newProject();
project.name = "Kyrie";
project.id = "repo.dkaluta.kyrie";
project.languages = ["la", "en"];

const cross: EditorStep = {
  uid: newUid(),
  kind: "common",
  commonKey: "signumCrucis",
  title: "Sign of the Cross",
  titleByLanguage: {},
  bodyByLanguage: {},
  isScripture: false,
};
const kyrie: EditorStep = {
  uid: newUid(),
  kind: "custom",
  title: "",
  titleByLanguage: { la: "Kyrie", en: "Kyrie" },
  bodyByLanguage: {
    la: "Kyrie, eleison.\n**Christe, eleison.**\nKyrie, eleison.",
    en: "Lord, have mercy.\n**Christ, have mercy.**\nLord, have mercy.",
  },
  isScripture: false,
  repeat: 3,
};
const gloria: EditorStep = {
  uid: newUid(),
  kind: "common",
  commonKey: "gloriaPatri",
  title: "Glory Be",
  titleByLanguage: {},
  bodyByLanguage: {},
  isScripture: false,
};
project.steps = [cross, kyrie, gloria];

const out = process.argv[2] ?? "dist-e2e/repo.dkaluta.kyrie.prosaryprayer";
writeFileSync(out, buildBundle(project));
console.log("wrote", out);
