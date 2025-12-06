import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  output: "standalone",
  typescript: {
    ignoreBuildErrors: true,
  },
  // @ts-expect-error - eslint config is valid but types might be outdated or strict
  eslint: {
    ignoreDuringBuilds: true,
  },
};

export default nextConfig;
