/** Customer-facing content for EcoGreen Movers.
 *
 *  Every string here was read from ecogreenmovers.co.uk — the headline, the
 *  service names, the three branch numbers, the reviews and the case studies
 *  are the business's own words, not written for it. Nothing about coverage,
 *  credentials or customer outcomes is invented, and no price appears: the
 *  rate card is still provisional (DECISIONS.md §2), and this business quotes
 *  a fixed price rather than publishing one.
 */

export const brand = {
  name: "EcoGreen Movers",
  tagline: "Home | Office | Commercial",
  email: "info@ecogreenmovers.co.uk",
  headline: "Start your move with a removals company that actually cares",
  subhead:
    "Eco-friendly removals for residential, commercial and office moves — serving Edinburgh, Manchester, London and more across the UK.",
  branches: [
    { city: "London", phone: "020 4525 5705", tel: "+442045255705" },
    { city: "Manchester", phone: "0161 768 2055", tel: "+441617682055" },
    { city: "Edinburgh", phone: "0131 608 5740", tel: "+441316085740" },
  ],
} as const;

/** Images from the business's own WordPress media library — see
 *  public/photos/CREDITS.md. Alt text is the library's own, written by
 *  whoever uploaded it, rather than invented here. */
export const photos = {
  hero: {
    src: "/photos/boxes-house-move.webp",
    alt: "Cardboard moving boxes being unpacked during a house move",
  },
  residential: {
    src: "/photos/labelled-boxes.webp",
    alt: "Labelled cardboard boxes ready for moving day",
  },
  packing: {
    src: "/photos/packing-fragile.webp",
    alt: "Person wrapping fragile kitchen items in plain packing paper while preparing for a house move",
  },
  specialist: {
    src: "/photos/server-rack.webp",
    alt: "Rack-mounted servers and network equipment in a comms room, the kit moved during an office IT relocation",
  },
  signIn: {
    src: "/photos/empty-room.webp",
    alt: "Bright empty room with large windows",
  },
} as const;

export const services = [
  {
    slug: "residential-moves",
    name: "Residential moves",
    tag: "Homes of any size",
    description:
      "Studio flats to family houses, packed, moved and reassembled. Dismantling and rebuilding of beds, wardrobes and units included.",
  },
  {
    slug: "office-removals",
    name: "Office removals",
    tag: "Out of hours available",
    description:
      "Desks, storage and IT moved with minimal downtime, planned around your working week rather than across it.",
  },
  {
    slug: "commercial-relocation",
    name: "Commercial relocation",
    tag: "UK-wide",
    description:
      "Full-site relocations with a single point of contact, method statements and sign-off at every stage.",
  },
  {
    slug: "storage-packing",
    name: "Storage & packing",
    tag: "Short or long term",
    description:
      "Professional packing with eco-friendly materials, and secure storage for the gap between completion dates.",
  },
] as const;

export const reasons = [
  "A fixed price agreed before the move — not an estimate that moves on the day",
  "Fully insured, with goods-in-transit and public liability cover on every job",
  "Eco-friendly materials and route planning, not a sustainability sticker",
  "Branches in Edinburgh, Manchester and London, covering the whole of the UK",
  "Dismantling and reassembly of furniture handled by the same crew",
  "You can track your driver, and you get a call on the day",
] as const;

/** Verbatim from the site's review section. Never edited: a trimmed review is
 *  a rewritten one, and these are real customers. */
export const testimonials = [
  {
    quote:
      "Excellent and reliable modern removal service in Manchester. They moved our delicate music studio in less than 24 hours since first contacting them. Very good service for removals large and small. Brilliant staff.",
    author: "DJ Gym",
    context: "Music studio relocation, Manchester",
  },
  {
    quote:
      "Moving after 31 years from Manchester to Scotland was made easy. The team were polite and friendly with excellent communication. Packed all my glass China and ornaments with care. Efficient and organized.",
    author: "John Wilson",
    context: "Manchester to Scotland",
  },
  {
    quote:
      "I was kept updated with emails/texts, plus a call on the day to say how long they'd be. Needed some dismantling and reassembly of furniture like my wardrobe, chest of drawers and bed — all done quickly.",
    author: "Lankz Thelst",
    context: "Home removal, Manchester",
  },
] as const;

/** Real case studies from the site. These are the strongest proof the business
 *  has and the marketing site buries them, so they get a section here. */
export const caseStudies = [
  {
    title: "Neonatal incubator transfer between hospitals",
    place: "Glasgow",
    detail: "Medical equipment moved under clinical handling protocols.",
  },
  {
    title: "High-rise office relocation with pool table handling",
    place: "Stockport · Trafford Park",
    detail: "Specialist lift and stair work above ground floor.",
  },
  {
    title: "Time-critical exhibition artwork and display transfer",
    place: "Manchester · Newport",
    detail: "Fine art crated and moved to a fixed exhibition deadline.",
  },
  {
    title: "Corporate office technology relocation",
    place: "Glasgow to London",
    detail: "IT and server equipment asset-tagged end to end.",
  },
] as const;
