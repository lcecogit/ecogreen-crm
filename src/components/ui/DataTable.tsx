import type { ReactNode } from "react";

import { cn } from "@/lib/cn";

/** Dense, hairline-separated, zebra-free. Numeric columns are right-aligned
 *  and carry tabular figures automatically — a CRM table that lets money
 *  columns drift is unreadable at a glance, and remembering per-cell is how it
 *  drifts (DESIGN.md §1, §5). */
export interface Column<Row> {
  key: string;
  header: string;
  numeric?: boolean;
  width?: string;
  render: (row: Row) => ReactNode;
}

export function DataTable<Row>({
  columns,
  rows,
  getKey,
  empty,
  caption,
}: {
  columns: readonly Column<Row>[];
  rows: readonly Row[];
  getKey: (row: Row) => string;
  empty?: ReactNode;
  caption: string;
}) {
  if (rows.length === 0 && empty) return <>{empty}</>;

  return (
    // min-w-0 alongside overflow-x-auto: without it the scroll box is sized by
    // the table when it sits in a grid or flex parent, and scrolls nothing.
    <div className="min-w-0 overflow-x-auto">
      <table className="w-full border-collapse text-body-dense">
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr className="border-b border-hairline">
            {columns.map((column) => (
              <th
                key={column.key}
                scope="col"
                style={column.width ? { width: column.width } : undefined}
                className={cn(
                  "px-3 py-2 text-label font-medium text-ink-2",
                  column.numeric ? "text-right" : "text-left",
                )}
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr
              key={getKey(row)}
              className="border-b border-hairline transition-colors duration-instant ease-standard hover:bg-surface-sunken"
            >
              {columns.map((column) => (
                <td
                  key={column.key}
                  data-numeric={column.numeric ? "" : undefined}
                  className={cn(
                    "h-9 px-3 align-middle text-ink-1",
                    column.numeric && "text-right",
                  )}
                >
                  {column.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
