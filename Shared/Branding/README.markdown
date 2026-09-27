# App color resources

`app-colors.json` is the canonical seven-color palette. `cross-template.png` preserves the
existing Prosary cross silhouette from the original Icon Composer document;
`android-cross-template.png` retains its existing adaptive-icon placement. The change is
color only. Blue is the default for Mary; white has a gold cross. Light/dark accent pairs
keep controls readable, while the icon colors do not change with dark mode.

Install the existing website dependencies, then regenerate:

```sh
npm ci --prefix Shared/website
node Shared/tools/build-app-icons.mjs
node Shared/tools/sync-web-branding.mjs
```

Use `node Shared/tools/build-app-icons.mjs --check` to verify deterministic output.
The generator writes seven native Apple Icon Composer packages, flattened previews for Mac
Dock/settings, Android launcher resources, Windows `.ico` and package logos, and the default
blue marketing icon. Android adaptive-icon XML and native settings/code are maintained by
their respective ports. All palette ids are persisted as `appColor`.

The iPhone app uses the `.icon` documents themselves, not flattened alternate app icons.
Both document and cross layer specify identical Default/Dark solid fills. A sibling `fill`
must not be added: Icon Composer gives it precedence over `fill-specializations`. Apple’s
`ictool` Default and Dark exports are compared byte-for-byte during icon verification.
System monochrome/tinted icon preferences remain owned by the OS.

Android’s `useSystemColors` defaults to true and lets Material You take precedence over the
manual accent on Android 12+. The chosen launcher icon still follows `appColor`.
