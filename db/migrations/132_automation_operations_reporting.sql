-- Otomasyon operasyon merkezi için özet raporlar.
CREATE OR REPLACE VIEW agency.module_operation_daily_report AS
SELECT
  tenant_id,
  module_key,
  date_trunc('day', started_at)::date AS report_date,
  count(*) FILTER (WHERE status='completed') AS completed_count,
  count(*) FILTER (WHERE status='failed') AS failed_count,
  count(*) FILTER (WHERE status='skipped') AS skipped_count,
  count(*) FILTER (WHERE status='started') AS running_count,
  coalesce(sum((metadata->>'tokens')::bigint) FILTER (WHERE metadata ? 'tokens'),0) AS tokens_used,
  coalesce(sum((metadata->>'cost_cents')::numeric) FILTER (WHERE metadata ? 'cost_cents'),0) AS cost_cents
FROM agency.module_run_events
GROUP BY tenant_id,module_key,date_trunc('day', started_at)::date;

CREATE OR REPLACE VIEW agency.module_operation_monthly_report AS
SELECT
  tenant_id,
  module_key,
  date_trunc('month', started_at)::date AS report_month,
  count(*) AS total_count,
  count(*) FILTER (WHERE status='completed') AS completed_count,
  count(*) FILTER (WHERE status='failed') AS failed_count,
  count(*) FILTER (WHERE status='skipped') AS skipped_count,
  coalesce(sum((metadata->>'tokens')::bigint) FILTER (WHERE metadata ? 'tokens'),0) AS tokens_used,
  coalesce(sum((metadata->>'cost_cents')::numeric) FILTER (WHERE metadata ? 'cost_cents'),0) AS cost_cents
FROM agency.module_run_events
GROUP BY tenant_id,module_key,date_trunc('month', started_at)::date;

GRANT SELECT ON agency.module_operation_daily_report,
  agency.module_operation_monthly_report TO agency_app;
