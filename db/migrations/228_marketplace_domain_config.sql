-- Migration 228: Marketplace Multi-Domain Configuration and Submission Management
-- Supports rezervasyonyap.com.tr (domestic/TRY) and reservationinturkey.com (global/multilingual)
-- Adds public listing submission management for admin panel.

-- -----------------------------------------------------------------------
-- 1. Marketplace domain configuration table
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agency.marketplace_domains (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  domain_key text NOT NULL CHECK(domain_key IN ('rezervasyonyap','reservationinturkey','custom')),
  domain_host text NOT NULL,                   -- e.g. rezervasyonyap.com.tr
  display_name text NOT NULL DEFAULT '',
  default_currency char(3) NOT NULL DEFAULT 'TRY',
  default_language text NOT NULL DEFAULT 'tr',
  supported_languages text[] NOT NULL DEFAULT ARRAY['tr'],
  supported_currencies text[] NOT NULL DEFAULT ARRAY['TRY'],
  seo_title text NOT NULL DEFAULT '',
  seo_description text NOT NULL DEFAULT '',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id, domain_key),
  UNIQUE(domain_host)
);

CREATE INDEX IF NOT EXISTS agency_marketplace_domains_host_idx
  ON agency.marketplace_domains(domain_host) WHERE active;

-- -----------------------------------------------------------------------
-- 2. Seed default marketplace domains for all existing tenants
-- -----------------------------------------------------------------------
INSERT INTO agency.marketplace_domains (
  tenant_id, domain_key, domain_host,
  display_name, default_currency, default_language,
  supported_languages, supported_currencies,
  seo_title, seo_description, active
)
SELECT
  t.id,
  'rezervasyonyap',
  'rezervasyonyap.com.tr',
  'Rezervasyon Yap',
  'TRY',
  'tr',
  ARRAY['tr'],
  ARRAY['TRY','USD','EUR'],
  'Türkiye''nin En Kapsamlı Seyahat Rezervasyon Platformu',
  'Otel, tur, villa, yat ve daha fazlası için anlık rezervasyon yapın.',
  true
FROM agency.tenants t
ORDER BY t.created_at ASC
LIMIT 1
ON CONFLICT (domain_host) DO NOTHING;

INSERT INTO agency.marketplace_domains (
  tenant_id, domain_key, domain_host,
  display_name, default_currency, default_language,
  supported_languages, supported_currencies,
  seo_title, seo_description, active
)
SELECT
  t.id,
  'reservationinturkey',
  'reservationinturkey.com',
  'Reservation in Turkey',
  'EUR',
  'en',
  ARRAY['en','de','ru','ar','fr'],
  ARRAY['EUR','USD','GBP','TRY'],
  'Book Hotels, Tours & Activities in Turkey | Best Price Guarantee',
  'Discover and book the best hotels, tours, villas, yachts and experiences in Turkey.',
  true
FROM agency.tenants t
ORDER BY t.created_at ASC
LIMIT 1
ON CONFLICT (domain_host) DO NOTHING;

-- -----------------------------------------------------------------------
-- 3. Public listing submission management view (for admin panel)
-- -----------------------------------------------------------------------
CREATE OR REPLACE VIEW agency.v_listing_submissions AS
SELECT
  s.id,
  s.tenant_id,
  s.company_name,
  s.contact_name,
  s.email,
  s.phone,
  s.tax_id,
  s.category_code,
  s.listing_title,
  s.locality,
  s.description,
  s.currency,
  s.price_minor,
  s.domain_target,
  s.status,
  s.created_listing_id,
  s.reviewed_by,
  s.reviewed_at,
  s.admin_notes,
  s.ip_address,
  s.created_at,
  s.updated_at,
  u.email AS reviewer_email,
  l.code AS listing_code,
  l.status AS listing_status
FROM agency.supplier_onboarding_submissions s
LEFT JOIN agency.users u ON u.id = s.reviewed_by
LEFT JOIN agency.listings l ON l.id = s.created_listing_id;

-- -----------------------------------------------------------------------
-- 4. Reject submission function (mirrors approve)
-- -----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION agency.reject_supplier_submission(
  p_tenant uuid,
  p_actor uuid,
  p_submission_id uuid,
  p_reason text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
  -- Verify actor permissions
  IF NOT EXISTS (
    SELECT 1 FROM agency.users u
    WHERE u.id = p_actor AND u.tenant_id = p_tenant AND u.active
      AND (u.membership_type IN ('owner','admin','staff')
        OR EXISTS (
          SELECT 1 FROM agency.user_roles ur
          JOIN agency.roles r ON r.id = ur.role_id
          WHERE ur.user_id = u.id AND r.tenant_id = p_tenant
            AND r.code IN ('owner','admin','staff')
        ))
  ) THEN
    RAISE EXCEPTION 'permission_denied: only admin/owner can reject supplier submissions';
  END IF;

  UPDATE agency.supplier_onboarding_submissions
  SET status = 'rejected',
      reviewed_by = p_actor,
      reviewed_at = now(),
      admin_notes = p_reason,
      updated_at = now()
  WHERE id = p_submission_id AND tenant_id = p_tenant
    AND status IN ('submitted','in_review');

  IF NOT FOUND THEN
    RAISE EXCEPTION 'submission_not_found_or_invalid_state';
  END IF;

  INSERT INTO agency.audit_logs(tenant_id, user_id, action, entity_type, entity_id, metadata)
  VALUES (
    p_tenant, p_actor, 'supplier.submission_rejected',
    'supplier_submission', p_submission_id,
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

-- -----------------------------------------------------------------------
-- 5. Rate limiting index for public listing submissions
-- -----------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS agency_supplier_submissions_ip_created_idx
  ON agency.supplier_onboarding_submissions(ip_address, created_at DESC);

-- -----------------------------------------------------------------------
-- 6. Grants
-- -----------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON agency.marketplace_domains TO agency_app;
GRANT SELECT ON agency.v_listing_submissions TO agency_app;
GRANT EXECUTE ON FUNCTION agency.reject_supplier_submission(uuid,uuid,uuid,text) TO agency_app;
