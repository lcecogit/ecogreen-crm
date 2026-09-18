import { redirect } from "next/navigation";

/** The quote funnel moved to the site root: one public page rather than two
 *  saying the same thing. Kept as a redirect because the brand sites and the
 *  email templates already link here. */
export default function QuoteRedirect() {
  redirect("/");
}
