# Photography credits

Every image in this directory is recorded here before it is used. An
unattributed licence trail is a problem that surfaces at the worst possible
moment, and "we got it from Google" is not a licence.

These five came from **EcoGreen Movers' own WordPress media library**, pulled
through the site connector and re-encoded to WebP at the sizes the pages
actually need. That is better than fresh stock in three ways: the business
already holds the licence, the images are already the ones its customers see
on the marketing site, and nothing new had to be cleared.

| File | Source | Original | Licence | Used on |
|---|---|---|---|---|
| `boxes-house-move.webp` | EcoGreen media library (Pexels-sourced) | attachment 10898, 1600×900 | Pexels licence, held by EcoGreen | Home hero |
| `labelled-boxes.webp` | EcoGreen media library (Pexels-sourced) | attachment 10872, 1600×900 | Pexels licence, held by EcoGreen | Residential moves |
| `packing-fragile.webp` | EcoGreen media library | attachment 10894, 1600×900 | Pexels licence, held by EcoGreen | Storage & packing |
| `server-rack.webp` | EcoGreen media library (Pexels-sourced) | attachment 10887, 1600×900 | Pexels licence, held by EcoGreen | Specialist work |
| `empty-room.webp` | EcoGreen media library (Pexels-sourced) | attachment 10696, 1600×900 | Pexels licence, held by EcoGreen | Sign-in |

Alt text is stored with each image in `src/lib/brand-content.ts` and came from
the media library's own alt field, written by whoever uploaded it — so it is
the business's description, not one invented here.

## Sourcing rules for anything added later

- The media library first. Fresh stock only when nothing there fits.
- Unsplash or Pexels under their standard licences, or commissioned work.
- **Subject matter**: vans, crates, hallways, loading, warehouse light, road
  and city texture. Prefer environment and material over people.
- **Avoid outright**: grinning teams with clipboards, high-fives, handshakes
  over boxes, headset call-centre portraits. They read as generic and actively
  undercut a premium impression.
- **Grade to one treatment** — cool-neutral, slightly desaturated, matched
  contrast — so six brands still look like one platform.
- **Replace with real photography of the actual fleet and crews as soon as it
  exists.** Stock is scaffolding, not the finish.

## Technical

Serve through `BrandPhoto` (`src/components/media/BrandPhoto.tsx`), which uses
`next/image`, so sizing and lazy loading are handled. Set `priority` only on
the image that is the LCP element. Commit the file rather than hotlinking: the
build stays reproducible and the page does not depend on another CDN staying
up.
