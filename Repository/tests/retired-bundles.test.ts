import assert from "node:assert/strict";
import test from "node:test";
import { getBundle, upsertBundle } from "../lib/db.ts";

const retiredId = "repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin";

test("retired detail and download lookup remains unavailable even without a database connection", async () => {
  assert.equal(await getBundle(retiredId), null);
});

test("direct persistence cannot bypass the publishing guard to recreate the retired upload", async () => {
  await assert.rejects(() => upsertBundle({
    id: retiredId, userId: "unused", name: "Old standalone", description: "",
    languages: ["he"], tags: [], fileUrl: "https://example.invalid/retired.prosaryprayer", fileSize: 1,
  }), /retired/);
});
