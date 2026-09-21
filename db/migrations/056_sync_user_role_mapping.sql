-- 056: keep the explicit role relation in sync when membership_type changes.
CREATE OR REPLACE FUNCTION agency.sync_user_membership_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency, public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.membership_type <> OLD.membership_type THEN
    DELETE FROM agency.user_roles WHERE user_id = NEW.id;
    INSERT INTO agency.user_roles(user_id, role_id)
    SELECT NEW.id, r.id
    FROM agency.roles r
    WHERE r.tenant_id = NEW.tenant_id
      AND r.code = NEW.membership_type
    ON CONFLICT (user_id, role_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agency_users_membership_role_trigger ON agency.users;
CREATE TRIGGER agency_users_membership_role_trigger
AFTER UPDATE OF membership_type ON agency.users
FOR EACH ROW EXECUTE FUNCTION agency.sync_user_membership_role();
