import { Badge, type Tone } from "@/components/ui/Badge";
import type { SampleLead } from "@/lib/sample-data";

const TONE: Record<SampleLead["status"], Tone> = {
  new: "accent",
  qualifying: "neutral",
  quoted: "neutral",
  chasing: "warning",
  booked: "good",
  completed: "good",
  lost: "critical",
};

const LABEL: Record<SampleLead["status"], string> = {
  new: "New",
  qualifying: "Qualifying",
  quoted: "Quoted",
  chasing: "Chasing",
  booked: "Booked",
  completed: "Completed",
  lost: "Lost",
};

export function StatusBadge({ status }: { status: SampleLead["status"] }) {
  return <Badge tone={TONE[status]}>{LABEL[status]}</Badge>;
}
