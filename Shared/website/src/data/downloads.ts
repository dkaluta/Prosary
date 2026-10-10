// Update availability only after the corresponding public release has been verified.
export const androidBetaEmail = "prosary@dkaluta.com";

export function androidBetaInvitationMailto(account = "[your Google account email]"): string {
  const body = [
    "Hello,", "",
    "I would like to join the Prosary Android closed beta.",
    `The Google account I use on my phone is ${account}.`, "",
    "Thank you!",
  ].join("\r\n");
  return `mailto:${androidBetaEmail}?subject=${encodeURIComponent("Prosary Android closed beta")}&body=${encodeURIComponent(body)}`;
}

export const downloads = {
  apple: {
    href: "https://testflight.apple.com/join/RJPs8DWS",
    note: "Join through TestFlight. The latest builds are awaiting Apple’s external beta review.",
  },
  android: {
    href: "https://play.google.com/store/apps/details?id=com.dkaluta.prosary",
    invitation: androidBetaInvitationMailto(),
    note: "Request an invitation by email. Once you’re added to the closed beta, install Prosary through Google Play.",
  },
  windows: {
    href: "https://apps.microsoft.com/detail/9NKBBRQX0JST",
    standalone: "https://github.com/dkaluta/Prosary/releases/tag/v0.20.4",
    note: "Join the Windows beta through Microsoft Store.",
  },
} as const;
