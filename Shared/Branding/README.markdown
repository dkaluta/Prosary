# App color resources

`app-colors.json` is the canonical seven-color palette. `cross-template.png` preserves the
existing Prosary cross silhouette from the original Icon Composer document;
`android-cross-template.png` retains its existing adaptive-icon placement. The change is
color only. Blue is the default for Mary; white has a gold cross. Light/dark accent pairs
keep controls readable. Every Apple color choice preserves the original dark icon.

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
The document specializes the Default background to the selected color and Dark to
`system-dark`, retaining the original cross layer's automatic fill. White specializes its
cross image to gold only for Light. Do not add a sibling `fill` to the document or
`image-name` to the white cross: Icon Composer gives them precedence over their
specializations. Apple’s `ictool` Dark exports are compared byte-for-byte against the
original dark icon on iOS and macOS during verification.
System monochrome/tinted icon preferences remain owned by the OS.

`apple-original-icon.json` retains the original Icon Composer document alongside the
unchanged cross template. On a Mac with Xcode selected, verify every generated Dark
rendition against this baseline:

```sh
uv run --script Shared/tools/verify-apple-dark-icons.py
```

Android’s `useSystemColors` defaults to true and lets Material You take precedence over the
manual accent on Android 12+. The chosen launcher icon still follows `appColor`.
