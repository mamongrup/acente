-- Align agency listing lifecycle statuses with supplier-listing contract v1.1.0.

UPDATE agency.listings
SET status='pending_review', updated_at=now()
WHERE status='review';

ALTER TABLE agency.listings
  DROP CONSTRAINT IF EXISTS listings_status_check;

ALTER TABLE agency.listings
  ADD CONSTRAINT listings_status_check
  CHECK (status IN ('draft','pending_review','published','paused','archived'));

CREATE OR REPLACE FUNCTION agency.supplier_listing_lifecycle_statuses()
RETURNS TABLE(data text[])
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog AS $$
  SELECT ARRAY[status_code, position::text]
  FROM (
    VALUES
      ('draft',10),
      ('pending_review',20),
      ('published',30),
      ('paused',40),
      ('archived',50)
  ) v(status_code, position)
  ORDER BY position;
$$;

GRANT EXECUTE ON FUNCTION agency.supplier_listing_lifecycle_statuses() TO agency_app;
