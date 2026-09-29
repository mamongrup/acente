-- Contract-level supplier permission decisions for SQL-side guards and reports.

CREATE OR REPLACE FUNCTION agency.role_allows_supplier_permission(
  p_role text,
  p_permission text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_permission
    WHEN 'supplier.dashboard.view' THEN p_role IN ('owner','operations_director','content_moderator','general_manager','sales','editor')
    WHEN 'supplier.company.view' THEN p_role IN ('owner','operations_director','general_manager')
    WHEN 'supplier.company.manage' THEN p_role IN ('owner','operations_director','general_manager')
    WHEN 'supplier.documents.view' THEN p_role IN ('owner','operations_director','onboarding_specialist')
    WHEN 'supplier.documents.manage' THEN p_role IN ('owner','operations_director','onboarding_specialist')
    WHEN 'supplier.catalog.view' THEN p_role IN ('owner','operations_director','content_moderator','general_manager','sales','editor')
    WHEN 'supplier.catalog.manage' THEN p_role IN ('owner','operations_director','content_moderator','general_manager','sales','editor')
    WHEN 'supplier.catalog.submit_review' THEN p_role IN ('owner','operations_director','content_moderator','general_manager','sales','editor')
    WHEN 'supplier.availability.view' THEN p_role IN ('owner','operations_director','content_moderator','general_manager','frontdesk','sales','editor','support_specialist')
    WHEN 'supplier.availability.manage' THEN p_role IN ('owner','operations_director','content_moderator','general_manager','frontdesk','sales','editor','support_specialist')
    WHEN 'supplier.pricing.view' THEN p_role IN ('owner','operations_director','ai_pricing_specialist','general_manager','sales','marketing')
    WHEN 'supplier.pricing.manage' THEN p_role IN ('owner','operations_director','ai_pricing_specialist','general_manager','sales','marketing')
    WHEN 'supplier.reservations.view' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','editor')
    WHEN 'supplier.reservations.manage' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','editor')
    WHEN 'supplier.offers.view' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','marketing','content_moderator','editor')
    WHEN 'supplier.offers.manage' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','marketing','content_moderator','editor')
    WHEN 'supplier.customers.view' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','marketing')
    WHEN 'supplier.customers.manage' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','marketing')
    WHEN 'supplier.messages.view' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','marketing')
    WHEN 'supplier.messages.manage' THEN p_role IN ('owner','operations_director','support_specialist','general_manager','frontdesk','sales','marketing')
    WHEN 'supplier.tasks.view' THEN p_role IN ('owner','operations_director','general_manager','housekeeping','frontdesk','editor','support_specialist','sales')
    WHEN 'supplier.tasks.manage' THEN p_role IN ('owner','operations_director','general_manager','housekeeping','frontdesk','editor','support_specialist','sales')
    WHEN 'supplier.staff.view' THEN p_role IN ('owner','operations_director','general_manager','finance_manager','accounting')
    WHEN 'supplier.staff.manage' THEN p_role IN ('owner','operations_director','general_manager')
    WHEN 'supplier.accounting.view' THEN p_role IN ('owner','operations_director','finance_manager','general_manager','accounting','purchasing','editor')
    WHEN 'supplier.accounting.manage' THEN p_role IN ('owner','operations_director','finance_manager','general_manager','accounting','purchasing','editor')
    WHEN 'supplier.payments.view' THEN p_role IN ('owner','operations_director','finance_manager','general_manager','accounting','purchasing','editor')
    WHEN 'supplier.payments.manage' THEN p_role IN ('owner','operations_director','finance_manager','general_manager','accounting','purchasing','editor')
    WHEN 'supplier.reports.view' THEN p_role IN ('owner','operations_director','finance_manager','general_manager','accounting','purchasing','editor','content_moderator','sales','support_specialist','frontdesk')
    WHEN 'supplier.integrations.view' THEN p_role IN ('owner','operations_director','general_manager')
    WHEN 'supplier.integrations.manage' THEN p_role IN ('owner','operations_director')
    WHEN 'supplier.settings.view' THEN p_role IN ('owner','operations_director','general_manager')
    WHEN 'supplier.settings.manage' THEN p_role IN ('owner','general_manager')
    ELSE p_role = 'owner'
  END;
$$;

CREATE OR REPLACE FUNCTION agency.role_allows_any_supplier_permission(
  p_role text,
  p_permissions_csv text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN coalesce(trim(p_permissions_csv), '') = '' THEN p_role IN ('owner','operations_director','general_manager')
    ELSE EXISTS (
      SELECT 1
      FROM unnest(string_to_array(p_permissions_csv, ',')) permission(value)
      WHERE agency.role_allows_supplier_permission(p_role, trim(permission.value))
    )
  END;
$$;

GRANT EXECUTE ON FUNCTION agency.role_allows_supplier_permission(text,text) TO agency_app;
GRANT EXECUTE ON FUNCTION agency.role_allows_any_supplier_permission(text,text) TO agency_app;


