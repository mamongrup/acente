BEGIN;

DO $$
DECLARE
  v_tenant_id uuid;
  v_listing_id uuid;
  v_post_id uuid;
  v_post_record record;
  v_policy_id uuid;
  v_event_count integer;
  v_manual_first uuid;
  v_manual_second uuid;
  v_other_tenant uuid;
  v_isolation_leak integer;
  v_own_visible integer;
BEGIN
  -- 1. Test tenantı seç
  SELECT id INTO v_tenant_id FROM agency.tenants WHERE slug = 'nexus-demo' LIMIT 1;
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Test tenantı bulunamadı';
  END IF;

  -- 2. Test ilanı oluştur (Sözleşme kurallarına uygun)
  INSERT INTO agency.listings(tenant_id, code, category, title, locality, description, currency, price_minor, status, source, images, owner_info, cancellation_policy, metadata)
  VALUES (
    v_tenant_id,
    'test-social-' || gen_random_uuid(),
    'holiday_home',
    'Lüks Kaş Balayı Villası',
    'Kaş, Antalya',
    'Eşsiz deniz manzaralı ve korunaklı havuzlu lüks villa.',
    'TRY',
    250000,
    'published',
    'manual',
    jsonb_build_array(jsonb_build_object('url', 'https://example.com/villa.jpg')),
    jsonb_build_object('provider', 'Test Villa Sahibi'),
    jsonb_build_object('policy', 'Standart İptal'),
    jsonb_build_object('contract_fields', jsonb_build_object('property_type', 'villa', 'bedroom_count', 3, 'bathroom_count', 3, 'guest_capacity', 6))
  )
  RETURNING id INTO v_listing_id;

  -- 3. Otomasyon politikası oluştur (Instagram, günlük limit 10, manuel onaylı)
  INSERT INTO agency.social_automation_policies(tenant_id, network, language_code, daily_limit, auto_generate, approval_required, updated_at)
  VALUES (v_tenant_id, 'instagram', 'tr', 10, true, true, now())
  ON CONFLICT (tenant_id, network, language_code, market_code)
  DO UPDATE SET daily_limit = EXCLUDED.daily_limit, approval_required = EXCLUDED.approval_required, updated_at = now()
  RETURNING id INTO v_policy_id;

  -- 4. Yapay zeka ile üretilmiş sosyal medya taslağı ekle (ai_generated = true, entity_type = 'listing')
  INSERT INTO agency.social_posts(
    tenant_id,
    entity_type,
    entity_id,
    network,
    language_code,
    content,
    scheduled_at,
    metadata,
    approved_at,
    ai_generated,
    status
  )
  VALUES (
    v_tenant_id,
    'listing',
    v_listing_id,
    'instagram',
    'tr',
    '✨ Kaş''ın en büyüleyici koylarına bakan Lüks Balayı Villası sizleri bekliyor! 🌊 Özel havuz ve gün batımı manzarasıyla unutulmaz bir tatil. #tatil #kas #villa',
    now() + interval '1 day',
    jsonb_build_object('media_url', 'https://example.com/villa.jpg', 'approval_required', true, 'listing_id', v_listing_id::text, 'ai_generated', true),
    NULL,
    TRUE,
    'queued'
  )
  RETURNING id INTO v_post_id;

  -- Doğrula: Post başarıyla eklendi, ai_generated = true ve henüz onaylanmadı
  SELECT * INTO v_post_record FROM agency.social_posts WHERE id = v_post_id;
  IF v_post_record.ai_generated IS NOT TRUE THEN
    RAISE EXCEPTION 'ai_generated kolonu TRUE olarak kaydedilmedi';
  END IF;
  IF v_post_record.approved_at IS NOT NULL THEN
    RAISE EXCEPTION 'approval_required olan post onaylanmadan approved_at aldı';
  END IF;
  IF v_post_record.entity_type <> 'listing' OR v_post_record.entity_id <> v_listing_id THEN
    RAISE EXCEPTION 'İlan entity ilişkilendirmesi hatalı';
  END IF;

  -- The studio resolves a listing by id, code or title and always scopes the
  -- lookup to the session tenant (see the `listing` CTE in router.gleam).
  -- Ask for this agency's listing under a *different* tenant's id: the lookup
  -- must come back empty. The previous version of this check compared
  -- v_listing_id against the other tenant, which is false by construction and
  -- therefore passed without asserting anything.
  SELECT id INTO v_other_tenant FROM agency.tenants WHERE id <> v_tenant_id LIMIT 1;
  IF v_other_tenant IS NULL THEN
    RAISE EXCEPTION 'İzolasyon testi için ikinci bir tenant gerekli';
  END IF;

  WITH listing AS (
    SELECT id FROM agency.listings
    WHERE tenant_id = v_other_tenant::uuid
      AND (id::text = v_listing_id::text
           OR code ILIKE '%' || v_listing_id::text || '%'
           OR title ILIKE '%' || v_listing_id::text || '%')
    ORDER BY id LIMIT 1
  )
  SELECT count(*) INTO v_isolation_leak FROM listing;
  IF v_isolation_leak <> 0 THEN
    RAISE EXCEPTION 'Başka tenant bağlamında bu acentinin ilanı çözümlendi';
  END IF;

  -- The same lookup under the owning tenant must still resolve, otherwise the
  -- check above would also pass on a lookup that is simply broken.
  WITH listing AS (
    SELECT id FROM agency.listings
    WHERE tenant_id = v_tenant_id::uuid AND id::text = v_listing_id::text
    LIMIT 1
  )
  SELECT count(*) INTO v_own_visible FROM listing;
  IF v_own_visible <> 1 THEN
    RAISE EXCEPTION 'Sahibi tenant ilanını göremiyor';
  END IF;

  -- Manual drafts must not share the tenant UUID as their entity ID.
  INSERT INTO agency.social_posts(tenant_id, entity_type, entity_id, network, language_code, content, approved_at, moderation_status)
  VALUES (v_tenant_id, 'manual', gen_random_uuid(), 'facebook', 'tr', 'İlk manuel taslak', NULL, 'pending')
  RETURNING entity_id INTO v_manual_first;
  INSERT INTO agency.social_posts(tenant_id, entity_type, entity_id, network, language_code, content, approved_at, moderation_status)
  VALUES (v_tenant_id, 'manual', gen_random_uuid(), 'facebook', 'tr', 'İkinci manuel taslak', NULL, 'pending')
  RETURNING entity_id INTO v_manual_second;
  IF v_manual_first = v_manual_second OR v_manual_first = v_tenant_id OR v_manual_second = v_tenant_id THEN
    RAISE EXCEPTION 'Manuel taslak entity kimlikleri benzersiz değil';
  END IF;

  -- 5. Moderasyon: Gönderiyi onayla (approve)
  WITH changed AS (
    UPDATE agency.social_posts
    SET approved_at = now(), moderation_status = 'approved'
    WHERE tenant_id = v_tenant_id AND id = v_post_id AND status = 'queued' AND approved_at IS NULL
    RETURNING tenant_id, id
  )
  INSERT INTO agency.social_post_events(tenant_id, social_post_id, event_type, payload)
  SELECT tenant_id, id, 'approved', '{}'::jsonb FROM changed;

  -- Doğrula: approved_at dolduruldu ve event kaydedildi
  SELECT COUNT(*) INTO v_event_count FROM agency.social_post_events WHERE social_post_id = v_post_id AND event_type = 'approved';
  IF v_event_count <> 1 THEN
    RAISE EXCEPTION 'Onaylama olay kaydı (event) oluşturulamadı';
  END IF;

  SELECT approved_at INTO v_post_record.approved_at FROM agency.social_posts WHERE id = v_post_id;
  IF v_post_record.approved_at IS NULL THEN
    RAISE EXCEPTION 'Post onaylandıktan sonra approved_at güncellenmedi';
  END IF;

  -- 6. Simülasyon: Gönderim başarısız olursa (delivery_unknown) ve yeniden sıraya alınırsa (retry)
  UPDATE agency.social_posts
  SET status = 'failed', failure_code = 'delivery_unknown', error = 'Ağ zaman aşımı'
  WHERE id = v_post_id;

  WITH changed AS (
    UPDATE agency.social_posts
    SET status = 'queued',
        approved_at = coalesce(approved_at, now()),
        moderation_status = 'approved',
        next_attempt_at = now(),
        started_at = NULL,
        attempts = 0,
        error = '',
        failure_code = NULL
    WHERE tenant_id = v_tenant_id AND id = v_post_id AND status = 'failed' AND failure_code = 'delivery_unknown'
    RETURNING tenant_id, id
  )
  INSERT INTO agency.social_post_events(tenant_id, social_post_id, event_type, payload)
  SELECT tenant_id, id, 'requeued', '{}'::jsonb FROM changed;

  SELECT COUNT(*) INTO v_event_count FROM agency.social_post_events WHERE social_post_id = v_post_id AND event_type = 'requeued';
  IF v_event_count <> 1 THEN
    RAISE EXCEPTION 'Yeniden sıraya alma olay kaydı oluşturulamadı';
  END IF;

  RAISE NOTICE 'Sosyal Medya & Yapay Zeka Stüdyosu Kabul Testi: BAŞARILI';
END $$;

ROLLBACK;
