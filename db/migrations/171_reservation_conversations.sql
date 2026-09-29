CREATE TABLE IF NOT EXISTS agency.reservation_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL,
  author_user_id uuid NOT NULL,
  author_role text NOT NULL CHECK(author_role IN ('customer','supplier','admin')),
  message text NOT NULL CHECK(length(trim(message)) BETWEEN 2 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY(tenant_id,reservation_id) REFERENCES agency.reservations(tenant_id,id) ON DELETE CASCADE,
  FOREIGN KEY(tenant_id,author_user_id) REFERENCES agency.users(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS reservation_messages_thread_idx
  ON agency.reservation_messages(tenant_id,reservation_id,created_at);

CREATE OR REPLACE FUNCTION agency.send_reservation_message(
  p_tenant uuid,p_actor uuid,p_reservation uuid,p_role text,p_message text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid; v_customer_user uuid;
BEGIN
  IF p_role NOT IN ('customer','supplier','admin')
     OR length(trim(p_message)) NOT BETWEEN 2 AND 4000
     OR NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_actor AND tenant_id=p_tenant AND active)
  THEN RAISE EXCEPTION 'invalid_reservation_message'; END IF;
  IF NOT EXISTS(
    SELECT 1 FROM agency.reservations r
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
    LEFT JOIN agency.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id
    JOIN agency.users u ON u.id=p_actor AND u.tenant_id=r.tenant_id AND u.active
    WHERE r.id=p_reservation AND r.tenant_id=p_tenant
      AND ((p_role='customer' AND u.membership_type='customer' AND c.id IS NOT NULL
            AND lower(u.email)=lower(c.email))
        OR (p_role='supplier' AND l.owner_user_id=p_actor
            AND (u.membership_type='supplier' OR EXISTS(
              SELECT 1 FROM agency.user_roles ur JOIN agency.roles role ON role.id=ur.role_id
              WHERE ur.user_id=p_actor AND role.tenant_id=p_tenant AND role.code='supplier')))
        OR (p_role='admin' AND u.membership_type='admin'))
  ) THEN RAISE EXCEPTION 'reservation_message_forbidden'; END IF;
  INSERT INTO agency.reservation_messages(tenant_id,reservation_id,author_user_id,author_role,message)
    VALUES(p_tenant,p_reservation,p_actor,p_role,trim(p_message)) RETURNING id INTO v_id;
  IF p_role<>'customer' THEN
    SELECT u.id INTO v_customer_user FROM agency.reservations r
      JOIN agency.customers c ON c.id=r.customer_id AND c.tenant_id=r.tenant_id
      JOIN agency.users u ON u.tenant_id=r.tenant_id AND u.membership_type='customer'
        AND u.active AND lower(u.email)=lower(c.email)
      WHERE r.id=p_reservation AND r.tenant_id=p_tenant LIMIT 1;
    IF v_customer_user IS NOT NULL THEN
      INSERT INTO agency.customer_notifications(tenant_id,user_id,kind,title,message,target_url)
        VALUES(p_tenant,v_customer_user,'reservation_message','Rezervasyon mesajı',
          'Rezervasyonunuzla ilgili yeni bir mesaj var.','/hesap#reservation-messages');
    END IF;
  END IF;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'reservation.message_sent','reservation',p_reservation,
      jsonb_build_object('messageId',v_id,'role',p_role));
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION agency.send_reservation_message(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT SELECT ON agency.reservation_messages TO agency_app;
GRANT EXECUTE ON FUNCTION agency.send_reservation_message(uuid,uuid,uuid,text,text) TO agency_app;
