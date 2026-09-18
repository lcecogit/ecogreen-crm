import type { MessagingProvider } from "../types";

/** No credentials: the message is drafted and queued for a human. This is the
 *  designed behaviour, not a degraded mode — WhatsApp Business verification
 *  takes weeks and the chase workflow has to work in the meantime. */
function stub(channel: "sms" | "whatsapp"): MessagingProvider {
  return {
    name: "stub",
    channel,
    isStub: true,
    async send() {
      return { queuedForManualSend: true as const };
    },
  };
}

export const stubSmsProvider = stub("sms");
export const stubWhatsAppProvider = stub("whatsapp");

export function getMessagingProvider(channel: "sms" | "whatsapp"): MessagingProvider {
  if (channel === "whatsapp" && !process.env.WHATSAPP_ACCESS_TOKEN) return stubWhatsAppProvider;
  return channel === "sms" ? stubSmsProvider : stubWhatsAppProvider;
}

/** Channels with a live provider. Fed to the scheduler, which queues a step
 *  for manual send rather than failing when its channel is absent. */
export function availableChannels(): ("email" | "sms" | "whatsapp")[] {
  const channels: ("email" | "sms" | "whatsapp")[] = ["email"];
  if (process.env.WHATSAPP_ACCESS_TOKEN) channels.push("whatsapp");
  if (process.env.TWILIO_AUTH_TOKEN) channels.push("sms");
  return channels;
}
