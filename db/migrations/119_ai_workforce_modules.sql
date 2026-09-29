-- AI çalışanları için uzmanlık modülleri ve ölçülebilir çıktı katmanı.
CREATE TABLE IF NOT EXISTS agency.ai_workforce_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  module_key text NOT NULL,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  enabled boolean NOT NULL DEFAULT false,
  autonomy_level text NOT NULL DEFAULT 'suggest' CHECK (autonomy_level IN ('suggest','draft','execute_low_risk','approval_required')),
  schedule text NOT NULL DEFAULT '',
  budget_limit_minor bigint,
  configuration jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, module_key)
);

CREATE TABLE IF NOT EXISTS agency.ai_revenue_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid,
  recommendation_type text NOT NULL CHECK (recommendation_type IN ('price','campaign','upsell','inventory')),
  current_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  proposed_value jsonb NOT NULL DEFAULT '{}'::jsonb,
  rationale text NOT NULL DEFAULT '',
  confidence numeric(5,4),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','applied','expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);

CREATE TABLE IF NOT EXISTS agency.ai_customer_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  segment_key text NOT NULL,
  name text NOT NULL,
  criteria jsonb NOT NULL DEFAULT '{}'::jsonb,
  estimated_count int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, segment_key)
);

CREATE TABLE IF NOT EXISTS agency.ai_quality_signals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid,
  signal_type text NOT NULL CHECK (signal_type IN ('fraud','image_quality','translation_quality','sentiment','complaint_risk','duplicate_content')),
  score numeric(5,4),
  evidence jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','dismissed','resolved')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agency.ai_executive_insights (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  insight_type text NOT NULL CHECK (insight_type IN ('sales','revenue','operations','customer','marketing','risk')),
  summary text NOT NULL,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  recommended_actions jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agency_ai_revenue_pending_idx ON agency.ai_revenue_recommendations(tenant_id,status,created_at);
CREATE INDEX IF NOT EXISTS agency_ai_quality_open_idx ON agency.ai_quality_signals(tenant_id,status,signal_type);
CREATE INDEX IF NOT EXISTS agency_ai_insights_period_idx ON agency.ai_executive_insights(tenant_id,period_end,insight_type);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_workforce_modules,agency.ai_revenue_recommendations,agency.ai_customer_segments,agency.ai_quality_signals,agency.ai_executive_insights TO agency_app;

INSERT INTO agency.ai_workforce_modules (tenant_id,module_key,name,description)
SELECT t.id, m.key, m.name, m.description
FROM agency.tenants t
CROSS JOIN (VALUES
  ('revenue_manager','Gelir yöneticisi','Talep, fiyat, stok ve kampanya önerileri'),
  ('sales_assistant','Satış asistanı','Rezervasyon fırsatları, upsell ve sepet kurtarma'),
  ('lifecycle_manager','Müşteri yaşam döngüsü','Rezervasyon öncesi ve sonrası görev akışları'),
  ('campaign_manager','Kampanya yöneticisi','Hedef kitle, kanal, zamanlama ve metin taslakları'),
  ('support_agent','Müşteri destek çalışanı','Soruları sınıflandırma ve yanıt taslakları'),
  ('content_editor','İçerik editörü','Blog, bölge, ilan ve sosyal medya içerikleri'),
  ('translation_reviewer','Çeviri kalite çalışanı','Çok dilli metin kalite kontrolü'),
  ('risk_guardian','Risk ve güvenlik çalışanı','Sahtekarlık, şikayet ve işlem riskleri'),
  ('media_curator','Görsel kalite çalışanı','Görsel kalite, tekrar ve uygunluk kontrolü'),
  ('executive_analyst','Yönetim analisti','Satış, gelir, operasyon ve müşteri özetleri')
) AS m(key,name,description) ON CONFLICT (tenant_id,module_key) DO NOTHING;
