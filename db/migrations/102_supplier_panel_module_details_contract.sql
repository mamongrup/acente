-- Supplier panel module detail contract v1.1.0.
-- Mirrors contracts/supplier-listing-contract.v1.json supplier_panel_module_details.

CREATE OR REPLACE FUNCTION agency.supplier_panel_module_contract_details()
RETURNS TABLE(
  code text,
  family text,
  label_tr text,
  scope text[],
  permissions text[]
)
LANGUAGE sql
STABLE
AS $$
  VALUES
    ('dashboard','operations','Genel Bakış',ARRAY['daily_summary','alerts','performance_kpis','pending_actions'],ARRAY['supplier.dashboard.view']),
    ('company_profile','governance','Şirket Profili',ARRAY['legal_profile','tax_profile','contact_profile','bank_profile','service_regions'],ARRAY['supplier.company.view','supplier.company.manage']),
    ('documents','governance','Belgeler',ARRAY['required_documents','expiry_tracking','renewal_requests','approval_history'],ARRAY['supplier.documents.view','supplier.documents.manage']),
    ('catalog','inventory','Katalog',ARRAY['listings','media','category_contract_fields','publication_state','quality_score'],ARRAY['supplier.catalog.view','supplier.catalog.manage','supplier.catalog.submit_review']),
    ('availability','inventory','Müsaitlik',ARRAY['calendar','stock','capacity','blackout_dates','ical_connections'],ARRAY['supplier.availability.view','supplier.availability.manage']),
    ('pricing','commercial','Fiyatlandırma',ARRAY['base_rates','season_rates','commission_rules','discounts','price_parity'],ARRAY['supplier.pricing.view','supplier.pricing.manage']),
    ('reservations','operations','Rezervasyonlar',ARRAY['requests','options','confirmations','cancellations','checkin_checkout'],ARRAY['supplier.reservations.view','supplier.reservations.manage']),
    ('offers','commercial','Teklifler',ARRAY['quotes','corporate_offers','packages','approval_flow'],ARRAY['supplier.offers.view','supplier.offers.manage']),
    ('customers','crm','Müşteriler',ARRAY['guest_profiles','agency_customers','preferences','history'],ARRAY['supplier.customers.view','supplier.customers.manage']),
    ('messages','crm','Mesajlar',ARRAY['customer_messages','agency_messages','internal_notes','templates'],ARRAY['supplier.messages.view','supplier.messages.manage']),
    ('tasks','operations','İş Takibi',ARRAY['tasks','checklists','maintenance_jobs','operation_followups'],ARRAY['supplier.tasks.view','supplier.tasks.manage']),
    ('staff','hr','Personel',ARRAY['users','roles','shifts','departments','attendance'],ARRAY['supplier.staff.view','supplier.staff.manage']),
    ('accounting','finance','Muhasebe',ARRAY['current_accounts','invoices','ledger','tax_reports','cash_desk'],ARRAY['supplier.accounting.view','supplier.accounting.manage']),
    ('payments','finance','Ödemeler',ARRAY['collections','refunds','deposits','payouts','reconciliation'],ARRAY['supplier.payments.view','supplier.payments.manage']),
    ('reports','analytics','Raporlar',ARRAY['sales_reports','operation_reports','finance_reports','supplier_scorecards'],ARRAY['supplier.reports.view']),
    ('integrations','integration','Entegrasyonlar',ARRAY['channel_manager','pms','accounting_integrations','payment_gateways','webhooks'],ARRAY['supplier.integrations.view','supplier.integrations.manage']),
    ('settings','governance','Ayarlar',ARRAY['panel_preferences','notification_rules','workflow_rules','security_settings'],ARRAY['supplier.settings.view','supplier.settings.manage'])
$$;

