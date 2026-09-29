CREATE UNIQUE INDEX IF NOT EXISTS agency_listings_tenant_id_unique
  ON agency.listings(tenant_id,id);

CREATE TABLE IF NOT EXISTS agency.listing_sync_conflicts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  listing_id uuid NOT NULL,
  external_listing_id text NOT NULL,
  conflicting_code text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK(status IN ('open','resolved')),
  detected_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid,
  UNIQUE(tenant_id,external_listing_id),
  FOREIGN KEY(tenant_id,listing_id) REFERENCES agency.listings(tenant_id,id),
  FOREIGN KEY(tenant_id,resolved_by) REFERENCES agency.users(tenant_id,id)
);

CREATE OR REPLACE FUNCTION agency.record_listing_sync_conflict(
  p_tenant uuid,p_external text,p_code text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_id uuid;
BEGIN
  IF p_external IS NULL OR length(p_external) NOT BETWEEN 1 AND 160
    OR p_code IS NULL OR length(p_code) NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION 'invalid_sync_conflict';
  END IF;
  INSERT INTO agency.listing_sync_conflicts(tenant_id,listing_id,external_listing_id,conflicting_code)
    SELECT p_tenant,l.id,p_external,p_code FROM agency.listings l
    WHERE l.tenant_id=p_tenant AND l.code=p_code AND l.source='manual'
    ON CONFLICT(tenant_id,external_listing_id) DO UPDATE
      SET listing_id=excluded.listing_id,conflicting_code=excluded.conflicting_code,
        status='open',detected_at=now(),resolved_at=NULL,resolved_by=NULL
    RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION agency.release_listing_sync_code(
  p_tenant uuid,p_actor uuid,p_conflict uuid
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_conflict agency.listing_sync_conflicts%ROWTYPE; v_code text;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE tenant_id=p_tenant AND id=p_actor
    AND active AND membership_type='admin') THEN RAISE EXCEPTION 'sync_resolution_forbidden'; END IF;
  SELECT * INTO v_conflict FROM agency.listing_sync_conflicts
    WHERE id=p_conflict AND tenant_id=p_tenant AND status='open' FOR UPDATE;
  IF v_conflict.id IS NULL THEN RAISE EXCEPTION 'sync_conflict_not_open'; END IF;
  v_code:='LOCAL-'||replace(v_conflict.listing_id::text,'-','');
  UPDATE agency.listings SET code=v_code,updated_at=now()
    WHERE tenant_id=p_tenant AND id=v_conflict.listing_id AND code=v_conflict.conflicting_code
      AND source='manual';
  IF NOT FOUND THEN RAISE EXCEPTION 'local_listing_not_matching'; END IF;
  UPDATE agency.listing_sync_conflicts SET status='resolved',resolved_at=now(),resolved_by=p_actor
    WHERE id=p_conflict;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    VALUES(p_tenant,p_actor,'listing.sync_code_released','listing',v_conflict.listing_id,
      jsonb_build_object('oldCode',v_conflict.conflicting_code,'newCode',v_code,
        'externalListingId',v_conflict.external_listing_id));
  RETURN v_conflict.listing_id;
END $$;

REVOKE ALL ON FUNCTION agency.record_listing_sync_conflict(uuid,text,text),
  agency.release_listing_sync_code(uuid,uuid,uuid) FROM PUBLIC;
GRANT SELECT ON agency.listing_sync_conflicts TO agency_app;
GRANT EXECUTE ON FUNCTION agency.record_listing_sync_conflict(uuid,text,text),
  agency.release_listing_sync_code(uuid,uuid,uuid) TO agency_app;
