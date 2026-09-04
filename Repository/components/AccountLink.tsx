import Link from "next/link";
import { getCurrentUser } from "@/lib/auth";

export async function AccountLink() {
  let username: string | null = null;
  try {
    username = (await getCurrentUser())?.username ?? null;
  } catch {
    // Navigation remains useful while account storage is unavailable.
  }

  return (
    <Link href="/account" aria-label={username ? `Account for ${username}` : undefined}>
      {username ? `@${username}` : "Account"}
    </Link>
  );
}
