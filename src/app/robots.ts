import type { MetadataRoute } from "next";

/** A private application: nothing here is ever indexable, in any environment.
 *  Unlike the brand marketing sites there is no go-live flag to flip. */
export default function robots(): MetadataRoute.Robots {
  return { rules: [{ userAgent: "*", disallow: "/" }] };
}
