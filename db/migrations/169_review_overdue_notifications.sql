ALTER TABLE agency.review_assignments
  ADD COLUMN IF NOT EXISTS last_overdue_notified_at timestamptz;

CREATE OR REPLACE FUNCTION agency.reset_review_overdue_notice()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.assignee_user_id IS DISTINCT FROM OLD.assignee_user_id
     OR NEW.due_at IS DISTINCT FROM OLD.due_at
     OR (OLD.status='closed' AND NEW.status='open') THEN
    NEW.last_overdue_notified_at := NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS reset_review_overdue_notice ON agency.review_assignments;
CREATE TRIGGER reset_review_overdue_notice BEFORE UPDATE ON agency.review_assignments
  FOR EACH ROW EXECUTE FUNCTION agency.reset_review_overdue_notice();

CREATE OR REPLACE FUNCTION agency.queue_overdue_review_notifications(p_tenant uuid,p_actor uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_assignment record; v_count integer:=0;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant
                AND active AND membership_type='admin') THEN
    RAISE EXCEPTION 'review_notification_forbidden';
  END IF;
  FOR v_assignment IN
    SELECT a.id,a.entity_type,a.entity_id,a.due_at,a.assignee_user_id,u.email,u.display_name
    FROM agency.review_assignments a
    JOIN agency.users u ON u.tenant_id=a.tenant_id AND u.id=a.assignee_user_id
    WHERE a.tenant_id=p_tenant AND a.status='open' AND a.due_at<now()
      AND (a.last_overdue_notified_at IS NULL OR a.last_overdue_notified_at<now()-interval '24 hours')
      AND u.active AND nullif(trim(u.email),'') IS NOT NULL
    ORDER BY a.due_at LIMIT 200 FOR UPDATE OF a SKIP LOCKED
  LOOP
    INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status)
    VALUES(p_tenant,v_assignment.assignee_user_id,'email','review.overdue',
      jsonb_build_object('email',v_assignment.email,'name',v_assignment.display_name,
        'assignment_id',v_assignment.id,'entity_type',v_assignment.entity_type,
        'entity_id',v_assignment.entity_id,'due_at',v_assignment.due_at,
        'message','İnceleme görevinizin son tarihi geçti. Yönetici inceleme merkezinden görevi kontrol edin.'),
      'queued');
    UPDATE agency.review_assignments SET last_overdue_notified_at=now()
      WHERE id=v_assignment.id AND tenant_id=p_tenant;
    v_count:=v_count+1;
  END LOOP;
  IF v_count>0 THEN
    INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,metadata)
      VALUES(p_tenant,p_actor,'review.overdue_notifications_queued','review_assignment',
        jsonb_build_object('count',v_count));
  END IF;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION agency.queue_overdue_review_notifications(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.queue_overdue_review_notifications(uuid,uuid) TO agency_app;
