import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

const agency = resolve('db/migrations/175_category_service_operations.sql');
const central = resolve('../Nexustraveltech/db/migrations/157_category_service_steps.sql');
const extract = (path) => {
  const source = readFileSync(path, 'utf8');
  const block = source.match(/INSERT INTO [a-z]+\.category_service_steps[\s\S]*?ON CONFLICT\(category_code,step_key\) DO NOTHING;/);
  if (!block) throw new Error(`Kategori hizmet adımları bulunamadı: ${path}`);
  const rows = [...block[0].matchAll(/\('([^']+)','([^']+)','([^']+)','([^']+)','([^']+)',(\d+)\)/g)]
    .map((match) => match.slice(1).join('|'));
  if (rows.length !== 51 || new Set(rows.map((row) => row.split('|')[0])).size !== 17) {
    throw new Error(`17 kategori için 51 adım bekleniyor: ${path}`);
  }
  return rows.sort();
};

const localRows = extract(agency);
if (!existsSync(central)) {
  console.log('NEXUS kurulu değil; yerel 17 kategori sözleşmesi geçerli.');
  process.exit(0);
}
const centralRows = extract(central);
if (JSON.stringify(localRows) !== JSON.stringify(centralRows)) {
  throw new Error('Acente ve NEXUS kategori hizmet sözleşmeleri farklı.');
}
console.log('17 kategori ve 51 hizmet adımı iki projede eşit.');
