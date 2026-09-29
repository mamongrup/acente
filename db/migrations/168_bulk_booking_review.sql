CREATE OR REPLACE FUNCTION agency.apply_supplier_booking_decisions_bulk(
  p_tenant uuid,p_actor uuid,p_reservations uuid[]
) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_decision text; v_changed integer:=0;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND active AND membership_type='admin')
    OR p_reservations IS NULL OR cardinality(p_reservations)<1 OR cardinality(p_reservations)>50
    OR (SELECT count(DISTINCT x) FROM unnest(p_reservations) x)<>cardinality(p_reservations)
    OR array_position(p_reservations,NULL) IS NOT NULL
  THEN RAISE EXCEPTION 'invalid_bulk_review'; END IF;
  FOREACH v_id IN ARRAY p_reservations LOOP
    SELECT d.decision INTO v_decision FROM agency.supplier_booking_decisions d
      JOIN agency.reservations r ON r.id=d.reservation_id AND r.tenant_id=d.tenant_id
      WHERE d.tenant_id=p_tenant AND d.reservation_id=v_id AND d.applied_at IS NULL AND r.status='inquiry'
      FOR UPDATE OF d,r;
    IF v_decision IS NULL THEN RAISE EXCEPTION 'review_item_not_pending: %',v_id; END IF;
    UPDATE agency.reservations SET status=CASE WHEN v_decision='accepted' THEN 'option' ELSE 'cancelled' END
      WHERE id=v_id AND tenant_id=p_tenant;
    UPDATE agency.supplier_booking_decisions SET applied_at=now(),applied_by=p_actor
      WHERE reservation_id=v_id AND tenant_id=p_tenant;
    UPDATE agency.review_assignments SET status='closed',updated_at=now()
      WHERE tenant_id=p_tenant AND entity_type='booking_decision' AND entity_id=v_id AND status='open';
    INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
      VALUES(p_tenant,p_actor,'supplier.booking_decision_applied','reservation',v_id,
        jsonb_build_object('decision',v_decision,'bulk',true));
    v_changed:=v_changed+1;
  END LOOP;
  RETURN v_changed;
END $$;
REVOKE ALL ON FUNCTION agency.apply_supplier_booking_decisions_bulk(uuid,uuid,uuid[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.apply_supplier_booking_decisions_bulk(uuid,uuid,uuid[]) TO agency_app;
