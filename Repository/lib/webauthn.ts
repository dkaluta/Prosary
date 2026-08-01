import { headers } from "next/headers";

// The relying party name is what password managers display alongside the
// saved passkey.
export const RP_NAME = "Prosary Prayers";

// Resolve the RP ID and origin from the incoming request (freebee's pattern)
// so dev works on localhost/LAN with zero configuration. `origins` is what
// verify routes pass as expectedOrigin; native-app origins (android
// apk-key-hash) would join via WEBAUTHN_NATIVE_ORIGINS if apps ever sign in.
export async function getRpInfo(): Promise<{
  rpID: string;
  origin: string;
  origins: string[];
}> {
  const h = await headers();
  const host = h.get("host") ?? "localhost:3000";
  const proto =
    h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  const hostname = host.split(":")[0];
  const origin = `${proto}://${host}`;
  const native = (process.env.WEBAUTHN_NATIVE_ORIGINS ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return { rpID: hostname, origin, origins: [origin, ...native] };
}
