// Browser-side media helpers. Step artwork is square; Gallery covers preserve
// their proportions. Both use JPEG, alongside chapter times and blob downloads.
import { isSdrSrgbJpeg, tagConvertedSrgbJpeg } from "../format/jpegColor";
import type { EditorImage, Project } from "../format/project";
import { newImageFileId } from "../format/imageIdentity";

export const MEDIA_LIMITS = {
  openFileBytes: 528 * 1024 * 1024,
  imageSourceBytes: 64 * 1024 * 1024,
  audioBytes: 256 * 1024 * 1024,
} as const;

// Safari can navigate to Blob-backed custom/text archives instead of downloading them. A
// generic binary type preserves the exact portable filename across all three browser engines.
export const PORTABLE_FILE_MIME = "application/octet-stream";
export const OGG_OPUS_MIME = 'audio/ogg; codecs="opus"';

export function supportsOggOpus(canPlayType: (mimeType: string) => string): boolean {
  return canPlayType(OGG_OPUS_MIME) !== "";
}

function mebibytes(bytes: number): number {
  return Math.round(bytes / (1024 * 1024));
}

export async function readFileBytes(
  file: File,
  maxBytes = MEDIA_LIMITS.openFileBytes,
  kind = "file",
): Promise<Uint8Array> {
  if (file.size > maxBytes) {
    throw new Error(`That ${kind} is larger than the ${mebibytes(maxBytes)} MB limit.`);
  }
  return new Uint8Array(await file.arrayBuffer());
}

export async function imageToSquareJpeg(
  file: File,
  size = 1024,
): Promise<Uint8Array> {
  return imageToJpeg(file, size, true);
}

/** Keep the whole cover, with its longest edge at most 2048 pixels. */
export async function imageToGalleryJpeg(file: File): Promise<Uint8Array> {
  return imageToJpeg(file, 2048, false);
}

/** File pickers and drops share the same single-image rule. Some systems omit MIME types. */
export function galleryImageFile(files: readonly File[]): File {
  if (files.length !== 1) throw new Error("Choose one image at a time.");
  const file = files[0];
  if (!file.type.startsWith("image/") &&
    !/\.(avif|bmp|gif|heic|heif|ico|jfif|jpe?g|png|svg|tiff?|webp)$/i.test(file.name)) {
    throw new Error("Choose an image file, such as a JPEG or PNG.");
  }
  return file;
}

async function imageToJpeg(file: File, size: number, square: boolean): Promise<Uint8Array> {
  if (file.size > MEDIA_LIMITS.imageSourceBytes) {
    throw new Error(
      `That image is larger than the ${mebibytes(MEDIA_LIMITS.imageSourceBytes)} MB limit.`,
    );
  }
  // Keep browser color management enabled; drawing below converts into SDR sRGB.
  const bitmap = await createImageBitmap(file, { colorSpaceConversion: "default" });
  try {
    const side = Math.min(bitmap.width, bitmap.height);
    if (side < 1) throw new Error("That image has no visible pixels.");
    const width = square ? side : bitmap.width;
    const height = square ? side : bitmap.height;
    const scale = Math.min(1, size / Math.max(width, height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(width * scale));
    canvas.height = Math.max(1, Math.round(height * scale));
    const context = canvas.getContext("2d", {
      alpha: false, colorSpace: "srgb", colorType: "unorm8", toneMapping: { mode: "standard" },
    } as CanvasRenderingContext2DSettings);
    if (!context) throw new Error("Could not read the image.");
    const attributes = context.getContextAttributes?.() as (CanvasRenderingContext2DSettings & {
      colorType?: string; toneMapping?: { mode?: string };
    }) | undefined;
    if (attributes && (attributes.colorSpace !== "srgb" || attributes.colorType && attributes.colorType !== "unorm8" ||
      attributes.toneMapping?.mode && attributes.toneMapping.mode !== "standard")) {
      throw new Error("This browser cannot prepare standard-color artwork.");
    }
    // JPEG has no alpha channel; both upload paths use an opaque white background.
    context.fillStyle = "white";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(
      bitmap,
      (bitmap.width - width) / 2,
      (bitmap.height - height) / 2,
      width,
      height,
      0,
      0,
      canvas.width,
      canvas.height,
    );
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, "image/jpeg", 0.85),
    );
    if (!blob) throw new Error("Could not convert the image.");
    return tagConvertedSrgbJpeg(new Uint8Array(await blob.arrayBuffer()));
  } finally {
    bitmap.close();
  }
}

/** Legacy bytes remain readable; newly emitted packs always receive normalized images. */
export async function prepareProjectArtwork(project: Project): Promise<Project> {
  const prepared = new Map<Uint8Array, Uint8Array>();
  const normalize = async (image: EditorImage): Promise<EditorImage> => {
    if (isSdrSrgbJpeg(image.jpeg)) return image;
    let jpeg = prepared.get(image.jpeg);
    if (!jpeg) {
      jpeg = await imageToJpeg(new File([image.jpeg as BlobPart], image.label, { type: "image/jpeg" }), 2048, false);
      prepared.set(image.jpeg, jpeg);
    }
    // A normalized legacy image must not reuse a globally published filename for
    // different bytes. Its editor uid still addresses the same autosave record.
    return { ...image, jpeg, ...(image.fileId ? { fileId: newImageFileId() } : {}) };
  };
  const images: EditorImage[] = [];
  // Bound simultaneous decoding memory for an imported project with many images.
  for (const image of project.images) images.push(await normalize(image));
  const galleryImage = project.galleryImage ? await normalize(project.galleryImage) : undefined;
  return { ...project, images, galleryImage };
}

/** 95 -> "1:35". */
export function formatTime(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds));
  const m = Math.floor(whole / 60);
  const s = whole % 60;
  const fraction = seconds - whole;
  const base = `${m}:${String(s).padStart(2, "0")}`;
  return fraction > 0 ? `${base}.${String(Math.round(fraction * 10))}` : base;
}

/** "1:35", "1:35.5", or "95" -> seconds; null when unparseable. */
export function parseTime(text: string): number | null {
  const trimmed = text.trim();
  const match = /^(?:(\d+):)?(\d{1,2}(?:\.\d+)?)$/.exec(trimmed);
  if (!match) return null;
  const minutes = match[1] ? parseInt(match[1], 10) : 0;
  const seconds = parseFloat(match[2]);
  if (match[1] && seconds >= 60) return null;
  return minutes * 60 + seconds;
}

export function download(name: string, bytes: Uint8Array, mime: string): void {
  const url = URL.createObjectURL(new Blob([bytes as BlobPart], { type: mime }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = name;
  anchor.hidden = true;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

export function pickFile(accept: string, onPick: (file: File) => void): void {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = accept;
  input.onchange = () => {
    const file = input.files?.[0];
    if (file) onPick(file);
  };
  input.click();
}
