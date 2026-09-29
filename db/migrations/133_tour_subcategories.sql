-- Tur katalog alt kategorileri. Bunlar yeni ana kategori değildir; her
-- tenant'ın kanonik `tour` kaydına bağlı yerel katalog düğümleridir.
WITH tour_parent AS (
  SELECT id, tenant_id
  FROM agency.categories
  WHERE code = 'tour' AND parent_id IS NULL
), tour_children(code, name, slug, description, sort_order) AS (
  VALUES
    ('tour_abroad', 'Yurtdışı Turlar', 'yurtdisi-turlar', 'Yurtdışı tur programları', 10),
    ('tour_culture', 'Kültür Turları', 'kultur-turlari', 'Kültür ve tarih odaklı tur programları', 20),
    ('tour_cruise', 'Gemi Turları', 'gemi-turlari', 'Gemiyle yapılan tur programları', 30),
    ('tour_daily', 'Günlük Turlar', 'gunluk-turlar', 'Günübirlik tur programları', 40),
    ('tour_religious', 'Dini Turlar', 'dini-turlar', 'Dini ve manevi gezi programları', 50)
)
INSERT INTO agency.categories (
  tenant_id, parent_id, code, name, slug, description, active, sort_order
)
SELECT p.tenant_id, p.id, c.code, c.name, c.slug, c.description, true, c.sort_order
FROM tour_parent p
CROSS JOIN tour_children c
ON CONFLICT (tenant_id, code) DO NOTHING;
