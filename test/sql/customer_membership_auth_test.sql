BEGIN;
DO $$
DECLARE t uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); uid uuid; code text; result text;
BEGIN
INSERT INTO agency.tenants(id,legal_name,brand_name,slug) VALUES(t,'Auth test','Test',t::text),(other,'Other auth','Other',other::text);
result:=agency.customer_register(t,'Test Customer','auth@example.test','+905551234567','long-test-password',true); IF result<>'terms_unavailable' THEN RAISE EXCEPTION 'Missing terms accepted'; END IF;
INSERT INTO agency.settings(tenant_id,key,value) VALUES(t,'contract_membership',to_jsonb('Test membership document long enough'::text)),(t,'contract_privacy_policy',to_jsonb('Test privacy document long enough'::text));
result:=agency.customer_register(t,'Test Customer','auth@example.test','+905551234567','long-test-password',true); IF result<>'accepted' THEN RAISE EXCEPTION 'Registration failed: %',result; END IF;
SELECT id INTO uid FROM agency.users WHERE tenant_id=t AND email='auth@example.test';
SELECT substring(payload->>'html' FROM '<strong>([0-9]+)</strong>') INTO code FROM agency.notifications WHERE user_id=uid AND template='customer.auth.email' ORDER BY created_at DESC LIMIT 1;
IF code IS NULL THEN RAISE EXCEPTION 'Email code not queued'; END IF;
result:=agency.customer_auth_confirm(other,'auth@example.test','email',code,''); IF result<>'invalid_code' THEN RAISE EXCEPTION 'Cross tenant code accepted'; END IF;
result:=agency.customer_auth_confirm(t,'auth@example.test','email','incorrect',''); IF result<>'invalid_code' THEN RAISE EXCEPTION 'Incorrect code accepted'; END IF;
result:=agency.customer_auth_confirm(t,'auth@example.test','email',code,''); IF result<>'verified' THEN RAISE EXCEPTION 'Valid code rejected'; END IF;
result:=agency.customer_auth_confirm(t,'auth@example.test','email',code,''); IF result<>'invalid_code' THEN RAISE EXCEPTION 'Code reused'; END IF;
INSERT INTO auth.sessions(token_digest,user_id,expires_at) VALUES(encode(digest('auth-test-session','sha256'),'hex'),uid,now()+interval '1 hour');
result:=agency.customer_auth_request(t,'auth@example.test','reset','email');
SELECT substring(payload->>'html' FROM '<strong>([0-9]+)</strong>') INTO code FROM agency.notifications WHERE user_id=uid AND template='customer.auth.reset' ORDER BY created_at DESC LIMIT 1;
result:=agency.customer_auth_confirm(t,'auth@example.test','reset',code,'updated-long-password'); IF result<>'verified' THEN RAISE EXCEPTION 'Reset failed'; END IF;
IF EXISTS(SELECT 1 FROM auth.sessions WHERE user_id=uid) THEN RAISE EXCEPTION 'Old session retained'; END IF;
IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=uid AND crypt('updated-long-password',password_hash)=password_hash) THEN RAISE EXCEPTION 'Password unchanged'; END IF;
END $$;
ROLLBACK;
