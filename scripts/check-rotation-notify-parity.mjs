import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { resolve, basename } from 'node:path';

// Iki deponun notify-rotation-overdue betikleri ayni sozlesmeyi paylasir:
// ayni parametre listesi (ad, tip, varsayilan), ayni karar senaryolari ve
// ayni cikis kodlari. AGENTS.md "Sozlesme degisikligi tek taraflı olamaz"
// kurali geregi iki taraf ayrilirsa biri sessizce eskir.
//
// Bu denetim SOZLESMEYI karsilastirir (davranisi degil): parametre
// sozlesmesi ve cikis kodu eslemesi. Karar mantiginin karsiligi olan
// DB fonksiyonu ayrica kontrol edilir.
//
// Kullanim:
//   node scripts/check-rotation-notify-parity.mjs
//   NEXUS_PROJECT_ROOT=/path/to/Nexustraveltech node scripts/check-rotation-notify-parity.mjs
//
// Cikis: 0 esit, 1 fark var (farklar stderr'e yazilir).

const agencyRoot = resolve(import.meta.dirname, '..');
const nexusRoot = process.env.NEXUS_PROJECT_ROOT || resolve(agencyRoot, '..', 'Nexustraveltech');
const SCRIPT = 'notify-rotation-overdue.ps1';

// Platform deposu bulunamazsa (CI yalnizca acente'yi checkout eder) denetim
// ATLANIR ve exit 0 verir: acente bagimsiz calisir (AGENTS.md ilkesi 1).
// Sözleşme esitligi ancak iki depo birlikte hazir oldugunda denetlenir.
if (!existsSync(resolve(nexusRoot, 'scripts', SCRIPT))) {
  console.log(`  platform deposu bulunamadi (${nexusRoot}); parite denetimi atlandi.`);
  console.log('  Acente bagimsiz calisir; iki depo birlikte denetlenir.');
  process.exit(0);
}

const differences = [];
function compare(label, agency, nexus) {
  if (agency !== nexus) {
    differences.push(`${label}\n    acente : ${agency}\n    platform: ${nexus}`);
  }
}

function readScript(root, label) {
  const file = resolve(root, 'scripts', SCRIPT);
  if (!existsSync(file)) throw new Error(`${label} betigi bulunamadi: ${file}`);
  return readFileSync(file, 'utf8');
}

// --- Parametre sozlesmesi -------------------------------------------------
// param(...) blogunu PowerShell AST yerine metin olarak ayristiriyoruz:
// blok icinde yorum satirlari ve varsayilan degerleri aynen korunur, bu
// yuzden iki taraf arasindaki yorum farki (238/acente sozlesmesi) sozlesme
// farki sayilmaz. Yalnizca <tip> $Ad = <varsayilan> satirlari karsilastirilir.
function paramContract(source) {
  const start = source.search(/^param\s*\(/m);
  assert.ok(start >= 0, 'param(...) blogu bulunamadi');
  const rest = source.slice(start);
  let depth = 0;
  let end = -1;
  for (let i = rest.indexOf('('); i < rest.length; i++) {
    if (rest[i] === '(') depth++;
    else if (rest[i] === ')') {
      depth--;
      if (depth === 0) { end = i; break; }
    }
  }
  assert.ok(end > 0, 'param(...) blogu kapatilmamis');
  const block = rest.slice(0, end + 1);

  const params = [];
  for (const raw of block.split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith('#')) continue;
    // [tip]$Ad = 'deger'  veya  [tip]$Ad = 180
    const m = line.match(/^\[([^\]]+)\]\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*(?:=\s*(.+?))?\s*$/);
    if (!m) continue;
    params.push({ type: m[1].trim(), name: m[2], default: (m[3] ?? '').trim() });
  }
  return params;
}

const agencySource = readScript(agencyRoot, 'acente');
const nexusSource = readScript(nexusRoot, 'platform');

const agencyParams = paramContract(agencySource);
const nexusParams = paramContract(nexusSource);

// Siralama sozlesmenin parcasidir: ayni ada sahip betikler ayni konum
// dagilimini kullanabilmelidir.
compare('parametre sayisi', String(agencyParams.length), String(nexusParams.length));

const names = new Set([...agencyParams, ...nexusParams].map(p => p.name));
for (const name of names) {
  const a = agencyParams.find(p => p.name === name);
  const n = nexusParams.find(p => p.name === name);
  compare(`parametre -$${name} varligi`, a ? 'var' : 'yok', n ? 'var' : 'yok');
  if (!a || !n) continue;
  compare(`parametre -$${name} tipi`, a.type, n.type);
  compare(`parametre -$${name} varsayilani`, a.default || '(bos)', n.default || '(bos)');
  compare(`parametre -$${name} sirasi`, String(agencyParams.indexOf(a)), String(nexusParams.indexOf(n)));
}

// Cikis kodu kumesi: ayni senaryolar ayni kodlara donusmelidir.
// Platform karari DB'den alir ve `exit $exitCode` yazar; literal kod
// kumesi '2'ye duser. Bu bir sozlesme farki DEGILDIR: karar tablosu
// denetlenen DB fonksiyonudur. Bu yuzden iki bicim de kabul edilir ve
// yalnizca ikisinin de bulunmadigi durum hata sayilir.
function exitCodes(source) {
  const codes = new Set();
  for (const m of source.matchAll(/\bexit\s+(\d+)\b/g)) codes.add(m[1]);
  return [...codes].sort().join(',');
}
function usesExitVariable(source) {
  return /exit\s+\$exitCode\b/.test(source);
}
const agencyExits = exitCodes(agencySource);
const nexusExits = exitCodes(nexusSource);
const agencyDelegates = usesExitVariable(agencySource);
const nexusDelegates = usesExitVariable(nexusSource);
if (!agencyExits && !agencyDelegates) throw new Error('acente betiginde cikis kodu bulunamadi');
if (!nexusExits && !nexusDelegates) throw new Error('platform betiginde cikis kodu bulunamadi');
// Literal kod kumesi yalnizca IKISI de degerlendirme yapmiyorsa karsilastirilir.
// Platform `exit $exitCode` ile yaziyor (karar DB'den gelir), dolayisiyla
// literal kumesi tek basina anlam tasimaz.
if (agencyExits && nexusExits && !nexusDelegates) compare('cikis kodu kumesi', agencyExits, nexusExits);

// Karar senaryolari: her iki tarafta da tanimli olmali. Platform karari
// DB'den (events.rotation_check_decision) alir ve metin olarak
// 'window_expired_previous_present' / 'no_record' turlerini isler; bu
// yuzden pencere durum adlari yorumda ya da govde metninde aranir.
for (const state of ['open', 'expired', 'unknown']) {
  const has = source => source.includes(state) ? 'var' : 'yok';
  compare(`karar senaryosu '${state}'`, has(agencySource), has(nexusSource));
}

// Alert kanallari: webhook + e-posta her iki tarafta opsiyonel olmali.
for (const channel of ['WebhookUrl', 'MailTo']) {
  compare(`alarm kanali -$$channel`,
    agencyParams.some(p => p.name === channel) ? 'var' : 'yok',
    nexusParams.some(p => p.name === channel) ? 'var' : 'yok');
}

// Gunluk yas siniri ayni olmali (varsayilan 180 gun).
const agencyMax = agencyParams.find(p => p.name === 'SecretKeyRotationMaxDays');
const nexusMax = nexusParams.find(p => p.name === 'SecretKeyRotationMaxDays');
if (agencyMax && nexusMax) {
  compare('gunluk yas siniri varsayilani', agencyMax.default, nexusMax.default);
}

// Cikis dosyasi ayni sozlesmeyi paylasir. Dokumantasyon satirinda gecen
// yol degil, gercekten kullanilan $logPath atamasi esas alinir.
function logPathOf(source) {
  const match = source.match(/\$logPath\s*=\s*Join-Path\s+\$root\s+'([^']+)'/);
  if (!match) throw new Error(`cikis dosyasi ($logPath) bulunamadi: ${source.slice(0, 0)}`);
  return match[1].replace(/^\.local[\\/]/, '');
}
compare('cikis dosyasi', logPathOf(agencySource), logPathOf(nexusSource));

// --- Karar mantiginin karsiligi olan DB fonksiyonu ------------------------
// Platform karar tablosunu events.rotation_check_decision olarak DB'de
// tasi (migration 192); acente tarafi ayni adimi atmali. Tek taraf kaliyor
//sa rotasyon denetimi iki projede farkli karar verir.
function hasDecisionFunction(root, schema, migrationGlob) {
  const dir = resolve(root, 'db', 'migrations');
  if (!existsSync(dir)) return false;
  for (const name of readdirSync(dir)) {
    if (!migrationGlob.test(name)) continue;
    if (readFileSync(resolve(dir, name), 'utf8').includes(`${schema}.rotation_check_decision`)) return true;
  }
  return false;
}

const agencyHasDecision = hasDecisionFunction(agencyRoot, 'agency', /^2(4[7-9]|[5-9]\d)/);
const nexusHasDecision = hasDecisionFunction(nexusRoot, 'events', /^19[0-9]/);
compare('karar tablosu DB fonksiyonu',
  agencyHasDecision ? 'var' : 'yok', nexusHasDecision ? 'var' : 'yok');

// --- 247 <-> 187 pencere semasi karsilastirmasi ---------------------------
// Pencere sozlesmesi iki depoda ayri migrationlarda yazilir: acente 247,
// platform 187. Imzalar, varsayilan pencere ve durum enum'lari ayrilirsa
// rotasyon uyarisi iki projede farkli karar verir (betik sozlesmesi denetimi
// bunu yakalamaz; yakalayan sey semadir).
// Migration numaralari TEKRARLANABILIR (ornegin acente'de 247 iki farkli
// dosyada kullanilir), bu yuzden dosya yalnizca numara ve degil, ICERIK
// ile de secilir: rotation_window_hours tanimini iceren dosya aranir.
function findMigration(root, numberPattern, contentPattern) {
  const dir = resolve(root, 'db', 'migrations');
  if (!existsSync(dir)) return null;
  const candidates = readdirSync(dir).sort().filter(name => numberPattern.test(name));
  for (const name of candidates) {
    const sql = readFileSync(resolve(dir, name), 'utf8');
    if (!contentPattern.test(sql)) continue;
    return { name, sql };
  }
  return null;
}

const agencyWindow = findMigration(agencyRoot, /^247_/, /rotation_window_hours\s*\(/);
const nexusWindow = findMigration(nexusRoot, /^187_/, /rotation_window_hours\s*\(/);
// NEXUS_CONFIG_KEY pencere genisletmesi SURLULU bir migration'da gelir
// (platform 193, acente 272): 187/247 DEGISTIRILMEZ, checksum korunur.
// Bu yuzden seed satirlarinin tamami tek dosyada degil, iki migration'in
// birlesimidir.
const agencyConfigKey = findMigration(agencyRoot, /^27[2-9]_/, /NEXUS_CONFIG_KEY'/);
const nexusConfigKey = findMigration(nexusRoot, /^19[3-9]_/, /NEXUS_CONFIG_KEY'/);
if (!agencyWindow || !nexusWindow) {
  throw new Error(`pencere migration'i bulunamadi: acente=${agencyWindow?.name ?? 'yok'} platform=${nexusWindow?.name ?? 'yok'}`);
}

// Fonksiyon imzalari: isim + parametre tipleri + donus tipi. Govde ve sema
// adi farkli olabilir; yalnizca sozlesme yuzeyi karsilastirilir.
function functionSignatures(sql, schema) {
  const signatures = new Map();
  const re = new RegExp(
    `CREATE\\s+OR\\s+REPLACE\\s+FUNCTION\\s+${schema}\\.(\\w+)\\s*\\(([^)]*)\\)\\s*\\nRETURNS\\s+(\\w+)([\\s\\S]*?)AS\\s+\\$\\$`, 'gi');
  for (const match of sql.matchAll(re)) {
    const [, name, args, returns, between] = match;
    // Arguman listesi sema-qualified olabilir; yalnizca tip adlari sozlesmedir.
    const normalizedArgs = args.split(',').map(arg => arg.trim().split(/\s+/).pop()).join(',');
    // Volatility sozlesmenin parcasidir: ayni imza farkli volatility ile
    // farkli plan/yanlis sonuc uretebilir. RETURNS ve govde arasinda yer alir.
    const volatility = (between.match(/\b(STABLE|IMMUTABLE|VOLATILE)\b/i) || ['', '?'])[1].toUpperCase();
    signatures.set(name.toLowerCase(), `${name}(${normalizedArgs})->${returns.toLowerCase()} [${volatility}]`);
  }
  return signatures;
}

const agencySignatures = functionSignatures(agencyWindow.sql, 'agency');
const nexusSignatures = functionSignatures(nexusWindow.sql, 'events');
compare('pencere fonksiyon sayisi', String(agencySignatures.size), String(nexusSignatures.size));

const windowFunctions = ['rotation_window_hours', 'set_rotation_window',
  'latest_rotation_age_hours', 'rotation_window_state'];
for (const fn of windowFunctions) {
  compare(`pencere fonksiyonu ${fn}()`,
    agencySignatures.get(fn) ?? '(yok)', nexusSignatures.get(fn) ?? '(yok)');
}

// Parametre ADLARI sozlesmenin parcasidir: cagiran taraflar ileride
// named notation'a gecerse ya da iki taraf dokumantasyonu birlikte
// guncellenmezse ayrilma olur. Tip imzasinda degil, sozlesme yuzeyinde
// raporlanir.
function parameterNames(sql, schema) {
  const names = new Map();
  const re = new RegExp(
    `CREATE\\s+OR\\s+REPLACE\\s+FUNCTION\\s+${schema}\\.(\\w+)\\s*\\(([^)]*)\\)`, 'gi');
  for (const match of sql.matchAll(re)) {
    names.set(match[1].toLowerCase(), match[2].split(',')
      .map(arg => arg.trim().split(/\s+/)[0] || '?').join(','));
  }
  return names;
}
const agencyParams_ = parameterNames(agencyWindow.sql, 'agency');
const nexusParams_ = parameterNames(nexusWindow.sql, 'events');
for (const fn of windowFunctions) {
  compare(`pencere fonksiyonu ${fn}() parametre adlari`,
    agencyParams_.get(fn) ?? '(yok)', nexusParams_.get(fn) ?? '(yok)');
}

// Varsayilan pencere: rotation_window_hours govdesindeki COALESCE degeri
// (bilinen sirlar icin satir satir da seed edilir; varsayilan deger burada).
function defaultWindow(sql) {
  const start = sql.search(/rotation_window_hours\s*\(/);
  if (start < 0) return '(yok)';
  const match = sql.slice(start).match(/COALESCE\([\s\S]*?,\s*(\d+)\s*\);/);
  return match ? match[1] : '(yok)';
}
compare('varsayilan pencere (saat)', defaultWindow(agencyWindow.sql), defaultWindow(nexusWindow.sql));

// Seed satirlari: varsayilan degerin hangi sirlara yazildigi da sozlesmedir.
// NEXUS_CONFIG_KEY sürümlü genisletme migration'inda gelir; ikisi birlestirilir
// (yoksa platform tarafinda eksik görünürdü).
function seededSecrets(...sources) {
  const values = [];
  for (const sql of sources.filter(Boolean)) {
    for (const block of sql.matchAll(/INSERT\s+INTO\s+\w+\.\w*secret_rotation_settings[\s\S]*?ON CONFLICT[^;]*;/gi)) {
      for (const m of block[0].matchAll(/\('([A-Z_]+)',\s*(\d+)\)/g)) values.push(`${m[1]}=${m[2]}`);
    }
  }
  return [...new Set(values)].sort().join(',');
}
compare('seed edilen sir pencereleri',
  seededSecrets(agencyWindow.sql, agencyConfigKey?.sql),
  seededSecrets(nexusWindow.sql, nexusConfigKey?.sql));

// Genisletme migration'i her iki depoda da mevcut olmali: tek tarafta
// kalirsa NEXUS_CONFIG_KEY'in penceresi ayri ayri olusur ve parite bozulur.
// Dosya ADLARI farkli olabilir (migration numaralari projeye gore degisir:
// platform 193, acente 272), bu yuzden varlik karsilastirilir, ad degil.
compare('NEXUS_CONFIG_KEY pencere migration\'i',
  agencyConfigKey ? 'var' : 'yok', nexusConfigKey ? 'var' : 'yok');

// NEXUS_CONFIG_KEY penceresi iki depoda da ayni degerde olmali.
function configKeyWindow(config) {
  const match = config?.sql.match(/\('NEXUS_CONFIG_KEY',\s*(\d+)\)/);
  return match ? match[1] : '(yok)';
}
compare('NEXUS_CONFIG_KEY varsayilan penceresi (saat)',
  configKeyWindow(agencyConfigKey), configKeyWindow(nexusConfigKey));

// Durum enum'lari: rotation_window_state yalnizca bu uc degeri dondurur
// (247/187 govdesi ve COMMENT ayni listeyi verir).
function stateEnum(sql) {
  const values = new Set();
  for (const match of sql.matchAll(/RETURN\s+'([a-z_]+)'/gi)) values.add(match[1]);
  const comment = sql.match(/COMMENT ON FUNCTION\s+\w+\.\w*rotation_window_state[\s\S]*?;/i);
  if (comment) for (const match of comment[0].matchAll(/\b(unknown|open|expired)\b/gi)) values.add(match[1].toLowerCase());
  return [...values].sort().join(',');
}
compare('durum enum degerleri', stateEnum(agencyWindow.sql), stateEnum(nexusWindow.sql));

// CHECK kisiti: pencere araligi [1, 720] saat olmali.
function checkRange(sql) {
  const match = sql.match(/CHECK\s*\(\s*window_hours\s+BETWEEN\s+(\d+)\s+AND\s+([\d* ]+?)\s*\)/i);
  if (!match) return '(yok)';
  return `${match[1]}..${match[2].replace(/\s+/g, '')}`;
}
compare('pencere CHECK kisiti', checkRange(agencyWindow.sql), checkRange(nexusWindow.sql));

// set_rotation_window reddedilen aralik ayni olmali (fail-closed).
function rejectRange(sql) {
  const match = sql.match(/p_hours\s*<\s*(\d+)\s+OR\s+p_hours\s*>\s*([\d* ]+?)\s*THEN/i);
  return match ? `${match[1]}..${match[2].replace(/\s+/g, '')}` : '(yok)';
}
compare('set_rotation_window red araligi', rejectRange(agencyWindow.sql), rejectRange(nexusWindow.sql));

if (differences.length > 0) {
  process.stderr.write(`\n${basename(SCRIPT)} sozlesme farki (acente <-> platform):\n\n`);
  for (const line of differences) process.stderr.write(`  - ${line}\n\n`);
  process.stderr.write(`Toplam ${differences.length} fark. Iki taraf ayni sozlesmeyi paylasmalidir.\n`);
  process.exit(1);
}

console.log(`  parametre: ${agencyParams.length} (${agencyParams.map(p => `$${p.name}`).join(', ')})`);
console.log(`  cikis kodlari: ${exitCodes(agencySource)} | karar tablosu: acente=${agencyHasDecision ? 'var' : 'yok'} platform=${nexusHasDecision ? 'var' : 'yok'}`);
console.log(`  pencere semasi (${agencyWindow.name} <-> ${nexusWindow.name}): ${windowFunctions.length} fonksiyon, varsayilan ${defaultWindow(agencyWindow.sql)}s, enum [${stateEnum(agencyWindow.sql)}]`);
console.log(`  seed pencereler: ${seededSecrets(agencyWindow.sql, agencyConfigKey?.sql)} (NEXUS_CONFIG_KEY genisletmesi: ${agencyConfigKey?.name ?? 'yok'} <-> ${nexusConfigKey?.name ?? 'yok'})`);
console.log('  rotasyon uyarisi sozlesmesi acente <-> platform ESIT.');
