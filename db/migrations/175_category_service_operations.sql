-- Category-specific service operations. This local contract works without NEXUS.
-- A reservation gets its own immutable task snapshot when confirmed.
CREATE TABLE IF NOT EXISTS agency.category_service_steps (
  category_code text NOT NULL,
  step_key text NOT NULL,
  stage text NOT NULL CHECK(stage IN ('before','during','after')),
  title_tr text NOT NULL,
  owner_role text NOT NULL CHECK(owner_role IN ('admin','supplier')),
  position integer NOT NULL,
  contract_version text NOT NULL DEFAULT '1.0.0',
  PRIMARY KEY(category_code,step_key)
);

INSERT INTO agency.category_service_steps(category_code,step_key,stage,title_tr,owner_role,position) VALUES
 ('hotel','room_ready','before','Oda ve giriş bilgisini doğrula','supplier',10),
 ('hotel','checkin','during','Giriş ve konaklama talebini izle','supplier',20),
 ('hotel','checkout','after','Çıkış ve konaklama belgesini tamamla','supplier',30),
 ('holiday_home','property_ready','before','Ev, temizlik ve anahtar teslimini doğrula','supplier',10),
 ('holiday_home','arrival','during','Giriş ve ev kurallarını misafire ilet','supplier',20),
 ('holiday_home','deposit_return','after','Depozito ve çıkış kontrolünü tamamla','supplier',30),
 ('yacht','vessel_ready','before','Tekne, rota ve hava koşullarını doğrula','supplier',10),
 ('yacht','embarkation','during','Yolcu kabulü ve seyir başlangıcını kaydet','supplier',20),
 ('yacht','disembarkation','after','İniş ve sefer kapanışını tamamla','supplier',30),
 ('tour','departure_pack','before','Program, buluşma yeri ve rehberi doğrula','supplier',10),
 ('tour','attendance','during','Katılım ve tur değişikliklerini izle','supplier',20),
 ('tour','completion','after','Tur gerçekleşmesini ve geri bildirimi kaydet','supplier',30),
 ('activity','slot_ready','before','Seans, ekipman ve güvenlik bilgisini doğrula','supplier',10),
 ('activity','participation','during','Katılımı ve etkinlik durumunu kaydet','supplier',20),
 ('activity','followup','after','Etkinlik sonrası geri bildirimi izle','supplier',30),
 ('flight','ticket_issue','before','Bilet, PNR ve yolcu bilgilerini doğrula','supplier',10),
 ('flight','departure_watch','during','Uçuş değişikliklerini ve binişi izle','supplier',20),
 ('flight','arrival','after','Varış ve aksaklık taleplerini kapat','supplier',30),
 ('car','vehicle_ready','before','Araç, sigorta ve teslim noktasını doğrula','supplier',10),
 ('car','handover','during','Araç teslimi ve hasar kaydını tamamla','supplier',20),
 ('car','return','after','İade, yakıt ve depozito kontrolünü tamamla','supplier',30),
 ('cruise','cabin_docs','before','Kabin, bilet ve liman belgelerini doğrula','supplier',10),
 ('cruise','boarding','during','Gemiye biniş ve rota değişikliğini izle','supplier',20),
 ('cruise','disembark','after','İniş ve sefer kapanışını tamamla','supplier',30),
 ('pilgrimage','pilgrim_docs','before','Vize, sağlık ve kafile belgelerini doğrula','supplier',10),
 ('pilgrimage','group_watch','during','Kafile ve rehber durumunu izle','supplier',20),
 ('pilgrimage','return','after','Dönüş ve belge kapanışını tamamla','supplier',30),
 ('visa','application_docs','before','Başvuru ve evrak kontrolünü tamamla','supplier',10),
 ('visa','appointment','during','Randevu ve konsolosluk sürecini izle','supplier',20),
 ('visa','result_delivery','after','Sonucu ve pasaport teslimini kaydet','supplier',30),
 ('ferry','ticket_check','before','Bilet, sefer ve liman bilgisini doğrula','supplier',10),
 ('ferry','boarding','during','Biniş ve sefer değişikliğini izle','supplier',20),
 ('ferry','arrival','after','Varış ve aksaklık talebini kapat','supplier',30),
 ('transfer','pickup_check','before','Uçuş, araç ve karşılama noktasını doğrula','supplier',10),
 ('transfer','pickup','during','Yolcu karşılamayı ve sürücü durumunu izle','supplier',20),
 ('transfer','dropoff','after','Bırakma ve hizmet kapanışını kaydet','supplier',30),
 ('beach','seat_ready','before','Şezlong, alan ve saat bilgisini doğrula','supplier',10),
 ('beach','admission','during','Giriş ve kullanım durumunu izle','supplier',20),
 ('beach','close','after','Kullanım bitişini kaydet','supplier',30),
 ('cinema','seat_ticket','before','Seans, koltuk ve bileti doğrula','supplier',10),
 ('cinema','admission','during','Bilet okutma ve giriş durumunu izle','supplier',20),
 ('cinema','close','after','Seans kapanışını kaydet','supplier',30),
 ('event','event_ticket','before','Etkinlik, bilet ve giriş bilgisini doğrula','supplier',10),
 ('event','admission','during','Giriş ve program değişikliklerini izle','supplier',20),
 ('event','close','after','Etkinlik kapanışı ve geri bildirimi kaydet','supplier',30),
 ('restaurant','table_confirm','before','Masa, saat ve özel isteği doğrula','supplier',10),
 ('restaurant','seating','during','Misafir kabulü ve masa durumunu izle','supplier',20),
 ('restaurant','close','after','Hizmet kapanışı ve geri bildirimi kaydet','supplier',30),
 ('bus','seat_ticket','before','Koltuk, sefer ve bileti doğrula','supplier',10),
 ('bus','boarding','during','Biniş ve sefer değişikliğini izle','supplier',20),
 ('bus','arrival','after','Varış ve aksaklık talebini kapat','supplier',30)
ON CONFLICT(category_code,step_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS agency.reservation_service_tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  reservation_id uuid NOT NULL REFERENCES agency.reservations(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL REFERENCES agency.listings(id) ON DELETE CASCADE,
  category_code text NOT NULL,
  step_key text NOT NULL,
  stage text NOT NULL CHECK(stage IN ('before','during','after')),
  title_tr text NOT NULL,
  owner_role text NOT NULL CHECK(owner_role IN ('admin','supplier')),
  position integer NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','done','waived')),
  completed_by uuid REFERENCES agency.users(id),
  completed_at timestamptz,
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,reservation_id,step_key)
);
CREATE INDEX IF NOT EXISTS reservation_service_tasks_queue_idx
  ON agency.reservation_service_tasks(tenant_id,status,stage,created_at);

CREATE OR REPLACE FUNCTION agency.start_reservation_service(p_tenant uuid,p_actor uuid,p_reservation uuid)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_listing agency.listings%ROWTYPE; v_status text; v_count integer;
BEGIN
  SELECT r.status INTO v_status FROM agency.reservations r
   WHERE r.tenant_id=p_tenant AND r.id=p_reservation FOR UPDATE;
  IF NOT FOUND OR v_status NOT IN ('confirmed','completed') THEN
    RAISE EXCEPTION 'reservation_not_serviceable';
  END IF;
  SELECT l.* INTO v_listing FROM agency.reservations r
    JOIN agency.listings l ON l.id=r.listing_id AND l.tenant_id=r.tenant_id
   WHERE r.tenant_id=p_tenant AND r.id=p_reservation;
  IF NOT FOUND THEN RAISE EXCEPTION 'reservation_listing_missing'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.users u WHERE u.tenant_id=p_tenant AND u.id=p_actor
      AND u.active AND (u.membership_type='admin' OR
        (u.membership_type='supplier' AND v_listing.owner_user_id=u.id))) THEN
    RAISE EXCEPTION 'service_access_denied';
  END IF;
  INSERT INTO agency.reservation_service_tasks
    (tenant_id,reservation_id,listing_id,category_code,step_key,stage,title_tr,owner_role,position)
  SELECT p_tenant,p_reservation,v_listing.id,v_listing.category,s.step_key,s.stage,
    s.title_tr,s.owner_role,s.position
  FROM agency.category_service_steps s WHERE s.category_code=v_listing.category
  ON CONFLICT(tenant_id,reservation_id,step_key) DO NOTHING;
  GET DIAGNOSTICS v_count=ROW_COUNT;
  RETURN v_count;
END $$;

CREATE OR REPLACE FUNCTION agency.finish_reservation_service_task(
  p_tenant uuid,p_actor uuid,p_task uuid,p_status text,p_note text DEFAULT ''
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_task agency.reservation_service_tasks%ROWTYPE;
BEGIN
  SELECT * INTO v_task FROM agency.reservation_service_tasks
   WHERE tenant_id=p_tenant AND id=p_task FOR UPDATE;
  IF NOT FOUND OR v_task.status<>'open' OR p_status NOT IN ('done','waived')
     OR length(coalesce(p_note,''))>2000 THEN RAISE EXCEPTION 'invalid_service_task'; END IF;
  IF NOT EXISTS(SELECT 1 FROM agency.users u
    JOIN agency.listings l ON l.id=v_task.listing_id AND l.tenant_id=p_tenant
    WHERE u.id=p_actor AND u.tenant_id=p_tenant AND u.active AND
      (u.membership_type='admin' OR (p_status='done' AND
       v_task.owner_role='supplier' AND u.membership_type='supplier'
       AND l.owner_user_id=u.id))) THEN RAISE EXCEPTION 'service_access_denied'; END IF;
  UPDATE agency.reservation_service_tasks SET status=p_status,completed_by=p_actor,
    completed_at=now(),note=coalesce(p_note,'') WHERE id=p_task;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'reservation.service_task_'||p_status,'reservation',v_task.reservation_id,
      jsonb_build_object('task',p_task,'step',v_task.step_key));
  RETURN p_task;
END $$;

REVOKE ALL ON agency.category_service_steps,agency.reservation_service_tasks FROM PUBLIC;
REVOKE ALL ON FUNCTION agency.start_reservation_service(uuid,uuid,uuid),
  agency.finish_reservation_service_task(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT SELECT ON agency.category_service_steps TO agency_app;
GRANT EXECUTE ON FUNCTION agency.start_reservation_service(uuid,uuid,uuid),
  agency.finish_reservation_service_task(uuid,uuid,uuid,text,text) TO agency_app;
