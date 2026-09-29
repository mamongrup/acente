import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root = resolve(import.meta.dirname, '..');
const nexusRoot = process.env.NEXUS_PROJECT_ROOT || resolve(root, '..', 'Nexustraveltech');
const expected = ['hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus'];
const files = ['catalog-categories.v1.json','supplier-listing-contract.v1.json'];
function read(base, file) { return JSON.parse(readFileSync(resolve(base, 'contracts', file), 'utf8')); }
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key,stable(value[key])]));
  return value;
}
const local = Object.fromEntries(files.map(file => [file,read(root,file)]));
const categories = local[files[0]];
const listing = local[files[1]];
assert.deepEqual(categories.categories.map(item => item.code), expected, 'Kanonik 17 kategori sırası farklı');
assert.deepEqual(Object.keys(listing.category_attributes), expected, 'Tedarikçi kategori alanları 17 kategoriyle eşleşmiyor');
assert.ok(categories.contract_version && listing.contract_version, 'Sözleşme sürümü eksik');
assert.ok(listing.listing_common.statuses?.length > 0, 'İlan durum sözlüğü boş');
assert.ok(listing.supplier_onboarding.approval_statuses?.length > 0, 'Tedarikçi durum sözlüğü boş');
for (const category of expected) assert.ok(listing.category_attributes[category].length > 0, `${category} alan tanımı boş`);

if (files.every(file => existsSync(resolve(nexusRoot,'contracts',file)))) {
  for (const file of files) assert.deepEqual(stable(local[file]), stable(read(nexusRoot,file)), `${file}: acente ve NEXUS sözleşmeleri farklı`);
  process.stdout.write(`Sözleşme uyumu doğrulandı: katalog ${categories.contract_version}, tedarikçi/ilan ${listing.contract_version}, 17 kategori, iki proje.\n`);
} else {
  process.stdout.write(`Yerel sözleşme doğrulandı: katalog ${categories.contract_version}, tedarikçi/ilan ${listing.contract_version}, 17 kategori. NEXUS projesi kurulu değil; bağımsız kip destekleniyor.\n`);
}
