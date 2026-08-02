import { getCurrentUser, slideSessionIfNeeded } from "@/lib/auth";
import { getPasskeysForUser, listBundlesByUsername } from "@/lib/db";
import { AccountPanel } from "@/components/AccountPanel";
import { AuthForms } from "@/components/AuthForms";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  let user = null;
  let passkeys: { credentialId: string; name: string | null; createdAt: string }[] = [];
  let ownBundles: { id: string; name: string; description: string; tags: string[] }[] = [];
  try {
    await slideSessionIfNeeded();
    user = await getCurrentUser();
    if (user) {
      passkeys = (await getPasskeysForUser(user.id)).map((p) => ({
        credentialId: p.credential_id,
        name: p.name,
        createdAt: String(p.created_at),
      }));
      ownBundles = (await listBundlesByUsername(user.username)).map((b) => ({
        id: b.id,
        name: b.name,
        description: b.description,
        tags: b.tags,
      }));
    }
  } catch {
    return (
      <main>
        <p className="error">Accounts are unavailable right now — try again shortly.</p>
      </main>
    );
  }

  return (
    <main>
      {user ? (
        <AccountPanel username={user.username} passkeys={passkeys} bundles={ownBundles} />
      ) : (
        <AuthForms />
      )}
    </main>
  );
}
