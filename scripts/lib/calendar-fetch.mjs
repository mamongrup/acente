import https from 'node:https';
import dns from 'node:dns/promises';
import net from 'node:net';

export function publicAddress(address) {
  if (net.isIP(address) !== 4) return false;
  const [a, b] = address.split('.').map(Number);
  return !(a === 0 || a === 10 || a === 127 || a >= 224 || (a === 169 && b === 254)
    || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168)
    || (a === 100 && b >= 64 && b <= 127) || (a === 198 && (b === 18 || b === 19)));
}

export async function fetchCalendar(input, redirects = 0) {
  const url = new URL(input);
  if (url.protocol !== 'https:' || url.username || url.password || (url.port && url.port !== '443')) throw new Error('unsafe_calendar_url');
  const addresses = await dns.lookup(url.hostname, { all: true });
  const ipv4 = addresses.filter(a => a.family === 4);
  if (!ipv4.length || ipv4.some(a => !publicAddress(a.address))
    || addresses.some(a => a.family === 6 && /^(::1|::ffff:|f[cd]|fe[89ab])/i.test(a.address))) throw new Error('unsafe_calendar_host');
  const response = await new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: 15000, headers: { Accept: 'text/calendar', 'User-Agent': 'NEXUS-Calendar/1.0' },
      lookup: (_host, _options, done) => done(null, ipv4[0].address, 4),
    }, res => {
      let size = 0; const chunks = [];
      res.on('data', chunk => { size += chunk.length; if (size > 1024 * 1024) res.destroy(new Error('calendar_size_limit')); else chunks.push(chunk); });
      res.on('error', reject);
      res.on('end', () => resolve({ status: res.statusCode, location: res.headers.location, text: Buffer.concat(chunks).toString('utf8') }));
    });
    req.on('timeout', () => req.destroy(new Error('calendar_timeout')));
    req.on('error', reject);
  });
  if ([301, 302, 303, 307, 308].includes(response.status)) {
    if (redirects >= 2 || !response.location) throw new Error('calendar_redirect_limit');
    return fetchCalendar(new URL(response.location, url).href, redirects + 1);
  }
  if (response.status !== 200) throw new Error('calendar_http_error');
  return response.text;
}
