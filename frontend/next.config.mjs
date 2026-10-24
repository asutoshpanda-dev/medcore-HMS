/** @type {import('next').NextConfig} */
const nextConfig = {
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
  // The browser calls /api on this Next.js address and Next.js forwards the call to the
  // Spring Boot backend. Because the browser only ever talks to one address, no CORS setting is needed.
  async rewrites() {
    const apiUrl = process.env.API_URL || "http://localhost:8080";
    return [{ source: "/api/:path*", destination: `${apiUrl}/api/:path*` }];
  },
};

export default nextConfig;
