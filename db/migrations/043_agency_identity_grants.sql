-- Tenant onboarding ve kullanıcı yönetimi için uygulama rolü izinleri.
-- Tenant izolasyonu uygulama servisindeki oturum/role kontrolleriyle korunur.
GRANT SELECT, INSERT, UPDATE, DELETE ON agency.tenants, agency.users TO agency_app;
