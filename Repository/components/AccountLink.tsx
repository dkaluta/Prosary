import { getCurrentUser } from "@/lib/auth";
import { RouteAwareLink } from "@/components/RouteAwareLink";

export async function AccountLink() {
  let username: string | null = null;
  try {
    username = (await getCurrentUser())?.username ?? null;
  } catch {
    // Navigation remains useful while account storage is unavailable.
  }

  return (
    <RouteAwareLink href="/account" aria-label={username ? `Account for ${username}` : undefined}>
      {username ? `@${username}` : "Account"}
    </RouteAwareLink>
  );
}
