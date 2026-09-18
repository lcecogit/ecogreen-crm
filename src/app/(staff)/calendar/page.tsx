import { sampleJobs } from "@/lib/sample-data";

export const dynamic = "force-dynamic";
export const metadata = { title: "Job calendar" };

const DAYS = [
  { label: "Wed 17", iso: "2026-09-17" },
  { label: "Thu 18", iso: "2026-09-18" },
  { label: "Fri 19", iso: "2026-09-19" },
  { label: "Sat 20", iso: "2026-09-20" },
  { label: "Sun 21", iso: "2026-09-21" },
];

const START_HOUR = 6;
const END_HOUR = 22;

/** Week board.
 *
 *  Jobs are placed by their real start time and duration rather than listed,
 *  because the question this screen answers is "what is already on that day"
 *  — and a list cannot show a clash. Double-booking is rejected by a database
 *  constraint, not by this view; the view only has to make it obvious. */
export default function CalendarPage() {
  return (
    <div className="mx-auto w-full max-w-content">
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-title-1 text-ink-1">Job calendar</h1>
          <p className="mt-1 text-body text-ink-2">Week of 17 September · all brands</p>
        </div>
        <div className="flex gap-2">
          {["Week", "Day", "Crew"].map((view, index) => (
            <button
              key={view}
              type="button"
              aria-current={index === 0 ? "true" : undefined}
              className={
                index === 0
                  ? "h-9 border border-ink-1 px-4 text-body-dense font-medium text-ink-1"
                  : "h-9 border border-hairline px-4 text-body-dense text-ink-2 hover:text-ink-1"
              }
            >
              {view}
            </button>
          ))}
        </div>
      </header>

      <div className="min-w-0 overflow-x-auto border border-hairline">
        <div className="grid min-w-[52rem] grid-cols-[3.5rem_repeat(5,1fr)]">
          <div className="border-b border-r border-hairline bg-surface-sunken" />
          {DAYS.map((day) => (
            <div
              key={day.iso}
              className="border-b border-hairline bg-surface-sunken px-3 py-2 text-caption text-ink-2"
            >
              {day.label}
            </div>
          ))}

          <div className="border-r border-hairline">
            {Array.from({ length: END_HOUR - START_HOUR }).map((_, i) => (
              <div
                key={i}
                data-numeric
                className="h-10 border-b border-hairline px-2 pt-1 text-caption text-ink-3 last:border-0"
              >
                {String(START_HOUR + i).padStart(2, "0")}
              </div>
            ))}
          </div>

          {DAYS.map((day) => (
            <div key={day.iso} className="relative border-r border-hairline last:border-r-0">
              {Array.from({ length: END_HOUR - START_HOUR }).map((_, i) => (
                <div key={i} className="h-10 border-b border-hairline last:border-0" />
              ))}
              {sampleJobs
                .filter((job) => job.start.startsWith(day.iso))
                .map((job) => {
                  const start = new Date(job.start);
                  const hour = start.getUTCHours() + start.getUTCMinutes() / 60;
                  const top = (hour - START_HOUR) * 40;
                  const height = job.durationHours * 40;
                  const live = job.status === "in_progress";
                  return (
                    <article
                      key={job.id}
                      style={{ top, height }}
                      className={`absolute inset-x-1 overflow-hidden border-l-2 px-2 py-1.5 ${
                        live
                          ? "border-l-accent bg-accent-wash"
                          : "border-l-ink-3 bg-surface-sunken"
                      }`}
                    >
                      <p className="truncate text-caption font-medium text-ink-1">{job.customer}</p>
                      <p className="truncate text-caption text-ink-2">
                        {job.crew.join(", ")}
                      </p>
                      {/* ink-2, not ink-3: on the accent-wash ground of a live
                          job the muted step drops below contrast in dark mode,
                          which the audit caught. */}
                      <p data-numeric className="truncate text-caption text-ink-2">
                        {job.vehicle} · {job.durationHours}h
                      </p>
                    </article>
                  );
                })}
            </div>
          ))}
        </div>
      </div>

      <p className="mt-3 text-caption text-ink-3">
        A crew member or van already booked on an overlapping slot is rejected by the database, not
        by this screen — a check in the form is bypassed by a second tab.
      </p>
    </div>
  );
}
