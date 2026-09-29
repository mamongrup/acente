CREATE OR REPLACE FUNCTION agency.retry_nexus_reservation_delivery(
  p_tenant uuid,p_actor uuid,p_delivery uuid
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_delivery agency.nexus_reservation_deliveries%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM agency.users u
    WHERE u.id=p_actor AND u.tenant_id=p_tenant
      AND u.active AND u.membership_type='admin'
  ) THEN RAISE EXCEPTION 'delivery_retry_forbidden'; END IF;
  SELECT * INTO v_delivery FROM agency.nexus_reservation_deliveries
  WHERE id=p_delivery AND tenant_id=p_tenant FOR UPDATE;
  IF NOT FOUND OR v_delivery.status<>'failed' OR v_delivery.attempts>=100 THEN
    RETURN false;
  END IF;
  UPDATE agency.nexus_reservation_deliveries SET status='pending',
    attempts=0,next_attempt_at=now(),started_at=NULL,updated_at=now()
  WHERE id=p_delivery AND tenant_id=p_tenant;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
  VALUES(p_tenant,p_actor,'nexus.reservation_delivery.retry','reservation',
    v_delivery.reservation_id,
    jsonb_build_object('delivery_id',p_delivery,'event_type',v_delivery.event_type,
      'previous_attempts',v_delivery.attempts));
  RETURN true;
END $$;
