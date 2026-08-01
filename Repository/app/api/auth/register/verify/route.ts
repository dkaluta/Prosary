import { verifyRegistrationResponse } from "@simplewebauthn/server";
import type { RegistrationResponseJSON } from "@simplewebauthn/server";
import { getCurrentUser, setSession } from "@/lib/auth";
import { createUser, insertPasskey, takeChallenge } from "@/lib/db";
import { getRpInfo } from "@/lib/webauthn";
import { extractChallenge, publicKeyToText, transportsToText } from "@/lib/webauthn-helpers";

type Body = { mode: "signup" | "add"; response: RegistrationResponseJSON };

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as Body | null;
  if (!body?.response || (body.mode !== "signup" && body.mode !== "add")) {
    return Response.json({ error: "invalid_body" }, { status: 400 });
  }

  const challenge = extractChallenge(body.response.response.clientDataJSON);
  if (!challenge) return Response.json({ error: "missing_challenge" }, { status: 400 });
  const pending = await takeChallenge(challenge, body.mode);
  if (!pending) return Response.json({ error: "unknown_challenge" }, { status: 400 });

  if (body.mode === "add") {
    const user = await getCurrentUser();
    if (!user || user.id !== pending.user_id) {
      return Response.json({ error: "unauthorized" }, { status: 401 });
    }
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
  if (body.mode === "signup") {
    if (!pending.user_id || !pending.username || !pending.email) {
      return Response.json({ error: "unknown_challenge" }, { status: 400 });
    }
    await createUser({ id: pending.user_id, username: pending.username, email: pending.email });
  }
  await insertPasskey({
    credentialId: credential.id,
    userId: pending.user_id!,
    publicKey: publicKeyToText(credential.publicKey),
    counter: credential.counter,
    transports: transportsToText(credential.transports),
  });
  await setSession(pending.user_id!);
  return Response.json({ ok: true });
}
