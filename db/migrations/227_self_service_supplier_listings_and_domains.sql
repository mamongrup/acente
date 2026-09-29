-- Migration 227: Self-Service Supplier Onboarding Submissions and Multi-Domain Visibility
-- Supports self-service listing creation for suppliers and multi-domain marketplace delivery:
-- rezervasyonyap.com.tr (Domestic B2C / TRY) and reservationinturkey.com (Global B2C / Multilingual / EUR/USD).

CREATE TABLE IF NOT EXISTS agency.supplier_onboarding_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  company_name text NOT NULL,
  contact_name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  tax_id text NOT NULL DEFAULT '',
  tax_office text NOT NULL DEFAULT '',
  category_code text NOT NULL,
  listing_title text NOT NULL,
  locality text NOT NULL,
  description text NOT NULL DEFAULT '',
  currency char(3) NOT NULL DEFAULT 'TRY',
  price_minor bigint NOT NULL DEFAULT 0 CHECK(price_minor >= 0),
  guest_capacity int NOT NULL DEFAULT 2 CHECK(guest_capacity > 0),
  specs jsonb NOT NULL DEFAULT '{}'::jsonb,
  images jsonb NOT NULL DEFAULT '[]'::jsonb,
  documents jsonb NOT NULL DEFAULT '[]'::jsonb,
  domain_target text NOT NULL DEFAULT 'both' CHECK(domain_target IN ('both','rezervasyonyap','reservationinturkey')),
  status text NOT NULL DEFAULT 'submitted' CHECK(status IN ('draft','submitted','in_review','approved','rejected')),
  created_listing_id uuid REFERENCES agency.listings(id) ON DELETE SET NULL,
  reviewed_by uuid REFERENCES agency.users(id),
  reviewed_at timestamptz,
  admin_notes text NOT NULL DEFAULT '',
  ip_address text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agency_supplier_submissions_tenant_status_idx
  ON agency.supplier_onboarding_submissions(tenant_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS agency_supplier_submissions_category_idx
  ON agency.supplier_onboarding_submissions(category_code, locality);

ALTER TABLE agency.listings
  ADD COLUMN IF NOT EXISTS domain_visibility text NOT NULL DEFAULT 'all'
    CHECK(domain_visibility IN ('all','rezervasyonyap','reservationinturkey')),
  ADD COLUMN IF NOT EXISTS supplier_submission_id uuid
    REFERENCES agency.supplier_onboarding_submissions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS specs jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS images jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Idempotent approval function for agency administrators
CREATE OR REPLACE FUNCTION agency.approve_supplier_submission(
  p_tenant uuid,
  p_actor uuid,
  p_submission_id uuid,
  p_initial_status text DEFAULT 'published'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  v_sub record;
  v_listing_id uuid;
  v_code text;
BEGIN
  -- Verify actor permissions
  IF NOT EXISTS (
    SELECT 1 FROM agency.users u
    WHERE u.id = p_actor AND u.tenant_id = p_tenant AND u.active
      AND (u.membership_type IN ('owner','admin','staff')
        OR EXISTS (
          SELECT 1 FROM agency.user_roles ur
          JOIN agency.roles r ON r.id = ur.role_id
          WHERE ur.user_id = u.id AND r.tenant_id = p_tenant AND r.code IN ('owner','admin','staff')
        ))
  ) THEN
    RAISE EXCEPTION 'permission_denied: only admin/owner can approve supplier submissions';
  END IF;

  -- Lock submission row
  SELECT * INTO v_sub
  FROM agency.supplier_onboarding_submissions
  WHERE id = p_submission_id AND tenant_id = p_tenant
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'submission_not_found';
  END IF;

  IF v_sub.status = 'approved' AND v_sub.created_listing_id IS NOT NULL THEN
    RETURN v_sub.created_listing_id;
  END IF;

  -- Generate unique listing code
  v_code := lower(v_sub.category_code) || '-' || substr(md5(v_sub.id::text || clock_timestamp()::text), 1, 8);

  -- Insert approved listing into agency.listings
  INSERT INTO agency.listings (
    tenant_id,
    code,
    category,
    title,
    locality,
    description,
    currency,
    price_minor,
    status,
    source,
    domain_visibility,
    supplier_submission_id,
    specs,
    images
  ) VALUES (
    p_tenant,
    v_code,
    v_sub.category_code,
    v_sub.listing_title,
    v_sub.locality,
    v_sub.description,
    v_sub.currency,
    v_sub.price_minor,
    CASE
      WHEN p_initial_status = 'published' AND (v_sub.images IS NOT NULL AND jsonb_typeof(v_sub.images) = 'array' AND jsonb_array_length(v_sub.images) > 0) THEN 'published'
      ELSE 'draft'
    END,
    'manual',
    CASE WHEN v_sub.domain_target IN ('both', 'all') THEN 'all' ELSE v_sub.domain_target END,
    v_sub.id,
    v_sub.specs,
    v_sub.images
  )
  RETURNING id INTO v_listing_id;

  -- Update submission status
  UPDATE agency.supplier_onboarding_submissions
  SET status = 'approved',
      created_listing_id = v_listing_id,
      reviewed_by = p_actor,
      reviewed_at = now(),
      updated_at = now()
  WHERE id = p_submission_id;

  -- Audit log
  INSERT INTO agency.audit_logs(tenant_id, user_id, action, entity_type, entity_id, metadata)
  VALUES (
    p_tenant,
    p_actor,
    'supplier.submission_approved',
    'supplier_submission',
    p_submission_id,
    jsonb_build_object(
      'listing_id', v_listing_id,
      'code', v_code,
      'category', v_sub.category_code,
      'company_name', v_sub.company_name
    )
  );

  RETURN v_listing_id;
END;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.supplier_onboarding_submissions TO agency_app;
