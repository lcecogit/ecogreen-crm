import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { formatDate, formatMoneyMinor } from "@/lib/format";
import type { LeadStatus } from "@/lib/db-types";

interface LiveLead {
  id: string; reference: string; status: LeadStatus; move_date: string | null;
  origin_postcode: string | null; destination_postcode: string | null; created_at: string;
  brands: { name: string } | null;
  customers: { first_name: string | null; last_name: string | null; email: string | null; phone: string | null } | null;
  staff: { full_name: string } | null;
  services: { name: string } | null;
}
const leadColumns = "id,reference,status,move_date,origin_postcode,destination_postcode,created_at,brands(name),customers(first_name,last_name,email,phone),staff!leads_owner_staff_id_fkey(full_name),services(name)";
const customerName = (lead: LiveLead) => [lead.customers?.first_name, lead.customers?.last_name].filter(Boolean).join(" ") || "Unnamed customer";
function check(error: { message: string } | null) {
  if (error) throw new Error("The CRM could not load saved records. Please retry or ask your administrator to check the database configuration.");
}
function Page({ title, children }: { title: string; children: React.ReactNode }) {
  return <div className="mx-auto w-full max-w-content"><h1 className="mb-6 text-title-1 text-ink-1">{title}</h1>{children}</div>;
}
function Table({ headers, rows }: { headers: string[]; rows: React.ReactNode[][] }) {
  if (!rows.length) return <p className="border border-hairline p-6 text-body text-ink-2">No saved records match this view.</p>;
  return <div className="overflow-x-auto border border-hairline"><table className="w-full text-left text-body-dense"><thead><tr>{headers.map(h => <th key={h} className="border-b border-hairline p-3 text-caption text-ink-3">{h}</th>)}</tr></thead><tbody>{rows.map((row,i) => <tr key={i}>{row.map((cell,j) => <td key={j} className="border-b border-hairline p-3">{cell ?? "—"}</td>)}</tr>)}</tbody></table></div>;
}
export async function LiveDashboard() {
  const db = createClient();
  const results = await Promise.all([
    db.from("leads").select("id", { count: "exact", head: true }).in("status", ["new","qualifying","quoted","chasing"]),
    db.from("leads").select("id", { count: "exact", head: true }).in("status", ["new","qualifying","quoted","chasing"]).is("owner_staff_id", null),
    db.from("leads").select("id", { count: "exact", head: true }).eq("status", "booked"),
    db.from("outbox").select("id", { count: "exact", head: true }).eq("status", "needs_manual_send"),
  ]);
  results.forEach(r => check(r.error));
  const labels = ["Open leads", "Unassigned leads", "Booked leads", "Messages awaiting manual send"];
  const links = ["/leads", "/leads?owner=none", "/leads?status=booked", "/inbox"];
  const recent = await db.from("leads").select(leadColumns).order("created_at", { ascending:false }).limit(10).returns<LiveLead[]>();
  check(recent.error);
  return <Page title="Dashboard"><p className="mb-6 text-body text-ink-2">{new Intl.DateTimeFormat("en-GB", { dateStyle:"full", timeZone:"Europe/London" }).format(new Date())} · saved records you have access to</p><section className="mb-8 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{results.map((r,i) => <Link key={labels[i]} href={links[i]!} className="border border-hairline p-5"><p className="text-caption text-ink-2">{labels[i]}</p><p className="mt-3 text-title-1">{r.count ?? 0}</p></Link>)}</section><h2 className="mb-3 text-title-3">Latest enquiries</h2><LeadTable leads={recent.data ?? []}/></Page>;
}
function LeadTable({ leads }: { leads: LiveLead[] }) {
  return <Table headers={["Reference","Customer","Brand","Status","Move date","Route","Owner"]} rows={leads.map(l => [<Link key={l.id} href={`/leads/${l.id}`} className="underline">{l.reference}</Link>,customerName(l),l.brands?.name,l.status,formatDate(l.move_date),`${l.origin_postcode ?? "—"} → ${l.destination_postcode ?? "—"}`,l.staff?.full_name ?? "Unassigned"])} />;
}
export async function LiveLeads({ status = "open", owner, page = "1" }: { status?: string; owner?: string; page?: string }) {
  const currentPage = Math.min(100000, Math.max(1, Number.parseInt(page,10) || 1));
  if (!["open","all","new","qualifying","quoted","chasing","booked","completed","reviewed","lost","duplicate"].includes(status)) status = "open";
  const db = createClient();
  let query = db.from("leads").select(leadColumns, { count:"exact" }).order("created_at",{ascending:false}).order("id");
  if (owner === "none") query = query.is("owner_staff_id",null);
  if (status === "open") query = query.in("status",["new","qualifying","quoted","chasing"]);
  else if (status !== "all") query = query.eq("status",status);
  const result = await query.range((currentPage-1)*50,currentPage*50-1).returns<LiveLead[]>();
  check(result.error);
  const pageUrl = (n:number) => `/leads?${new URLSearchParams({ status, ...(owner ? {owner} : {}), page:String(n) })}`;
  return <Page title="Leads"><nav className="mb-5 flex flex-wrap gap-4">{["open","new","quoted","chasing","booked","lost","all"].map(s => <Link key={s} href={`/leads?status=${s}`} className={s===status ? "font-semibold underline" : "underline"}>{s}</Link>)}</nav><p className="mb-3 text-caption text-ink-2">{result.count ?? 0} matching leads · page {currentPage}</p><LeadTable leads={result.data ?? []}/><nav className="mt-4 flex gap-4">{currentPage>1 && <Link href={pageUrl(currentPage-1)}>Previous</Link>}{currentPage*50<(result.count ?? 0) && <Link href={pageUrl(currentPage+1)}>Next</Link>}</nav></Page>;
}
export async function LiveLeadDetail({ id }: { id:string }) {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) notFound();
  const db = createClient();
  const result = await db.from("leads").select(leadColumns).eq("id",id).maybeSingle<LiveLead>();
  check(result.error);
  if (!result.data) notFound();
  const lead = result.data;
  const quotes = await db.from("quotes").select("id,reference,version,status,currency,net_minor,vat_minor,gross_minor").eq("lead_id",id).order("version",{ascending:false});
  check(quotes.error);
  return <Page title={lead.reference}><Link href="/leads" className="mb-5 inline-block underline">← Leads</Link><Table headers={["Field","Saved value"]} rows={[["Customer",customerName(lead)],["Email",lead.customers?.email],["Phone",lead.customers?.phone],["Brand",lead.brands?.name],["Service",lead.services?.name],["Status",lead.status],["Owner",lead.staff?.full_name ?? "Unassigned"],["Move date",formatDate(lead.move_date)],["Collection postcode",lead.origin_postcode],["Delivery postcode",lead.destination_postcode]]}/><h2 className="mb-3 mt-8 text-title-3">Saved quotes</h2><Table headers={["Reference","Version","Status","Net","VAT","Total"]} rows={(quotes.data ?? []).map(q => [q.reference,q.version,q.status,formatMoneyMinor(Number(q.net_minor),q.currency),formatMoneyMinor(Number(q.vat_minor),q.currency),formatMoneyMinor(Number(q.gross_minor),q.currency)])}/></Page>;
}
export async function LiveCalendar() {
  const db = createClient();
  const today = new Intl.DateTimeFormat("en-CA", {timeZone:"Europe/London",year:"numeric",month:"2-digit",day:"2-digit"}).format(new Date());
  const result = await db.from("jobs").select("id,reference,status,scheduled_start,scheduled_end,access_notes").gte("scheduled_start",`${today}T00:00:00Z`).order("scheduled_start").limit(100);
  check(result.error);
  const dateTime = (value:string|null) => value ? new Intl.DateTimeFormat("en-GB",{dateStyle:"medium",timeStyle:"short",timeZone:"Europe/London"}).format(new Date(value)) : "Unscheduled";
  return <Page title="Job calendar"><p className="mb-4 text-body text-ink-2">Next 100 scheduled jobs · times shown for the UK.</p><Table headers={["Reference","Status","Start","End","Access notes"]} rows={(result.data ?? []).map(j => [j.reference,j.status,dateTime(j.scheduled_start),dateTime(j.scheduled_end),j.access_notes])}/></Page>;
}
export async function LiveInbox() {
  const db = createClient();
  const result = await db.from("outbox").select("id,channel,to_address,template_key,payload,created_at").eq("status","needs_manual_send").order("created_at").limit(100);
  check(result.error);
  return <Page title="Send queue"><p className="mb-4 text-body text-ink-2">Up to 100 saved messages awaiting manual sending. Sending controls are not connected yet.</p><Table headers={["Channel","Recipient","Template","Message"]} rows={(result.data ?? []).map(m => [m.channel,m.to_address,m.template_key,typeof m.payload?.body === "string" ? m.payload.body : "Message text not yet rendered"])}/></Page>;
}
