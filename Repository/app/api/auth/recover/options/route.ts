import { createHash } from "node:crypto";
import { generateRegistrationOptions } from "@simplewebauthn/server";
import {
  findLiveRecoveryToken,
  findUserById,
  getPasskeysForUser,
  pruneExpiredChallenges,
  saveChallenge,
} from "@/lib/db";
import { getRpInfo, RP_NAME } from "@/lib/webauthn";
import { transportsFromText } from "@/lib/webauthn-helpers";

export async function POST(request: Request) {
  await pruneExpiredChallenges();
  const body = (await request.json().catch(() => null)) as { token?: string } | null;
  if (!body?.token) return Response.json({ error: "invalid_body" }, { status: 400 });

  const tokenHash = createHash("sha256").update(body.token).digest("base64url");
  const live = await findLiveRecoveryToken(tokenHash);
  const user = live ? await findUserById(live.user_id) : null;
  if (!user) return Response.json({ error: "invalid_token" }, { status: 400 });

  const { rpID } = await getRpInfo();
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
  await saveChallenge({ challenge: options.challenge, kind: "recovery", userId: user.id });
  return Response.json(options);
}
