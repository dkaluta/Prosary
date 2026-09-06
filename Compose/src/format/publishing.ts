import { LANGUAGES, REPOSITORY_PUBLISH_LANGUAGE_CODES } from "./catalog";
import type { Project } from "./project";
import { storedZipByteLength, type ZipFile } from "./zip";

const REPOSITORY_MAX_BUNDLE_BYTES = 8 * 1024 * 1024;
const REPOSITORY_LANGUAGE_SET = new Set<string>(REPOSITORY_PUBLISH_LANGUAGE_CODES);

/** The same publication readiness check used by Finish and the publishing round-trip tests. */
export function publicationIssues(project: Project, files: ZipFile[]): string[] {
  const messages: string[] = [];
  const unsupported = project.languages.filter((code) => !REPOSITORY_LANGUAGE_SET.has(code));
  if (unsupported.length > 0) {
    const names = unsupported.map((code) => LANGUAGES.find((language) => language.code === code)?.name ?? code);
    messages.push(`The community repository does not support these prayer languages: ${names.join(", ")}.`);
  }
  const byteLength = storedZipByteLength(files);
  if (byteLength > REPOSITORY_MAX_BUNDLE_BYTES) {
    messages.push(
      `The community repository accepts bundles up to 8 MB; this one is about ${(byteLength / (1024 * 1024)).toFixed(1)} MB.`,
    );
  }
  return messages;
}
