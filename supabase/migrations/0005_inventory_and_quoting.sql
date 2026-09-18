-- Inventory catalogue and quoting.

create table rooms (
  slug text primary key,
  name text not null,
  icon text not null,
  sort_order int not null default 0
);

create table items (
  slug text primary key,
  name text not null,
  room_slug text not null references rooms(slug) on delete restrict,
  icon text not null,
  volume_ft3 numeric(8,2) not null check (volume_ft3 > 0),
  crew_minutes int not null check (crew_minutes > 0),
  is_fragile boolean not null default false,
  requires_dismantle boolean not null default false,
  handling handling_class not null default 'standard',
  is_active boolean not null default true
);

create index items_room_idx on items (room_slug, name);

create table rate_cards (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  service_category customer_type not null,
  currency currency_code not null default 'GBP',
  effective_from date not null,
  effective_to date,
  -- True until the business signs the numbers off. Drives the PROVISIONAL
  -- PRICING watermark on the quote PDF. See DECISIONS.md §2.
  provisional boolean not null default true,
  rules jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One card per brand, service and start date; overlapping cards would make a
-- historical quote irreproducible.
create unique index rate_cards_unique_idx on rate_cards (brand_id, service_category, effective_from);

create table promo_codes (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  code text not null,
  kind text not null check (kind in ('percentage','fixed')),
  value numeric(10,4) not null,
  max_uses int,
  used_count int not null default 0,
  valid_from timestamptz,
  valid_to timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (brand_id, code)
);

create table quotes (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references brands(id) on delete cascade,
  lead_id uuid not null references leads(id) on delete cascade,
  reference text not null,
  version int not null default 1,
  status quote_status not null default 'draft',
  rate_card_id uuid references rate_cards(id) on delete restrict,
  prepared_by_staff_id uuid references staff(id) on delete set null,
  requires_manual_pricing boolean not null default false,
  manual_pricing_reasons text[] not null default '{}',
  packing packing_service not null default 'none',
  volume_ft3 numeric(10,2) not null default 0,
  crew_size int not null default 2,
  crew_minutes int not null default 0,
  road_distance_miles numeric(8,1),
  currency currency_code not null default 'GBP',
  net_minor bigint not null default 0,
  vat_minor bigint not null default 0,
  gross_minor bigint not null default 0,
  deposit_minor bigint not null default 0,
  fx_rate_to_gbp numeric(12,6) not null default 1,
  -- The frozen computation. The accepted PDF must be reproducible from this
  -- alone, months later, when a customer says "you quoted me less".
  pricing_snapshot jsonb,
  valid_until timestamptz,
  sent_at timestamptz,
  first_viewed_at timestamptz,
  accepted_at timestamptz,
  declined_at timestamptz,
  superseded_by_quote_id uuid references quotes(id) on delete set null,
  pdf_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (brand_id, reference, version)
);

create index quotes_lead_idx on quotes (lead_id, version desc);
create index quotes_chase_idx on quotes (status, first_viewed_at) where status in ('sent','viewed');
create index quotes_expiry_idx on quotes (valid_until) where status in ('sent','viewed');

create table quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references quotes(id) on delete cascade,
  item_slug text references items(slug) on delete restrict,
  room_slug text references rooms(slug) on delete restrict,
  custom_name text,
  quantity int not null check (quantity > 0),
  volume_ft3 numeric(8,2) not null,
  notes text,
  -- Either a catalogue item or a named custom one, never neither: a line with
  -- no identity is how an item goes missing between the quote and the van.
  constraint quote_items_identified check (item_slug is not null or custom_name is not null)
);

create index quote_items_quote_idx on quote_items (quote_id);

create table quote_lines (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references quotes(id) on delete cascade,
  rule_id text not null,
  kind quote_line_kind not null,
  label text not null,
  detail text,
  inputs jsonb not null default '{}'::jsonb,
  quantity numeric(10,2),
  unit_amount_minor bigint,
  net_minor bigint not null,
  vat_rate numeric(5,4) not null default 0.2000,
  sort_order int not null default 0
);

create index quote_lines_quote_idx on quote_lines (quote_id, sort_order);

-- ── Quote immutability ────────────────────────────────────────────────────
-- Once a quote leaves the building it is frozen. A change makes version N+1
-- and supersedes N. Enforced here rather than in application code because a
-- convention is not a guarantee, and this is the row a dispute turns on.

create or replace function private.reject_sent_quote_change()
returns trigger
language plpgsql
as $$
declare
  frozen_status public.quote_status[] := array['sent','viewed','accepted','expired','superseded','declined'];
begin
  if tg_op = 'DELETE' then
    if old.status = any (frozen_status) then
      raise exception 'Quote % has been sent and cannot be deleted; supersede it with a new version.', old.id
        using errcode = 'restrict_violation';
    end if;
    return old;
  end if;

  if old.status = any (frozen_status) then
    -- Status, view/acceptance timestamps and the supersede pointer are the
    -- only things a sent quote may still record about itself.
    if (new.net_minor, new.vat_minor, new.gross_minor, new.deposit_minor,
        new.pricing_snapshot, new.rate_card_id, new.volume_ft3, new.packing,
        new.currency, new.valid_until)
       is distinct from
       (old.net_minor, old.vat_minor, old.gross_minor, old.deposit_minor,
        old.pricing_snapshot, old.rate_card_id, old.volume_ft3, old.packing,
        old.currency, old.valid_until)
    then
      raise exception 'Quote % is sent and its pricing is frozen; create version %.', old.id, old.version + 1
        using errcode = 'restrict_violation';
    end if;
  end if;

  return new;
end;
$$;

create trigger quotes_freeze_after_send
  before update or delete on quotes
  for each row execute function private.reject_sent_quote_change();

create or replace function private.reject_sent_quote_child_change()
returns trigger
language plpgsql
as $$
declare
  parent uuid := coalesce(new.quote_id, old.quote_id);
  parent_status public.quote_status;
begin
  select q.status into parent_status from public.quotes q where q.id = parent;
  if parent_status in ('sent','viewed','accepted','expired','superseded','declined') then
    raise exception 'Quote % is sent; its lines and items are frozen.', parent
      using errcode = 'restrict_violation';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger quote_items_freeze
  before insert or update or delete on quote_items
  for each row execute function private.reject_sent_quote_child_change();

create trigger quote_lines_freeze
  before insert or update or delete on quote_lines
  for each row execute function private.reject_sent_quote_child_change();

create trigger rate_cards_touch before update on rate_cards for each row execute function private.touch_updated_at();
create trigger quotes_touch before update on quotes for each row execute function private.touch_updated_at();
