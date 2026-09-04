import { useEffect, useState } from "react";

/** A short-lived browser URL for binary previews. Keeping this derived value out of Project
 * avoids a second base64 copy of every upload and guarantees the browser allocation is revoked. */
export function useObjectUrl(bytes: Uint8Array | null, mimeType: string): string | undefined {
  const [url, setUrl] = useState<string>();

  useEffect(() => {
    if (!bytes) {
      setUrl(undefined);
      return;
    }
    const next = URL.createObjectURL(new Blob([bytes as BlobPart], { type: mimeType }));
    setUrl(next);
    return () => URL.revokeObjectURL(next);
  }, [bytes, mimeType]);

  return url;
}
