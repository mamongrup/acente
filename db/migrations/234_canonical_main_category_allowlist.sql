-- Keep the 17 versioned main category codes authoritative for both local and
-- synchronized listings. Child category codes remain tenant-managed.
ALTER TABLE agency.listings
  ADD CONSTRAINT agency_listings_canonical_main_category
  CHECK (category IN (
    'hotel','holiday_home','yacht','tour','activity','flight','car','cruise',
    'pilgrimage','visa','ferry','transfer','beach','cinema','event',
    'restaurant','bus'
  )) NOT VALID;

ALTER TABLE agency.categories
  ADD CONSTRAINT agency_categories_canonical_main_category
  CHECK (parent_id IS NOT NULL OR code IN (
    'hotel','holiday_home','yacht','tour','activity','flight','car','cruise',
    'pilgrimage','visa','ferry','transfer','beach','cinema','event',
    'restaurant','bus'
  )) NOT VALID;

ALTER TABLE agency.listings
  VALIDATE CONSTRAINT agency_listings_canonical_main_category;
ALTER TABLE agency.categories
  VALIDATE CONSTRAINT agency_categories_canonical_main_category;
