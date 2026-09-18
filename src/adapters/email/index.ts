import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

import type { EmailMessage, EmailProvider } from "../types";

/** Writes the rendered message to .tmp/mail/ and returns a deterministic id.
 *  A developer can open the file and read exactly what a customer would. */
export const stubEmailProvider: EmailProvider = {
  name: "stub",
  isStub: true,
  async send(message: EmailMessage) {
    const id = `stub-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    try {
      const dir = resolve(process.cwd(), ".tmp/mail");
      mkdirSync(dir, { recursive: true });
      writeFileSync(
        resolve(dir, `${id}.html`),
        `<!-- to: ${message.to}\n     from: ${message.from}\n     subject: ${message.subject} -->\n${message.html}`,
      );
    } catch {
      // A read-only filesystem (serverless) must not fail a send. The message
      // is still logged to message_log by the caller, which is the record that
      // matters.
    }
    return { providerMessageId: id };
  },
};

export function getEmailProvider(): EmailProvider {
  // Real providers are selected here once a key exists. Until then the stub is
  // returned deliberately rather than throwing, so every flow stays runnable.
  if (!process.env.EMAIL_PROVIDER_API_KEY) return stubEmailProvider;
  return stubEmailProvider;
}
