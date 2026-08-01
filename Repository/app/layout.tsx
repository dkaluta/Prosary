import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";
import { AccountLink } from "@/components/AccountLink";

export const metadata: Metadata = {
  title: "Prosary Prayers",
  description:
    "Devotions shared by the Prosary community — download a .prosaryprayer bundle and import it from the app's Favorites screen.",
  icons: { icon: "/favicon.svg" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <header className="top">
          <h1>
            <Link href="/">Prosary Prayers</Link>
          </h1>
          <nav>
            <Link href="/">Browse</Link>
            <Link href="/submit">Submit</Link>
            <AccountLink />
          </nav>
        </header>
        {children}
      </body>
    </html>
  );
}
