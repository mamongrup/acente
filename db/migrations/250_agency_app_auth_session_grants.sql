-- Fresh-install privilege parity for the agency_auth session store.
--
-- Live databases applied migrations as the application role, so
-- agency_auth objects ended up owned by (and accessible to) agency_app.
-- Fresh databases apply migrations as postgres, and the migration chain
-- only granted these objects to the retired operator role. Mirror the
-- effective live capabilities for the application role.
GRANT USAGE ON SCHEMA agency_auth TO agency_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON agency_auth.sessions TO agency_app;
