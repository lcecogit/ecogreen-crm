/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    formats: ["image/avif", "image/webp"],
  },
  async headers() {
    // The CRM is a private application. Unlike the marketing sites this is
    // never indexable, so the header is unconditional rather than behind a
    // go-live flag. The only public surface is /embed, which is framed by the
    // brand sites and still must not rank on its own.
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "DENY" },
        ],
      },
      {
        // The embeddable widget is the one route that must be frameable, and
        // only by the six brand domains. X-Frame-Options is omitted here on
        // purpose: frame-ancestors supersedes it and supports a list.
        source: "/embed/:path*",
        headers: [
          { key: "X-Robots-Tag", value: "noindex, nofollow" },
          {
            key: "Content-Security-Policy",
            value:
              "frame-ancestors 'self' https://*.ecogreenmovers.co.uk https://*.ecolondonmovers.co.uk https://*.continuumgreen.co.uk https://*.removalscompanymanchester.co.uk https://*.edinburghmoving.co.uk https://*.glasgowmoving.co.uk",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
