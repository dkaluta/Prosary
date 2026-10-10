// Update availability only after the corresponding public release has been verified.
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
    href: "https://apps.microsoft.com/detail/9NKBBRQX0JST",
    standalone: "https://github.com/dkaluta/Prosary/releases/tag/v0.20.4",
    note: "Join the Windows beta through Microsoft Store.",
  },
} as const;
