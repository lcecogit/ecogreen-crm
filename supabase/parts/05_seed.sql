-- ==========================================================================
--  EcoGreen Group CRM — PART 5 — SEED DATA: brands, catalogue, rate cards, sequences
--
--  Safe to re-run. Run the parts in order: 1, 2, 3, 4, 5.
-- ==========================================================================

-- ---------------------------------------------------------------------------
-- Bootstrap. Present at the top of EVERY part so each one stands alone and no
-- part can fail with "schema private does not exist". Helpers live outside
-- `public` so that RLS policies which call them cannot recurse back through
-- the very tables those policies protect.
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create or replace function private.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Prerequisite check: a clear message beats a cryptic error.
do $precheck$
begin
    if to_regclass('public.brands') is null then
      raise exception 'Run PARTS 1-3 first — table "brands" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.rooms') is null then
      raise exception 'Run PARTS 1-3 first — table "rooms" does not exist.'
        using errcode = 'undefined_table';
    end if;
    if to_regclass('public.rate_cards') is null then
      raise exception 'Run PARTS 1-3 first — table "rate_cards" does not exist.'
        using errcode = 'undefined_table';
    end if;
end
$precheck$;

-- Guarded: if any brand already exists the whole block is skipped, so
-- re-running this script never duplicates the catalogue or the rate cards.
do $seed$
begin
  if exists (select 1 from public.brands) then
    raise notice 'Seed data already present - skipping.';
    return;
  end if;


insert into brands (slug, code, name, primary_domain, accent_hex, accent_dark_hex, email_from, email_reply_to, phone)
values
  ('ecogreen-movers',              'EGM', 'EcoGreen Movers',              'ecogreenmovers.co.uk',              '#18794E', '#3FBF84', 'quotes@ecogreenmovers.co.uk',              'hello@ecogreenmovers.co.uk',              null),
  ('eco-london-movers',            'ELM', 'Eco London Movers',            'ecolondonmovers.co.uk',             '#0B5FA5', '#4DA3E8', 'quotes@ecolondonmovers.co.uk',             'hello@ecolondonmovers.co.uk',             null),
  ('continuum-green',              'CG',  'Continuum Green',              'continuumgreen.co.uk',              '#146B63', '#35B3A6', 'quotes@continuumgreen.co.uk',              'hello@continuumgreen.co.uk',              null),
  ('removals-company-manchester',  'RCM', 'Removals Company Manchester',  'removalscompanymanchester.co.uk',   '#B42318', '#F0736A', 'quotes@removalscompanymanchester.co.uk',   'hello@removalscompanymanchester.co.uk',   null),
  ('edinburgh-moving',             'EDM', 'Edinburgh Moving',             'edinburghmoving.co.uk',             '#43467F', '#9195DB', 'quotes@edinburghmoving.co.uk',             'hello@edinburghmoving.co.uk',             null),
  ('glasgow-moving',               'GM',  'Glasgow Moving',               'glasgowmoving.co.uk',               '#1D4ED8', '#7CA0F5', 'quotes@glasgowmoving.co.uk',               'hello@glasgowmoving.co.uk',               null);
-- Branches. Outward codes are left empty rather than guessed: they drive
-- distance banding and branch routing, and a wrong list silently misroutes.
insert into branches (brand_id, name, city)
select b.id, v.name, v.city
from brands b
join (values
  ('ecogreen-movers', 'London',     'London'),
  ('ecogreen-movers', 'Manchester', 'Manchester'),
  ('ecogreen-movers', 'Edinburgh',  'Edinburgh'),
  ('eco-london-movers', 'London',   'London'),
  ('continuum-green', 'London',     'London'),
  ('removals-company-manchester', 'Manchester', 'Manchester'),
  ('edinburgh-moving', 'Edinburgh', 'Edinburgh'),
  ('glasgow-moving', 'Glasgow',     'Glasgow')
) as v(brand_slug, name, city) on v.brand_slug = b.slug;
-- Services, one row per brand per category actually offered.
insert into services (brand_id, slug, name, category)
select b.id, v.slug, v.name, v.category::customer_type
from brands b
cross join (values
  ('home-removals',        'Home removals',            'residential'),
  ('commercial-removals',  'Commercial removals',      'commercial'),
  ('office-relocation',    'Office relocation',        'office'),
  ('specialist-moves',     'Specialist relocations',   'specialist'),
  ('clearance',            'Clearance and disposal',   'clearance'),
  ('storage',              'Storage',                  'storage')
) as v(slug, name, category);
-- Lead sources and lost reasons, per brand.
insert into lead_sources (brand_id, kind, name)
select b.id, v.kind::lead_source_kind, v.name
from brands b
cross join (values
  ('website',  'Website enquiry form'),
  ('website',  'Embedded quote widget'),
  ('phone',    'Inbound call'),
  ('whatsapp', 'WhatsApp'),
  ('organic',  'Google organic'),
  ('ppc',      'Google Ads'),
  ('referral', 'Referral'),
  ('repeat',   'Repeat customer'),
  ('provider', 'Lead provider')
) as v(kind, name);
insert into lost_reasons (brand_id, label, sort_order)
select b.id, v.label, v.sort_order
from brands b
cross join (values
  ('Price too high', 1),
  ('Booked a competitor', 2),
  ('Move cancelled or postponed', 3),
  ('Date unavailable', 4),
  ('No response after chasing', 5),
  ('Out of area', 6),
  ('Service not offered', 7),
  ('Duplicate enquiry', 8)
) as v(label, sort_order);
insert into rooms (slug, name, icon, sort_order) values
  ('living_room', 'Living room', 'sofa', 1),
  ('dining_room', 'Dining room', 'dining-table', 2),
  ('kitchen', 'Kitchen', 'kitchen', 3),
  ('bedroom', 'Bedroom', 'bed', 4),
  ('nursery', 'Nursery', 'cot', 5),
  ('bathroom', 'Bathroom', 'bath', 6),
  ('study', 'Study / home office', 'desk', 7),
  ('garage', 'Garage / shed', 'garage', 8),
  ('garden', 'Garden', 'plant', 9),
  ('loft', 'Loft / storage', 'boxes', 10),
  ('office', 'Commercial office', 'office', 11),
  ('specialist', 'Specialist items', 'shield', 12);
insert into items (slug, name, room_slug, icon, volume_ft3, crew_minutes, is_fragile, requires_dismantle, handling) values
  ('sofa_2', 'Sofa, 2-seater', 'living_room', 'sofa', 20.00, 12, false, false, 'standard'),
  ('sofa_3', 'Sofa, 3-seater', 'living_room', 'sofa', 25.00, 15, false, false, 'standard'),
  ('sofa_corner', 'Corner sofa', 'living_room', 'sofa', 45.00, 25, false, true, 'standard'),
  ('armchair', 'Armchair', 'living_room', 'armchair', 12.00, 8, false, false, 'standard'),
  ('coffee_table', 'Coffee table', 'living_room', 'table', 8.00, 5, false, false, 'standard'),
  ('tv_55', 'Television, up to 55"', 'living_room', 'tv', 8.00, 8, true, false, 'standard'),
  ('tv_75', 'Television, over 55"', 'living_room', 'tv', 14.00, 12, true, false, 'standard'),
  ('bookcase', 'Bookcase', 'living_room', 'bookcase', 20.00, 12, false, true, 'standard'),
  ('rug_large', 'Rug, large', 'living_room', 'rug', 6.00, 5, false, false, 'standard'),
  ('floor_lamp', 'Floor lamp', 'living_room', 'lamp', 5.00, 4, false, false, 'standard'),
  ('dining_table_4', 'Dining table, seats 4', 'dining_room', 'dining-table', 20.00, 14, false, true, 'standard'),
  ('dining_table_8', 'Dining table, seats 6-8', 'dining_room', 'dining-table', 32.00, 20, false, true, 'standard'),
  ('dining_chair', 'Dining chair', 'dining_room', 'chair', 6.00, 3, false, false, 'standard'),
  ('sideboard', 'Sideboard', 'dining_room', 'sideboard', 25.00, 15, false, false, 'standard'),
  ('display_cabinet', 'Display cabinet', 'dining_room', 'cabinet', 28.00, 18, true, false, 'standard'),
  ('fridge_freezer', 'Fridge freezer', 'kitchen', 'fridge', 30.00, 20, false, false, 'heavy'),
  ('under_counter_fridge', 'Under-counter fridge', 'kitchen', 'fridge', 12.00, 10, false, false, 'standard'),
  ('washing_machine', 'Washing machine', 'kitchen', 'washer', 12.00, 15, false, false, 'heavy'),
  ('dishwasher', 'Dishwasher', 'kitchen', 'dishwasher', 12.00, 12, false, false, 'heavy'),
  ('cooker', 'Cooker / range', 'kitchen', 'cooker', 20.00, 18, false, false, 'heavy'),
  ('microwave', 'Microwave', 'kitchen', 'microwave', 4.00, 3, false, false, 'standard'),
  ('kitchen_box', 'Kitchen box, packed', 'kitchen', 'box', 4.00, 2, true, false, 'standard'),
  ('bed_single', 'Bed, single', 'bedroom', 'bed', 20.00, 14, false, true, 'standard'),
  ('bed_double', 'Bed, double', 'bedroom', 'bed', 30.00, 18, false, true, 'standard'),
  ('bed_king', 'Bed, king or super king', 'bedroom', 'bed', 40.00, 22, false, true, 'standard'),
  ('mattress_double', 'Mattress, double', 'bedroom', 'mattress', 18.00, 10, false, false, 'standard'),
  ('wardrobe_single', 'Wardrobe, single', 'bedroom', 'wardrobe', 30.00, 18, false, true, 'standard'),
  ('wardrobe_double', 'Wardrobe, double', 'bedroom', 'wardrobe', 40.00, 25, false, true, 'standard'),
  ('chest_drawers', 'Chest of drawers', 'bedroom', 'drawers', 18.00, 12, false, false, 'standard'),
  ('bedside_table', 'Bedside table', 'bedroom', 'table', 6.00, 4, false, false, 'standard'),
  ('mirror_large', 'Mirror, large', 'bedroom', 'mirror', 5.00, 6, true, false, 'standard'),
  ('cot', 'Cot / cot bed', 'nursery', 'cot', 18.00, 12, false, true, 'standard'),
  ('changing_table', 'Changing table', 'nursery', 'table', 12.00, 8, false, false, 'standard'),
  ('pushchair', 'Pushchair', 'nursery', 'pushchair', 8.00, 4, false, false, 'standard'),
  ('bathroom_cabinet', 'Bathroom cabinet', 'bathroom', 'cabinet', 8.00, 6, false, false, 'standard'),
  ('bathroom_box', 'Bathroom box, packed', 'bathroom', 'box', 4.00, 2, false, false, 'standard'),
  ('desk', 'Desk', 'study', 'desk', 20.00, 14, false, true, 'standard'),
  ('office_chair', 'Office chair', 'study', 'chair', 10.00, 5, false, false, 'standard'),
  ('filing_cabinet', 'Filing cabinet', 'study', 'cabinet', 14.00, 12, false, false, 'heavy'),
  ('desktop_computer', 'Desktop computer', 'study', 'computer', 6.00, 6, true, false, 'standard'),
  ('printer', 'Printer', 'study', 'printer', 6.00, 5, true, false, 'standard'),
  ('bicycle', 'Bicycle', 'garage', 'bicycle', 12.00, 6, false, false, 'standard'),
  ('lawnmower', 'Lawnmower', 'garage', 'mower', 12.00, 8, false, false, 'standard'),
  ('tool_chest', 'Tool chest', 'garage', 'toolbox', 14.00, 12, false, false, 'heavy'),
  ('workbench', 'Workbench', 'garage', 'workbench', 25.00, 18, false, false, 'heavy'),
  ('bbq', 'Barbecue', 'garden', 'bbq', 15.00, 10, false, false, 'standard'),
  ('garden_table_set', 'Garden table and chairs', 'garden', 'dining-table', 30.00, 18, false, false, 'standard'),
  ('plant_pot_large', 'Plant pot, large', 'garden', 'plant', 8.00, 6, false, false, 'heavy'),
  ('box_small', 'Box, standard (small)', 'loft', 'box', 2.00, 1, false, false, 'standard'),
  ('box_large', 'Box, double-walled (large)', 'loft', 'box', 4.00, 2, false, false, 'standard'),
  ('wardrobe_box', 'Wardrobe box', 'loft', 'wardrobe-box', 12.00, 4, false, false, 'standard'),
  ('suitcase', 'Suitcase', 'loft', 'suitcase', 4.00, 2, false, false, 'standard'),
  ('storage_crate', 'Storage crate', 'loft', 'crate', 5.00, 2, false, false, 'standard'),
  ('office_desk', 'Office desk', 'office', 'desk', 22.00, 15, false, true, 'standard'),
  ('office_pedestal', 'Desk pedestal', 'office', 'drawers', 8.00, 6, false, false, 'standard'),
  ('meeting_table', 'Meeting table', 'office', 'dining-table', 40.00, 25, false, true, 'standard'),
  ('office_storage_unit', 'Office storage unit', 'office', 'cabinet', 25.00, 16, false, false, 'standard'),
  ('server_rack', 'Server rack', 'office', 'server', 35.00, 45, true, false, 'it_equipment'),
  ('photocopier', 'Photocopier', 'office', 'printer', 30.00, 35, false, false, 'heavy'),
  ('piano_upright', 'Piano, upright', 'specialist', 'piano', 45.00, 60, false, false, 'piano'),
  ('piano_grand', 'Piano, grand', 'specialist', 'piano', 80.00, 120, false, true, 'piano'),
  ('artwork_framed', 'Artwork, framed', 'specialist', 'art', 6.00, 20, true, false, 'fine_art'),
  ('sculpture', 'Sculpture', 'specialist', 'art', 15.00, 30, true, false, 'fine_art'),
  ('safe', 'Safe', 'specialist', 'safe', 20.00, 45, false, false, 'heavy'),
  ('lab_equipment', 'Laboratory equipment', 'specialist', 'flask', 20.00, 40, true, false, 'laboratory'),
  ('medical_equipment', 'Medical equipment', 'specialist', 'medical', 25.00, 40, true, false, 'medical'),
  ('antique_furniture', 'Antique furniture', 'specialist', 'antique', 25.00, 30, true, false, 'fine_art');
insert into rate_cards (brand_id, service_category, effective_from, provisional, rules)
select b.id, v.category::customer_type, v.effective_from::date, v.provisional, v.rules
from brands b
cross join (values
  ('residential', '2026-01-01', true, '{"minimumChargeMinor":18000,"volumeBands":[{"upToFt3":250,"perFt3Minor":90},{"upToFt3":500,"perFt3Minor":70},{"upToFt3":900,"perFt3Minor":55},{"upToFt3":1400,"perFt3Minor":45},{"upToFt3":null,"perFt3Minor":38}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":2800,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('commercial', '2026-01-01', true, '{"minimumChargeMinor":35000,"volumeBands":[{"upToFt3":250,"perFt3Minor":110},{"upToFt3":500,"perFt3Minor":85},{"upToFt3":900,"perFt3Minor":68},{"upToFt3":1400,"perFt3Minor":55},{"upToFt3":null,"perFt3Minor":46}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":3200,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('office', '2026-01-01', true, '{"minimumChargeMinor":35000,"volumeBands":[{"upToFt3":250,"perFt3Minor":110},{"upToFt3":500,"perFt3Minor":85},{"upToFt3":900,"perFt3Minor":68},{"upToFt3":1400,"perFt3Minor":55},{"upToFt3":null,"perFt3Minor":46}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":3200,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('specialist', '2026-01-01', true, '{"minimumChargeMinor":50000,"volumeBands":[{"upToFt3":250,"perFt3Minor":140},{"upToFt3":500,"perFt3Minor":110},{"upToFt3":900,"perFt3Minor":90},{"upToFt3":1400,"perFt3Minor":75},{"upToFt3":null,"perFt3Minor":60}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":3800,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('clearance', '2026-01-01', true, '{"minimumChargeMinor":15000,"volumeBands":[{"upToFt3":250,"perFt3Minor":70},{"upToFt3":500,"perFt3Minor":55},{"upToFt3":900,"perFt3Minor":44},{"upToFt3":1400,"perFt3Minor":36},{"upToFt3":null,"perFt3Minor":30}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":2600,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb),
  ('storage', '2026-01-01', true, '{"minimumChargeMinor":12000,"volumeBands":[{"upToFt3":250,"perFt3Minor":60},{"upToFt3":500,"perFt3Minor":48},{"upToFt3":900,"perFt3Minor":38},{"upToFt3":1400,"perFt3Minor":32},{"upToFt3":null,"perFt3Minor":28}],"includedMiles":20,"perMileMinor":180,"includedMovers":2,"additionalMoverPerHourMinor":2600,"perFloorWithoutLiftMinor":2500,"longCarryThresholdM":25,"longCarryMinor":3000,"packingPerFt3Minor":{"none":0,"materials_only":0,"part":35,"full":75},"materialUnitMinor":{"box_small":250,"box_large":350,"wardrobe_box":1200,"bubble_wrap_roll":1500,"packing_paper_pack":1200,"tape_roll":300,"mattress_cover":600,"sofa_cover":800,"crate_rental_week":800,"eco_crate_rental_week":900},"weekendMultiplier":1.15,"bankHolidayMultiplier":1.3,"peakSeasonMultiplier":1.1,"peakMonths":[6,7,8,9],"peakMonthEndDays":3,"peakMonthStartDays":2,"bankHolidays":[],"congestionPerVehiclePerDayMinor":0,"ulezPerVehiclePerDayMinor":0,"fuelSurchargeRate":0,"vatRate":0.2,"depositPercentage":0.25,"depositMinimumMinor":10000,"manualPricing":{"declaredValueOverMinor":1000000,"volumeOverFt3":2500,"distanceOverMiles":400}}'::jsonb)
) as v(category, effective_from, provisional, rules);
insert into retention_policies (entity_type, retain_days, basis, action) values
  ('invoices',            2555, 'UK company and HMRC record-keeping (6 years + current year)', 'anonymise'),
  ('payments',            2555, 'UK company and HMRC record-keeping',                          'anonymise'),
  ('jobs_completed',      2555, 'Contract limitation period (England & Wales)',                'anonymise'),
  ('quotes_accepted',     2555, 'Contract limitation period',                                  'anonymise'),
  ('job_sheets',          2555, 'Claims evidence window',                                      'anonymise'),
  ('leads_unconverted',    730, 'No lawful basis to retain beyond active interest',            'delete'),
  ('quotes_unaccepted',    730, 'Follows the lead that produced it',                           'delete'),
  ('partial_submissions',   90, 'Recovery window only',                                        'delete'),
  ('marketing_consent',    730, 'Consent is not indefinite; 24 months of no engagement',       'delete'),
  ('message_log',          395, 'Behavioural analytics norm (13 months)',                      'delete'),
  ('customer_portal_tokens',  7, 'Single-use access tokens',                                   'delete'),
  ('staff_records',       2555, 'Employment record-keeping norm',                              'anonymise'),
  ('audit_log',           2555, 'Kept for the full financial period; never editable',          'anonymise');
insert into sequences (brand_id, key, name, description)
select null, v.key, v.name, v.description
from (values
  ('lead_acknowledgement', 'Enquiry acknowledgement', 'Sent immediately, at any hour. An enquiry that arrives at 2 a.m. is answered at 2 a.m. — this is the fix for overnight lead loss.'),
  ('quote_chase', '48-hour quote chase', 'The core of the brief: a quote viewed but not accepted within 48 hours is chased, then chased again, then handed to a human.'),
  ('quote_expiry_warning', 'Quote expiry warning', 'Warns before a fixed price lapses, rather than letting it lapse silently.'),
  ('abandoned_inventory', 'Abandoned inventory recovery', 'Recovers a half-finished inventory from the web form.'),
  ('booking_confirmation', 'Booking confirmation', 'Transactional. Goes out immediately regardless of hour or cap.'),
  ('pre_move_reminder', 'Pre-move reminder', 'Three days out, then the evening before.'),
  ('payment_retry', 'Payment retry', 'A failed or expired payment never silently cancels a booking — it chases, then raises a task.'),
  ('review_request', 'Review request', 'Sent the day after completion, while the move is fresh. Review lag is on the problem list; the fix is timing, not nagging.')
) as v(key, name, description);
insert into sequence_steps (sequence_id, step_order, delay_minutes, channel, template_key, stop_conditions, respect_quiet_hours, counts_toward_frequency_cap)
select s.id, v.step_order, v.delay_minutes, v.channel::message_channel, v.template_key, v.stop_conditions, v.respect_quiet_hours, v.counts_toward_cap
from (values
  ('lead_acknowledgement', 1, 0, 'email', 'lead_acknowledgement', array['unsubscribed','manual_stop']::text[], false, false),
  ('quote_chase', 1, 2880, 'email', 'quote_chase_1', array['unsubscribed','manual_stop','lead_lost','quote_accepted','customer_replied','quote_expired']::text[], true, true),
  ('quote_chase', 2, 5760, 'whatsapp', 'quote_chase_2', array['unsubscribed','manual_stop','lead_lost','quote_accepted','customer_replied','quote_expired']::text[], true, true),
  ('quote_chase', 3, 10080, 'task', 'quote_chase_call_task', array['unsubscribed','manual_stop','lead_lost','quote_accepted','quote_expired']::text[], false, false),
  ('quote_expiry_warning', 1, 0, 'email', 'quote_expiry_warning', array['unsubscribed','manual_stop','lead_lost','quote_accepted','quote_expired']::text[], true, true),
  ('abandoned_inventory', 1, 120, 'email', 'abandoned_inventory', array['unsubscribed','manual_stop','lead_lost','quote_accepted','customer_replied']::text[], true, true),
  ('booking_confirmation', 1, 0, 'email', 'booking_confirmation', array['manual_stop']::text[], false, false),
  ('pre_move_reminder', 1, 0, 'email', 'pre_move_reminder_3d', array['manual_stop','unsubscribed']::text[], true, false),
  ('pre_move_reminder', 2, 2880, 'whatsapp', 'pre_move_reminder_1d', array['manual_stop','unsubscribed']::text[], true, false),
  ('payment_retry', 1, 60, 'email', 'payment_retry_1', array['payment_received','manual_stop']::text[], true, false),
  ('payment_retry', 2, 1440, 'task', 'payment_retry_task', array['payment_received','manual_stop']::text[], false, false),
  ('review_request', 1, 1440, 'email', 'review_request_1', array['unsubscribed','manual_stop','lead_lost','customer_replied']::text[], true, true),
  ('review_request', 2, 7200, 'whatsapp', 'review_request_2', array['unsubscribed','manual_stop','lead_lost','customer_replied']::text[], true, true)
) as v(sequence_key, step_order, delay_minutes, channel, template_key, stop_conditions, respect_quiet_hours, counts_toward_cap)
join sequences s on s.key = v.sequence_key and s.brand_id is null;

end
$seed$;

-- Brand identity. These are UPDATEs, so they run on every install and stay
-- correct whether or not the seed block above was skipped.

comment on column brands.accent_hex is
  'Accent as a FILL. Not guaranteed to pass contrast as text — use accent_text_hex for that.';
comment on column brands.accent_contrast_hex is
  'What sits ON the accent fill. For EcoGreen this is navy, not white: white on the brand lime measures 2.38:1 and fails AA, navy on it is 7.14:1.';
comment on column brands.brand_identity_confirmed is
  'False means the values here are the group default standing in for a brand that has not been designed yet.';

update brands set
  accent_hex = '#7DB903',
  accent_dark_hex = '#7DB903',
  accent_text_hex = '#235F2A',
  accent_text_dark_hex = '#97DD09',
  accent_contrast_hex = '#161A36',
  email_from = 'info@ecogreenmovers.co.uk',
  email_reply_to = 'info@ecogreenmovers.co.uk',
  logo_path = 'https://ecogreenmovers.co.uk/wp-content/uploads/2023/11/EcoGreen-Movers-commercial-Movers-Office-Movers-Horizontal-with-tag-line.webp',
  brand_identity_confirmed = true
where slug = 'ecogreen-movers';

update brands set
  accent_hex = '#E4581B',
  accent_dark_hex = '#E4581B',
  accent_text_hex = '#B8420E',
  accent_text_dark_hex = '#E4581B',
  accent_contrast_hex = '#1D1A16',
  brand_identity_confirmed = true
where slug = 'glasgow-moving';

-- Awaiting a real identity: the group palette, explicitly marked as such.
update brands set
  accent_hex = '#7DB903',
  accent_dark_hex = '#7DB903',
  accent_text_hex = '#235F2A',
  accent_text_dark_hex = '#97DD09',
  accent_contrast_hex = '#161A36',
  brand_identity_confirmed = false
where slug in ('eco-london-movers', 'continuum-green', 'removals-company-manchester', 'edinburgh-moving');
