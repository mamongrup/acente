-- Genel iletişim ve AI sohbet taleplerini de doğru acente tenant'ına bağla.
ALTER TABLE agency.public_inquiries
  ADD COLUMN IF NOT EXISTS tenant_id uuid REFERENCES agency.tenants(id) ON DELETE CASCADE;

-- İlanlı eski talepleri mevcut ilanın tenant'ından tamamla.
UPDATE agency.public_inquiries i
SET tenant_id = l.tenant_id
FROM agency.listings l
WHERE i.tenant_id IS NULL AND l.id = i.listing_id;

-- İlanı olmayan eski kayıtlar tek acente kurulumunda ilk tenant'a bağlanır.
UPDATE agency.public_inquiries
SET tenant_id = (SELECT id FROM agency.tenants ORDER BY created_at LIMIT 1)
WHERE tenant_id IS NULL;

CREATE INDEX IF NOT EXISTS public_inquiries_tenant_status_idx
  ON agency.public_inquiries(tenant_id, status, created_at DESC);
