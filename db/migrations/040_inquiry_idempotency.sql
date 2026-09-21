ALTER TABLE agency.public_inquiries ADD COLUMN IF NOT EXISTS idempotency_key text;
CREATE UNIQUE INDEX IF NOT EXISTS public_inquiries_idempotency_idx ON agency.public_inquiries(idempotency_key) WHERE idempotency_key IS NOT NULL;
