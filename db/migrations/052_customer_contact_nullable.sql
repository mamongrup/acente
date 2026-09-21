-- 052: phone-only leads are valid customers. Keep email optional so a blank
-- address does not collapse every phone lead into one customer record.
ALTER TABLE agency.customers
  ALTER COLUMN email DROP NOT NULL;

UPDATE agency.customers
SET email = NULL
WHERE email IS NOT NULL AND trim(email) = '';
