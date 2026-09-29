-- pgcrypto functions live in public while this security function has pg_catalog search_path.
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
    v_key:='price-'||NEW.id||'-'||encode(public.digest(v_payload::text,'sha256'),'hex');
  ELSE
    SELECT * INTO v_listing FROM agency.listings WHERE id=NEW.listing_id;
    IF NOT FOUND OR v_listing.source='nexus' THEN RETURN NEW; END IF;
    v_type:=CASE WHEN NEW.closed THEN 'restriction' ELSE 'availability' END;
    v_payload:=jsonb_build_object('listingCode',v_listing.code,'date',NEW.day,
      'unitsAvailable',NEW.units_available,'unitsTotal',NEW.units_total,'closed',NEW.closed);
    v_key:='inventory-'||NEW.listing_id||'-'||NEW.day||'-'||
      encode(public.digest(v_payload::text,'sha256'),'hex');
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

