// Update availability only after the corresponding public release has been verified.
// The assigned Store beta link is pending certification; GitHub remains the available download.
export const downloads = {
  apple: {
    href: "https://testflight.apple.com/join/RJPs8DWS",
    note: "Join through TestFlight. The latest builds are awaiting Apple’s external beta review.",
  },
  android: {
    href: "https://play.google.com/store/apps/details?id=com.dkaluta.prosary",
    invitation: "https://docs.google.com/forms/d/e/1FAIpQLSe2pFPBmjBL6SOxjh7zktRDzEraxdfNUR-L6vuiPuy-sOunPw/viewform?usp=sharing&ouid=107334041819347937443",
    note: "Available to invited testers on Google Play. Request access first if you haven’t joined the closed test.",
  },
  windows: {
    version: "0.20.4",
    href: "https://github.com/dkaluta/Prosary/releases/tag/v0.20.4",
    instructions: "https://github.com/dkaluta/Prosary/releases/download/v0.20.4/Windows-README.markdown",
    note: "Signed installers for ARM64 and x64. First-time setup uses the supplied public testing certificate; follow the installation guide.",
    store: {
      href: "https://apps.microsoft.com/detail/9NKBBRQX0JST",
      status: "Certification pending",
      note: "Awaiting Microsoft Store certification. You can download the signed GitHub beta now.",
    },
  },
} as const;
