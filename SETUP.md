# Setup

Three things, in this order: get it running, give it a database, deploy it.

---

## 1. Run it locally (5 minutes, no accounts needed)

```bash
npm install
npm run dev
```

Open **http://localhost:3000**.

It runs with **no Supabase project and no API keys**. Every screen opens with
sample data behind a banner saying so, which is the point: you can review the
whole thing before provisioning anything.

| Route | What it is |
|---|---|
| `/` | The public site and quote funnel |
| `/login` | Staff sign-in |
| `/dashboard` | The CRM — charts, pipeline, crew, send queue |
| `/leads` · `/leads/l1` | Leads list and a lead in full |
| `/calendar` | Job board for the week |
| `/inbox` | The manual send queue |
| `/styleguide` | Every component and state, for design review |

---

## 2. Give it a database

Free Supabase tier is enough.

1. **supabase.com** → New project. Keep the database password somewhere.
2. **SQL Editor → New query.** Run the five parts in order from
   `supabase/parts/`:

   ```
   01_schema.sql      extensions, 24 enums, 42 tables, indexes, triggers
   02_integrity.sql   reference numbering, quote freezing, audit immutability
   03_security.sql    helpers and 68 row-level-security policies
   04_functions.sql   intake, booking, scheduler, job sheets, GDPR
   05_seed.sql        6 brands, 67 catalogue items, 36 rate cards, sequences
   ```

   Every part is safe to re-run, and each checks its prerequisites and tells you
   plainly if something is missing. `supabase/install.sql` is all five
   concatenated if you would rather paste once.

3. **Check it worked:**

   ```sql
   select
     (select count(*) from information_schema.tables
        where table_schema='public' and table_type='BASE TABLE') as tables,
     (select count(*) from pg_policies where schemaname='public') as policies,
     (select count(*) from brands)                                as brands;
   ```

   Expect **42, 68, 6**.

4. **Wire the app to it.** Copy `.env.example` to `.env.local` and fill in the
   three Supabase values from Project Settings → API:

   ```
   NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
   NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   SUPABASE_SECRET_KEY=sb_secret_...
   ```

   Restart `npm run dev`. The sample-data banner disappears and the screens read
   real records.

5. **Create your first staff account.** Supabase → Authentication → Add user,
   then in the SQL Editor:

   ```sql
   insert into staff (auth_user_id, full_name, email, department)
   values ((select id from auth.users where email = 'you@ecogreenmovers.co.uk'),
           'Your Name', 'you@ecogreenmovers.co.uk', 'admin');

   -- The guard trigger is admin-only, so the very first grant bypasses it.
   alter table staff_brand_access disable trigger staff_brand_access_guard;
   insert into staff_brand_access (staff_id, brand_id, role)
   select s.id, b.id, 'admin'
   from staff s, brands b
   where s.email = 'you@ecogreenmovers.co.uk' and b.slug = 'ecogreen-movers';
   alter table staff_brand_access enable trigger staff_brand_access_guard;
   ```

---

## 3. Deploy

Vercel, free Hobby tier.

1. Push this to a Git repo, then import it at vercel.com.
2. **Set Root Directory to `crm`** if the repo has the app in a subfolder.
3. Add the same three environment variables, plus:

   ```
   CRON_SECRET=<any long random string>
   INTAKE_SIGNING_SECRET=<any long random string>
   ```

   `vercel.json` registers a 5-minute cron that drives the chase sequences. It
   returns 401 without `CRON_SECRET`, so set it or the sequences never run.

Providers are optional. With `STRIPE_SECRET_KEY`, `EMAIL_PROVIDER_API_KEY` and
`WHATSAPP_ACCESS_TOKEN` all empty, the flows still work: payment links are
local and marked paid by hand, email renders to `.tmp/mail/`, and WhatsApp and
SMS steps queue in the send queue for a person. Set a key, get the real
provider — no code changes.

---

## Commands

| Command | What it proves |
|---|---|
| `npm run dev` | Local development |
| `npm run build` | Production build |
| `npm run typecheck` | TypeScript strict |
| `npm test` | 81 unit tests over the pure domain layer |
| `npm run audit` | Accessibility, layout floors, keyboard and contrast, both themes (needs the app running) |
| `npm run db:verify` | Applies every migration to a throwaway Postgres and runs 92 SQL assertions (needs a local Postgres 16) |

---

## Before you quote a real customer

Every seeded rate card is flagged `provisional = true`. Those figures are
recommendations, not your prices, and congestion and ULEZ are seeded at zero
rather than guessed — a stale TfL rate loses money on every London job.
`DECISIONS.md` §2 explains each number and what to change.

## Where to read next

| File | What it covers |
|---|---|
| `RECOMMENDATIONS.md` | The full module map, the pricing matrix, and 54 improvements in build order |
| `DECISIONS.md` | The defaults chosen for you, and which need sign-off |
| `DESIGN.md` | The design system and the craft gate every screen must pass |
| `SPEC.md` | What is built, what is not, and the acceptance criteria |
| `PROGRESS.md` | Session-by-session log of what changed and why |
