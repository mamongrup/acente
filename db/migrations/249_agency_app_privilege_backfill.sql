-- Fresh-install privilege backfill for the application role.
--
-- Live databases received these grants operationally, but the migration
-- chain only covered part of the surface, so a fresh database broke:
--   1. any insert consuming a SERIAL-style sequence
--      (e.g. agency.application_document_revision_seq used by
--      application_documents); identity-column sequences are unaffected
--      either way, granting them here is harmless and keeps the rule uniform.
--   2. helper functions the app calls directly or through its workers
--      (commercial workspace, connected-order, public-inquiry and
--      supplier-review guards).
--
-- Only missing grants are added; nothing already granted is tightened.
-- Note: functions owned by in-review migrations (e.g. the SEO listing
-- helpers) grant their own EXECUTE in their own migrations.

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA agency TO agency_app;

GRANT EXECUTE ON FUNCTION agency.commercial_admin(uuid, uuid) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.guard_connected_category_order() TO agency_app;
GRANT EXECUTE ON FUNCTION agency.guard_public_inquiry_listing_scope() TO agency_app;
GRANT EXECUTE ON FUNCTION agency.reconcile_partner_bonus(uuid, uuid) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.supplier_review_actor_allowed(uuid, uuid) TO agency_app;
