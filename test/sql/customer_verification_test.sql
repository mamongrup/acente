BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); customer uuid:=gen_random_uuid(); admin uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); result text;
BEGIN
INSERT INTO agency.tenants(id,legal_name,brand_name,slug) VALUES(t,'Verification test','Test',t::text),(other,'Other','Other',other::text);
INSERT INTO agency.users(id,tenant_id,email,display_name,membership_type) VALUES(customer,t,'customer@example.test','Test Customer','customer'),(admin,t,'admin@example.test','Test Admin','admin'),(outsider,other,'other@example.test','Other Admin','admin');
result:=agency.submit_customer_identity(t,customer,'11111111111',date '1990-01-01'); IF result<>'invalid' THEN RAISE EXCEPTION 'Invalid checksum accepted'; END IF;
-- Synthetic number with valid checksum; this never claims a real NVİ match.
result:=agency.submit_customer_identity(t,customer,'10000000146',date '1990-01-01'); IF result<>'pending' THEN RAISE EXCEPTION 'Submission failed: %',result; END IF;
result:=agency.review_customer_identity(t,outsider,customer,'manual_approved','Cross tenant test'); IF result<>'forbidden' THEN RAISE EXCEPTION 'Tenant isolation failed'; END IF;
result:=agency.review_customer_identity(t,admin,customer,'nvi_verified','Fake provider test'); IF result<>'invalid' THEN RAISE EXCEPTION 'Fake NVİ accepted'; END IF;
result:=agency.review_customer_identity(t,admin,customer,'manual_approved','Documents reviewed manually'); IF result<>'manual_approved' THEN RAISE EXCEPTION 'Review failed'; END IF;
result:=agency.review_customer_identity(t,admin,customer,'rejected','Repeated decision'); IF result<>'conflict' THEN RAISE EXCEPTION 'Decision overwritten'; END IF;
IF NOT EXISTS(SELECT 1 FROM agency.customer_notifications WHERE tenant_id=t AND user_id=customer AND kind='identity_review') THEN RAISE EXCEPTION 'Missing customer notice'; END IF;
END $$;
ROLLBACK;
