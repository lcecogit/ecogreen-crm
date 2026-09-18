-- Retention policy seed.
--
-- These are the conservative recommendations from DECISIONS.md §4, chosen so
-- that erring costs storage rather than compliance. They need legal sign-off
-- before they are relied on, and two points need a decision:
--
--   * Scotland's prescription period differs from England & Wales, and two of
--     the six brands trade there. The contract figure below is the England &
--     Wales one.
--   * Cross-brand data sharing needs a stated lawful basis. Until there is
--     one, a customer's record stays inside the brand that captured it.

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
