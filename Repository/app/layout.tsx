import type { Metadata, Viewport } from "next";
import Link from "next/link";
import { Suspense } from "react";
import "./globals.css";
import { AccountLink } from "@/components/AccountLink";

export const metadata: Metadata = {
  metadataBase: new URL("https://prayers.prosary.app"),
  title: {
    default: "Prosary Prayers",
    template: "%s · Prosary Prayers",
  },
  description:
    "Devotions shared by the Prosary community — browse and install them in the Prosary app, or download a .prosaryprayer bundle directly.",
  icons: { icon: "/favicon.svg" },
};

export const viewport: Viewport = {
  colorScheme: "light dark",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#fffafc" },
    { media: "(prefers-color-scheme: dark)", color: "#171215" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <a className="skip-link" href="#main-content">
          Skip to main content
        </a>
        <header className="top">
          <div className="top-inner">
            <Link className="brand" href="/" aria-label="Prosary Prayers home">
              <img src="/favicon.svg" width="28" height="28" alt="" aria-hidden="true" />
              <span>Prosary Prayers</span>
            </Link>
            <nav aria-label="Primary navigation">
              <Link href="/">Browse</Link>
              <a href="https://compose.prosary.app">Compose</a>
              <Link href="/submit">Submit</Link>
              <Suspense fallback={<Link href="/account">Account</Link>}>
                <AccountLink />
              </Suspense>
            </nav>
          </div>
        </header>
        {children}
        <footer className="site-footer">
          <p>
            Community-made devotions for the native Prosary apps.{" "}
            <a href="https://prosary.app">About Prosary</a>
            <span aria-hidden="true"> · </span>
            <a href="/index.json">Repository index</a>
          </p>
        </footer>
      </body>
    </html>
  );
}
