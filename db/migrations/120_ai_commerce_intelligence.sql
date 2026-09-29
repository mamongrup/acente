-- Turizm e-ticareti için AI ticaret zekâsı katmanı.
CREATE TABLE IF NOT EXISTS agency.ai_product_quality_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL, score numeric(5,4), missing_fields jsonb NOT NULL DEFAULT '[]'::jsonb,
  duplicate_candidates jsonb NOT NULL DEFAULT '[]'::jsonb, recommendations jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','reviewed','resolved')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_inventory_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL, signal_type text NOT NULL CHECK(signal_type IN ('low_demand','high_demand','overbooking','expiry','capacity_gap')),
  severity text NOT NULL DEFAULT 'normal' CHECK(severity IN ('low','normal','high','critical')), value jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','acknowledged','resolved')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_personalization_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid, session_key text NOT NULL DEFAULT '', event_type text NOT NULL, entity_type text NOT NULL DEFAULT '', entity_id uuid,
  context jsonb NOT NULL DEFAULT '{}'::jsonb, occurred_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_recovery_flows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid, reservation_id uuid, flow_type text NOT NULL CHECK(flow_type IN ('abandoned_search','abandoned_reservation','winback','pre_arrival','post_stay')),
  channel text NOT NULL CHECK(channel IN ('email','sms','whatsapp','push')), message jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','scheduled','sent','converted','cancelled')), scheduled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_loyalty_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL, tier text NOT NULL DEFAULT 'standard', points bigint NOT NULL DEFAULT 0, lifetime_value_minor bigint NOT NULL DEFAULT 0,
  preferences jsonb NOT NULL DEFAULT '{}'::jsonb, updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(tenant_id,customer_id)
);
CREATE TABLE IF NOT EXISTS agency.ai_finance_reconciliations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  period_start date NOT NULL, period_end date NOT NULL, source text NOT NULL, expected jsonb NOT NULL DEFAULT '{}'::jsonb,
  actual jsonb NOT NULL DEFAULT '{}'::jsonb, discrepancies jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','reviewed','resolved')), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS agency.ai_ad_campaign_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  network text NOT NULL CHECK(network IN ('google','meta','yandex','baidu','wechat','xiaohongshu')),
  objective text NOT NULL DEFAULT 'conversion', audience jsonb NOT NULL DEFAULT '{}'::jsonb, creatives jsonb NOT NULL DEFAULT '{}'::jsonb,
  budget_minor bigint, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','awaiting_approval','approved','published','paused','rejected')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS agency_ai_events_customer_idx ON agency.ai_personalization_events(tenant_id,customer_id,occurred_at);
CREATE INDEX IF NOT EXISTS agency_ai_recovery_status_idx ON agency.ai_recovery_flows(tenant_id,status,scheduled_at);
CREATE INDEX IF NOT EXISTS agency_ai_inventory_status_idx ON agency.ai_inventory_signals(tenant_id,status,severity);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_product_quality_reviews,agency.ai_inventory_signals,agency.ai_personalization_events,agency.ai_recovery_flows,agency.ai_loyalty_profiles,agency.ai_finance_reconciliations,agency.ai_ad_campaign_drafts TO agency_app;
