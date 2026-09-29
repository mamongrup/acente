-- Final cleanup/guards after the shared category + sealed secret migration.
-- The application may still read old plain values for backward-compatible
-- migration, but new writes must not reintroduce them.

DELETE FROM agency.categories c
WHERE c.code IN (
  'villa','VILLA','OTEL','YAT','TUR','AKTIVITE','UCUS','ARAC',
  'KRUVAZIYER','HAC_UMRE','VIZE','FERIBOT','TRANSFER','SEZLONG',
  'SINEMA','ETKINLIK','RESTORAN','OTOBUS'
)
  AND NOT c.active
  AND NOT EXISTS (
    SELECT 1 FROM agency.listings l
    WHERE l.tenant_id = c.tenant_id AND l.category = c.code
  )
  AND NOT EXISTS (
    SELECT 1 FROM agency.category_fields f
    WHERE f.category_id = c.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM agency.category_filter_groups g
    WHERE g.category_code = c.code
  );

ALTER TABLE agency.settings
  DROP CONSTRAINT IF EXISTS agency_settings_no_plain_secret_keys;
ALTER TABLE agency.settings
  ADD CONSTRAINT agency_settings_no_plain_secret_keys
  CHECK (
    key NOT IN (
      'parampos_password',
      'parampos_guid',
      'smtp_password',
      'ai_api_key',
      'netgsm_password'
    )
  ) NOT VALID;

ALTER TABLE agency.integrations
  DROP CONSTRAINT IF EXISTS agency_integrations_no_plain_secret_credentials;
ALTER TABLE agency.integrations
  ADD CONSTRAINT agency_integrations_no_plain_secret_credentials
  CHECK (
    NOT (
      credentials ?| array[
        'password',
        'api_key',
        'token',
        'netgsm_pass',
        'whatsapp_token',
        'access_token',
        'pinterest_token',
        'parampos_password',
        'parampos_guid',
        'guid'
      ]
    )
  ) NOT VALID;

ALTER TABLE agency.categories
  DROP CONSTRAINT IF EXISTS agency_categories_no_legacy_main_codes;
ALTER TABLE agency.categories
  ADD CONSTRAINT agency_categories_no_legacy_main_codes
  CHECK (
    code NOT IN (
      'villa','VILLA','OTEL','YAT','TUR','AKTIVITE','UCUS','ARAC',
      'KRUVAZIYER','HAC_UMRE','VIZE','FERIBOT','TRANSFER','SEZLONG',
      'SINEMA','ETKINLIK','RESTORAN','OTOBUS'
    )
  ) NOT VALID;

ALTER TABLE agency.listings
  DROP CONSTRAINT IF EXISTS agency_listings_no_legacy_main_categories;
ALTER TABLE agency.listings
  ADD CONSTRAINT agency_listings_no_legacy_main_categories
  CHECK (
    category NOT IN (
      'villa','VILLA','OTEL','YAT','TUR','AKTIVITE','UCUS','ARAC',
      'KRUVAZIYER','HAC_UMRE','VIZE','FERIBOT','TRANSFER','SEZLONG',
      'SINEMA','ETKINLIK','RESTORAN','OTOBUS'
    )
  ) NOT VALID;

ALTER TABLE agency.settings
  VALIDATE CONSTRAINT agency_settings_no_plain_secret_keys;

ALTER TABLE agency.integrations
  VALIDATE CONSTRAINT agency_integrations_no_plain_secret_credentials;

ALTER TABLE agency.categories
  VALIDATE CONSTRAINT agency_categories_no_legacy_main_codes;

ALTER TABLE agency.listings
  VALIDATE CONSTRAINT agency_listings_no_legacy_main_categories;
