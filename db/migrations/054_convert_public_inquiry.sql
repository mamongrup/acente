-- 054: convert listing-less public leads atomically. This is a function because
-- a data-changing CTE cannot reliably pass a newly inserted customer through
-- several sibling CTEs on every supported PostgreSQL plan.
CREATE OR REPLACE FUNCTION agency.convert_public_inquiry(p_inquiry_id uuid, p_tenant_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency, public
AS $$
DECLARE
  inquiry_row agency.public_inquiries%ROWTYPE;
  customer_id uuid;
  reference text;
  safe_listing uuid;
  safe_currency char(3);
BEGIN
  SELECT * INTO inquiry_row
  FROM agency.public_inquiries
  WHERE id = p_inquiry_id
    AND tenant_id = p_tenant_id
    AND status <> 'closed'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT c.id INTO customer_id
  FROM agency.customers c
  WHERE c.tenant_id = p_tenant_id
    AND (
      (NULLIF(trim(inquiry_row.email), '') IS NOT NULL
        AND lower(coalesce(c.email, '')) = lower(trim(inquiry_row.email)))
      OR (NULLIF(trim(inquiry_row.phone), '') IS NOT NULL
        AND c.phone = trim(inquiry_row.phone))
    )
  ORDER BY c.created_at
  LIMIT 1;

  IF customer_id IS NULL THEN
    INSERT INTO agency.customers(tenant_id, full_name, email, phone)
    VALUES (
      p_tenant_id,
      inquiry_row.full_name,
      NULLIF(lower(trim(inquiry_row.email)), ''),
      trim(inquiry_row.phone)
    )
    RETURNING id INTO customer_id;
  ELSE
    UPDATE agency.customers
    SET full_name = inquiry_row.full_name,
        email = COALESCE(NULLIF(lower(trim(inquiry_row.email)), ''), email),
        phone = COALESCE(NULLIF(trim(inquiry_row.phone), ''), phone)
    WHERE id = customer_id;
  END IF;

  SELECT l.id, l.currency INTO safe_listing, safe_currency
  FROM agency.listings l
  WHERE l.id = inquiry_row.listing_id
    AND l.tenant_id = p_tenant_id;

  safe_currency := COALESCE(safe_currency, 'TRY');
  reference := 'INQ-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));

  INSERT INTO agency.reservations(
    tenant_id, listing_id, customer_id, reference_code,
    check_in, check_out, guest_count, total_minor, currency, status
  ) VALUES (
    p_tenant_id, safe_listing, customer_id, reference,
    inquiry_row.check_in, inquiry_row.check_out,
    inquiry_row.guest_count, 0, safe_currency, 'inquiry'
  );

  UPDATE agency.public_inquiries
  SET status = 'converted'
  WHERE id = p_inquiry_id AND tenant_id = p_tenant_id;

  RETURN reference;
END;
$$;

GRANT EXECUTE ON FUNCTION agency.convert_public_inquiry(uuid, uuid) TO agency_app;
