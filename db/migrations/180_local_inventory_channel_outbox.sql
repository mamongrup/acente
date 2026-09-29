-- Local price and availability changes produce idempotent channel work items.
-- No remote delivery occurs until an approved provider adapter is configured.
CREATE OR REPLACE FUNCTION agency.queue_local_channel_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_listing agency.listings%ROWTYPE; v_payload jsonb; v_key text;
  v_type text;
BEGIN
  IF TG_TABLE_NAME='listings' THEN
    IF NEW.source='nexus' OR NEW.price_minor IS NOT DISTINCT FROM OLD.price_minor THEN RETURN NEW; END IF;
    v_listing:=NEW;
    v_type:='price';
    v_payload:=jsonb_build_object('listingCode',NEW.code,'priceMinor',NEW.price_minor,
      'currency',NEW.currency,'updatedAt',NEW.updated_at);
    v_key:='price-'||NEW.id||'-'||encode(digest(v_payload::text,'sha256'),'hex');
  ELSE
    SELECT * INTO v_listing FROM agency.listings WHERE id=NEW.listing_id;
    IF NOT FOUND OR v_listing.source='nexus' THEN RETURN NEW; END IF;
    v_type:=CASE WHEN NEW.closed THEN 'restriction' ELSE 'availability' END;
    v_payload:=jsonb_build_object('listingCode',v_listing.code,'date',NEW.day,
      'unitsAvailable',NEW.units_available,'unitsTotal',NEW.units_total,'closed',NEW.closed);
    v_key:='inventory-'||NEW.listing_id||'-'||NEW.day||'-'||
      encode(digest(v_payload::text,'sha256'),'hex');
  END IF;
  INSERT INTO agency.channel_sync_outbox
    (tenant_id,channel_id,listing_id,event_key,event_type,payload)
  SELECT v_listing.tenant_id,m.channel_id,v_listing.id,v_key,v_type,v_payload
    FROM agency.channel_product_maps m
    JOIN agency.sales_channels c ON c.id=m.channel_id AND c.tenant_id=m.tenant_id
   WHERE m.tenant_id=v_listing.tenant_id AND m.listing_id=v_listing.id
     AND m.enabled AND c.mode IN ('test','live')
  ON CONFLICT(tenant_id,channel_id,event_key) DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS agency_listing_channel_price ON agency.listings;
CREATE TRIGGER agency_listing_channel_price AFTER UPDATE OF price_minor ON agency.listings
FOR EACH ROW EXECUTE FUNCTION agency.queue_local_channel_change();
DROP TRIGGER IF EXISTS agency_availability_channel_change ON agency.availability;
CREATE TRIGGER agency_availability_channel_change AFTER INSERT OR UPDATE OF units_total,units_available,closed
ON agency.availability FOR EACH ROW EXECUTE FUNCTION agency.queue_local_channel_change();

-- Tenant-scoped summary exposed through the admin workspace only.
CREATE OR REPLACE FUNCTION agency.channel_delivery_summary(p_tenant uuid,p_actor uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT agency.commercial_admin(p_tenant,p_actor) THEN RAISE EXCEPTION 'channel_access_denied'; END IF;
  SELECT jsonb_build_object('pending',count(*) FILTER(WHERE status='pending'),
    'failed',count(*) FILTER(WHERE status='failed'),
    'sent',count(*) FILTER(WHERE status='sent')) INTO v_result
    FROM agency.channel_sync_outbox WHERE tenant_id=p_tenant;
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION agency.channel_delivery_summary(uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.channel_delivery_summary(uuid,uuid) TO agency_app;
