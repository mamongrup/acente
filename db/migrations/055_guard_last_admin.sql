-- 055: never allow an accidental removal of the last active administrator.
CREATE OR REPLACE FUNCTION agency.guard_last_active_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, agency, public
AS $$
BEGIN
  IF OLD.active
     AND OLD.membership_type = 'admin'
     AND (NEW.active = false OR NEW.membership_type <> 'admin')
     AND NOT EXISTS (
       SELECT 1 FROM agency.users u
       WHERE u.tenant_id = OLD.tenant_id
         AND u.id <> OLD.id
         AND u.active
         AND u.membership_type = 'admin'
     )
  THEN
    RAISE EXCEPTION 'last active administrator cannot be disabled or demoted';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agency_users_last_admin_trigger ON agency.users;
CREATE TRIGGER agency_users_last_admin_trigger
BEFORE UPDATE OF active, membership_type ON agency.users
FOR EACH ROW EXECUTE FUNCTION agency.guard_last_active_admin();
