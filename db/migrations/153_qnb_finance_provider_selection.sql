-- Dijital Köprü is the selected ecosystem; QNBpay and QNB eSolutions are
-- separate products. Selection never implies an active provider connection.
CREATE TABLE IF NOT EXISTS agency.finance_provider_settings (
  tenant_id uuid PRIMARY KEY REFERENCES agency.tenants(id) ON DELETE CASCADE,
  ecosystem text NOT NULL DEFAULT 'qnb_dijital_kopru' CHECK (ecosystem='qnb_dijital_kopru'),
  payment_provider text NOT NULL DEFAULT 'qnbpay' CHECK (payment_provider='qnbpay'),
  document_provider text NOT NULL DEFAULT 'qnb_esolutions' CHECK (document_provider='qnb_esolutions'),
  payment_status text NOT NULL DEFAULT 'awaiting_credentials' CHECK (payment_status IN ('awaiting_credentials','testing','active','suspended')),
  document_status text NOT NULL DEFAULT 'awaiting_credentials' CHECK (document_status IN ('awaiting_credentials','testing','active','suspended')),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (payment_status <> 'active' OR document_status IN ('awaiting_credentials','testing','active','suspended'))
);

INSERT INTO agency.finance_provider_settings(tenant_id)
SELECT id FROM agency.tenants
ON CONFLICT (tenant_id) DO NOTHING;

CREATE OR REPLACE FUNCTION agency.initialize_finance_provider_settings()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO agency.finance_provider_settings(tenant_id) VALUES(NEW.id)
  ON CONFLICT (tenant_id) DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS initialize_finance_provider_settings ON agency.tenants;
CREATE TRIGGER initialize_finance_provider_settings
AFTER INSERT ON agency.tenants FOR EACH ROW
EXECUTE FUNCTION agency.initialize_finance_provider_settings();

GRANT SELECT ON agency.finance_provider_settings TO agency_app;
