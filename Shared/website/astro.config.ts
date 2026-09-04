import { defineConfig } from "astro/config";

// https://astro.build/config
export default defineConfig({
  site: "https://prosary.app",
  // One cacheable stylesheet serves every static page instead of inlining the same rules into
  // each HTML document.
  build: { inlineStylesheets: "never" },
});
