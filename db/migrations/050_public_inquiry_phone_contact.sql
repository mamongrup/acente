-- Public chat leads may provide either an e-mail address or a phone number.
-- Keep the existing e-mail validation while allowing phone-only contact data.
ALTER TABLE agency.public_inquiries
  DROP CONSTRAINT IF EXISTS public_inquiries_email_length_ck;

ALTER TABLE agency.public_inquiries
  ADD CONSTRAINT public_inquiries_contact_ck
  CHECK (
    (char_length(trim(email)) BETWEEN 5 AND 320 AND position('@' in email) > 1)
    OR char_length(regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g')) BETWEEN 7 AND 20
  ) NOT VALID;

CREATE OR REPLACE FUNCTION agency.enforce_public_inquiry_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  normalized_contact text := CASE
    WHEN trim(coalesce(NEW.email, '')) <> '' THEN lower(trim(NEW.email))
    ELSE regexp_replace(coalesce(NEW.phone, ''), '[^0-9]', '', 'g')
  END;
  recent_count integer;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext(normalized_contact));
  SELECT count(*) INTO recent_count
    FROM agency.public_inquiries
   WHERE created_at >= now() - interval '1 hour'
     AND (
       (normalized_contact ~ '@' AND lower(trim(email)) = normalized_contact)
       OR (normalized_contact !~ '@' AND regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = normalized_contact)
     );
  IF recent_count >= 10 THEN
    RAISE EXCEPTION 'public inquiry rate limit exceeded';
  END IF;
  RETURN NEW;
END;
$$;
