const fs = require('fs'); const vm = require('vm');
function objectBetween(path,start,end) { const s=fs.readFileSync(path,'utf8'); const a=s.indexOf(start); const b=s.indexOf(end,a); if(a<0||b<0) throw Error(path); return vm.runInNewContext('('+s.slice(a+start.length,b+end.length-1)+')'); }
const tr=objectBetween('priv/static/chisfis/js/main.js','var TR = ','\n  };');
const home=objectBetween('priv/static/home-i18n.js','var copy = ','\n  };');
const map={...tr}; for(const [k,v] of Object.entries(home)) if(Array.isArray(v)) map[k]=v[0];
const lines=Object.entries(map).filter(([a,b])=>typeof b==='string'&&a!==b&&!/[\r\n\t]/.test(a+b)).map(([a,b])=>Buffer.from(a).toString('base64')+'\t'+Buffer.from(b).toString('base64'));
fs.writeFileSync('priv/static/home-ssr-tr.tsv',lines.join('\n')+'\n');
console.log('translations='+lines.length);
