import { rateLimited } from "@/lib/limits";
import { generateRegistrationOptions } from "@simplewebauthn/server";
import { getCurrentUser } from "@/lib/auth";
import {
  findUserByEmail,
  findUserByUsername,
  getPasskeysForUser,
  newId,
  normalizeUsername,
  pruneExpiredChallenges,
  saveChallenge,
} from "@/lib/db";
import { getRpInfo, RP_NAME } from "@/lib/webauthn";
import { transportsFromText } from "@/lib/webauthn-helpers";

type Body = { mode: "signup"; username?: string; email?: string } | { mode: "add" };

export async function POST(request: Request) {
  const limited = await rateLimited(request, "register-options", 10, 3600);
  if (limited) return limited;

  await pruneExpiredChallenges();
  const body = (await request.json().catch(() => null)) as Body | null;
  if (!body || (body.mode !== "signup" && body.mode !== "add")) {
    return Response.json({ error: "invalid_body" }, { status: 400 });
  }

  const { rpID } = await getRpInfo();

  if (body.mode === "signup") {
    const username = normalizeUsername(body.username ?? "");
    const email = (body.email ?? "").trim().toLowerCase();
    if (!username) {
      return Response.json({ error: "invalid_username" }, { status: 400 });
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return Response.json({ error: "invalid_email" }, { status: 400 });
    }
    if (await findUserByUsername(username)) {
      return Response.json({ error: "username_taken" }, { status: 409 });
    }
    if (await findUserByEmail(email)) {
      return Response.json({ error: "email_taken" }, { status: 409 });
    }

    // Reserve the id up front so the WebAuthn user handle matches the eventual row.
    const userId = newId();
    const options = await generateRegistrationOptions({
      rpName: RP_NAME,
      rpID,
      userName: username,
      userID: new TextEncoder().encode(userId),
      attestationType: "none",
      authenticatorSelection: { residentKey: "preferred", userVerification: "preferred" },
    });
    await saveChallenge({ challenge: options.challenge, kind: "signup", userId, username, email });
    return Response.json(options);
  }

  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });
  const existing = await getPasskeysForUser(user.id);
  const options = await generateRegistrationOptions({
    rpName: RP_NAME,
    rpID,
    userName: user.username,
    userID: new TextEncoder().encode(user.id),
    attestationType: "none",
    excludeCredentials: existing.map((p) => ({
      id: p.credential_id,
      transports: transportsFromText(p.transports),
    })),
    authenticatorSelection: { residentKey: "preferred", userVerification: "preferred" },
  });
  await saveChallenge({ challenge: options.challenge, kind: "add", userId: user.id });
  return Response.json(options);
}
