-- Follow-up for an explicit customer interest response; no automatic contact is sent.
CREATE TABLE agency.customer_journey_lead_followups (
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES agency.users(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  target_category text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','contacted','closed')),
  note text NOT NULL DEFAULT '' CHECK(length(note)<=1000),
  updated_by uuid NOT NULL REFERENCES agency.users(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,user_id,reservation_id,target_category),
  FOREIGN KEY(tenant_id,user_id,reservation_id,target_category)
    REFERENCES agency.customer_journey_answers(tenant_id,user_id,reservation_id,target_category)
    ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION agency.save_customer_journey_lead_followup(
  p_tenant uuid,p_actor uuid,p_user uuid,p_reservation uuid,p_target text,
  p_status text,p_note text
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) OR p_status NOT IN ('open','contacted','closed')
    OR length(coalesce(p_note,''))>1000 OR NOT EXISTS(
      SELECT 1 FROM agency.customer_journey_answers a
      JOIN agency.reservations r ON r.id=a.reservation_id AND r.tenant_id=a.tenant_id
      WHERE a.tenant_id=p_tenant AND a.user_id=p_user AND a.reservation_id=p_reservation
        AND a.target_category=p_target AND a.answer='yes'
        AND r.status IN ('confirmed','completed')
    ) THEN RETURN false; END IF;
  INSERT INTO agency.customer_journey_lead_followups
    (tenant_id,user_id,reservation_id,target_category,status,note,updated_by)
    VALUES(p_tenant,p_user,p_reservation,p_target,p_status,coalesce(p_note,''),p_actor)
    ON CONFLICT(tenant_id,user_id,reservation_id,target_category)
    DO UPDATE SET status=excluded.status,note=excluded.note,updated_by=excluded.updated_by,updated_at=now();
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION agency.customer_journey_leads(p_tenant uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE result jsonb;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'lead_access_denied'; END IF;
  SELECT coalesce(jsonb_agg(x.item ORDER BY x.answered_at DESC),'[]'::jsonb) INTO result
  FROM (SELECT a.updated_at answered_at,
      jsonb_build_object('userId',a.user_id,'reservationId',a.reservation_id,
        'customer',u.display_name,'reference',r.reference_code,'target',a.target_category,
        'answeredAt',to_char(a.updated_at,'YYYY-MM-DD HH24:MI'),
        'status',coalesce(f.status,'open'),'note',coalesce(f.note,'')) item
      FROM agency.customer_journey_answers a
      JOIN agency.users u ON u.id=a.user_id AND u.tenant_id=a.tenant_id
      JOIN agency.reservations r ON r.id=a.reservation_id AND r.tenant_id=a.tenant_id
      LEFT JOIN agency.customer_journey_lead_followups f ON f.tenant_id=a.tenant_id
        AND f.user_id=a.user_id AND f.reservation_id=a.reservation_id
        AND f.target_category=a.target_category
      WHERE a.tenant_id=p_tenant AND a.answer='yes'
        AND r.status IN ('confirmed','completed')
      ORDER BY a.updated_at DESC LIMIT 100) x;
  RETURN result;
END $$;
REVOKE ALL ON agency.customer_journey_lead_followups FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.save_customer_journey_lead_followup(uuid,uuid,uuid,uuid,text,text,text),
  agency.customer_journey_leads(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.save_customer_journey_lead_followup(uuid,uuid,uuid,uuid,text,text,text),
  agency.customer_journey_leads(uuid,uuid) TO agency_app;
