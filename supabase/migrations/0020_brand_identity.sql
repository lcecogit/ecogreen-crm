-- Real brand identity, read from the live sites rather than guessed.
--
-- Source: each site's Elementor global kit, via the WordPress connector.
-- Two of the six are actually branded today:
--
--   EcoGreen Movers   navy #161A36 · lime #7DB903 · off-white #F9F7F5 · Inter
--   Glasgow Moving    ink #1D1A16 · signal orange #E4581B · Instrument Sans
--
-- The other four still carry Elementor's factory defaults (#6EC1E4 / #61CE70),
-- and continuumgreen.co.uk is still titled "We Are Building Continuum Green".
-- Those defaults are NOT brands, so they are not seeded as if they were: those
-- four inherit the group's flagship palette and are flagged below, so nobody
-- later mistakes a theme default for a brand decision.

alter table brands
  add column if not exists accent_text_hex text,
  add column if not exists accent_text_dark_hex text,
  add column if not exists accent_contrast_hex text,
  add column if not exists brand_identity_confirmed boolean not null default false;

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
