# App color resources

`app-colors.json` is the canonical seven-color palette. `cross-template.png` preserves the
existing Prosary cross silhouette from the original Icon Composer document;
`android-cross-template.png` retains its existing adaptive-icon placement. The change is
color only. Blue is the default for Mary; white has a gold cross. Light/dark accent pairs
keep controls readable. Every Apple color choice preserves the original dark icon.
The small web mark regenerates from that same default blue icon; web tokens use the matching
Marian blue light/dark accents across the marketing site, repository and composer.

Install the existing website dependencies, then regenerate:

```sh
npm ci --prefix Shared/website
node Shared/tools/build-app-icons.mjs
node Shared/tools/sync-web-branding.mjs
```

Use `node Shared/tools/build-app-icons.mjs --check` to verify deterministic output.
The generator writes seven native Apple Icon Composer packages, flattened Apple Appearance
previews, the default blue visionOS icon stack, Android launcher resources, Windows `.ico`
and package logos, and the default blue marketing icon. Android adaptive-icon XML and native settings/code are maintained by
their respective ports. Palette choices persist as `appColor` on iPhone/iPad, visionOS,
Android and Windows. Mac retains that historical preference without consuming it: the
default blue Icon Composer document supplies its app/Dock identity, and native controls
follow the system accent. The blue AccentColor asset remains the default for Multicolor;
explicit macOS accent selections take precedence.

`iOS/Prosary/Assets.xcassets/ProsaryVision.solidimagestack` is the visionOS primary icon.
The generator writes its five catalog JSON files and two 1024 × 1024 PNG layers: an opaque
RGB `Back.solidimagestacklayer/Content.imageset/background.png` and a transparent
`Front.solidimagestacklayer/Content.imageset/cross.png`. Both image sets use `idiom: vision`
and `scale: 2x`; Front appears above Back. The cross keeps the canonical silhouette,
default palette color and centered 550-pixel height. Generation verifies that the combined
pixels equal the default marketing icon. The target selects `ProsaryVision` with its
`[sdk=xr*]` primary-icon setting and clears alternate icons for visionOS device and simulator.
visionOS keeps this blue installed icon while the chosen app color changes its accent.

Apple's large mobile Appearance previews use actual Icon Composer
Default exports. `apple-icon-previews/` holds these rendered inputs with a manifest of
document and image hashes, so Linux generation and CI can verify them without Apple's
renderer. When the `.icon` sources change, regenerate these previews on a Mac with Xcode:

```sh
node Shared/tools/build-app-icons.mjs --render-apple-previews
```

This exports directly from the generated Icon Composer documents at 512 pixels and copies
the matching previews into Apple's image catalog. Default previews remain colorful when
the Appearance page is dark so each choice is recognizable.

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
