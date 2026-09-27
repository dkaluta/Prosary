#!/usr/bin/env node
// Rebuild native icon resources from the existing cross template and canonical palette.
// Requires Shared/website's installed sharp dependency. --check verifies without writing.
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

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
  const previewMask = Buffer.from('<svg width="1024" height="1024"><rect width="1024" height="1024" rx="236" fill="white"/></svg>');
  output.set(`${previewPath}/icon.png`, await sharp(icon).composite([{ input: previewMask, blend: "dest-in" }]).png().toBuffer());
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
