CREATE OR REPLACE FUNCTION agency.close_resolved_review_assignment()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE v_type text; v_id uuid; v_resolved boolean;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'listings' THEN
      v_type:='listing'; v_id:=NEW.id;
      v_resolved:=OLD.status='review' AND NEW.status<>'review';
    WHEN 'applications' THEN
      v_type:='application'; v_id:=NEW.id;
      v_resolved:=OLD.status IN ('pending','in_review') AND NEW.status NOT IN ('pending','in_review');
    WHEN 'supplier_documents' THEN
      v_type:='supplier_document'; v_id:=NEW.id;
      v_resolved:=OLD.status='pending' AND NEW.status<>'pending';
    WHEN 'supplier_booking_decisions' THEN
      v_type:='booking_decision'; v_id:=NEW.reservation_id;
      v_resolved:=OLD.applied_at IS NULL AND NEW.applied_at IS NOT NULL;
    ELSE RETURN NEW;
  END CASE;
  IF v_resolved THEN
    UPDATE agency.review_assignments SET status='closed',updated_at=now()
      WHERE tenant_id=NEW.tenant_id AND entity_type=v_type AND entity_id=v_id AND status='open';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS close_listing_review_assignment ON agency.listings;
CREATE TRIGGER close_listing_review_assignment AFTER UPDATE OF status ON agency.listings
  FOR EACH ROW EXECUTE FUNCTION agency.close_resolved_review_assignment();
DROP TRIGGER IF EXISTS close_application_review_assignment ON agency.applications;
CREATE TRIGGER close_application_review_assignment AFTER UPDATE OF status ON agency.applications
  FOR EACH ROW EXECUTE FUNCTION agency.close_resolved_review_assignment();
DROP TRIGGER IF EXISTS close_document_review_assignment ON agency.supplier_documents;
CREATE TRIGGER close_document_review_assignment AFTER UPDATE OF status ON agency.supplier_documents
  FOR EACH ROW EXECUTE FUNCTION agency.close_resolved_review_assignment();
DROP TRIGGER IF EXISTS close_booking_review_assignment ON agency.supplier_booking_decisions;
CREATE TRIGGER close_booking_review_assignment AFTER UPDATE OF applied_at ON agency.supplier_booking_decisions
  FOR EACH ROW EXECUTE FUNCTION agency.close_resolved_review_assignment();
