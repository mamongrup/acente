-- Paket, komisyon ve müsaitlik için merkezi ve tekrar kullanılabilir hesap kuralları.
CREATE OR REPLACE FUNCTION agency.calculate_package_total(p_package uuid)
RETURNS bigint LANGUAGE sql STABLE AS $$
  SELECT coalesce(sum(i.price_minor * greatest(i.quantity,1)),0)::bigint
  FROM agency.travel_package_items i WHERE i.package_id=p_package;
$$;

CREATE OR REPLACE FUNCTION agency.refresh_package_price(p_package uuid)
RETURNS bigint LANGUAGE plpgsql AS $$
DECLARE v_total bigint;
BEGIN
  v_total := agency.calculate_package_total(p_package);
  UPDATE agency.travel_packages SET price_minor=v_total WHERE id=p_package;
  RETURN v_total;
END;
$$;

CREATE OR REPLACE FUNCTION agency.calculate_commission(
  p_tenant uuid, p_category text, p_channel text, p_supplier uuid, p_amount_minor bigint, p_at timestamptz DEFAULT now()
) RETURNS bigint LANGUAGE sql STABLE AS $$
  SELECT coalesce(round(p_amount_minor * coalesce(r.percentage,0) / 100.0)::bigint,0) + coalesce(r.fixed_minor,0)
  FROM agency.commission_rules r
  WHERE r.tenant_id=p_tenant AND r.active
    AND (r.category_code IS NULL OR r.category_code=p_category)
    AND (r.channel=p_channel OR r.channel='all')
    AND (r.supplier_id IS NULL OR r.supplier_id=p_supplier)
    AND (r.starts_at IS NULL OR r.starts_at<=p_at) AND (r.ends_at IS NULL OR r.ends_at>=p_at)
  ORDER BY (r.supplier_id IS NOT NULL) DESC,(r.category_code IS NOT NULL) DESC,(r.channel<>'all') DESC LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION agency.available_capacity(p_tenant uuid,p_listing uuid,p_date date)
RETURNS int LANGUAGE sql STABLE AS $$
  SELECT greatest(coalesce(capacity,0)-coalesce(reserved,0)-coalesce(blocked,0),0)
  FROM agency.availability_snapshots WHERE tenant_id=p_tenant AND listing_id=p_listing AND date=p_date;
$$;

CREATE OR REPLACE FUNCTION agency.detect_overbooking_signals()
RETURNS int LANGUAGE plpgsql AS $$
DECLARE v_count int;
BEGIN
  INSERT INTO agency.ai_inventory_signals(tenant_id,listing_id,signal_type,severity,value)
  SELECT a.tenant_id,a.listing_id,'overbooking','critical',jsonb_build_object('date',a.date,'capacity',a.capacity,'reserved',a.reserved,'blocked',a.blocked)
  FROM agency.availability_snapshots a
  WHERE a.reserved+a.blocked>a.capacity
    AND NOT EXISTS (SELECT 1 FROM agency.ai_inventory_signals s WHERE s.tenant_id=a.tenant_id AND s.listing_id=a.listing_id AND s.signal_type='overbooking' AND s.status='open' AND s.value->>'date'=a.date::text);
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION agency.calculate_package_total(uuid),agency.refresh_package_price(uuid),agency.calculate_commission(uuid,text,text,uuid,bigint,timestamptz),agency.available_capacity(uuid,uuid,date),agency.detect_overbooking_signals() TO agency_app;
