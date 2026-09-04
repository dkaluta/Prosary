#!/usr/bin/env node

import { copyFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = fileURLToPath(new URL("../..", import.meta.url));
const brandRoot = join(repositoryRoot, "Shared", "Branding");

const targetsByName = {
  website: {
    publicRoot: join(repositoryRoot, "Shared", "website", "public"),
    tokens: join(repositoryRoot, "Shared", "website", "src", "styles", "prosary-tokens.generated.css"),
  },
  repository: {
    publicRoot: join(repositoryRoot, "Repository", "public"),
    tokens: join(repositoryRoot, "Repository", "app", "prosary-tokens.generated.css"),
  },
  compose: {
    publicRoot: join(repositoryRoot, "Compose", "public"),
    tokens: join(repositoryRoot, "Compose", "src", "prosary-tokens.generated.css"),
  },
};

const assets = {
  "apple-touch-icon.png": "apple-touch-icon.png",
  "favicon-32x32.png": "favicon-32x32.png",
  "favicon.ico": "favicon.ico",
  "prosary-icon.png": "prosary-mark.png",
  "prosary-social.png": "prosary-app-icon.png",
};

const requestedTargets = process.argv.slice(2).map((target) => target.toLowerCase());
const targets = requestedTargets.length > 0 ? requestedTargets : Object.keys(targetsByName);

for (const target of targets) {
  const destinations = targetsByName[target];
  if (!destinations) {
    throw new Error(
      `Unknown web target "${target}". Expected one of: ${Object.keys(targetsByName).join(", ")}.`,
    );
  }

  await mkdir(destinations.publicRoot, { recursive: true });
  for (const [destinationName, sourceName] of Object.entries(assets)) {
    const destination = join(destinations.publicRoot, destinationName);
    await mkdir(dirname(destination), { recursive: true });
    await copyFile(join(brandRoot, sourceName), destination);
  }

  await mkdir(dirname(destinations.tokens), { recursive: true });
  await copyFile(join(brandRoot, "web-tokens.css"), destinations.tokens);
}

console.log(`Synced Prosary web branding for ${targets.join(", ")}.`);
