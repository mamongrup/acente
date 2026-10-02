BEGIN;
CREATE TABLE IF NOT EXISTS agency.customer_verification (
  user_id uuid PRIMARY KEY REFERENCES agency.users(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  email_verified_at timestamptz,
  phone_verified_at timestamptz,
  identity_status text NOT NULL DEFAULT 'pending' CHECK(identity_status IN ('pending','manual_approved','rejected','nvi_verified')),
  national_id_digest text,
  national_id_last_four text CHECK(national_id_last_four ~ '^[0-9]{4}$'),
  birth_date date,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES agency.users(id),
  review_reason text NOT NULL DEFAULT '',
  UNIQUE(tenant_id,user_id)
);
CREATE INDEX IF NOT EXISTS customer_verification_pending_idx ON agency.customer_verification(tenant_id,identity_status,submitted_at);
GRANT SELECT ON agency.customer_verification TO agency_app;

CREATE OR REPLACE FUNCTION agency.submit_customer_identity(p_tenant uuid,p_user uuid,p_national_id text,p_birth date)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$
DECLARE digits integer[]; total integer; i integer;
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_user AND tenant_id=p_tenant AND membership_type='customer' AND active) THEN RETURN 'forbidden'; END IF;
  IF p_national_id !~ '^[1-9][0-9]{10}$' OR p_birth IS NULL OR p_birth>current_date OR p_birth<date '1900-01-01' THEN RETURN 'invalid'; END IF;
  digits:=ARRAY(SELECT substring(p_national_id FROM n FOR 1)::integer FROM generate_series(1,11) n);
  IF ((digits[1]+digits[3]+digits[5]+digits[7]+digits[9])*7-(digits[2]+digits[4]+digits[6]+digits[8]))%10 <> digits[10] THEN RETURN 'invalid'; END IF;
  total:=0; FOR i IN 1..10 LOOP total:=total+digits[i]; END LOOP;
  IF total%10<>digits[11] THEN RETURN 'invalid'; END IF;
  IF EXISTS(SELECT 1 FROM agency.customer_verification WHERE user_id=p_user AND identity_status IN ('manual_approved','nvi_verified')) THEN RETURN 'already_approved'; END IF;
  IF EXISTS(SELECT 1 FROM agency.customer_verification WHERE user_id=p_user AND submitted_at>now()-interval '1 minute') THEN RETURN 'rate_limited'; END IF;
  INSERT INTO agency.customer_verification(user_id,tenant_id,national_id_digest,national_id_last_four,birth_date,submitted_at)
    VALUES(p_user,p_tenant,encode(digest(p_tenant::text||':'||p_national_id,'sha256'),'hex'),right(p_national_id,4),p_birth,now())
    ON CONFLICT(user_id) DO UPDATE SET national_id_digest=excluded.national_id_digest,national_id_last_four=excluded.national_id_last_four,birth_date=excluded.birth_date,submitted_at=now(),identity_status='pending',reviewed_at=NULL,reviewed_by=NULL,review_reason='';
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,p_user,'customer.identity.submitted','user',p_user,'{}');
  INSERT INTO agency.notifications(tenant_id,user_id,channel,template,payload,status)
    SELECT p_tenant,id,'email','customer.identity.review',jsonb_build_object('to',email,'email',email,'subject','Üye kimlik incelemesi bekliyor','html','<p>Yeni bir üye kimlik başvurusu yönetici incelemesi bekliyor. Yönetim panelindeki Üye kimlik incelemeleri ekranını açın.</p>'),'queued'
    FROM agency.users WHERE tenant_id=p_tenant AND membership_type='admin' AND active;
  RETURN 'pending';
END $$;

CREATE OR REPLACE FUNCTION agency.review_customer_identity(p_tenant uuid,p_admin uuid,p_user uuid,p_decision text,p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,agency AS $$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM agency.users WHERE id=p_admin AND tenant_id=p_tenant AND membership_type='admin' AND active) THEN RETURN 'forbidden'; END IF;
  IF p_decision NOT IN ('manual_approved','rejected') OR length(trim(p_reason))<10 OR length(p_reason)>1000 THEN RETURN 'invalid'; END IF;
  UPDATE agency.customer_verification SET identity_status=p_decision,reviewed_at=now(),reviewed_by=p_admin,review_reason=trim(p_reason) WHERE tenant_id=p_tenant AND user_id=p_user AND identity_status='pending' AND submitted_at IS NOT NULL;
  IF NOT FOUND THEN RETURN 'conflict'; END IF;
  INSERT INTO agency.audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) VALUES(p_tenant,p_admin,'customer.identity.reviewed','user',p_user,jsonb_build_object('decision',p_decision,'reason',trim(p_reason)));
  INSERT INTO agency.customer_notifications(tenant_id,user_id,kind,title,message,target_url)
    VALUES(p_tenant,p_user,'identity_review','Kimlik incelemeniz tamamlandı',case when p_decision='manual_approved' then 'Kimlik başvurunuz yönetici tarafından onaylandı.' else 'Kimlik başvurunuz için düzeltme gerekiyor. Profil bölümünde inceleme gerekçesini görebilirsiniz.' end,'/hesap#profile');
  RETURN p_decision;
END $$;
REVOKE ALL ON FUNCTION agency.submit_customer_identity(uuid,uuid,text,date),agency.review_customer_identity(uuid,uuid,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.submit_customer_identity(uuid,uuid,text,date),agency.review_customer_identity(uuid,uuid,uuid,text,text) TO agency_app;
COMMIT;
