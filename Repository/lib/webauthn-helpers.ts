// Small shared pieces for the WebAuthn routes.

export function extractChallenge(clientDataJSON: string): string | null {
  try {
    const decoded = JSON.parse(Buffer.from(clientDataJSON, "base64url").toString("utf-8"));
    return typeof decoded.challenge === "string" ? decoded.challenge : null;
  } catch {
    return null;
  }
}

export function publicKeyToText(publicKey: Uint8Array): string {
  return Buffer.from(publicKey).toString("base64url");
}

export function publicKeyFromText(text: string): Uint8Array<ArrayBuffer> {
  const decoded = Buffer.from(text, "base64url");
  // Copy into a fresh ArrayBuffer-backed view — @simplewebauthn's types require
  // Uint8Array<ArrayBuffer>, and Buffer's backing store is ArrayBufferLike.
  const out = new Uint8Array(new ArrayBuffer(decoded.length));
  out.set(decoded);
  return out;
}

export function transportsToText(transports: string[] | undefined): string | null {
  return transports && transports.length > 0 ? transports.join(",") : null;
}

export function transportsFromText(text: string | null): AuthenticatorTransport[] | undefined {
  return text ? (text.split(",") as AuthenticatorTransport[]) : undefined;
}

type AuthenticatorTransport = "ble" | "cable" | "hybrid" | "internal" | "nfc" | "smart-card" | "usb";
