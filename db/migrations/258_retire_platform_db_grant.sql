-- Corrective follow-up to the 5432 PostgreSQL cluster cleanup
-- (docs/db-cluster-cleanup-plan.md).
--
-- Leftover: migration 024_runtime_compatibility (line 6) granted CONNECT on
-- the pre-split platform database 'nexustraveltech'. The cleanup dropped that
-- database from this cluster, which retired the grant with it. This migration
-- makes the retirement explicit and idempotent on every installation:
-- fresh installs never had the grant (migrate.ps1 omits the leftover 024 line
-- when the platform database is absent from the cluster), while clusters that
-- still host the platform database drop the agency app's link grant here.
-- The agency chain must never fail over platform-cluster permissions, so a
-- missing ownership or missing role is tolerated as a no-op.
DO $retire_platform_db_grant$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'nexustraveltech') THEN
    BEGIN
      REVOKE CONNECT ON DATABASE nexustraveltech FROM agency_app;
    EXCEPTION WHEN insufficient_privilege OR undefined_object THEN
      NULL; -- platform cluster belongs to another installation; its owner performs the cleanup
    END;
  END IF;
END
$retire_platform_db_grant$;
