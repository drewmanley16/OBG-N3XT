import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // WASM provers: load from node_modules at runtime instead of bundling.
  serverExternalPackages: ["@aztec/bb.js", "@noir-lang/noir_js"],
  /* config options here */
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
