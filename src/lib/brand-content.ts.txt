export const brand = {
  name: "EcoGreen Movers",
  tagline: "Home | Office | Commercial",
  email: "info@ecogreenmovers.co.uk",
  headline: "Start your move with a removals company that actually cares",
  subhead: "Eco-friendly removals for residential, commercial and office moves — serving Edinburgh, Manchester, London and more across the UK.",
  branches: [
    { city: "London", phone: "020 4525 5705", tel: "+442045255705" },
    { city: "Manchester", phone: "0161 768 2055", tel: "+441617682055" },
    { city: "Edinburgh", phone: "0131 608 5740", tel: "+441316085740" },
  ],
} as const;

export const photos = {
  hero: { src: "", alt: "Cardboard moving boxes being unpacked" },
  residential: { src: "", alt: "Labelled cardboard boxes ready" },
  packing: { src: "", alt: "Packing fragile items" },
  specialist: { src: "", alt: "Server rack equipment" },
  signIn: { src: "", alt: "Empty room" },
} as const;

export const services = [
  { slug: "residential-moves", name: "Residential moves", tag: "Homes of any size", description: "Studio flats to family houses, packed and moved." },
  { slug: "office-removals", name: "Office removals", tag: "Out of hours available", description: "Desks and IT moved with minimal downtime." },
  { slug: "commercial-relocation", name: "Commercial relocation", tag: "UK-wide", description: "Full-site relocations with single point of contact." },
  { slug: "storage-packing", name: "Storage & packing", tag: "Short or long term", description: "Professional packing with eco materials." },
] as const;

export const reasons = [
  "A fixed price agreed before the move",
  "Fully insured with goods-in-transit cover",
  "Eco-friendly materials and route planning",
  "Branches across the UK",
  "Dismantling and reassembly handled by crew",
  "Track your driver with a call on the day",
] as const;

export const testimonials = [
  { quote: "Excellent and reliable modern removal service.", author: "DJ Gym", context: "Manchester" },
  { quote: "Moving from Manchester to Scotland was made easy.", author: "John Wilson", context: "Scotland" },
] as const;

export const caseStudies = [
  { title: "Medical equipment transfer", place: "Glasgow", detail: "Clinical handling." },
] as const;