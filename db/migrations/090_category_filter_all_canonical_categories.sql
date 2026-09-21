-- Managed category filters are available for every canonical main category.
-- The filter system must not be limited to holiday_home/yacht, and it must not
-- accept one-sided or non-contract category codes.

ALTER TABLE agency.category_filter_groups
  DROP CONSTRAINT IF EXISTS category_filter_groups_category_code_contract_chk;

ALTER TABLE agency.category_filter_groups
  ADD CONSTRAINT category_filter_groups_category_code_contract_chk
  CHECK (
    category_code IN (
      'hotel',
      'holiday_home',
      'yacht',
      'tour',
      'activity',
      'flight',
      'car',
      'cruise',
      'pilgrimage',
      'visa',
      'ferry',
      'transfer',
      'beach',
      'cinema',
      'event',
      'restaurant',
      'bus'
    )
  );
