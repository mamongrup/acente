BEGIN;
DO $$
DECLARE v_listing uuid; v_tenant uuid; v_supplier uuid; v_application uuid; v_blocked boolean:=false;
BEGIN
  SELECT id,tenant_id INTO v_listing,v_tenant FROM agency.listings
  WHERE source='manual' AND status='published' AND category='hotel' LIMIT 1;
  IF v_listing IS NULL THEN RAISE EXCEPTION 'published manual hotel fixture missing'; END IF;
  INSERT INTO agency.users(tenant_id,email,display_name,membership_type)
  VALUES(v_tenant,'listing-gate-'||gen_random_uuid()||'@example.invalid','Listing Gate Supplier','supplier')
  RETURNING id INTO v_supplier;
  BEGIN
    UPDATE agency.listings SET owner_user_id=v_supplier WHERE id=v_listing;
  EXCEPTION WHEN insufficient_privilege THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'supplier published without approval'; END IF;
  INSERT INTO agency.applications(tenant_id,user_id,type,status,identity_status,category_code)
  VALUES(v_tenant,v_supplier,'supplier','approved','verified','hotel') RETURNING id INTO v_application;
  UPDATE agency.listings SET owner_user_id=v_supplier WHERE id=v_listing;
  IF (SELECT owner_user_id FROM agency.listings WHERE id=v_listing)<>v_supplier THEN
    RAISE EXCEPTION 'approved supplier could not own published listing';
  END IF;
  UPDATE agency.applications SET status='suspended' WHERE id=v_application;
  IF (SELECT status FROM agency.listings WHERE id=v_listing)<>'paused' THEN
    RAISE EXCEPTION 'supplier listing stayed published after approval loss';
  END IF;
END $$;
ROLLBACK;
