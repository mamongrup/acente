-module(commerce_operations).
-export([page/1,data/3,action/5,export/2]).

value(Db,Sql,P)->
 Q=lists:foldl(fun(V,A)->pog:parameter(A,pog_ffi:coerce(V)) end,pog:'query'(Sql),P),
 case pog:execute(pog:returning(Q,gleam@dynamic@decode:at([0],{decoder,fun gleam@dynamic@decode:decode_string/1})),Db) of
  {ok,R}->case element(3,R) of [V|_]->V;_-> <<>> end;_-> <<>> end.
reply(<<>>)->wisp:json_body(wisp:response(422),<<"{\"error\":\"İşlem tamamlanamadı. İlanı, bağlantıyı ve yetkinizi kontrol edin.\"}"/utf8>>);
reply(V)->wisp:json_body(wisp:ok(),V).
field(F,K)->proplists:get_value(K,F,<<>>).
data(Db,T,U)->reply(value(Db,<<"select agency.commerce_operations_data($1::uuid,$2::uuid)::text">>,[T,U])).
action(Db,T,U,<<"calendar-save">>,F)->reply(value(Db,<<"select jsonb_build_object('id',agency.save_external_calendar($1::uuid,$2::uuid,$3::uuid,$4,$5,$6),'status','saved')::text">>,[T,U,field(F,<<"listing_id">>),field(F,<<"label">>),field(F,<<"url">>),field(F,<<"timezone">>)]));
action(Db,T,U,<<"calendar-sync">>,F)->calendar_action(Db,T,U,F,<<"sync">>);
action(Db,T,U,<<"calendar-remove">>,F)->calendar_action(Db,T,U,F,<<"remove">>);
action(Db,T,U,<<"calendar-export">>,F)->
 Token=binary:encode_hex(crypto:strong_rand_bytes(32),lowercase),
 case value(Db,<<"select agency.rotate_calendar_export($1::uuid,$2::uuid,$3::uuid,$4)::text">>,[T,U,field(F,<<"listing_id">>),Token]) of
  <<"true">>->reply(<<"{\"path\":\"/api/public/calendar/",Token/binary,".ics\"}">>);
  _->reply(<<>>) end;
action(_,_,_,_,_)->wisp:response(404).
calendar_action(Db,T,U,F,A)->reply(value(Db,<<"select jsonb_build_object('changed',agency.external_calendar_action($1::uuid,$2::uuid,$3::uuid,$4))::text">>,[T,U,field(F,<<"feed_id">>),A])).

export(Db,PathToken)->
 Token=case binary:split(PathToken,<<".ics">>) of [Raw,<<>>]->Raw;_-> <<>> end,
 case re:run(Token,<<"^[a-f0-9]{64}$">>,[{capture,none}]) of
 match->case value(Db,<<"select agency.calendar_export_data($1)::text">>,[Token]) of
  <<>>->wisp:response(404);
  V->try
   D=json:decode(V),Events=maps:get(<<"events">>,D,[]),
   Stamp=iolist_to_binary(io_lib:format("~4..0B~2..0B~2..0BT~2..0B~2..0B~2..0BZ",tuple_to_list(element(1,calendar:universal_time()))++tuple_to_list(element(2,calendar:universal_time())))),
   Lines=[<<"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//NEXUS//Calendar 1.0//EN\r\nCALSCALE:GREGORIAN\r\n">>,
    [<<"BEGIN:VEVENT\r\nUID:",(maps:get(<<"key">>,E))/binary,"@nexus\r\nDTSTAMP:",Stamp/binary,"\r\nDTSTART;VALUE=DATE:",(date(maps:get(<<"start">>,E)))/binary,"\r\nDTEND;VALUE=DATE:",(date(maps:get(<<"end">>,E)))/binary,"\r\nSUMMARY:Reserved\r\nEND:VEVENT\r\n">> || E<-Events],<<"END:VCALENDAR\r\n">>],
   Res=wisp:string_body(wisp:ok(),iolist_to_binary(Lines)),
   gleam@http@response:set_header(gleam@http@response:set_header(Res,<<"content-type">>,<<"text/calendar; charset=utf-8">>),<<"cache-control">>,<<"no-store">>)
  catch _:_ ->wisp:response(503) end end;
 _->wisp:response(404) end.
date(D)->binary:replace(D,<<"-">>,<<>>,[global]).

page(Csrf)->
 Html= <<"<!doctype html><html lang='tr'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><meta name='csrf-token' content='{{csrf}}'><title>Satış ve kanal operasyonları</title><link rel='stylesheet' href='/static/commerce-operations.css'></head><body><main class='operations'><nav><a href='/admin'>Yönetim paneli</a><a href='/admin/finance-overview'>Finans</a><a href='/admin/integrations'>Bağlantı ayarları</a><a href='/admin/seo'>Dil ve SEO</a><a href='/admin/ai'>Yapay zekâ</a></nav><header><div><small>NEXUS · ACENTE OPERASYONU</small><h1>Satış ve kanal operasyonları</h1><p>Stok, takvim, finans ve yayın durumunu birlikte takip edin.</p></div><button id='operations-refresh'>Yenile</button></header><p id='operations-status' role='status'></p><section class='op-card'><h2>Satış hazırlığı</h2><div id='operations-readiness'></div></section><section class='op-card'><h2>Takvim bağlantısı ekle</h2><p>Tatil evi ve yatın tamamının kiralandığı yerel ilanlar için. Dış bloklar stok verisini değiştirmez. NEXUS kaynaklı stok merkezi sistemden yönetilir.</p><form id='calendar-save'><label>İlan<select name='listing_id' required id='calendar-listing'></select></label><label>Bağlantı adı<input name='label' required maxlength='100' placeholder='Tedarikçi takvimi'></label><label class='wide'>HTTPS iCal adresi<input name='url' type='url' required maxlength='2048' placeholder='https://…/calendar.ics'></label><label>Saat dilimi<input name='timezone' value='Europe/Istanbul' required maxlength='80'></label><button>Bağlantıyı kaydet</button></form><p class='hint'>İlk güncelleme takvim işçisinin sıradaki çalışmasında yapılır. Hatalı bağlantıda son geçerli bloklar korunur.</p></section><section class='op-card'><h2>Takvim bağlantıları</h2><div id='calendar-feeds'></div><h3>Çakışan rezervasyonlar</h3><div id='calendar-conflicts'></div></section><section class='op-card'><h2>Takvimi dışa aktar</h2><p>Misafir adı, telefon ve e-posta paylaşılmaz. Bağlantı gizlidir; yenilendiğinde eski bağlantı iptal edilir.</p><form id='calendar-export'><label>İlan<select name='listing_id' id='calendar-export-listing' required></select></label><button>Yeni paylaşım bağlantısı oluştur</button></form><div id='calendar-export-result'></div></section><section class='op-card'><h2>Kanal ve NEXUS teslim durumu</h2><div id='operations-channels'></div><p class='hint'>Kuyrukta bulunmak, karşı sisteme teslim edilmiş olmak anlamına gelmez.</p></section><section class='op-card'><h2>Dil ve kategori hazırlığı</h2><div id='operations-languages'></div><div id='operations-categories'></div></section><section class='op-card'><h2>Son 30 gün</h2><div id='operations-metrics'></div><p class='hint'>Tutarlar para birimine göre ayrılır. Tahsil edilmiş rezervasyon tutarıdır; net kâr değildir.</p></section></main><script src='/static/commerce-operations.js' defer></script></body></html>"/utf8>>,
 wisp:html_body(wisp:ok(),binary:replace(Html,<<"{{csrf}}">>,Csrf,[global])).
