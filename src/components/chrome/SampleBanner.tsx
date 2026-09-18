/** Shown whenever the app is running without a database.
 *
 *  Every screen opens in a realistic working state rather than as an empty
 *  shell, which is the only way the design can be reviewed before a project
 *  exists — but figures a viewer might mistake for the business's own must
 *  never go unlabelled. */
export function SampleBanner() {
  return (
    <div className="border-b border-hairline bg-accent-wash px-4 py-2 text-caption text-ink-2 md:px-6">
      <span className="font-medium text-ink-1">Sample data.</span> No database is
      connected, so every figure on these screens is an example. Set the Supabase
      values in <code className="font-mono">.env.local</code> to see real records.
    </div>
  );
}
