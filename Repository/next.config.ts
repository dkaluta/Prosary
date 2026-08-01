import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  serverExternalPackages: ["postgres"],
  // The /api/admin/migrate route reads SQL files from migrations/ at runtime,
  // so Next's tracer must bundle them into the function (freebee's pattern).
  outputFileTracingIncludes: {
    "/api/admin/migrate": ["./migrations/**/*.sql"],
  },
  experimental: {
    serverActions: {
      bodySizeLimit: "8mb",
    },
  },
};

export default nextConfig;
