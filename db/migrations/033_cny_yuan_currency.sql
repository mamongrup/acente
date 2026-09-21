-- Chinese yuan support for marketplace and agency settlement.
INSERT INTO agency.languages(code,name,native_name,is_default) VALUES
 ('zh','Chinese','简体中文',false)
ON CONFLICT(code) DO UPDATE SET name=excluded.name,native_name=excluded.native_name,active=true;
INSERT INTO agency.currencies(code,name,symbol) VALUES
 ('CNY','Chinese Yuan','¥')
ON CONFLICT(code) DO UPDATE SET name=excluded.name,symbol=excluded.symbol,active=true,updated_at=now();
