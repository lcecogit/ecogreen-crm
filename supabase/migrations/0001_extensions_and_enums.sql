-- Extensions and the enumerated vocabulary of the system.
-- btree_gist is required by the job-assignment exclusion constraints in 0006:
-- they mix equality on a uuid with overlap on a tstzrange.

create extension if not exists "pgcrypto";
create extension if not exists "btree_gist";
create extension if not exists "pg_trgm";

create type staff_department as enum ('admin','sales','transport','movers','support','accounts');
create type brand_role       as enum ('admin','manager','sales','ops','crew','accounts','readonly');
create type organisation_type as enum ('corporate','public_sector','education','healthcare','agent');

-- The pipeline from the brief. Transitions are enforced in the domain layer
-- (src/domain/pipeline/status.ts) and every change appends to lead_events.
create type lead_status   as enum ('new','qualifying','quoted','chasing','booked','completed','reviewed','lost','duplicate');
create type customer_type as enum ('residential','commercial','office','specialist','clearance','storage');
create type lead_source_kind as enum ('website','provider','phone','whatsapp','referral','repeat','ppc','organic','walk_in');

create type quote_status    as enum ('draft','sent','viewed','accepted','expired','superseded','declined');
create type quote_line_kind as enum ('transport','labour','materials','surcharge','discount','storage');
create type packing_service as enum ('none','materials_only','part','full');
create type handling_class  as enum ('standard','heavy','fine_art','piano','it_equipment','laboratory','medical');

create type job_status      as enum ('booked','scheduled','in_progress','completed','cancelled');
create type assignment_role as enum ('lead_mover','mover','driver','supervisor','vehicle');

create type invoice_status  as enum ('draft','issued','part_paid','paid','overdue','void');
create type payment_method  as enum ('stripe','bank_transfer','cash','card_terminal');
create type payment_status  as enum ('pending','succeeded','failed','refunded','cancelled');
create type currency_code   as enum ('GBP','EUR','USD');

create type message_channel as enum ('email','sms','whatsapp','task');
create type message_direction as enum ('outbound','inbound');
create type outbox_status  as enum ('queued','sending','sent','failed','cancelled','needs_manual_send');
create type enrolment_status as enum ('active','stopped','completed');

create type target_period as enum ('day','week','month');
create type move_size     as enum ('small','medium','large','commercial','office');
create type data_request_kind as enum ('export','erasure');
create type retention_action  as enum ('anonymise','delete');
