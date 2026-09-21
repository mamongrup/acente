-- Keep the storefront language set aligned with the current product contract.
-- Arabic remains supported by the legacy i18n helpers for existing links, but
-- it is no longer an active storefront language. Chinese is the sixth active
-- language alongside Turkish, English, German, Russian and French.
INSERT INTO agency.languages(code, name, native_name, active, is_default)
VALUES ('zh', 'Chinese', '简体中文', true, false)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    native_name = EXCLUDED.native_name,
    active = true;

UPDATE agency.languages
SET active = false
WHERE code = 'ar';

UPDATE agency.languages
SET is_default = (code = 'tr')
WHERE code IN ('tr', 'en', 'de', 'ru', 'zh', 'fr');

GRANT SELECT, INSERT, UPDATE ON agency.languages TO agency_app;
