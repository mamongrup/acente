-- Public teklif kayıtlarında ikinci savunma hattı.
-- NOT VALID mevcut eski kayıtları kilitlemeden yeni kayıtları doğrular.
ALTER TABLE agency.public_inquiries
  ADD CONSTRAINT public_inquiries_name_length_ck
    CHECK (char_length(trim(full_name)) BETWEEN 2 AND 160) NOT VALID;

ALTER TABLE agency.public_inquiries
  ADD CONSTRAINT public_inquiries_email_length_ck
    CHECK (char_length(trim(email)) BETWEEN 5 AND 320 AND position('@' in email) > 1) NOT VALID;

ALTER TABLE agency.public_inquiries
  ADD CONSTRAINT public_inquiries_message_length_ck
    CHECK (char_length(message) <= 5000 AND char_length(phone) <= 60) NOT VALID;

ALTER TABLE agency.public_inquiries
  ADD CONSTRAINT public_inquiries_guest_count_ck
    CHECK (guest_count >= 1) NOT VALID;
