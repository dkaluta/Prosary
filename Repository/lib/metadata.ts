import type { Metadata } from "next";

export const REPOSITORY_DESCRIPTION =
  "Devotions shared by the Prosary community — browse and install them in the Prosary app, or download a .prosaryprayer bundle directly.";

const SOCIAL_IMAGE = {
  url: "/prosary-social.png",
  width: 1024,
  height: 1024,
  alt: "Prosary's white rosary cross on a green app icon",
} as const;

function socialTitle(title: string): string {
  return title === "Prosary Prayers" ? title : `${title} · Prosary`;
}

export function publicPageMetadata({
  title,
  path,
  description = REPOSITORY_DESCRIPTION,
}: {
  title: string;
  path: string;
  description?: string;
}): Metadata {
  const brandedTitle = socialTitle(title);
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      type: "website",
      url: path,
      siteName: "Prosary",
      title: brandedTitle,
      description,
      images: [SOCIAL_IMAGE],
    },
    twitter: {
      card: "summary",
      title: brandedTitle,
      description,
      images: [SOCIAL_IMAGE],
    },
  };
}

export function privatePageMetadata({
  title,
  description,
}: {
  title: string;
  description: string;
}): Metadata {
  return {
    title,
    description,
    robots: { index: false, follow: false },
    alternates: null,
    openGraph: null,
    twitter: null,
  };
}
