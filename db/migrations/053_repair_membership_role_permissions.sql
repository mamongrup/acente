-- 053: keep the built-in role catalogue authoritative after an administrator
-- changes a user's membership type or an older installation missed the seed.
UPDATE agency.roles
SET name = CASE code
    WHEN 'admin' THEN 'Yönetici'
    WHEN 'staff' THEN 'Personel'
    WHEN 'supplier' THEN 'Tedarikçi'
    WHEN 'sub_agency' THEN 'Alt acente'
    WHEN 'customer' THEN 'Müşteri'
  END,
  permissions = CASE code
    WHEN 'admin' THEN '["*"]'::jsonb
    WHEN 'staff' THEN '["dashboard.read","catalog.read","catalog.write","reservations.read","reservations.write","customers.read","customers.write","inquiries.read","inquiries.write","reports.read"]'::jsonb
    WHEN 'supplier' THEN '["dashboard.read","catalog.read","catalog.write","campaigns.supplier"]'::jsonb
    WHEN 'sub_agency' THEN '["dashboard.read","catalog.read","reservations.read","reservations.write","customers.read","customers.write","inquiries.read"]'::jsonb
    WHEN 'customer' THEN '["storefront.read","booking.create","inquiries.create"]'::jsonb
  END
WHERE code IN ('admin','staff','supplier','sub_agency','customer');
