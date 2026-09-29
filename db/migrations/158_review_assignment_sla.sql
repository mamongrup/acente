CREATE TABLE IF NOT EXISTS agency.review_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  entity_type text NOT NULL CHECK(entity_type IN ('booking_decision','listing','application','supplier_document')),
  entity_id uuid NOT NULL,
  assignee_user_id uuid NOT NULL,
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','closed')),
  assigned_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,entity_type,entity_id),
  FOREIGN KEY(tenant_id,assignee_user_id) REFERENCES agency.users(tenant_id,id),
  FOREIGN KEY(tenant_id,assigned_by) REFERENCES agency.users(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS review_assignments_due_idx ON agency.review_assignments(tenant_id,status,due_at);

CREATE OR REPLACE FUNCTION agency.assign_review(
  p_tenant uuid,p_actor uuid,p_entity_type text,p_entity_id uuid,p_assignee uuid,p_due timestamptz
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_valid boolean;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND membership_type='admin' AND active)
     OR NOT EXISTS (SELECT 1 FROM agency.users u WHERE u.id=p_assignee AND u.tenant_id=p_tenant AND u.active
       AND (u.membership_type IN ('admin','staff') OR EXISTS(SELECT 1 FROM agency.user_roles ur JOIN agency.roles r ON r.id=ur.role_id WHERE ur.user_id=u.id AND r.tenant_id=p_tenant AND r.code IN ('admin','staff'))))
     OR p_due<=now() OR p_due>now()+interval '90 days'
  THEN RAISE EXCEPTION 'invalid_review_assignment'; END IF;
  v_valid := CASE p_entity_type
    WHEN 'booking_decision' THEN EXISTS(SELECT 1 FROM agency.supplier_booking_decisions WHERE tenant_id=p_tenant AND reservation_id=p_entity_id AND applied_at IS NULL)
    WHEN 'listing' THEN EXISTS(SELECT 1 FROM agency.listings WHERE tenant_id=p_tenant AND id=p_entity_id AND status='review')
    WHEN 'application' THEN EXISTS(SELECT 1 FROM agency.applications WHERE tenant_id=p_tenant AND id=p_entity_id AND status IN ('pending','in_review'))
    WHEN 'supplier_document' THEN EXISTS(SELECT 1 FROM agency.supplier_documents WHERE tenant_id=p_tenant AND id=p_entity_id AND status='pending')
    ELSE false END;
  IF NOT v_valid THEN RAISE EXCEPTION 'review_item_not_pending'; END IF;
  INSERT INTO agency.review_assignments(tenant_id,entity_type,entity_id,assignee_user_id,due_at,assigned_by)
    VALUES(p_tenant,p_entity_type,p_entity_id,p_assignee,p_due,p_actor)
    ON CONFLICT(tenant_id,entity_type,entity_id) DO UPDATE SET assignee_user_id=excluded.assignee_user_id,due_at=excluded.due_at,status='open',assigned_by=excluded.assigned_by,updated_at=now()
    RETURNING id INTO v_id;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'review.assigned',p_entity_type,p_entity_id,jsonb_build_object('assignee',p_assignee,'dueAt',p_due));
  RETURN v_id;
END $$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.review_assignments TO agency_app;
GRANT EXECUTE ON FUNCTION agency.assign_review(uuid,uuid,text,uuid,uuid,timestamptz) TO agency_app;
