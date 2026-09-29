-- Otonom satış, kampanya ve satış sonrası operasyonları için denetlenebilir AI çekirdeği.
-- AI hiçbir finansal/geri ödeme işlemini insan onayı olmadan sonuçlandıramaz.
CREATE TABLE IF NOT EXISTS agency.ai_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  agent_key text NOT NULL,
  display_name text NOT NULL,
  purpose text NOT NULL DEFAULT '',
  enabled boolean NOT NULL DEFAULT true,
  autonomy_level text NOT NULL DEFAULT 'suggest' CHECK (autonomy_level IN ('suggest','draft','execute_low_risk','approval_required')),
  allowed_actions jsonb NOT NULL DEFAULT '[]'::jsonb,
  blocked_actions jsonb NOT NULL DEFAULT '["refund","payout","price_override","delete_customer"]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, agent_key)
);

CREATE TABLE IF NOT EXISTS agency.ai_operation_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  agent_id uuid REFERENCES agency.ai_agents(id) ON DELETE SET NULL,
  operation text NOT NULL CHECK (operation IN ('campaign','sales_assist','reservation_followup','support','refund_review','upsell','content','report')),
  entity_type text NOT NULL DEFAULT '',
  entity_id uuid,
  input jsonb NOT NULL DEFAULT '{}'::jsonb,
  recommendation jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','awaiting_approval','completed','rejected','failed','cancelled')),
  risk_level text NOT NULL DEFAULT 'low' CHECK (risk_level IN ('low','medium','high','financial')),
  requested_by uuid,
  approved_by uuid,
  approved_at timestamptz,
  error text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agency.ai_campaign_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  task_id uuid REFERENCES agency.ai_operation_tasks(id) ON DELETE SET NULL,
  campaign_id uuid REFERENCES agency.campaigns(id) ON DELETE SET NULL,
  channel text NOT NULL CHECK (channel IN ('email','sms','whatsapp','push','onsite','social')),
  audience jsonb NOT NULL DEFAULT '{}'::jsonb,
  offer jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','running','paused','completed','cancelled')),
  scheduled_at timestamptz,
  metrics jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agency.customer_service_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid,
  reservation_id uuid REFERENCES agency.reservations(id) ON DELETE SET NULL,
  task_id uuid REFERENCES agency.ai_operation_tasks(id) ON DELETE SET NULL,
  case_type text NOT NULL CHECK (case_type IN ('question','change_request','complaint','refund_request','cancellation','lost_item','follow_up')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high','urgent')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','waiting_customer','waiting_supplier','approved','resolved','closed')),
  summary text NOT NULL DEFAULT '',
  resolution text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE IF NOT EXISTS agency.ai_action_approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  task_id uuid NOT NULL REFERENCES agency.ai_operation_tasks(id) ON DELETE CASCADE,
  action text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected','expired')),
  reviewer_id uuid,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agency_ai_tasks_queue_idx ON agency.ai_operation_tasks(tenant_id,status,risk_level,created_at);
CREATE INDEX IF NOT EXISTS agency_ai_cases_status_idx ON agency.customer_service_cases(tenant_id,status,priority);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.ai_agents,agency.ai_operation_tasks,agency.ai_campaign_runs,agency.customer_service_cases,agency.ai_action_approvals TO agency_app;
