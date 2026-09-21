ALTER TABLE agency.public_inquiries ADD COLUMN IF NOT EXISTS check_in date;
ALTER TABLE agency.public_inquiries ADD COLUMN IF NOT EXISTS check_out date;
ALTER TABLE agency.public_inquiries ADD COLUMN IF NOT EXISTS guest_count int NOT NULL DEFAULT 1 CHECK (guest_count > 0);
