#!/usr/bin/env node
// Rebuild native icon resources from the existing cross template and canonical palette.
// Requires Shared/website's installed sharp dependency. --check verifies without writing.
// --render-apple-previews refreshes the checked-in Icon Composer exports on macOS.
import { readFile, writeFile, mkdir, mkdtemp, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { createHash } from "node:crypto";
import { execFile as execFileCallback } from "node:child_process";
import { promisify } from "node:util";
import { tmpdir } from "node:os";

const root = fileURLToPath(new URL("../..", import.meta.url));
const require = createRequire(join(root, "Shared/website/package.json"));
const sharp = require("sharp");
const brand = join(root, "Shared/Branding");
const palette = JSON.parse(await readFile(join(brand, "app-colors.json"), "utf8"));
const originalAppleIcon = JSON.parse(await readFile(join(brand, "apple-original-icon.json"), "utf8"));
const glyph = await readFile(join(brand, "cross-template.png"));
const glyphInfo = await sharp(glyph).metadata();
const androidTemplate = await readFile(join(brand, "android-cross-template.png"));
const output = new Map();
const json = value => Buffer.from(JSON.stringify(value, null, 2) + "\n");
const rgb = hex => [1, 3, 5].map(start => parseInt(hex.slice(start, start + 2), 16));
const composerColor = hex => "srgb:" + [...rgb(hex).map(n => (n / 255).toFixed(6)), "1.000000"].join(",");
const execFile = promisify(execFileCallback);
const renderApplePreviews = process.argv.includes("--render-apple-previews");
const applePreviewSpec = { platform: "iOS", rendition: "Default", width: 512, height: 512, scale: 1 };
const applePreviewDirectory = "Shared/Branding/apple-icon-previews";
const applePreviewManifestPath = `${applePreviewDirectory}/manifest.json`;
const cachedApplePreviews = renderApplePreviews ? {}
  : JSON.parse(await readFile(join(root, applePreviewManifestPath), "utf8").catch(() => "{}"));
const applePreviewManifest = {};

async function applePreview(packageName, packagePath) {
  const files = [...output.entries()]
    .filter(([path]) => path.startsWith(`${packagePath}/`))
    .map(([path, bytes]) => [path.slice(packagePath.length + 1), bytes])
    .sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0);
  const hash = createHash("sha256").update(json(applePreviewSpec)).update("\0");
  for (const [path, bytes] of files) hash.update(path).update("\0").update(bytes).update("\0");
  const sourceSha256 = hash.digest("hex");
  const previewPath = `${applePreviewDirectory}/${packageName}.png`;
  let bytes;
  if (renderApplePreviews) {
    const { stdout } = await execFile("xcode-select", ["-p"]);
    const renderer = join(dirname(stdout.trim()), "Applications/Icon Composer.app/Contents/Executables/ictool");
    const temporaryDirectory = await mkdtemp(join(tmpdir(), "prosary-apple-preview-"));
    try {
      const document = join(temporaryDirectory, `${packageName}.icon`);
      for (const [path, contents] of files) {
        const target = join(document, path);
        await mkdir(dirname(target), { recursive: true });
        await writeFile(target, contents);
      }
      const rendered = join(temporaryDirectory, "preview.png");
      await execFile(renderer, [document, "--export-image", "--output-file", rendered,
        "--platform", applePreviewSpec.platform, "--rendition", applePreviewSpec.rendition,
        "--width", String(applePreviewSpec.width), "--height", String(applePreviewSpec.height), "--scale", String(applePreviewSpec.scale)]);
      bytes = await readFile(rendered);
    } finally {
      await rm(temporaryDirectory, { recursive: true, force: true });
    }
  } else {
    if (cachedApplePreviews[packageName]?.sourceSha256 !== sourceSha256) {
      throw new Error(`${packageName} preview is stale. On macOS run build-app-icons.mjs --render-apple-previews.`);
    }
    bytes = await readFile(join(root, previewPath));
    if (cachedApplePreviews[packageName]?.imageSha256 !== createHash("sha256").update(bytes).digest("hex")) {
      throw new Error(`${packageName} preview differs from its Icon Composer export. Regenerate with --render-apple-previews.`);
    }
  }
  applePreviewManifest[packageName] = { sourceSha256, imageSha256: createHash("sha256").update(bytes).digest("hex") };
  output.set(previewPath, bytes);
  return bytes;
}

async function tintedGlyph(color) {
  return sharp({ create: { width: glyphInfo.width, height: glyphInfo.height, channels: 4, background: color } })
    .composite([{ input: glyph, blend: "dest-in" }]).png().toBuffer();
}
async function canvas(width, height, background, foreground, crossHeight) {
  const cross = await sharp(foreground).resize({ height: crossHeight }).png().toBuffer();
  const info = await sharp(cross).metadata();
  return sharp({ create: { width, height, channels: 4, background } })
    .composite([{ input: cross, left: Math.round((width - info.width) / 2), top: Math.round((height - info.height) / 2) }])
    .png().toBuffer();
}
async function androidForeground(color) {
  return sharp({ create: { width: 864, height: 864, channels: 4, background: color } })
    .composite([{ input: androidTemplate, blend: "dest-in" }]).png().toBuffer();
}
async function ico(image) {
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const images = await Promise.all(sizes.map(size => sharp(image).resize(size, size).png().toBuffer()));
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  images.forEach((image, index) => {
    const start = 6 + index * 16;
    header[start] = header[start + 1] = sizes[index] === 256 ? 0 : sizes[index];
    header.writeUInt16LE(1, start + 4);
    header.writeUInt16LE(32, start + 6);
    header.writeUInt32LE(image.length, start + 8);
    header.writeUInt32LE(offset, start + 12);
    offset += image.length;
  });
  return Buffer.concat([header, ...images]);
}

for (const color of palette.colors) {
  const name = color.id[0].toUpperCase() + color.id.slice(1);
  const foreground = await tintedGlyph(color.cross);
  const icon = await canvas(1024, 1024, color.background, foreground, 550);
  const packageName = color.id === palette.default ? "Prosary" : `Prosary${name}`;
  const packagePath = `iOS/Prosary/${packageName}.icon`;
  output.set(`${packagePath}/Assets/Path 2.png`, glyph);
  const appleIcon = structuredClone(originalAppleIcon);
  // System Dark and the original automatic glyph fill reproduce the original dark icon.
  appleIcon["fill-specializations"] = [
    { value: { solid: composerColor(color.background) } },
    { appearance: "dark", value: "system-dark" },
  ];
  delete appleIcon.fill;
  if (color.id === "white") {
    const layer = appleIcon.groups[0].layers[0];
    delete layer["image-name"];
    layer["image-name-specializations"] = [
      { value: "Path 2.png" },
      { appearance: "light", value: "Gold.png" },
    ];
    output.set(`${packagePath}/Assets/Gold.png`, foreground);
  }
  output.set(`${packagePath}/icon.json`, json(appleIcon));
  const previewPath = `iOS/Prosary/Assets.xcassets/AppIcon${name}.imageset`;
  output.set(`${previewPath}/icon.png`, await applePreview(packageName, packagePath));
  output.set(`${previewPath}/Contents.json`, json({ images: [{ filename: "icon.png", idiom: "universal" }], info: { author: "xcode", version: 1 } }));
  output.set(`Windows/Prosary/Assets/Icons/prosary-${color.id}.ico`, await ico(icon));
  output.set(`Android/app/src/main/res/drawable/ic_launcher_background_${color.id}.xml`, Buffer.from(
    `<?xml version="1.0" encoding="utf-8"?>\n<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="${color.background}" /></shape>\n`));
  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    const resized = await sharp(icon).resize(size, size).png().toBuffer();
    const mask = radius => Buffer.from(`<svg width="${size}" height="${size}"><rect width="${size}" height="${size}" rx="${radius}" fill="white"/></svg>`);
    const legacy = await sharp(resized).composite([{ input: mask(size * 0.23), blend: "dest-in" }]).webp({ lossless: true }).toBuffer();
    output.set(`Android/app/src/main/res/mipmap-${density}/ic_launcher_${color.id}.webp`, legacy);
    if (color.id === palette.default) {
      output.set(`Android/app/src/main/res/mipmap-${density}/ic_launcher.webp`, legacy);
      output.set(`Android/app/src/main/res/mipmap-${density}/ic_launcher_round.webp`,
        await sharp(resized).composite([{ input: mask(size / 2), blend: "dest-in" }]).webp({ lossless: true }).toBuffer());
    }
  }
  if (color.id === "white") {
    output.set("Android/app/src/main/res/drawable-nodpi/ic_launcher_foreground_gold.png",
      await androidForeground(color.cross));
  }
  if (color.id === palette.default) {
    output.set("Shared/Branding/prosary-app-icon.png", await sharp(icon).removeAlpha().png().toBuffer());
    output.set("Shared/Branding/prosary-mark.png", await sharp(icon).resize(96).removeAlpha().png().toBuffer());
    output.set("Shared/Branding/apple-touch-icon.png", await sharp(icon).resize(180).removeAlpha().png().toBuffer());
    output.set("Shared/Branding/favicon-32x32.png", await sharp(icon).resize(32).removeAlpha().png().toBuffer());
    output.set("Shared/Branding/favicon.ico", await ico(icon));
    output.set("Android/store-assets/play-store-icon-512.png", await sharp(icon).resize(512).removeAlpha().png().toBuffer());
    output.set("Android/icon/background_reference.png", await sharp({ create: { width: 1024, height: 1024, channels: 3, background: color.background } }).png().toBuffer());
    output.set("Android/icon/glyph_reference.png", glyph);
    output.set("Android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png",
      await androidForeground(color.cross));
    output.set("Android/app/src/main/res/drawable/ic_launcher_background.xml", output.get(`Android/app/src/main/res/drawable/ic_launcher_background_${color.id}.xml`));
    for (const [file, width, height] of [["StoreLogo", 50, 50], ["Square44x44Logo", 44, 44], ["Square150x150Logo", 150, 150], ["Wide310x150Logo", 310, 150], ["SplashScreen", 620, 300]]) {
      output.set(`Windows/Prosary/Assets/${file}.png`, await canvas(width, height, color.background, foreground, Math.round(height * 0.54)));
    }
  }
}
output.set(applePreviewManifestPath, json(applePreviewManifest));

let mismatches = 0;
for (const [relativePath, bytes] of output) {
  const path = join(root, relativePath);
  if (process.argv.includes("--check")) {
    const existing = await readFile(path).catch(() => Buffer.alloc(0));
    if (!existing.equals(bytes)) { console.error(`Stale app icon: ${relativePath}`); mismatches++; }
  } else {
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, bytes);
  }
}
if (mismatches) process.exitCode = 1;
else console.log(`${process.argv.includes("--check") ? "Verified" : "Generated"} ${output.size} app icon resources in ${palette.colors.length} colors.`);
