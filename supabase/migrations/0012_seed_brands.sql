-- Brand seed.
--
-- Accent colours are the contrast-verified recommendations from DECISIONS.md
-- §1 — every light step clears 4.5:1 on white and every dark step clears
-- 4.5:1 on #0B0B0C. Replace with the real brand values when they arrive; if a
-- real colour fails, keep it for the logo and darken it for interactive use.
--
-- Bank details, VAT and company numbers are left null on purpose. They print
-- on customer-facing invoices, so a placeholder is worse than a blank.

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
