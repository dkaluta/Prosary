import assert from "node:assert/strict";
import test from "node:test";
import { privatePageMetadata, publicPageMetadata } from "../lib/metadata.ts";

test("public page metadata keeps canonical and social details route-specific", () => {
  const metadata = publicPageMetadata({
    title: "Submit a devotion",
    path: "/submit",
    description: "Share a devotion.",
  });

  assert.deepEqual(metadata.alternates, { canonical: "/submit" });
  assert.equal(metadata.openGraph?.title, "Submit a devotion · Prosary");
  assert.equal(metadata.openGraph?.url, "/submit");
  assert.equal(metadata.openGraph?.description, "Share a devotion.");
  assert.equal(metadata.twitter?.title, "Submit a devotion · Prosary");
  assert.equal(metadata.twitter?.description, "Share a devotion.");
  assert.deepEqual(metadata.twitter?.images, metadata.openGraph?.images);
});

test("private page metadata does not expose a canonical or social URL", () => {
  const metadata = privatePageMetadata({
    title: "Recover your account",
    description: "Private recovery flow.",
  });

  assert.equal(metadata.alternates, null);
  assert.equal(metadata.openGraph, null);
  assert.equal(metadata.twitter, null);
  assert.deepEqual(metadata.robots, { index: false, follow: false });
});
