import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/** Session-scoped client. Every read through this goes through RLS, which is
 *  why the policies in migration 0011 are the security boundary rather than
 *  anything in the route handlers. */
export function createClient() {
  const store = cookies();
  return createServerClient(requiredEnv("NEXT_PUBLIC_SUPABASE_URL"), requiredEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"), {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (list) => {
        try {
          for (const { name, value, options } of list) store.set(name, value, options);
        } catch {
          // Called from a Server Component, where cookies are read-only. The
          // middleware refreshes the session, so this is safe to swallow.
        }
      },
    },
  });
}

function requiredEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(
      `${key} is not set. Copy crm/.env.example to crm/.env.local and fill in the Supabase values.`,
    );
  }
  return value;
}
