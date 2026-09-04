import type { Metadata } from "next";
import {
  AccountPanel,
  type AccountBundleInfo,
  type PasskeyInfo,
} from "@/components/AccountPanel";
import { AuthForms } from "@/components/AuthForms";
import { PageHeader } from "@/components/PageHeader";
import { StatusMessage } from "@/components/StatusMessage";
import { getCurrentUser } from "@/lib/auth";
import { getPasskeysForUser, listBundlesByUsername } from "@/lib/db";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Account",
  robots: { index: false, follow: false },
};

export default async function AccountPage() {
  let user: Awaited<ReturnType<typeof getCurrentUser>> = null;
  let passkeys: PasskeyInfo[] = [];
  let ownBundles: AccountBundleInfo[] = [];
  let offline = false;

  try {
    user = await getCurrentUser();
    if (user) {
      const [passkeyRows, bundleRows] = await Promise.all([
        getPasskeysForUser(user.id),
        listBundlesByUsername(user.username),
      ]);
      passkeys = passkeyRows.map((passkey) => ({
        credentialId: passkey.credential_id,
        name: passkey.name,
        createdAt: String(passkey.created_at),
      }));
      ownBundles = bundleRows.map((bundle) => ({
        id: bundle.id,
        name: bundle.name,
        description: bundle.description,
        tags: bundle.tags,
      }));
    }
  } catch {
    offline = true;
  }

  return (
    <main id="main-content" tabIndex={-1}>
      <PageHeader eyebrow="Private account" title={user ? `Welcome, ${user.username}` : "Your account"}>
        <p>
          Sign in without a password, manage your passkeys, and care for the devotions you
          have shared.
        </p>
      </PageHeader>
      {offline ? (
        <StatusMessage tone="error">
          Accounts are unavailable right now — try again shortly.
        </StatusMessage>
      ) : user ? (
        <AccountPanel username={user.username} passkeys={passkeys} bundles={ownBundles} />
      ) : (
        <AuthForms />
      )}
    </main>
  );
}
