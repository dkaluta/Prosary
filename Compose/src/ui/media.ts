// Browser-side media helpers: file reading, the square-crop rule for bundle artwork
// (Shared/Images files are exact 1:1 squares — uploads are center-cropped to match and
// re-encoded as JPEG), chapter time parsing, and blob downloads.

export async function readFileBytes(file: File): Promise<Uint8Array> {
  return new Uint8Array(await file.arrayBuffer());
}

export async function imageToSquareJpeg(
  file: File,
  size = 1024,
): Promise<{ jpeg: Uint8Array; dataUrl: string }> {
  const bitmap = await createImageBitmap(file);
  const side = Math.min(bitmap.width, bitmap.height);
  const target = Math.min(side, size);
  const canvas = document.createElement("canvas");
  canvas.width = target;
  canvas.height = target;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("Could not read the image.");
  context.drawImage(
    bitmap,
    (bitmap.width - side) / 2,
    (bitmap.height - side) / 2,
    side,
    side,
    0,
    0,
    target,
    target,
  );
  bitmap.close();
  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(resolve, "image/jpeg", 0.85),
  );
  if (!blob) throw new Error("Could not convert the image.");
  const jpeg = new Uint8Array(await blob.arrayBuffer());
  return { jpeg, dataUrl: canvas.toDataURL("image/jpeg", 0.85) };
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
  anchor.click();
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
