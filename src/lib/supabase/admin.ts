import "server-only";

import { createClient as createSupabaseClient } from "@supabase/supabase-js";

/** Service-role client. Bypasses RLS, so its use is restricted by convention
 *  and by review to exactly three places:
 *
 *    /api/intake/*    — anonymous lead posts from the brand websites
 *    /api/cron/*      — the scheduler, which acts for no user
 *    /api/webhooks/*  — providers, which have no session
 *
 *  Importing this into a page, a Server Component or any other route is a
 *  security bug, not a shortcut. */
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;
  if (!url || !key) {
    throw new Error("SUPABASE_SECRET_KEY and NEXT_PUBLIC_SUPABASE_URL are required for admin access");
  }
  return createSupabaseClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
