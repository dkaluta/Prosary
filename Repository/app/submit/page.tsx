import Link from "next/link";
import { getCurrentUser } from "@/lib/auth";
import { SubmitForm } from "@/components/SubmitForm";

export const dynamic = "force-dynamic";

export default async function SubmitPage() {
  let user = null;
  try {
    user = await getCurrentUser();
  } catch {
    // DB offline — fall through to the signed-out message.
  }
  return (
    <main>
      {user ? (
        <SubmitForm username={user.username} />
      ) : (
        <div className="card">
          <h2>Submit a devotion</h2>
          <p className="hint">
            <Link href="/account">Sign in</Link> first — bundles publish under your username
            (repo.&lt;username&gt;.…).
          </p>
        </div>
      )}
    </main>
  );
}
