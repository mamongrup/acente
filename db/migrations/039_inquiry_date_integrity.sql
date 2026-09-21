DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'public_inquiries_date_order_ck'
  ) THEN
    ALTER TABLE agency.public_inquiries
      ADD CONSTRAINT public_inquiries_date_order_ck
      CHECK (check_in IS NULL OR check_out IS NULL OR check_out > check_in);
  END IF;
END $$;
