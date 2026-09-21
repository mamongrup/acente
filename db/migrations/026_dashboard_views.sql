CREATE OR REPLACE VIEW agency.dashboard_metrics AS
SELECT t.id AS tenant_id,
 (SELECT count(*) FROM agency.listings l WHERE l.tenant_id=t.id AND l.status='published') AS published_listings,
 (SELECT count(*) FROM agency.reservations r WHERE r.tenant_id=t.id AND r.status IN ('inquiry','option')) AS pending_reservations,
 (SELECT count(*) FROM agency.reservations r WHERE r.tenant_id=t.id AND r.check_in >= current_date AND r.check_in < current_date + 30) AS upcoming_reservations,
 (SELECT count(*) FROM agency.contact_requests c WHERE c.tenant_id=t.id AND c.status='new') AS new_contact_requests
FROM agency.tenants t;
GRANT SELECT ON agency.dashboard_metrics TO nexus_owner;
