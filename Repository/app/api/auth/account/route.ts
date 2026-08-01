import { del } from "@vercel/blob";
import { clearSession, getCurrentUser } from "@/lib/auth";
import { bundleFileUrlsForUser, deleteUser } from "@/lib/db";

// Self-serve account deletion (the privacy policy's promise): removes the user's bundle
// files from Blob (best-effort), then the user row — passkeys, recovery tokens, and bundle
// rows follow via ON DELETE CASCADE — and ends the session. Irreversible by design; the
// client is responsible for making the user very sure first.
export async function DELETE() {
  const user = await getCurrentUser();
  if (!user) return Response.json({ error: "unauthorized" }, { status: 401 });

  for (const fileUrl of await bundleFileUrlsForUser(user.id)) {
    await del(fileUrl).catch(() => {});
  }
  await deleteUser(user.id);
  await clearSession();
  return Response.json({ ok: true });
}
