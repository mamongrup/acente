CREATE TABLE IF NOT EXISTS agency.supplier_settlement_policies (
  tenant_id uuid PRIMARY KEY REFERENCES agency.tenants(id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT false,
  days_after_checkout integer NOT NULL DEFAULT 7 CHECK(days_after_checkout BETWEEN 0 AND 90),
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,updated_by) REFERENCES agency.users(tenant_id,id)
);

CREATE OR REPLACE FUNCTION agency.set_supplier_settlement_policy(
  p_tenant uuid,p_actor uuid,p_enabled boolean,p_days integer
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant
    AND membership_type='admin' AND active)
    OR p_enabled IS NULL OR p_days NOT BETWEEN 0 AND 90 THEN
    RAISE EXCEPTION 'invalid_settlement_policy';
  END IF;
  INSERT INTO agency.supplier_settlement_policies(tenant_id,enabled,days_after_checkout,updated_by)
    VALUES(p_tenant,p_enabled,p_days,p_actor)
    ON CONFLICT(tenant_id) DO UPDATE SET enabled=excluded.enabled,
      days_after_checkout=excluded.days_after_checkout,updated_by=excluded.updated_by,updated_at=now();
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'supplier.settlement_policy_updated','tenant',p_tenant,
      jsonb_build_object('enabled',p_enabled,'daysAfterCheckout',p_days));
  RETURN p_tenant;
END $$;

CREATE OR REPLACE FUNCTION agency.generate_scheduled_supplier_settlements(p_tenant uuid,p_actor uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_res record; v_count integer:=0;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant
    AND membership_type='admin' AND active)
    OR NOT EXISTS(SELECT 1 FROM agency.supplier_settlement_policies
      WHERE tenant_id=p_tenant AND enabled) THEN
    RAISE EXCEPTION 'settlement_schedule_disabled';
  END IF;
  FOR v_res IN
    SELECT r.id, greatest(current_date,r.check_out+p.days_after_checkout) AS due_on
    FROM agency.reservations r
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
    JOIN agency.supplier_settlement_policies p ON p.tenant_id=r.tenant_id
    WHERE r.tenant_id=p_tenant AND r.status='completed' AND r.payment_status='paid'
      AND r.total_minor>0 AND r.check_out IS NOT NULL AND r.check_out<=current_date
      AND l.owner_user_id IS NOT NULL
      AND NOT EXISTS(SELECT 1 FROM agency.supplier_settlements s WHERE s.reservation_id=r.id)
    ORDER BY r.check_out,r.id LIMIT 100 FOR UPDATE OF r SKIP LOCKED
  LOOP
    BEGIN
      PERFORM agency.propose_supplier_settlement(p_tenant,p_actor,v_res.id,v_res.due_on);
      v_count:=v_count+1;
    EXCEPTION WHEN raise_exception OR unique_violation THEN
      INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
        VALUES(p_tenant,p_actor,'supplier.settlement_schedule_skipped','reservation',v_res.id,
          jsonb_build_object('reason',SQLERRM));
    END;
  END LOOP;
  RETURN v_count;
END $$;

REVOKE ALL ON FUNCTION agency.set_supplier_settlement_policy(uuid,uuid,boolean,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.generate_scheduled_supplier_settlements(uuid,uuid) FROM PUBLIC;
GRANT SELECT,INSERT,UPDATE ON agency.supplier_settlement_policies TO agency_app;
GRANT EXECUTE ON FUNCTION agency.set_supplier_settlement_policy(uuid,uuid,boolean,integer),
  agency.generate_scheduled_supplier_settlements(uuid,uuid) TO agency_app;
