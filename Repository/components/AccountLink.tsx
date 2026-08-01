"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

export function AccountLink() {
  const [username, setUsername] = useState<string | null>(null);
  useEffect(() => {
    fetch("/api/auth/me")
      .then((r) => r.json())
      .then((d) => setUsername(d.username))
      .catch(() => {});
  }, []);
  return <Link href="/account">{username ?? "Account"}</Link>;
}
