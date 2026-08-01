import { getCurrentUser, slideSessionIfNeeded } from "@/lib/auth";
import { getPasskeysForUser, listBundles } from "@/lib/db";
import { AccountPanel } from "@/components/AccountPanel";
import { AuthForms } from "@/components/AuthForms";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  let user = null;
  let passkeyCount = 0;
  let ownBundles: { id: string; name: string }[] = [];
  try {
    await slideSessionIfNeeded();
    user = await getCurrentUser();
    if (user) {
      passkeyCount = (await getPasskeysForUser(user.id)).length;
      ownBundles = (await listBundles({}))
        .filter((b) => b.author === user!.username)
        .map((b) => ({ id: b.id, name: b.name }));
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
        <AccountPanel username={user.username} passkeyCount={passkeyCount} bundles={ownBundles} />
      ) : (
        <AuthForms />
      )}
    </main>
  );
}
