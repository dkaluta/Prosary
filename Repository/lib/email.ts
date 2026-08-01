// Email transport — Resend when RESEND_API_KEY is set, stdout logging
// otherwise so dev works without any external service (freebee's pattern).
// Email exists in this app for exactly one purpose: account recovery.

import { headers } from "next/headers";

const FROM_ADDRESS = process.env.EMAIL_FROM ?? "Prosary Prayers <noreply@prosary.app>";

export async function getAppOrigin(): Promise<string> {
  if (process.env.APP_ORIGIN) return process.env.APP_ORIGIN;
  const h = await headers();
  const host = h.get("host") ?? "localhost:3000";
  const proto =
    h.get("x-forwarded-proto") ?? (host.startsWith("localhost") ? "http" : "https");
  return `${proto}://${host}`;
}

async function deliver(message: { to: string; subject: string; text: string }): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.log(`[email:dev] To: ${message.to}\nSubject: ${message.subject}\n\n${message.text}`);
    return;
  }
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: FROM_ADDRESS,
      to: message.to,
      subject: message.subject,
      text: message.text,
    }),
  });
  if (!response.ok) {
    throw new Error(`Resend failed: ${response.status} ${await response.text()}`);
  }
}

export async function sendRecoveryEmail(to: string, username: string, link: string): Promise<void> {
  await deliver({
    to,
    subject: "Recover your Prosary Prayers account",
    text:
      `Someone (hopefully you) asked to recover the Prosary Prayers account “${username}”.\n\n` +
      `Open this link to add a new passkey to your account:\n\n${link}\n\n` +
      `The link works once and expires in 30 minutes. If you didn't ask for this, ignore this email — nothing changes without the link.`,
  });
}
