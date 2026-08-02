import { rateLimited } from "@/lib/limits";
import { verifyAuthenticationResponse } from "@simplewebauthn/server";
import type { AuthenticationResponseJSON } from "@simplewebauthn/server";
import { setSession } from "@/lib/auth";
import { findPasskey, takeChallenge, updatePasskeyCounter } from "@/lib/db";
import { getRpInfo } from "@/lib/webauthn";
import { extractChallenge, publicKeyFromText, transportsFromText } from "@/lib/webauthn-helpers";

export async function POST(request: Request) {
  const limited = await rateLimited(request, "login-verify", 30, 600);
  if (limited) return limited;

  const body = (await request.json().catch(() => null)) as
    | { response?: AuthenticationResponseJSON }
    | null;
  if (!body?.response) return Response.json({ error: "invalid_body" }, { status: 400 });

  const challenge = extractChallenge(body.response.response.clientDataJSON);
  if (!challenge) return Response.json({ error: "missing_challenge" }, { status: 400 });
  const pending = await takeChallenge(challenge, "login");
  if (!pending) return Response.json({ error: "unknown_challenge" }, { status: 400 });

  const passkey = await findPasskey(body.response.id);
  if (!passkey || passkey.user_id !== pending.user_id) {
    return Response.json({ error: "unknown_credential" }, { status: 400 });
  }

  const { rpID, origins } = await getRpInfo();
  let verification;
  try {
    verification = await verifyAuthenticationResponse({
      response: body.response,
      expectedChallenge: challenge,
      expectedOrigin: origins,
      expectedRPID: rpID,
      requireUserVerification: false,
      credential: {
        id: passkey.credential_id,
        publicKey: publicKeyFromText(passkey.public_key),
        counter: Number(passkey.counter),
        transports: transportsFromText(passkey.transports),
      },
    });
  } catch (err) {
    return Response.json({ error: "verification_failed", detail: String(err) }, { status: 400 });
  }
  if (!verification.verified) return Response.json({ error: "not_verified" }, { status: 400 });

  await updatePasskeyCounter(passkey.credential_id, verification.authenticationInfo.newCounter);
  await setSession(passkey.user_id);
  return Response.json({ ok: true });
}
