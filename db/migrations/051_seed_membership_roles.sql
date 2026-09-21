-- 051: make the five panel membership types explicit, reusable roles.
-- The application still keeps membership_type on users for fast session checks;
-- this table is the source of the role permission catalogue and user mapping.
INSERT INTO agency.roles (tenant_id, code, name, permissions)
SELECT t.id, r.code, r.name, r.permissions
FROM agency.tenants t
CROSS JOIN (
  VALUES
    ('admin', 'Yönetici', '["*"]'::jsonb),
    ('staff', 'Personel', '["dashboard.read","catalog.read","catalog.write","reservations.read","reservations.write","customers.read","customers.write","inquiries.read","inquiries.write","reports.read"]'::jsonb),
    ('supplier', 'Tedarikçi', '["dashboard.read","catalog.read","catalog.write","campaigns.supplier"]'::jsonb),
    ('sub_agency', 'Alt acente', '["dashboard.read","catalog.read","reservations.read","reservations.write","customers.read","customers.write","inquiries.read"]'::jsonb),
    ('customer', 'Müşteri', '["storefront.read","booking.create","inquiries.create"]'::jsonb)
) AS r(code, name, permissions) ON CONFLICT (tenant_id, code) DO UPDATE
SET name = EXCLUDED.name, permissions = EXCLUDED.permissions;

INSERT INTO agency.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM agency.users u
JOIN agency.roles r
  ON r.tenant_id = u.tenant_id
 AND r.code = u.membership_type
ON CONFLICT (user_id, role_id) DO NOTHING;

CREATE INDEX IF NOT EXISTS agency_user_roles_role_idx
  ON agency.user_roles(role_id, user_id);
