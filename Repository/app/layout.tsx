import type { Metadata, Viewport } from "next";
import Link from "next/link";
import { Suspense } from "react";
import "./globals.css";
import { AccountLink } from "@/components/AccountLink";
import { RouteAwareLink } from "@/components/RouteAwareLink";

export const metadata: Metadata = {
  metadataBase: new URL("https://prayers.prosary.app"),
  applicationName: "Prosary Prayers",
  title: {
    default: "Prosary Prayers",
    template: "%s · Prosary",
  },
  description:
    "Devotions shared by the Prosary community — browse and install them in the Prosary app, or download a .prosaryprayer bundle directly.",
  openGraph: {
    type: "website",
    url: "/",
    siteName: "Prosary",
    title: "Prosary Prayers",
    description:
      "Devotions shared by the Prosary community — browse and install them in the Prosary app, or download a .prosaryprayer bundle directly.",
    images: [
      {
        url: "/prosary-social.png",
        width: 1024,
        height: 1024,
        alt: "Prosary's white rosary cross on a green app icon",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "Prosary Prayers",
    description:
      "Devotions shared by the Prosary community — browse and install them in the Prosary app, or download a .prosaryprayer bundle directly.",
    images: [
      {
        url: "/prosary-social.png",
        alt: "Prosary's white rosary cross on a green app icon",
      },
    ],
  },
  icons: {
    icon: [
      { url: "/favicon.ico" },
      { url: "/favicon-32x32.png", type: "image/png", sizes: "32x32" },
    ],
    apple: [{ url: "/apple-touch-icon.png", type: "image/png", sizes: "180x180" }],
    shortcut: "/favicon.ico",
  },
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
              <img src="/prosary-icon.png" width="36" height="36" alt="" aria-hidden="true" />
              <span className="brand-lockup">
                <span className="brand-name">Prosary</span>
                <span className="brand-context">Prayers</span>
              </span>
            </Link>
            <nav aria-label="Primary navigation">
              <ul>
                <li>
                  <RouteAwareLink href="/">Browse</RouteAwareLink>
                </li>
                <li>
                  <a href="https://compose.prosary.app">Compose</a>
                </li>
                <li>
                  <RouteAwareLink href="/submit" currentFor={["/submit", "/publish"]}>Submit</RouteAwareLink>
                </li>
                <li>
                  <Suspense fallback={<RouteAwareLink href="/account">Account</RouteAwareLink>}>
                    <AccountLink />
                  </Suspense>
                </li>
              </ul>
            </nav>
          </div>
        </header>
        {children}
        <footer className="site-footer">
          <div className="site-footer-inner">
            <div className="footer-identity">
              <img src="/prosary-icon.png" width="28" height="28" alt="" aria-hidden="true" />
              <p>
                <strong>Prosary Prayers</strong>
                <span>Community devotions for every native Prosary app.</span>
              </p>
            </div>
            <nav aria-label="Footer navigation">
              <a href="https://prosary.app">About Prosary</a>
              <a href="https://compose.prosary.app">Compose a devotion</a>
              <a href="/index.json">Repository index</a>
            </nav>
          </div>
        </footer>
      </body>
    </html>
  );
}
