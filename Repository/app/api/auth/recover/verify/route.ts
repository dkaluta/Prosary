import { createHash } from "node:crypto";
import { verifyRegistrationResponse } from "@simplewebauthn/server";
import type { RegistrationResponseJSON } from "@simplewebauthn/server";
import { setSession } from "@/lib/auth";
import { consumeRecoveryToken, findLiveRecoveryToken, insertPasskey, takeChallenge } from "@/lib/db";
import { getRpInfo } from "@/lib/webauthn";
import { extractChallenge, publicKeyToText, transportsToText } from "@/lib/webauthn-helpers";

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as
    | { token?: string; response?: RegistrationResponseJSON }
    | null;
  if (!body?.token || !body.response) {
    return Response.json({ error: "invalid_body" }, { status: 400 });
  }

  const tokenHash = createHash("sha256").update(body.token).digest("base64url");
  const live = await findLiveRecoveryToken(tokenHash);
  if (!live) return Response.json({ error: "invalid_token" }, { status: 400 });

  const challenge = extractChallenge(body.response.response.clientDataJSON);
  if (!challenge) return Response.json({ error: "missing_challenge" }, { status: 400 });
  const pending = await takeChallenge(challenge, "recovery");
  if (!pending || pending.user_id !== live.user_id) {
    return Response.json({ error: "unknown_challenge" }, { status: 400 });
  }

  const { rpID, origins } = await getRpInfo();
  let verification;
  try {
    verification = await verifyRegistrationResponse({
      response: body.response,
      expectedChallenge: challenge,
      expectedOrigin: origins,
      expectedRPID: rpID,
      requireUserVerification: false,
    });
  } catch (err) {
    return Response.json({ error: "verification_failed", detail: String(err) }, { status: 400 });
  }
  if (!verification.verified || !verification.registrationInfo) {
    return Response.json({ error: "not_verified" }, { status: 400 });
  }

  const { credential } = verification.registrationInfo;
  await insertPasskey({
    credentialId: credential.id,
    userId: live.user_id,
    publicKey: publicKeyToText(credential.publicKey),
    counter: credential.counter,
    transports: transportsToText(credential.transports),
  });
  await consumeRecoveryToken(tokenHash);
  await setSession(live.user_id);
  return Response.json({ ok: true });
}
