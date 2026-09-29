-- ParamPOS aktif ödeme konfigürasyonu agency.integrations üzerinden sealed alanlarla yürür.
-- Eski admin/settings akışından kalmış düz metin ParamPOS secret ayarlarını tutmayalım.
delete from agency.settings
where key in ('parampos_password', 'parampos_guid');
