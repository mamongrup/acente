-- Fraud sinyalleri ve KVKK/GDPR veri talepleri için güvenli iş akışları.
CREATE TABLE IF NOT EXISTS agency.customer_privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL, request_type text NOT NULL CHECK(request_type IN ('export','erase','restrict','correct')),
  status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','verified','approved','processing','completed','rejected')),
  requested_at timestamptz NOT NULL DEFAULT now(), verified_at timestamptz, completed_at timestamptz,
  requested_by uuid, approved_by uuid, result jsonb NOT NULL DEFAULT '{}'::jsonb, error text NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS agency.fraud_risk_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  customer_id uuid, reservation_id uuid, risk_score numeric(5,4) NOT NULL DEFAULT 0, signals jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','reviewing','approved','blocked','dismissed')),
  reviewer_id uuid, reviewed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION agency.queue_privacy_request(p_tenant uuid,p_customer uuid,p_type text,p_requester uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  IF p_type NOT IN ('export','erase','restrict','correct') THEN RAISE EXCEPTION 'invalid privacy request type'; END IF;
  INSERT INTO agency.customer_privacy_requests(tenant_id,customer_id,request_type,requested_by)
  VALUES(p_tenant,p_customer,p_type,p_requester) RETURNING id INTO v_id;
  INSERT INTO agency.ai_privacy_events(tenant_id,event_type,subject_id,status)
  VALUES(p_tenant,CASE WHEN p_type='erase' THEN 'erasure_requested' ELSE 'export_requested' END,p_customer,'recorded');
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION agency.open_fraud_case(p_tenant uuid,p_customer uuid,p_reservation uuid,p_score numeric,p_signals jsonb)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO agency.fraud_risk_cases(tenant_id,customer_id,reservation_id,risk_score,signals)
  VALUES(p_tenant,p_customer,p_reservation,greatest(0,least(1,p_score)),coalesce(p_signals,'[]'::jsonb)) RETURNING id INTO v_id;
  INSERT INTO agency.ai_quality_signals(tenant_id,entity_type,entity_id,signal_type,score,evidence)
  VALUES(p_tenant,'reservation',p_reservation,'fraud',greatest(0,least(1,p_score)),coalesce(p_signals,'[]'::jsonb));
  RETURN v_id;
END;
$$;

CREATE INDEX IF NOT EXISTS agency_privacy_requests_status_idx ON agency.customer_privacy_requests(tenant_id,status,requested_at);
CREATE INDEX IF NOT EXISTS agency_fraud_cases_status_idx ON agency.fraud_risk_cases(tenant_id,status,risk_score);
GRANT SELECT,INSERT,UPDATE,DELETE ON agency.customer_privacy_requests,agency.fraud_risk_cases TO agency_app;
GRANT EXECUTE ON FUNCTION agency.queue_privacy_request(uuid,uuid,text,uuid),agency.open_fraud_case(uuid,uuid,uuid,numeric,jsonb) TO agency_app;
