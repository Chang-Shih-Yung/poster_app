/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    // Server Actions are stable in Next 15 but we opt-in explicitly so we
    // remember this is what the CRUD pages rely on.
  },
};

module.exports = nextConfig;
