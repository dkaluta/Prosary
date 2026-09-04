import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  serverExternalPackages: ["postgres"],
  turbopack: {
    root: process.cwd(),
  },
};

export default nextConfig;
