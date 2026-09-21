-- Repair legacy application status check constraints left from the original
-- pending/approved/rejected/deleted workflow.

ALTER TABLE agency.applications
  DROP CONSTRAINT IF EXISTS applications_status_check;

ALTER TABLE agency.applications
  DROP CONSTRAINT IF EXISTS agency_applications_status_contract_chk;

UPDATE agency.applications
SET status = 'submitted',
    updated_at = now()
WHERE status = 'pending';

ALTER TABLE agency.applications
  ADD CONSTRAINT agency_applications_status_contract_chk
  CHECK(status IN ('draft','submitted','in_review','approved','rejected','suspended','deleted'));
