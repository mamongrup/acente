-- Payment/refund provider is ParamPOS; QNB eSolutions is the document provider.
-- Provider selection does not assert that either external connection is live.
ALTER TABLE agency.finance_provider_settings
  DROP CONSTRAINT finance_provider_settings_ecosystem_check,
  DROP CONSTRAINT finance_provider_settings_payment_provider_check;

ALTER TABLE agency.finance_provider_settings
  ALTER COLUMN ecosystem SET DEFAULT 'parampos_qnb_esolutions',
  ALTER COLUMN payment_provider SET DEFAULT 'parampos';

UPDATE agency.finance_provider_settings
SET ecosystem='parampos_qnb_esolutions',
    payment_provider='parampos',
    payment_status='awaiting_credentials',
    updated_at=now();

ALTER TABLE agency.finance_provider_settings
  ADD CONSTRAINT finance_provider_settings_ecosystem_check
    CHECK (ecosystem='parampos_qnb_esolutions'),
  ADD CONSTRAINT finance_provider_settings_payment_provider_check
    CHECK (payment_provider='parampos');
