import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), {
    name: "compose-deployment-version",
    generateBundle(_options, bundle) {
      const entry = Object.values(bundle).find((item) => item.type === "chunk" && item.isEntry);
      if (entry) this.emitFile({
        type: "asset", fileName: "version.json", source: JSON.stringify({ entry: entry.fileName }),
      });
    },
  }],
});
