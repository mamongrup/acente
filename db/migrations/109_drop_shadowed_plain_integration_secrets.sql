-- Sealed karşılığı bulunan eski düz metin entegrasyon secret alanlarını temizle.
-- Sealed karşılığı yoksa düz alan bırakılır; aksi halde çalışan eski entegrasyon sessizce kırılabilir.
update agency.integrations
set credentials =
  credentials
  - case when credentials ? 'password_sealed' then 'password' else '__keep_password__' end
  - case when credentials ? 'api_key_sealed' then 'api_key' else '__keep_api_key__' end
  - case when credentials ? 'token_sealed' then 'token' else '__keep_token__' end
  - case when credentials ? 'netgsm_pass_sealed' then 'netgsm_pass' else '__keep_netgsm_pass__' end
  - case when credentials ? 'whatsapp_token_sealed' then 'whatsapp_token' else '__keep_whatsapp_token__' end
  - case when credentials ? 'access_token_sealed' then 'access_token' else '__keep_access_token__' end
  - case when credentials ? 'pinterest_token_sealed' then 'pinterest_token' else '__keep_pinterest_token__' end
where credentials ?| array[
  'password_sealed',
  'api_key_sealed',
  'token_sealed',
  'netgsm_pass_sealed',
  'whatsapp_token_sealed',
  'access_token_sealed',
  'pinterest_token_sealed'
];
