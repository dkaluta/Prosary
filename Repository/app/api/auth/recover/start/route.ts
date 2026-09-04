import { rateLimited } from "@/lib/limits";
import { createHash } from "node:crypto";
import { findUserByEmail, findUserByUsername, newRecoveryToken, saveRecoveryToken } from "@/lib/db";
import { getAppOrigin, sendRecoveryEmail } from "@/lib/email";

// Always answers ok — whether the account exists is not disclosed.
export async function POST(request: Request) {
  const limited = await rateLimited(request, "recover-start", 5, 3600);
  if (limited) return limited;

  const body = (await request.json().catch(() => null)) as { identifier?: string } | null;
  const identifier = (body?.identifier ?? "").trim().toLowerCase();
  if (!identifier) return Response.json({ error: "invalid_body" }, { status: 400 });

  const user = identifier.includes("@")
    ? await findUserByEmail(identifier)
    : await findUserByUsername(identifier);
  if (user) {
    const token = newRecoveryToken();
    const [, origin] = await Promise.all([
      saveRecoveryToken(createHash("sha256").update(token).digest("base64url"), user.id),
      getAppOrigin(),
    ]);
    await sendRecoveryEmail(user.email, user.username, `${origin}/recover/${token}`);
  }
  return Response.json({ ok: true });
}
