// Email transport — Brevo when BREVO_API_KEY is set (free tier allows multiple
// sender domains, unlike Resend's single-domain limit), else Resend when
// RESEND_API_KEY is set, else stdout logging so dev works without any external
// service (freebee's pattern). Email exists in this app for exactly one
// purpose: account recovery.

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

function parseFromAddress(): { name: string; email: string } {
  const match = /^(.*)<([^>]+)>\s*$/.exec(FROM_ADDRESS);
  return match
    ? { name: match[1].trim(), email: match[2].trim() }
    : { name: "Prosary Prayers", email: FROM_ADDRESS };
}

async function deliver(message: { to: string; subject: string; text: string }): Promise<void> {
  const brevoKey = process.env.BREVO_API_KEY;
  if (brevoKey) {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: { "api-key": brevoKey, "Content-Type": "application/json" },
      body: JSON.stringify({
        sender: parseFromAddress(),
        to: [{ email: message.to }],
        subject: message.subject,
        textContent: message.text,
      }),
    });
    if (!response.ok) {
      throw new Error(`Brevo failed: ${response.status} ${await response.text()}`);
    }
    return;
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (!resendKey) {
    console.log(`[email:dev] To: ${message.to}\nSubject: ${message.subject}\n\n${message.text}`);
    return;
  }
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
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
