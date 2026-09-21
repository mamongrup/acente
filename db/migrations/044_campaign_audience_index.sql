-- Campaigns are shared by agency and supplier channels. Keep audience filtering
-- fast as the catalogue grows; old rows without audience remain shared.
CREATE INDEX IF NOT EXISTS agency_campaigns_audience_idx
  ON agency.campaigns (tenant_id, (coalesce(rules->>'audience', 'all')), active, starts_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON agency.campaigns TO agency_app;
