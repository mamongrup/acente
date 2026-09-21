-- Give supplier inventory an explicit owner while preserving existing data.
-- Existing listings are assigned to the first active administrator of their
-- tenant; this keeps the current catalogue visible to administrators and
-- prevents an unowned listing from becoming editable by every supplier.
ALTER TABLE agency.listings
  ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES agency.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS agency_listings_owner_idx
  ON agency.listings(tenant_id, owner_user_id, updated_at DESC);

UPDATE agency.listings l
SET owner_user_id = (
  SELECT u.id
  FROM agency.users u
  WHERE u.tenant_id = l.tenant_id
    AND u.membership_type = 'admin'
    AND u.active
  ORDER BY u.created_at, u.id
  LIMIT 1
)
WHERE l.owner_user_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM agency.users u
    WHERE u.tenant_id = l.tenant_id
      AND u.membership_type = 'admin'
      AND u.active
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.listings TO agency_app;
