-- Teklif formu için transaction güvenli, e-posta bazlı spam sınırı.
CREATE OR REPLACE FUNCTION agency.enforce_public_inquiry_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  normalized_email text := lower(trim(NEW.email));
  recent_count integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(normalized_email));
  SELECT count(*) INTO recent_count
    FROM agency.public_inquiries
   WHERE lower(trim(email)) = normalized_email
     AND created_at >= now() - interval '1 hour';
  IF recent_count >= 10 THEN
    RAISE EXCEPTION 'public inquiry rate limit exceeded';
  END IF;
  RETURN NEW;
END;
$$;

CREATE INDEX IF NOT EXISTS public_inquiries_email_created_idx
  ON agency.public_inquiries ((lower(trim(email))), created_at DESC);

DROP TRIGGER IF EXISTS public_inquiries_rate_limit_trigger ON agency.public_inquiries;
CREATE TRIGGER public_inquiries_rate_limit_trigger
BEFORE INSERT ON agency.public_inquiries
FOR EACH ROW EXECUTE FUNCTION agency.enforce_public_inquiry_rate_limit();
