-- A tenant may work with several independent partner agencies. Existing
-- sub-agency users receive private organizations; sharing requires an explicit
-- administrator assignment. Legacy unowned records are not assigned.
CREATE TABLE IF NOT EXISTS agency.partner_organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES agency.tenants(id) ON DELETE CASCADE,
  name text NOT NULL CHECK(length(trim(name)) BETWEEN 2 AND 160),
  status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(tenant_id,id)
);
CREATE INDEX IF NOT EXISTS agency_partner_organizations_tenant_idx ON agency.partner_organizations(tenant_id,status,name);

CREATE UNIQUE INDEX IF NOT EXISTS agency_users_tenant_id_unique ON agency.users(tenant_id,id);
CREATE TABLE IF NOT EXISTS agency.partner_organization_members (
  tenant_id uuid NOT NULL,
  organization_id uuid NOT NULL,
  user_id uuid NOT NULL,
  member_role text NOT NULL DEFAULT 'agent' CHECK(member_role IN ('owner','manager','agent')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(tenant_id,user_id),
  FOREIGN KEY(tenant_id,organization_id) REFERENCES agency.partner_organizations(tenant_id,id) ON DELETE CASCADE,
  FOREIGN KEY(tenant_id,user_id) REFERENCES agency.users(tenant_id,id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS agency_partner_members_org_idx ON agency.partner_organization_members(tenant_id,organization_id);

ALTER TABLE agency.customers ADD COLUMN IF NOT EXISTS partner_organization_id uuid;
ALTER TABLE agency.reservations ADD COLUMN IF NOT EXISTS partner_organization_id uuid;
ALTER TABLE agency.offers ADD COLUMN IF NOT EXISTS partner_organization_id uuid;
ALTER TABLE agency.contact_requests ADD COLUMN IF NOT EXISTS partner_organization_id uuid;

ALTER TABLE agency.customers ADD CONSTRAINT agency_customers_partner_org_fk FOREIGN KEY(tenant_id,partner_organization_id) REFERENCES agency.partner_organizations(tenant_id,id);
ALTER TABLE agency.reservations ADD CONSTRAINT agency_reservations_partner_org_fk FOREIGN KEY(tenant_id,partner_organization_id) REFERENCES agency.partner_organizations(tenant_id,id);
ALTER TABLE agency.offers ADD CONSTRAINT agency_offers_partner_org_fk FOREIGN KEY(tenant_id,partner_organization_id) REFERENCES agency.partner_organizations(tenant_id,id);
ALTER TABLE agency.contact_requests ADD CONSTRAINT agency_contacts_partner_org_fk FOREIGN KEY(tenant_id,partner_organization_id) REFERENCES agency.partner_organizations(tenant_id,id);

CREATE INDEX IF NOT EXISTS agency_customers_partner_idx ON agency.customers(tenant_id,partner_organization_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_reservations_partner_idx ON agency.reservations(tenant_id,partner_organization_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_offers_partner_idx ON agency.offers(tenant_id,partner_organization_id,created_at DESC);
CREATE INDEX IF NOT EXISTS agency_contacts_partner_idx ON agency.contact_requests(tenant_id,partner_organization_id,created_at DESC);

DO $$
DECLARE account record; new_org uuid;
BEGIN
  FOR account IN
    SELECT u.id,u.tenant_id,u.display_name FROM agency.users u
    WHERE u.membership_type='sub_agency'
      AND NOT EXISTS (SELECT 1 FROM agency.partner_organization_members m WHERE m.tenant_id=u.tenant_id AND m.user_id=u.id)
  LOOP
    INSERT INTO agency.partner_organizations(tenant_id,name)
      VALUES(account.tenant_id,coalesce(nullif(trim(account.display_name),''),'Alt acente')) RETURNING id INTO new_org;
    INSERT INTO agency.partner_organization_members(tenant_id,organization_id,user_id,member_role)
      VALUES(account.tenant_id,new_org,account.id,'owner');
  END LOOP;
END $$;

UPDATE agency.customers c SET partner_organization_id=m.organization_id
FROM agency.partner_organization_members m WHERE c.tenant_id=m.tenant_id AND c.created_by_user_id=m.user_id AND c.partner_organization_id IS NULL;
UPDATE agency.reservations r SET partner_organization_id=m.organization_id
FROM agency.partner_organization_members m WHERE r.tenant_id=m.tenant_id AND r.created_by_user_id=m.user_id AND r.partner_organization_id IS NULL;
UPDATE agency.offers o SET partner_organization_id=m.organization_id
FROM agency.partner_organization_members m WHERE o.tenant_id=m.tenant_id AND o.created_by_user_id=m.user_id AND o.partner_organization_id IS NULL;

CREATE OR REPLACE FUNCTION agency.ensure_partner_organization_for_user()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE new_org uuid;
BEGIN
  IF NEW.membership_type='sub_agency' AND NOT EXISTS (
    SELECT 1 FROM agency.partner_organization_members m WHERE m.tenant_id=NEW.tenant_id AND m.user_id=NEW.id
  ) THEN
    INSERT INTO agency.partner_organizations(tenant_id,name)
      VALUES(NEW.tenant_id,coalesce(nullif(trim(NEW.display_name),''),'Alt acente')) RETURNING id INTO new_org;
    INSERT INTO agency.partner_organization_members(tenant_id,organization_id,user_id,member_role)
      VALUES(NEW.tenant_id,new_org,NEW.id,'owner');
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS agency_user_partner_organization ON agency.users;
CREATE TRIGGER agency_user_partner_organization AFTER INSERT OR UPDATE OF membership_type ON agency.users
FOR EACH ROW EXECUTE FUNCTION agency.ensure_partner_organization_for_user();

CREATE OR REPLACE FUNCTION agency.partner_can_access(p_tenant uuid,p_user uuid,p_organization uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT p_organization IS NOT NULL AND EXISTS (
    SELECT 1 FROM agency.partner_organization_members m
    JOIN agency.partner_organizations o ON o.tenant_id=m.tenant_id AND o.id=m.organization_id
    WHERE m.tenant_id=p_tenant AND m.user_id=p_user AND m.organization_id=p_organization AND o.status='active'
  )
$$;

GRANT SELECT,INSERT,UPDATE,DELETE ON agency.partner_organizations,agency.partner_organization_members TO agency_app;
GRANT EXECUTE ON FUNCTION agency.partner_can_access(uuid,uuid,uuid) TO agency_app;
