-- Agency-owned inventory remains independent. A local supplier's own
-- inventory needs an approved application for its category to be published.
CREATE OR REPLACE FUNCTION agency.guard_supplier_listing_publication()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.status='published' AND NEW.source='manual' AND NEW.owner_user_id IS NOT NULL
    AND EXISTS(SELECT 1 FROM agency.users u WHERE u.id=NEW.owner_user_id
      AND u.tenant_id=NEW.tenant_id AND u.membership_type='supplier')
    AND NOT EXISTS(SELECT 1 FROM agency.applications a
      WHERE a.tenant_id=NEW.tenant_id AND a.user_id=NEW.owner_user_id
        AND a.type='supplier' AND a.category_code=NEW.category AND a.status='approved')
  THEN RAISE EXCEPTION 'supplier_not_approved' USING ERRCODE='42501'; END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS supplier_listing_publication_guard ON agency.listings;
CREATE TRIGGER supplier_listing_publication_guard
BEFORE INSERT OR UPDATE OF status,category,owner_user_id,source ON agency.listings
FOR EACH ROW EXECUTE FUNCTION agency.guard_supplier_listing_publication();

CREATE OR REPLACE FUNCTION agency.pause_supplier_listings_on_application_loss()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF OLD.status='approved' AND NEW.status<>'approved' AND NEW.type='supplier'
    AND NOT EXISTS(SELECT 1 FROM agency.applications a
      WHERE a.id<>NEW.id AND a.tenant_id=NEW.tenant_id AND a.user_id=NEW.user_id
        AND a.type='supplier' AND a.category_code=NEW.category_code AND a.status='approved')
  THEN
    WITH changed AS (
      UPDATE agency.listings l SET status='paused',updated_at=now()
      WHERE l.tenant_id=NEW.tenant_id AND l.owner_user_id=NEW.user_id
        AND l.category=NEW.category_code AND l.source='manual' AND l.status='published'
      RETURNING l.id
    )
    INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
    SELECT NEW.tenant_id,coalesce(NEW.reviewed_by,NEW.user_id),
      'supplier_listing.paused_approval_lost','listing',c.id,
      jsonb_build_object('application_id',NEW.id,'application_status',NEW.status)
    FROM changed c;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS supplier_listing_application_loss ON agency.applications;
CREATE TRIGGER supplier_listing_application_loss AFTER UPDATE OF status ON agency.applications
FOR EACH ROW WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION agency.pause_supplier_listings_on_application_loss();
