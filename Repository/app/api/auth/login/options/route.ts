import { generateAuthenticationOptions } from "@simplewebauthn/server";
import {
  findUserByUsername,
  getPasskeysForUser,
  normalizeUsername,
  pruneExpiredChallenges,
  saveChallenge,
} from "@/lib/db";
import { getRpInfo } from "@/lib/webauthn";
import { transportsFromText } from "@/lib/webauthn-helpers";

export async function POST(request: Request) {
  await pruneExpiredChallenges();
  const body = (await request.json().catch(() => null)) as { username?: string } | null;
  const username = normalizeUsername(body?.username ?? "");
  if (!username) return Response.json({ error: "invalid_username" }, { status: 400 });

  const user = await findUserByUsername(username);
  const passkeys = user ? await getPasskeysForUser(user.id) : [];
  if (!user || passkeys.length === 0) {
    return Response.json({ error: "unknown_user" }, { status: 404 });
  }

  const { rpID } = await getRpInfo();
  const options = await generateAuthenticationOptions({
    rpID,
    userVerification: "preferred",
    allowCredentials: passkeys.map((p) => ({
      id: p.credential_id,
      transports: transportsFromText(p.transports),
    })),
  });
  await saveChallenge({ challenge: options.challenge, kind: "login", userId: user.id });
  return Response.json(options);
}
