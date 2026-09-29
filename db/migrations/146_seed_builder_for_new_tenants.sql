-- New standalone agencies get editable home, category and travel-blog layouts
-- without depending on the central supplier service.
CREATE OR REPLACE FUNCTION agency.seed_tenant_page_builder()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  category_code text;
  page_id uuid;
  section_key text;
  section_index integer;
  home_sections text[] := ARRAY['hero','adventure','why_host','featured','divider_one','how_it_works','become_host','newsletter','divider_two','explore_nearby','host_cta','stay_types','videos','news'];
  category_sections text[] := ARRAY['hero','results_heading','filters','listings','region','theme'];
BEGIN
  INSERT INTO agency.blog_categories (tenant_id,slug,title)
  VALUES (NEW.id,'gezilesi-yerler','Gezilesi Yerler')
  ON CONFLICT (tenant_id,slug) DO NOTHING;

  INSERT INTO agency.pages (tenant_id,slug,template,status,seo,published_at)
  VALUES (NEW.id,'home','standard','published','{}'::jsonb,now())
  ON CONFLICT (tenant_id,slug) DO NOTHING;
  SELECT id INTO page_id FROM agency.pages WHERE tenant_id=NEW.id AND slug='home';
  FOR section_index IN 1..array_length(home_sections,1) LOOP
    section_key := home_sections[section_index];
    INSERT INTO agency.page_blocks (page_id,block_type,sort_order,content)
    VALUES (page_id,'source_section',section_index-1,jsonb_build_object('sectionKey',section_key,'enabled',true));
  END LOOP;

  FOREACH category_code IN ARRAY ARRAY['hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus'] LOOP
    INSERT INTO agency.pages (tenant_id,slug,template,status,seo,published_at)
    VALUES (NEW.id,'category-'||category_code,'standard','published',jsonb_build_object('category_scope',category_code),now())
    ON CONFLICT (tenant_id,slug) DO NOTHING;
    SELECT id INTO page_id FROM agency.pages WHERE tenant_id=NEW.id AND slug='category-'||category_code;
    FOR section_index IN 1..array_length(category_sections,1) LOOP
      section_key := category_sections[section_index];
      INSERT INTO agency.page_blocks (page_id,block_type,sort_order,content)
      VALUES (page_id,'source_section',section_index-1,jsonb_build_object('sectionKey',section_key,'enabled',true));
    END LOOP;
    INSERT INTO agency.page_blocks (page_id,block_type,sort_order,content)
    VALUES (page_id,'region_places',6,jsonb_build_object('title','Gezilesi Yerler','blogCategory','gezilesi-yerler','limit',3));
    INSERT INTO agency.page_blocks (page_id,block_type,sort_order,content)
    VALUES (page_id,'source_section',7,jsonb_build_object('sectionKey','benefits','enabled',true));
  END LOOP;

  INSERT INTO agency.pages (tenant_id,slug,template,status,seo,published_at)
  VALUES (NEW.id,'blog/gezilesi-yerler','landing','published',jsonb_build_object('title','Gezilesi Yerler','description','Bölge rehberleri ve gezilesi yerler.','blog_category','gezilesi-yerler'),now())
  ON CONFLICT (tenant_id,slug) DO NOTHING;
  SELECT id INTO page_id FROM agency.pages WHERE tenant_id=NEW.id AND slug='blog/gezilesi-yerler';
  INSERT INTO agency.page_blocks (page_id,block_type,sort_order,content)
  VALUES (page_id,'region_places',0,jsonb_build_object('title','Gezilesi Yerler','blogCategory','gezilesi-yerler','limit',3));
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS agency_tenant_page_builder_seed ON agency.tenants;
CREATE TRIGGER agency_tenant_page_builder_seed
AFTER INSERT ON agency.tenants
FOR EACH ROW EXECUTE FUNCTION agency.seed_tenant_page_builder();
