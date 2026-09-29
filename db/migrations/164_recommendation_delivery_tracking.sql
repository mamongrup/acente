ALTER TABLE agency.notifications ADD COLUMN IF NOT EXISTS provider_message_id text;
ALTER TABLE agency.notifications ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'pending'
  CHECK(delivery_status IN ('pending','accepted','delivered','read','failed'));
ALTER TABLE agency.notifications ADD COLUMN IF NOT EXISTS delivered_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS agency_notifications_provider_message_idx
  ON agency.notifications(provider_message_id) WHERE provider_message_id IS NOT NULL;

CREATE OR REPLACE FUNCTION agency.recommendation_notification_state() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $$
BEGIN
  IF NEW.template='travel.recommendation' THEN
    IF NEW.status='sent' AND NEW.delivery_status='pending' THEN NEW.delivery_status:='accepted'; END IF;
    IF NEW.status='failed' THEN NEW.delivery_status:='failed'; END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS recommendation_notification_state ON agency.notifications;
CREATE TRIGGER recommendation_notification_state BEFORE INSERT OR UPDATE OF status ON agency.notifications
FOR EACH ROW EXECUTE FUNCTION agency.recommendation_notification_state();

CREATE OR REPLACE FUNCTION agency.record_whatsapp_delivery(p_provider_id text,p_status text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
  IF length(coalesce(p_provider_id,''))>255 OR p_status NOT IN ('sent','delivered','read','failed') THEN RETURN false; END IF;
  UPDATE agency.notifications SET
    delivery_status=CASE p_status WHEN 'sent' THEN 'accepted' ELSE p_status END,
    status=CASE p_status WHEN 'delivered' THEN 'delivered' WHEN 'read' THEN 'read' WHEN 'failed' THEN 'failed' ELSE status END,
    delivered_at=CASE WHEN p_status IN ('delivered','read') THEN coalesce(delivered_at,now()) ELSE delivered_at END,
    last_error=CASE WHEN p_status='failed' THEN 'WhatsApp sağlayıcısı mesajı teslim edemedi.' ELSE last_error END
  WHERE provider_message_id=p_provider_id AND channel='whatsapp' AND template='travel.recommendation'
    AND (delivery_status NOT IN ('read','delivered') OR p_status='read');
  RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION agency.record_whatsapp_delivery(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.record_whatsapp_delivery(text,text) TO agency_app;
