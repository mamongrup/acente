-module(seo_engine).
-export([response/6, panel/1, panel_data/2, save/4, translations_save/3, config/2, config_save/3,value/3,obj/3,path/1,params/1,esc/1]).
langs()->[<<"tr">>,<<"en">>,<<"de">>,<<"ru">>,<<"fr">>,<<"zh">>].
query(Db,Sql,P)->Q=lists:foldl(fun(V,A)->pog:parameter(A,pog_ffi:coerce(V)) end,pog:'query'(Sql),P),pog:execute(pog:returning(Q,gleam@dynamic@decode:at([0],{decoder,fun gleam@dynamic@decode:decode_string/1})),Db).
value(Db,Sql,P)->case query(Db,Sql,P) of {ok,R}->case element(3,R) of [V|_]->V;_-> <<>> end;_-> <<>> end.
obj(Db,Sql,P)->try json:decode(value(Db,Sql,P)) catch _:_ ->#{} end.
params(Req)->case gleam@http@request:get_query(Req) of {ok,P}->P;_->[] end.
v(P,K)->proplists:get_value(K,P,<<>>).
esc(V)->lists:foldl(fun({A,B},S)->binary:replace(S,A,B,[global]) end,to_binary(V),[{<<"&">>,<<"&amp;">>},{<<"<">>,<<"&lt;">>},{<<">">>,<<"&gt;">>},{<<"\"">>,<<"&quot;">>},{<<"'">>,<<"&#39;">>}]).
to_binary(V) when is_binary(V)->V;to_binary(V) when is_integer(V)->integer_to_binary(V);to_binary(_)-> <<>>.
jsonsafe(M)->binary:replace(iolist_to_binary(json:encode(M)),<<"<">>,<<"\\u003c">>,[global]).
path(Req)->case gleam@http@request:path_segments(Req) of [L] when L=:= <<"tr">>;L=:= <<"en">>;L=:= <<"de">>;L=:= <<"ru">>;L=:= <<"fr">>;L=:= <<"zh">>-> <<"/",L/binary,"/">>;Segments-> <<"/",(iolist_to_binary(lists:join(<<"/">>,Segments)))/binary>> end.
origin(Db,T,Default)->Configured=value(Db,<<"select value#>>'{}' from agency.settings where tenant_id=$1::uuid and key='seo_public_origin'">>,[T]),case re:run(Configured,<<"^https://[a-zA-Z0-9.-]+(:[0-9]{1,5})?$">>,[{capture,none}]) of match->Configured;_->Default end.
noindex(Req,Res)->P=path(Req),Q=params(Req),Status=element(2,Res),
 Status>=400 orelse lists:any(fun(X)->P=:=X orelse binary:match(P,<<X/binary,"/">>)=:={0,byte_size(X)+1} end,[<<"/admin">>,<<"/api">>,<<"/login">>,<<"/hesap">>,<<"/uye-ol">>,<<"/uye-girisi">>,<<"/parolami-unuttum">>,<<"/rezervasyon">>,<<"/odeme">>,<<"/sepet">>]) orelse v(Q,<<"preview">>)=/= <<>> orelse v(Q,<<"tenant">>)=/= <<>> orelse v(Q,<<"tenant_slug">>)=/= <<>> orelse lists:any(fun(K)->v(Q,K)=/= <<>> end,[<<"q">>,<<"sort">>,<<"kategori">>,<<"property_type">>,<<"yacht_type">>,<<"date_from">>,<<"date_to">>,<<"konum">>,<<"checkin">>,<<"checkout">>,<<"guests">>]).
%% ResolvedLang: gövdeye gerçekten SSR çevirisi uygulanan dil (`<<>>` = uygulanmadı).
%% Çağıran tek kaynak olan router:ssr_lang_from/1 sonucunu geçirir; SEO
%% motoru `nexus_lang` çerezini kendisi okumaz. Daha önce dil yalnızca
%% `?lang=`/yol segmentinden türetiliyordu, bu yüzden çerezle seçilen dilde
%% gövde çevrilirken `<html lang="tr">` olduğu gibi kalıyordu: ekran
%% okuyucu Rusça metni Türkçe sesle okur, tarayıcı zaten Rusça olan sayfayı
%% "çevirmek" ister.
response(Req,Db,Default,T,ResolvedLang,Res)->
 P=path(Req),O=origin(Db,T,Default),
 case P of
 <<"/robots.txt">>->wisp:string_body(gleam@http@response:set_header(wisp:ok(),<<"content-type">>,<<"text/plain; charset=utf-8">>),<<"User-agent: *\nAllow: /\nDisallow: /admin/\nDisallow: /api/\nSitemap: ",O/binary,"/sitemap-index.xml\n">>);
 <<"/sitemap.xml">>->sitemap(Db,T,O,<<"index">>,params(Req));
 <<"/sitemap-index.xml">>->sitemap(Db,T,O,<<"index">>,params(Req));
 <<"/sitemap-categories.xml">>->sitemap(Db,T,O,<<"categories">>,params(Req));
 <<"/sitemap-content.xml">>->sitemap(Db,T,O,<<"content">>,params(Req));
 <<"/sitemap-listings.xml">>->sitemap(Db,T,O,<<"listings">>,params(Req));
 _->case element(4,Res) of {text,B0}->B=iolist_to_binary(B0),case binary:match(B,<<"</head>">>) of nomatch->case noindex(Req,Res) of true->gleam@http@response:set_header(Res,<<"x-robots-tag">>,<<"noindex">>);false->Res end;_->decorate(Req,Db,O,T,ResolvedLang,Res,B) end;_->Res end end.
category(<<"/",P/binary>>)->case nexus_agency@router_impl:public_listing_category_path(P) of C when is_binary(C)->C;_-> <<>> end;category(_)-> <<>>.
listing(Db,T,P,Lang)->case binary:split(P,<<"/">>,[global]) of [<<>>,Cat,Slug]->C=category(<<"/",Cat/binary>>),case C of <<>>->#{};_->obj(Db,<<"select agency.seo_listing_data($1::uuid,l.id,$3)::text from agency.listings l join agency.listing_seo s on s.listing_id=l.id and s.tenant_id=l.tenant_id where l.tenant_id=$1::uuid and l.category=$4 and l.status='published' and (s.stable_slug=$2 or regexp_replace(regexp_replace(translate(lower(translate(l.title,'ÇĞİIÖŞÜ','CGIIOSU')),'çğıöşü','cgiosu'),'[^a-z0-9]+','-','g'),'(^-+|-+$)','','g')=$2) order by (s.stable_slug=$2) desc limit 1"/utf8>>,[T,Slug,Lang,C]) end;_->#{} end.
strip(H,Pattern)->re:replace(H,Pattern,<<>>,[global,dotall,caseless,{return,binary}]).
meta(Name,Content)-> <<"<meta name=\"",Name/binary,"\" content=\"",(esc(Content))/binary,"\">">>.
match(B,Pattern)->case re:run(B,Pattern,[dotall,{capture,[1],binary}]) of {match,[V]}->V;_-> <<>> end.
decorate(Req,Db,O,T,ResolvedLang,Res,B)->
 P=path(Req),Q=params(Req),Requested=seo_languages:language(Req),
 Lang=case ResolvedLang=/= <<>> andalso lists:member(ResolvedLang,langs()) of true->ResolvedLang;false->case lists:member(Requested,langs()) of true->Requested;false-> <<"tr">> end end,
 Resolved=seo_languages:resolve(Req,Db,T),BaseP=maps:get(<<"source_path">>,Resolved,P),
 D=listing(Db,T,BaseP,Lang),IsListing=maps:is_key(<<"id">>,D),Tr=maps:get(<<"translated">>,D,#{}),
 BaseCanon=case IsListing of true-> <<(nexus_agency@router_impl:category_tr_path(maps:get(<<"category">>,D)))/binary,"/",(maps:get(<<"stableSlug">>,D))/binary>>;false->case category(BaseP) of <<>>->BaseP;CC->nexus_agency@router_impl:category_tr_path(CC) end end,
 Resource=seo_languages:resource(D,BaseCanon),Profile=seo_languages:profile(Db,T,Resource,Lang,D),Translated=maps:get(<<"ready">>,Profile,Lang=:= <<"tr">>),
 %% UI translation already applied to catalog pages remains the document
 %% language even when the independently managed SEO profile is not ready.
 %% Listing source content still requires a real content translation.
 ActualLang=case {IsListing,ResolvedLang,Translated} of
   {false,L,_} when L=/= <<>>->Lang;
   {_,_,true}->Lang;
   _-> <<"tr">>
 end,
 Profiles=seo_languages:alternatives(Db,T,Resource,D),TrPath=case [maps:get(<<"path">>,R) || R<-Profiles,maps:get(<<"language_code">>,R)=:= <<"tr">>] of [TrPathValue|_]->TrPathValue;_->BaseCanon end,
 CanonPath=maps:get(<<"path">>,Profile,BaseCanon),
 NeedsRedirect=(IsListing orelse category(BaseP)=/= <<>> orelse maps:is_key(<<"resource_key">>,Resolved)) andalso (P=/=CanonPath orelse proplists:is_defined(<<"lang">>,Q)),
 case NeedsRedirect of true->Url=redirect_query(<<O/binary,CanonPath/binary>>,Q),setelement(2,wisp:redirect(Url),301);false->
 Canon=case Translated of true-> <<O/binary,CanonPath/binary>>;false->TrP=seo_languages:profile(Db,T,Resource,<<"tr">>,#{}),<<O/binary,(maps:get(<<"path">>,TrP,BaseCanon))/binary>> end,

 [Before,Rest]=binary:split(B,<<"</head>">>),
 Head0=strip(Before,<<"<title[^>]*>.*?</title>|<link\\b[^>]*(?:canonical|hreflang)[^>]*>|<meta\\b[^>]*(?:name=[\"'](?:description|keywords|robots|twitter:[^\"']+)[\"']|property=[\"']og:[^\"']+[\"'])[^>]*>">>),
 Head=case IsListing orelse Lang=/= <<"tr">> of true->strip(Head0,<<"<script\\b[^>]*application/ld\\+json[^>]*>.*?</script>">>);false->Head0 end,
 OldTitle=match(Before,<<"<title[^>]*>(.*?)</title>">>),Brand=value(Db,<<"select coalesce((select value#>>'{}' from agency.settings where tenant_id=$1::uuid and key='brand_name'),'NEXUS Agency')">>,[T]),
 Home=obj(Db,<<"select coalesce(jsonb_object_agg(key,value),'{}')::text from agency.settings where tenant_id=$1::uuid and key in ('seo_home_title','seo_home_description','seo_google_verification') and nullif(value#>>'{}','') is not null">>,[T]),
 DefaultTitle=case IsListing of true-> case ActualLang of <<"tr">>->maps:get(<<"title">>,D);_->maps:get(<<"seo_title">>,Tr,maps:get(<<"title">>,Tr)) end;false->case P of <<"/">>-> maps:get(<<"seo_home_title">>,Home,<<Brand/binary," | Seyahatinizi planlayın"/utf8>>);_->OldTitle end end,
 DefaultDescription=case IsListing of true->case ActualLang of <<"tr">>->maps:get(<<"description">>,D);_->maps:get(<<"seo_description">>,Tr,maps:get(<<"description">>,Tr)) end;false->case meta_description(Before) of <<>>-> maps:get(<<"seo_home_description">>,Home,<<Brand/binary," ile konaklama, yat kiralama, tur ve seyahat seçeneklerini keşfedin."/utf8>>);V->V end end,
 Title=seo_first([maps:get(<<"title">>,Profile,<<>>),DefaultTitle]),Description=seo_first([maps:get(<<"description">>,Profile,<<>>),DefaultDescription]),Keywords=maps:get(<<"keywords">>,Profile,<<>>),
 Block=noindex(Req,Res) orelse maps:get(<<"noindex">>,D,false) orelse maps:get(<<"noindex">>,Profile,false) orelse not Translated orelse not lists:member(Requested,langs()),
 Robot=case Block of true-> <<"noindex,follow">>;false-> <<"index,follow,max-image-preview:large">> end,
 Available=[R || R<-Profiles,maps:get(<<"ready">>,R,false),not maps:get(<<"noindex">>,R,false)],
 Alternates=case Block of true-> <<>>;false->iolist_to_binary([<<"<link rel=\"alternate\" hreflang=\"",(maps:get(<<"language_code">>,R))/binary,"\" href=\"",(esc(<<O/binary,(maps:get(<<"path">>,R))/binary>>))/binary,"\">">> || R<-Available]++[<<"<link rel=\"alternate\" hreflang=\"x-default\" href=\"",(esc(<<O/binary,TrPath/binary>>))/binary,"\">">>]) end,

 DisplayName=case IsListing of true->case ActualLang of <<"tr">>->maps:get(<<"sourceTitle">>,D);_->maps:get(<<"title">>,Tr) end;false->Title end, Schemas=schema(D#{<<"schemaName">>=>DisplayName,<<"seoLanguage">>=>ActualLang,<<"seoCategoryPath">>=>category_profile_path(Db,T,maps:get(<<"category">>,D,<<>>),Lang)},Canon,Title,Description,O,Brand),Verify=maps:get(<<"seo_google_verification">>,Home,<<>>),Verification=case re:run(Verify,<<"^[a-zA-Z0-9_-]{10,200}$">>,[{capture,none}]) of match->meta(<<"google-site-verification">>,Verify);_-> <<>> end,
 DetailStyle=case IsListing of true-> <<"<link rel=\"stylesheet\" href=\"/static/listing-detail.css?v=20261001-detail-unified2\">">>;false-> <<>> end,
 OgTitle=seo_first([maps:get(<<"og_title">>,Profile,<<>>),Title]),OgDescription=seo_first([maps:get(<<"og_description">>,Profile,<<>>),Description]),OgImage=maps:get(<<"og_image">>,Profile,<<>>),OgImageTag=case OgImage of <<>>-> <<>>;_-> <<(meta(<<"twitter:image">>,OgImage))/binary,"<meta property=\"og:image\" content=\"",(esc(OgImage))/binary,"\">">> end,
 SeoState=#{<<"lang">>=>Lang,<<"basePath">>=>BaseCanon,<<"categoryUrls">>=>category_urls(Db,T),<<"listingUrls">>=>listing_urls(Db,T,Lang),<<"urls">>=>maps:from_list([{maps:get(<<"language_code">>,R),maps:get(<<"path">>,R)} || R<-Profiles])},
 Tags= <<DetailStyle/binary,(meta(<<"keywords">>,Keywords))/binary,(meta(<<"twitter:card">>,<<"summary_large_image">>))/binary,(meta(<<"twitter:title">>,OgTitle))/binary,(meta(<<"twitter:description">>,OgDescription))/binary,OgImageTag/binary,"<meta property=\"og:locale\" content=\"",(og_locale(Lang))/binary,"\">","<title>",(esc(Title))/binary,"</title>",(meta(<<"description">>,Description))/binary,(meta(<<"robots">>,Robot))/binary,"<link rel=\"canonical\" href=\"",(esc(Canon))/binary,"\">",Alternates/binary,Verification/binary,"<meta property=\"og:title\" content=\"",(esc(OgTitle))/binary,"\"><meta property=\"og:description\" content=\"",(esc(OgDescription))/binary,"\"><meta property=\"og:url\" content=\"",(esc(Canon))/binary,"\"><script type=\"application/ld+json\">",(jsonsafe(Schemas))/binary,"</script><script>window.NEXUS_SEO=",(jsonsafe(SeoState))/binary,";</script>">>,
 Body=case IsListing of true->Name=case ActualLang of <<"tr">>->maps:get(<<"sourceTitle">>,D);_->maps:get(<<"title">>,Tr) end,Body0=re:replace(Rest,<<"(<h1[^>]*>).*?</h1>">>,<<"\\1",(replacement(esc(Name)))/binary,"</h1>">>,[dotall,{return,binary}]),case ActualLang of <<"tr">>->Body0;_->re:replace(Body0,<<"(<div[^>]*class=\"product-description\"[^>]*>).*?(</div>)">>,<<"\\1",(replacement(esc(maps:get(<<"description">>,Tr))))/binary,"\\2">>,[dotall,{return,binary}]) end;false->case Lang=/= <<"tr">> andalso Translated of true->LocaleBody=re:replace(Rest,<<"(<main[^>]*>.*?<h1[^>]*>).*?(</h1>)">>,<<"\\1",(replacement(esc(Title)))/binary,"\\2">>,[dotall,{return,binary}]),re:replace(LocaleBody,<<"(<main[^>]*>.*?<p[^>]*>).*?(</p>)">>,<<"\\1",(replacement(esc(Description)))/binary,"\\2">>,[dotall,{return,binary}]);false->Rest end end,
 Html0= <<Head/binary,Tags/binary,"</head>",(seo_languages:localized_links(Db,T,Lang,internal_links(Db,T,gallery(D#{<<"imageTitle">>=>DisplayName},Body))))/binary>>,Html=re:replace(Html0,<<"(<html[^>]*lang=)[\"'][^\"']*[\"']">>,<<"\\1\"",ActualLang/binary,"\"">>,[{return,binary}]),
 Response=setelement(4,Res,{text,Html}),gleam@http@response:set_header(gleam@http@response:set_header(Response,<<"x-robots-tag">>,Robot),<<"vary">>,<<"Cookie">>) end.
schema(D,Url,Title,Description,O,Brand)->
 Org=#{<<"@type">>=><<"TravelAgency">>,<<"@id">>=><<O/binary,"/#organization">>,<<"name">>=>Brand,<<"url">>=>O},Page=#{<<"@type">>=><<"WebPage">>,<<"@id">>=><<Url/binary,"#page">>,<<"url">>=>Url,<<"name">>=>Title,<<"description">>=>Description,<<"inLanguage">>=>maps:get(<<"seoLanguage">>,D,<<"tr">>)},
 Graph=case maps:is_key(<<"id">>,D) of false->[Org,Page];true->C=maps:get(<<"category">>,D),Type=case C of <<"hotel">>-> <<"Hotel">>;<<"holiday_home">>-> <<"VacationRental">>;_-> <<"Service">> end,
 Images=[I || I<-images(D),is_binary(I), re:run(I,<<"^https?://">>,[{capture,none}])=:=match],
 Item=#{<<"@type">>=>Type,<<"@id">>=><<Url/binary,"#listing">>,<<"identifier">>=>maps:get(<<"id">>,D),<<"name">>=>maps:get(<<"schemaName">>,D,Title),<<"description">>=>Description,<<"url">>=>Url,<<"image">>=>Images},
 Rich=rich_item(Item,D,Url),
 Bread=#{<<"@type">>=><<"BreadcrumbList">>,<<"itemListElement">>=>[#{<<"@type">>=><<"ListItem">>,<<"position">>=>1,<<"name">>=>Brand,<<"item">>=>O},#{<<"@type">>=><<"ListItem">>,<<"position">>=>2,<<"name">>=>nexus_agency@router_impl:public_category_name(C),<<"item">>=><<O/binary,(maps:get(<<"seoCategoryPath">>,D,nexus_agency@router_impl:category_tr_path(C)))/binary>>},#{<<"@type">>=><<"ListItem">>,<<"position">>=>3,<<"name">>=>Title,<<"item">>=>Url}]},[Org,Page,Rich,Bread] end,
 #{<<"@context">>=><<"https://schema.org">>,<<"@graph">>=>Graph}.
xml(R)->wisp:string_body(gleam@http@response:set_header(wisp:ok(),<<"content-type">>,<<"application/xml; charset=utf-8">>),R).
sitemap(Db,T,O,<<"index">>,_)->Count=value(Db,<<"select count(*)::text from agency.listings l join agency.listing_seo s on s.listing_id=l.id and s.tenant_id=l.tenant_id where l.tenant_id=$1::uuid and l.status='published' and not s.noindex">>,[T]),N=try max(1,(binary_to_integer(Count)+999) div 1000) catch _:_ ->1 end,Urls=[<<"/sitemap-categories.xml">>,<<"/sitemap-content.xml">>]++[<<"/sitemap-listings.xml?page=",(integer_to_binary(I))/binary>> || I<-lists:seq(1,N)],xml(iolist_to_binary([<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?><sitemapindex xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">">>,[<<"<sitemap><loc>",(esc(<<O/binary,U/binary>>))/binary,"</loc></sitemap>">> || U<-Urls],<<"</sitemapindex>">>]));
sitemap(Db,T,O,Kind,Q)->
 Data=case Kind of
 <<"categories">>->[#{<<"path">>=> <<"/">>},#{<<"path">>=> <<"/otel">>},#{<<"path">>=> <<"/tatil-evi">>},#{<<"path">>=> <<"/yat">>}]++[#{<<"path">>=>nexus_agency@router_impl:category_tr_path(C)} || C<-[<<"tour">>,<<"activity">>,<<"flight">>,<<"car">>,<<"cruise">>,<<"pilgrimage">>,<<"visa">>,<<"ferry">>,<<"transfer">>,<<"beach">>,<<"cinema">>,<<"event">>,<<"restaurant">>,<<"bus">>]];
 <<"content">>->try json:decode(value(Db,<<"select coalesce(jsonb_agg(jsonb_build_object('path','/'||slug,'lastmod',published_at::date)),'[]')::text from agency.pages where tenant_id=$1::uuid and status='published' and slug<>'home' and slug not like 'category-%' and slug !~ '^(admin|api|login|hesap|uye-ol|uye-girisi|rezervasyon|odeme|sepet)(/|$)' and coalesce(seo->>'noindex','false')<>'true' and length(slug)-length(replace(slug,'/',''))<=1">>,[T])) catch _:_ ->[] end;
 _->Page=try max(1,binary_to_integer(v(Q,<<"page">>))) catch _:_ ->1 end,Offset=integer_to_binary((Page-1)*1000),try json:decode(value(Db,<<"select coalesce(jsonb_agg(x),'[]')::text from (select s.stable_slug slug,l.category,l.id::text id,greatest(l.updated_at,s.updated_at)::date lastmod from agency.listings l join agency.listing_seo s on s.listing_id=l.id and s.tenant_id=l.tenant_id where l.tenant_id=$1::uuid and l.status='published' and not s.noindex order by l.id limit 1000 offset $2::text::int) x">>,[T,Offset])) catch _:_ ->[] end end,
 Nodes=[begin Base=case maps:is_key(<<"slug">>,D) of true-> <<(nexus_agency@router_impl:category_tr_path(maps:get(<<"category">>,D)))/binary,"/",(maps:get(<<"slug">>,D))/binary>>;false->maps:get(<<"path">>,D) end,K=seo_languages:resource(D,Base),Profiles=seo_languages:alternatives(Db,T,K,D),Available=[R || R<-Profiles,maps:get(<<"ready">>,R,false),not maps:get(<<"noindex">>,R,false)],DefaultPath=case [maps:get(<<"path">>,R) || R<-Profiles,maps:get(<<"language_code">>,R)=:= <<"tr">>] of [V|_]->V;_->Base end,
 [[<<"<url><loc>",(esc(<<O/binary,(maps:get(<<"path">>,R))/binary>>))/binary,"</loc>">>,case maps:get(<<"lastmod">>,D,<<>>) of Date when is_binary(Date),Date=/= <<>>-> <<"<lastmod>",Date/binary,"</lastmod>">>;_-> <<>> end,[<<"<xhtml:link rel=\"alternate\" hreflang=\"",(maps:get(<<"language_code">>,AR))/binary,"\" href=\"",(esc(<<O/binary,(maps:get(<<"path">>,AR))/binary>>))/binary,"\"/>">> || AR<-Available],<<"<xhtml:link rel=\"alternate\" hreflang=\"x-default\" href=\"",(esc(<<O/binary,DefaultPath/binary>>))/binary,"\"/></url>">>] || R<-Available] end || D<-Data],xml(iolist_to_binary([<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\">">>,Nodes,<<"</urlset>">>])).

panel(Csrf)->wisp:html_body(wisp:ok(),<<"<!doctype html><html lang=\"tr\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta name=\"csrf-token\" content=\"",Csrf/binary,"\"><title>SEO merkezi</title><style>.seo-checkbox{display:flex!important;align-items:center;gap:10px}.seo-checkbox input{width:18px!important;min-height:18px}.cv-card input,.cv-card textarea{max-width:100%}</style><link rel=\"stylesheet\" href=\"/static/customer-verification.css\"></head><body><main class=\"cv-wrap\"><a href=\"/admin\">Yönetim paneli</a><h1>SEO merkezi</h1><p>Yeni ilanların SEO bilgileri otomatik üretilir. Dilerseniz başlık ve açıklamayı değiştirin. Adresler başlık değişse bile korunur.</p><p><a href=\"/sitemap-index.xml\">Sitemap indeksi</a> · <a href=\"/admin/regions\">Bölge içerikleri</a> · <a href=\"/admin/pages\">İçerik sayfaları</a></p><section class=\"cv-card\"><h2>Site SEO ayarları</h2><form id=\"seo-config\"><label>Canlı site adresi<input name=\"seo_public_origin\" type=\"url\" placeholder=\"https://www.ornek.com\"></label><label>Ana sayfa SEO başlığı<input name=\"seo_home_title\" maxlength=\"160\"></label><label>Ana sayfa açıklaması<textarea name=\"seo_home_description\" maxlength=\"400\"></textarea></label><label>Google Search Console doğrulama kodu<input name=\"seo_google_verification\" maxlength=\"200\"></label><button>Site ayarlarını kaydet</button><p role=\"status\"></p></form></section><section class=\"cv-card\"><h2>Dil bazında sayfa SEO ayarları</h2><p>Ana sayfa, 17 kategori ve içerik sayfaları için her dile ayrı başlık, açıklama, anahtar kelimeler, URL ve sosyal paylaşım bilgileri girin.</p><div id=\"seo-pages\"></div></section><label>İlanlarda ara<input id=\"seo-search\" type=\"search\" placeholder=\"Başlık veya kategori\"></label><div id=\"seo-documents\"></div></main><script src=\"/static/seo-admin.js?v=20261002-locale\" defer></script></body></html>"/utf8>>).
panel_data(Db,T)->V=value(Db,<<"select coalesce(jsonb_agg(x),'[]')::text from (select l.id::text,l.title,l.category,l.status,s.stable_slug,s.title seo_title,s.description seo_description,s.noindex,l.description source_description,coalesce(l.metadata->'extra_metadata'->'translations','{}'::jsonb)||coalesce((select jsonb_object_agg(language_code,fields) from (select language_code,jsonb_object_agg(field_name,value) fields from agency.translations where tenant_id=l.tenant_id and entity_type='listing' and entity_id=l.id group by language_code) a),'{}') translations from agency.listings l join agency.listing_seo s on s.listing_id=l.id and s.tenant_id=l.tenant_id where l.tenant_id=$1::uuid order by l.updated_at desc) x">>,[T]),wisp:json_body(wisp:ok(),V).
save(Db,T,_U,F)->Id=v(F,<<"id">>),Title=v(F,<<"title">>),Description=v(F,<<"description">>),Noindex=case v(F,<<"noindex">>) of <<"on">>-> <<"true">>;_-> <<"false">> end,
 case byte_size(Title)=<600 andalso byte_size(Description)=<1600 of false->wisp:response(422);true->Result=value(Db,<<"with saved as (update agency.listing_seo set title=$3,description=$4,noindex=$5::text::boolean,updated_at=now() where tenant_id=$1::uuid and listing_id=$2::uuid returning listing_id) select jsonb_build_object('saved',count(*)=1)::text from saved">>,[T,Id,Title,Description,Noindex]),wisp:json_body(wisp:ok(),Result) end.

images(D)->case maps:get(<<"images">>,D,[]) of V when is_list(V)->V;_->[] end.
gallery(D,Body)->
 StyledBody=binary:replace(Body,<<"class=\"product-detail ">>,<<"class=\"product-detail reference-listing-detail ">>),
 WithSource=case maps:is_key(<<"id">>,D) of true->re:replace(StyledBody,<<"(<main[^>]*class=\"product-detail[^\"]*\")">>,<<"\\1 data-seo-source-title=\"",(replacement(esc(maps:get(<<"sourceTitle">>,D))))/binary,"\" data-seo-source-description=\"",(replacement(esc(maps:get(<<"body">>,D))))/binary,"\"">>,[{return,binary}]);false->StyledBody end,
 Valid=[I || I<-images(D),is_binary(I),re:run(I,<<"^(https?://|/[^/])">>,[{capture,none}])=:=match],
 Cells=iolist_to_binary([begin Class=case N of 1-> <<"gallery-main">>;_-> <<"gallery-sub">> end,Loading=case N of 1-> <<"eager\" fetchpriority=\"high">>;_-> <<"lazy">> end, <<"<button type=\"button\" class=\"",Class/binary,"\"><img src=\"",(esc(I))/binary,"\" alt=\"",(esc(maps:get(<<"imageTitle">>,D,maps:get(<<"sourceTitle">>,D,<<>>))))/binary," — "/utf8,(integer_to_binary(N))/binary,"\" width=\"1200\" height=\"800\" loading=\"",Loading/binary,"\" decoding=\"async\"></button>">> end || {I,N}<-lists:zip(lists:sublist(Valid,5),lists:seq(1,min(5,length(Valid))))]),
 Filled=re:replace(WithSource,<<"(<div[^>]*class=\"detail-gallery\"[^>]*>)</div>">>,<<"\\1",(replacement(Cells))/binary,"</div>">>,[{return,binary}]),
 Class=case length(Valid) of 1-> <<"g1">>;2-> <<"g2">>;_-> <<"g3plus">> end,
 Final=binary:replace(Filled,<<"class=\"detail-gallery\"">>,<<"class=\"detail-gallery ",Class/binary,"\" data-photo-count=\"",(integer_to_binary(length(Valid)))/binary,"\"">>),
 binary:replace(Final,<<"public-detail.js?v=20261001-hotel-pricing">>,<<"public-detail.js?v=20261002-seo">>,[global]).

translations_save(Db,T,F)->
 Id=v(F,<<"id">>),Lang=v(F,<<"lang">>),Title=v(F,<<"title">>),Description=v(F,<<"description">>),
 case lists:member(Lang,langs()) andalso Lang=/= <<"tr">> andalso byte_size(Title)=<600 andalso byte_size(Description)=<20000 of
 false->wisp:response(422);
 true->Result=value(Db,<<"with source as (select id from agency.listings where tenant_id=$1::uuid and id=$2::uuid), saved as (insert into agency.translations(tenant_id,entity_type,entity_id,language_code,field_name,value) select $1::uuid,'listing',source.id,$3,p.key,p.value from source cross join (values ('title',$4::text),('description',$5::text)) p(key,value) on conflict(tenant_id,entity_type,entity_id,language_code,field_name) do update set value=excluded.value returning entity_id), touched as (update agency.listing_seo set updated_at=now() where tenant_id=$1::uuid and listing_id in (select entity_id from saved)) select jsonb_build_object('saved',count(*)=2)::text from saved">>,[T,Id,Lang,Title,Description]),wisp:json_body(wisp:ok(),Result) end.

config(Db,T)->wisp:json_body(wisp:ok(),value(Db,<<"select coalesce(jsonb_object_agg(key,value),'{}')::text from agency.settings where tenant_id=$1::uuid and key in ('seo_public_origin','seo_home_title','seo_home_description','seo_google_verification')">>,[T])).
config_save(Db,T,F)->
 O=v(F,<<"seo_public_origin">>),Verify=v(F,<<"seo_google_verification">>),Title=v(F,<<"seo_home_title">>),Desc=v(F,<<"seo_home_description">>),
 case (O=:= <<>> orelse re:run(O,<<"^https://[a-zA-Z0-9.-]+(:[0-9]{1,5})?$">>,[{capture,none}])=:=match) andalso (Verify=:= <<>> orelse re:run(Verify,<<"^[a-zA-Z0-9_-]{10,200}$">>,[{capture,none}])=:=match) andalso byte_size(Title)=<600 andalso byte_size(Desc)=<1600 of
 false->wisp:response(422);
 true->Result=value(Db,<<"with saved as (insert into agency.settings(tenant_id,key,value) values ($1::uuid,'seo_public_origin',to_jsonb($2::text)),($1::uuid,'seo_home_title',to_jsonb($3::text)),($1::uuid,'seo_home_description',to_jsonb($4::text)),($1::uuid,'seo_google_verification',to_jsonb($5::text)) on conflict(tenant_id,key) do update set value=excluded.value returning key) select jsonb_build_object('saved',count(*)=4)::text from saved">>,[T,O,Title,Desc,Verify]),wisp:json_body(wisp:ok(),Result) end.

rich_item(Item,D,Url)->
 M=maps:get(<<"metadata">>,D,#{}),C=maps:get(<<"category">>,D),Locality=maps:get(<<"locality">>,D,<<>>),
 Base=case Locality of <<>>->Item;_->case C of <<"hotel">>->Item#{<<"address">>=>#{<<"@type">>=><<"PostalAddress">>,<<"addressLocality">>=>Locality}};<<"holiday_home">>->Item#{<<"address">>=>#{<<"@type">>=><<"PostalAddress">>,<<"addressLocality">>=>Locality}};_->Item#{<<"areaServed">>=>Locality,<<"serviceType">>=>C} end end,
 Guests=maps:get(<<"guests">>,M,maps:get(<<"capacity">>,M,<<>>)),Number=try binary_to_integer(to_binary(Guests)) catch _:_ ->0 end,
 Accommodation=#{<<"@type">>=><<"Accommodation">>},A=case Number>0 of true->Accommodation#{<<"occupancy">>=>#{<<"@type">>=><<"QuantitativeValue">>,<<"value">>=>Number}};false->Accommodation end,
 WithPlace=case C of <<"holiday_home">>->Base#{<<"containsPlace">>=>A};_->Base end,
 Minor=maps:get(<<"priceMinor">>,D,0),Currency=maps:get(<<"currency">>,D,<<>>),
 case is_integer(Minor) andalso Minor>0 andalso Currency=/= <<>> of true->WithPlace#{<<"offers">>=>#{<<"@type">>=><<"Offer">>,<<"price">>=>Minor/100,<<"priceCurrency">>=>Currency,<<"url">>=>Url}};false->WithPlace end.

replacement(B)->binary:replace(binary:replace(B,<<"\\">>,<<"\\\\">>,[global]),<<"&">>,<<"\\&">>,[global]).
redirect_query(U,Q)->lists:foldl(fun(K,A)->case v(Q,K) of <<>>->A;V->Separator=case binary:match(A,<<"?">>) of nomatch-> <<"?">>;_-> <<"&">> end,<<A/binary,Separator/binary,K/binary,"=",(uri_string:quote(V))/binary>> end end,U,[<<"tenant">>,<<"tenant_slug">>,<<"preview">>]).

internal_links(Db,T,B)->
 Ids=case re:run(B,<<"href=[\"']/urunler/([a-fA-F0-9-]{36})[\"']">>,[global,{capture,[1],binary}]) of {match,Matches}->lists:usort([I || [I]<-Matches]);_->[] end,
 case Ids of []->B;_->Rows=try json:decode(value(Db,<<"select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'category',l.category,'slug',s.stable_slug)),'[]')::text from agency.listings l join agency.listing_seo s on s.listing_id=l.id and s.tenant_id=l.tenant_id where l.tenant_id=$1::uuid and l.status='published' and l.id::text in (select jsonb_array_elements_text($2::jsonb))">>,[T,iolist_to_binary(json:encode(Ids))])) catch _:_ ->[] end,
 lists:foldl(fun(R,A)->Id=maps:get(<<"id">>,R),U= <<(nexus_agency@router_impl:category_tr_path(maps:get(<<"category">>,R)))/binary,"/",(maps:get(<<"slug">>,R))/binary>>,binary:replace(A,<<"href=\"/urunler/",Id/binary,"\"">>,<<"href=\"",U/binary,"\"">>,[global]) end,B,Rows) end.

meta_description(H)->case match(H,<<"<meta[^>]*name=[\"']description[\"'][^>]*content=[\"']([^\"']*)[\"']">>) of <<>>->match(H,<<"<meta[^>]*content=[\"']([^\"']*)[\"'][^>]*name=[\"']description[\"']">>);V->V end.

seo_first([V|Rest])->case is_binary(V) andalso string:trim(V)=/= <<>> of true->V;false->seo_first(Rest) end;seo_first([])-> <<>>.
category_profile_path(_,_,<<>>,_)-> <<"/">>;
category_profile_path(Db,T,C,L)->P=nexus_agency@router_impl:category_tr_path(C),R=seo_languages:profile(Db,T,<<"page:",P/binary>>,L,#{}),maps:get(<<"path">>,R,P).
og_locale(<<"tr">>)-> <<"tr_TR">>;og_locale(<<"en">>)-> <<"en_US">>;og_locale(<<"de">>)-> <<"de_DE">>;og_locale(<<"ru">>)-> <<"ru_RU">>;og_locale(<<"fr">>)-> <<"fr_FR">>;og_locale(_)-> <<"zh_CN">>.

category_urls(Db,T)->obj(Db,<<"select coalesce(jsonb_object_agg(language_code,paths),'{}')::text from (select s.language_code,jsonb_object_agg(c.code,s.path) paths from agency.seo_locales s cross join unnest(ARRAY['hotel','holiday_home','yacht','tour','activity','flight','car','cruise','pilgrimage','visa','ferry','transfer','beach','cinema','event','restaurant','bus']) c(code) where s.tenant_id=$1::uuid and s.resource_key='page:'||agency.seo_category_path(c.code,'tr') group by s.language_code) x">>,[T]).
listing_urls(Db,T,L)->obj(Db,<<"select coalesce(jsonb_object_agg(l.id::text,s.path),'{}')::text from agency.seo_locales s join agency.listings l on s.resource_key='listing:'||l.id::text and s.tenant_id=l.tenant_id where s.tenant_id=$1::uuid and s.language_code=$2 and l.status='published'">>,[T,L]).
