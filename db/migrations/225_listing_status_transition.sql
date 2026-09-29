-- 225: İlan durum geçiş makinesi (WP1 — sözleşme, yetki ve geçerli geçiş kontrolü)
--
-- Sözleşme: draft → pending_review → published | paused | archived
--           published → paused | archived
--           paused → published | archived
-- İzin kuralı:
--   draft → pending_review : ilan sahibi (owner_user_id) veya tenant admin
--   pending_review → published : tenant admin veya reviewer rolü
--   pending_review → draft (ret) : tenant admin veya reviewer rolü
--   published/paused → paused/published : tenant admin
--   * → archived : tenant admin
--   Tedarikçi ilanları yayına geçmeden önce approved başvuru gereklidir (trigger ile)
--
-- WP1 kabul koşulu: Aynı sözleşme sürümündeki bir ilan iki projede aynı yetki
-- ve durum geçiş kararını vermelidir.

CREATE OR REPLACE FUNCTION agency.transition_listing_status(
  p_tenant    uuid,
  p_actor     uuid,
  p_listing   uuid,
  p_new_status text,
  p_note      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog'
AS $$
DECLARE
  v_old_status  text;
  v_owner       uuid;
  v_is_admin    boolean;
  v_is_reviewer boolean;
  v_is_owner    boolean;
  v_allowed     boolean := false;
BEGIN
  -- İlanı kilitle ve doğrula
  SELECT status, owner_user_id
  INTO STRICT v_old_status, v_owner
  FROM agency.listings
  WHERE id = p_listing AND tenant_id = p_tenant
  FOR UPDATE;

  -- Geçiş matrisi — aynı duruma geçiş yok
  IF v_old_status = p_new_status THEN
    RAISE EXCEPTION 'listing_status_unchanged' USING ERRCODE = '22000';
  END IF;

  -- İzin verilmeyen geçişler
  IF NOT (
    (v_old_status = 'draft'          AND p_new_status IN ('pending_review', 'archived'))
    OR (v_old_status = 'pending_review' AND p_new_status IN ('published', 'draft', 'archived'))
    OR (v_old_status = 'published'      AND p_new_status IN ('paused', 'archived'))
    OR (v_old_status = 'paused'         AND p_new_status IN ('published', 'archived'))
    OR (v_old_status = 'archived'       AND p_new_status IN ('draft'))
  ) THEN
    RAISE EXCEPTION 'listing_status_transition_not_allowed: % -> %', v_old_status, p_new_status
      USING ERRCODE = '22000';
  END IF;

  -- Aktör yetki kontrolü
  v_is_admin    := agency.has_panel_role(p_tenant, p_actor, 'admin');
  v_is_reviewer := agency.has_panel_role(p_tenant, p_actor, 'reviewer')
                   OR agency.has_panel_role(p_tenant, p_actor, 'listing_reviewer');
  v_is_owner    := (v_owner IS NOT NULL AND v_owner = p_actor);

  -- draft → pending_review: sahip veya admin
  IF v_old_status = 'draft' AND p_new_status = 'pending_review' THEN
    v_allowed := v_is_owner OR v_is_admin;

  -- pending_review → published: admin veya reviewer
  ELSIF v_old_status = 'pending_review' AND p_new_status = 'published' THEN
    v_allowed := v_is_admin OR v_is_reviewer;

  -- pending_review → draft (ret): admin veya reviewer
  ELSIF v_old_status = 'pending_review' AND p_new_status = 'draft' THEN
    v_allowed := v_is_admin OR v_is_reviewer;

  -- yayından duraklatma / tekrar yayın / arşiv: sadece admin
  ELSIF p_new_status IN ('paused', 'archived') THEN
    v_allowed := v_is_admin;

  -- arşivden taslağa geri al: admin
  ELSIF v_old_status = 'archived' AND p_new_status = 'draft' THEN
    v_allowed := v_is_admin;

  ELSE
    v_allowed := v_is_admin;
  END IF;

  IF NOT v_allowed THEN
    RAISE EXCEPTION 'listing_status_transition_access_denied'
      USING ERRCODE = '42501';
  END IF;

  -- Durum güncelle — trigger'lar sözleşme ve tedarikçi yayın kontrolünü yapar
  UPDATE agency.listings
  SET status = p_new_status,
      updated_at = now()
  WHERE id = p_listing AND tenant_id = p_tenant;

  -- Denetim kaydı
  INSERT INTO agency.audit_logs(tenant_id, user_id, entity_type, entity_id, action, metadata)
  VALUES (
    p_tenant, p_actor, 'listing', p_listing,
    'status_transition',
    jsonb_build_object(
      'from', v_old_status,
      'to',   p_new_status,
      'note', p_note
    )
  );
END;
$$;

COMMENT ON FUNCTION agency.transition_listing_status(uuid,uuid,uuid,text,text) IS
  'WP1 — sözleşme 1.2.0: Tenant korumalı ilan durum geçiş makinesi.
   Geçiş matrisi ve yetki kuralları NEXUS onboarding.transition_listing_status ile eşdeğerdir.';
