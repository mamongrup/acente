/* chisfis-final link & asset audit */
'use strict';
const fs = require('fs');
const path = require('path');

// Site kökü: bu script chisfis-final/tools/ içindeyse bir üst dizin site köküdür.
const ROOT = path.basename(__dirname) === 'tools'
  ? path.join(__dirname, '..')
  : path.join(__dirname, '..', 'chisfis-final');

function walk(dir, exts, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, exts, out);
    else if (exts.some(x => e.name.toLowerCase().endsWith(x))) out.push(p);
  }
  return out;
}

const pages = walk(ROOT, ['.html'], []);
const problems = [];
let imgRefs = 0, linkRefs = 0, cssRefs = 0, jsRefs = 0;

for (const page of pages) {
  const rel = path.relative(ROOT, page).replace(/\\/g, '/');
  const html = fs.readFileSync(page, 'utf8');

  // 1) images (img src, srcset first url, source src/srcset)
  const srcRe = /(?:src|srcset|data-src)\s*=\s*"([^"]+)"/gi;
  let m;
  while ((m = srcRe.exec(html))) {
    const raw = m[1].split(',')[0].trim().split(/\s+/)[0];
    if (!raw || /^(data:|https?:|mailto:|tel:|javascript:|#)/i.test(raw)) continue;
    imgRefs++;
    const target = path.join(path.dirname(page), decodeURIComponent(raw.split('?')[0]));
    if (!fs.existsSync(target)) {
      problems.push(`[IMG ] ${rel} -> ${raw}`);
    }
  }

  // 2) CSS url(...)
  const cssRe = /url\(\s*['"]?([^'")]+)['"]?\s*\)/gi;
  while ((m = cssRe.exec(html))) {
    const raw = m[1].trim();
    if (!raw || /^(data:|https?:|#)/i.test(raw)) continue;
    cssRefs++;
    const target = path.join(path.dirname(page), decodeURIComponent(raw.split('?')[0]));
    if (!fs.existsSync(target)) problems.push(`[CSS ] ${rel} -> ${raw}`);
  }

  // 3) stylesheets & scripts
  const linkRe = /<link[^>]+href\s*=\s*"([^"]+)"/gi;
  while ((m = linkRe.exec(html))) {
    const raw = m[1];
    if (!/\.css/i.test(raw) || /^(https?:|\/\/)/i.test(raw)) continue;
    cssRefs++;
    const target = path.join(path.dirname(page), decodeURIComponent(raw.split('?')[0]));
    if (!fs.existsSync(target)) problems.push(`[LINK] ${rel} -> ${raw}`);
  }
  const scriptRe = /<script[^>]+src\s*=\s*"([^"]+)"/gi;
  while ((m = scriptRe.exec(html))) {
    const raw = m[1];
    if (/^(https?:|\/\/)/i.test(raw)) continue;
    jsRefs++;
    const target = path.join(path.dirname(page), decodeURIComponent(raw.split('?')[0]));
    if (!fs.existsSync(target)) problems.push(`[JS  ] ${rel} -> ${raw}`);
  }

  // 4) anchors -> internal .html targets
  const aRe = /<a\b[^>]*href\s*=\s*"([^"]*)"/gi;
  while ((m = aRe.exec(html))) {
    let raw = m[1].trim();
    if (!raw || /^(https?:|mailto:|tel:|javascript:|#|\/\*)/i.test(raw)) continue;
    const [filePart] = raw.split('#');
    if (!filePart || !/\.html$/i.test(filePart)) continue; // asset or hash-only
    linkRefs++;
    const target = path.join(path.dirname(page), decodeURIComponent(filePart));
    if (!fs.existsSync(target)) problems.push(`[HREF] ${rel} -> ${raw}`);
  }
}

console.log(`Pages scanned:   ${pages.length}`);
console.log(`img refs:        ${imgRefs}`);
console.log(`css url()/link:  ${cssRefs}`);
console.log(`script refs:     ${jsRefs}`);
console.log(`anchor .html:    ${linkRefs}`);
console.log(`----------------------------------`);
if (problems.length === 0) {
  console.log('ALL CLEAR — no broken images or dead links.');
} else {
  console.log(`PROBLEMS: ${problems.length}`);
  problems.forEach(p => console.log(p));
}
