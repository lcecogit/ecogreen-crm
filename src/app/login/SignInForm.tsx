"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";

import { Button } from "@/components/ui/Button";
import { Field, TextInput } from "@/components/ui/Field";
import { createClient } from "@/lib/supabase/client";

export function SignInForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setError(null);

    const { error: signInError } = await createClient().auth.signInWithPassword({ email, password });

    if (signInError) {
      // Deliberately not "no account with that email": that distinction tells
      // an attacker which addresses are staff accounts.
      setError("That email and password don't match. Check both and try again.");
      setPending(false);
      return;
    }

    router.replace("/dashboard");
    router.refresh();
  }

  return (
    <form onSubmit={handleSubmit} noValidate>
      {/* No visual "(required)" marker: both fields are required, so the
          marker carries no information and is just noise. The inputs keep the
          `required` attribute, which is what assistive technology reads. */}
      <Field label="Email" htmlFor="email" error={error ?? undefined}>
        <TextInput
          id="email"
          name="email"
          type="email"
          autoComplete="username"
          required
          invalid={Boolean(error)}
          value={email}
          onChange={(event) => setEmail(event.target.value)}
        />
      </Field>
      <Field label="Password" htmlFor="password">
        <TextInput
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          invalid={Boolean(error)}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
      </Field>
      <Button type="submit" variant="primary" className="mt-2 w-full" disabled={pending}>
        {pending ? "Signing in…" : "Sign in"}
      </Button>
      <p role="status" aria-live="polite" className="sr-only">
        {pending ? "Signing in" : error ?? ""}
      </p>
    </form>
  );
}
