/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    // Server Actions are stable in Next 15 but we opt-in explicitly so we
    // remember this is what the CRUD pages rely on.
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          // Prevent clickjacking — admin panel must never be framed.
          { key: "X-Frame-Options", value: "DENY" },
          // Stop browsers from MIME-sniffing responses away from the
          // declared Content-Type (prevents drive-by downloads).
          { key: "X-Content-Type-Options", value: "nosniff" },
          // Force HTTPS for 2 years + include subdomains.
          {
            key: "Strict-Transport-Security",
            value: "max-age=63072000; includeSubDomains; preload",
          },
          // Block cross-origin information leaks.
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          // Opt out of FLoC / Topics API.
          { key: "Permissions-Policy", value: "interest-cohort=()" },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
