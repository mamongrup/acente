-- Public selectors must never fall through to an unrelated tenant. Empty
-- selectors are used only by the local preview/default storefront.
CREATE OR REPLACE FUNCTION agency.resolve_public_tenant(p_selector text)
RETURNS uuid LANGUAGE sql STABLE SECURITY INVOKER AS $$
  SELECT CASE
    WHEN btrim(coalesce(p_selector,'')) <> '' THEN
      coalesce(
        (SELECT t.id FROM agency.tenants t
         WHERE lower(t.slug)=lower(btrim(p_selector))
            OR t.id::text=btrim(p_selector)
         LIMIT 1),
        (SELECT d.tenant_id FROM agency.marketplace_domains d
         WHERE d.active AND lower(d.domain_host)=lower(btrim(p_selector))
         LIMIT 1)
      )
    ELSE
      coalesce(
        (SELECT t.id FROM agency.tenants t
         WHERE lower(t.slug)='nexus-demo'
           AND EXISTS (SELECT 1 FROM agency.listings l
                       WHERE l.tenant_id=t.id AND l.status='published')
         LIMIT 1),
        (SELECT t.id FROM agency.tenants t
         WHERE EXISTS (SELECT 1 FROM agency.listings l
                       WHERE l.tenant_id=t.id AND l.status='published')
         ORDER BY t.created_at LIMIT 1),
        (SELECT t.id FROM agency.tenants t ORDER BY t.created_at LIMIT 1)
      )
  END
$$;

REVOKE ALL ON FUNCTION agency.resolve_public_tenant(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION agency.resolve_public_tenant(text) TO agency_app;
