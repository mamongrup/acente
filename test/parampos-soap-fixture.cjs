// Synthetic card data only. Bind loopback; no upstream network calls.
const http = require('node:http');
let starts = 0, pays = 0;
http.createServer((req, res) => {
  let body = '';
  req.on('data', c => body += c);
  req.on('end', () => {
    const action = req.headers.soapaction || '';
    let xml;
    if (req.url === '/counts') return res.end(JSON.stringify({starts,pays}));
    if (action.endsWith('/SHA2B64')) {
      if (!body.includes('370,35')) { res.writeHead(400); return res.end(); }
      xml = '<SHA2B64Result>fixture-hash=</SHA2B64Result>';
    } else if (action.endsWith('/TP_WMD_UCD')) {
      starts++;
      if (!body.includes('<Islem_Hash>fixture-hash=</Islem_Hash>') || !body.includes('<Islem_Tutar>370,35</Islem_Tutar>')) { res.writeHead(400); return res.end(); }
      xml = '<Sonuc>1</Sonuc><UCD_HTML><![CDATA[<form>3D bank</form>]]></UCD_HTML><Islem_GUID>fixture-guid-'+starts+'</Islem_GUID>';
    } else if (action.endsWith('/TP_WMD_Pay')) {
      pays++;
      xml = '<Sonuc>1</Sonuc><Dekont_ID>98765</Dekont_ID><Bank_Sonuc_Kod>0</Bank_Sonuc_Kod>';
    } else { res.writeHead(400); return res.end(); }
    res.setHeader('Content-Type','text/xml');
    res.end('<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><r>'+xml+'</r></soap:Body></soap:Envelope>');
  });
}).listen(18089,'127.0.0.1',()=>console.log('SOAP fixture ready'));
