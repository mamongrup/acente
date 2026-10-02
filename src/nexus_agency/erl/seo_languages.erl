-module(seo_languages).
-export([request/3,language/1,resolve/3,resource/2,profile/5,alternatives/4,data/2,save/3,localized_links/4]).
q(D,S,P)->seo_engine:value(D,S,P).
obj(D,S,P)->seo_engine:obj(D,S,P).
path(R)->seo_engine:path(R).
language(R)->case gleam@http@request:path_segments(R) of [L|_] when L=:= <<"tr">>;L=:= <<"en">>;L=:= <<"de">>;L=:= <<"ru">>;L=:= <<"fr">>;L=:= <<"zh">>->L;_->proplists:get_value(<<"lang">>,seo_engine:params(R),<<"tr">>) end.
resolve(R,D,T)->P=path(R),obj(D,<<"select row_to_json(x)::text from (select resource_key,language_code,source_path,path,false alias from agency.seo_locales where tenant_id=$1::uuid and path=$2 union all select s.resource_key,s.language_code,s.source_path,s.path,true alias from agency.seo_path_aliases a join agency.seo_locales s using(tenant_id,resource_key,language_code) where a.tenant_id=$1::uuid and a.path=$2 order by alias limit 1) x">>,[T,P]).
request(R,D,T)->case element(2,R) of get->case resolve(R,D,T) of #{<<"source_path">>:=P,<<"language_code">>:=_L}->gleam@http@request:set_query(setelement(8,R,P),[{<<"lang">>,language(R)}|[X || X={K,_}<-seo_engine:params(R),K=/= <<"lang">>]]);_->R end;_->R end.
resource(#{<<"id">>:=Id},_)-> <<"listing:",Id/binary>>;resource(_,P)-> <<"page:",P/binary>>.
nonempty(V)->is_binary(V) andalso string:trim(V)=/= <<>>.
first([V|Rest])->case nonempty(V) of true->V;false->first(Rest) end;first([])-> <<>>.
profile(D,T,K,L,Listing)->
 Row=obj(D,<<"select row_to_json(s)::text from agency.seo_locales s where tenant_id=$1::uuid and resource_key=$2 and language_code=$3">>,[T,K,L]),
 compute_profile(Row,L,Listing).
compute_profile(Row,L,Listing)->
 Tr=maps:get(<<"translated">>,Listing,#{}),IsListing=maps:is_key(<<"id">>,Listing),
 Ready=case L of <<"tr">>->true;_->case IsListing of true->nonempty(maps:get(<<"title">>,Tr,<<>>)) andalso nonempty(maps:get(<<"description">>,Tr,<<>>));false->nonempty(maps:get(<<"title">>,Row,<<>>)) andalso nonempty(maps:get(<<"description">>,Row,<<>>)) end end,
 Metadata=maps:get(<<"metadata">>,Listing,#{}),
 Title=first([maps:get(<<"title">>,Row,<<>>),case L of <<"tr">>->maps:get(<<"title">>,Listing,<<>>);_->first([maps:get(<<"seo_title">>,Tr,<<>>),maps:get(<<"title">>,Tr,<<>>)]) end]),
 Desc=first([maps:get(<<"description">>,Row,<<>>),case L of <<"tr">>->maps:get(<<"description">>,Listing,<<>>);_->first([maps:get(<<"seo_description">>,Tr,<<>>),maps:get(<<"description">>,Tr,<<>>)]) end]),
 Keywords=first([maps:get(<<"keywords">>,Row,<<>>),case L of <<"tr">>->maps:get(<<"seo_keywords">>,Metadata,<<>>);_->maps:get(<<"seo_keywords">>,Tr,<<>>) end]),
 Row#{<<"ready">>=>Ready,<<"title">>=>Title,<<"description">>=>Desc,<<"keywords">>=>Keywords}.
alternatives(D,T,K,_Listing)->
 Rows=try json:decode(q(D,<<"select coalesce(jsonb_agg(jsonb_build_object('row',row_to_json(s),'listing',case when s.resource_key like 'listing:%' then agency.seo_listing_data(s.tenant_id,substring(s.resource_key from 9)::uuid,s.language_code) else '{}'::jsonb end)),'[]')::text from agency.seo_locales s where tenant_id=$1::uuid and resource_key=$2">>,[T,K])) catch _:_ ->[] end,
 [compute_profile(maps:get(<<"row">>,R),maps:get(<<"language_code">>,maps:get(<<"row">>,R)),case maps:get(<<"listing">>,R,#{}) of M when is_map(M)->M;_->#{} end) || R<-Rows].

data(D,T)->wisp:json_body(wisp:ok(),q(D,<<"select coalesce(jsonb_agg(row_to_json(s) order by resource_key,language_code),'[]')::text from agency.seo_locales s where tenant_id=$1::uuid">>,[T])).
valid_path(P,L)->case L of <<"tr">>->re:run(P,<<"^/(?:[\\p{L}\\p{N}][\\p{L}\\p{N}_-]*(?:/[\\p{L}\\p{N}][\\p{L}\\p{N}_-]*)*)?$">>,[unicode,{capture,none}])=:=match;_->Prefix= <<"/",L/binary,"/">>,byte_size(P)>=byte_size(Prefix) andalso binary:part(P,0,byte_size(Prefix))=:=Prefix andalso re:run(P,<<"^/[a-z]{2}/(?:[\\p{L}\\p{N}][\\p{L}\\p{N}_-]*(?:/[\\p{L}\\p{N}][\\p{L}\\p{N}_-]*)*)?$">>,[unicode,{capture,none}])=:=match end.
get(F,K)->proplists:get_value(K,F,<<>>).
save(D,T,F)->
 K=get(F,<<"resource_key">>),L=get(F,<<"lang">>),P=get(F,<<"path">>),Title=get(F,<<"title">>),Desc=get(F,<<"description">>),Keywords=get(F,<<"keywords">>),OgTitle=get(F,<<"og_title">>),OgDesc=get(F,<<"og_description">>),OgImage=get(F,<<"og_image">>),CT=get(F,<<"content_title">>),CD=get(F,<<"content_description">>),NI=case get(F,<<"noindex">>) of <<"on">>-> <<"true">>;_-> <<"false">> end,
 Current=obj(D,<<"select row_to_json(s)::text from agency.seo_locales s where tenant_id=$1::uuid and resource_key=$2 and language_code=$3">>,[T,K,L]),
 Segments=binary:split(P,<<"/">>,[global]),PublicSegment=case {L,Segments} of {<<"tr">>,[<<>>,V|_]}->V;{_,[<<>>,_Lang,V|_]}->V;_-> <<>> end,
 Safe=not lists:member(PublicSegment,[<<"admin">>,<<"api">>,<<"static">>,<<"login">>,<<"hesap">>,<<"uye-ol">>,<<"uye-girisi">>,<<"parolami-unuttum">>,<<"rezervasyon">>,<<"odeme">>,<<"sepet">>,<<"urunler">>,<<"kategori">>]) andalso not (L=:= <<"tr">> andalso lists:member(PublicSegment,[<<"tr">>,<<"en">>,<<"de">>,<<"ru">>,<<"fr">>,<<"zh">>])),
 Valid=Safe andalso maps:is_key(<<"path">>,Current) andalso valid_path(P,L) andalso byte_size(P)=<1500 andalso lists:all(fun(V)->byte_size(V)=<20000 end,[Title,Desc,Keywords,OgTitle,OgDesc,CT,CD]) andalso (OgImage=:= <<>> orelse re:run(OgImage,<<"^https?://[^\\s<>]+$">>,[{capture,none}])=:=match),
 case Valid of false->wisp:json_body(wisp:response(422),<<"{\"saved\":false,\"error\":\"invalid_fields\"}">>);true->
 Result=q(D,<<"with eligible as (select s.* from agency.seo_locales s where s.tenant_id=$1::uuid and s.resource_key=$2 and s.language_code=$3 and not exists(select 1 from agency.seo_locales other where other.tenant_id=s.tenant_id and other.path=$4 and (other.resource_key,other.language_code)<>(s.resource_key,s.language_code)) and not exists(select 1 from agency.seo_path_aliases a where a.tenant_id=s.tenant_id and a.path=$4 and (a.resource_key,a.language_code)<>(s.resource_key,s.language_code))), aliases as (insert into agency.seo_path_aliases(tenant_id,path,resource_key,language_code) select tenant_id,path,resource_key,language_code from eligible where path<>$4 on conflict(tenant_id,path) do nothing), saved as (update agency.seo_locales s set path=$4,path_custom=true,title=$5,description=$6,keywords=$7,og_title=$8,og_description=$9,og_image=$10,noindex=$11::text::boolean,updated_at=now() from eligible e where (s.tenant_id,s.resource_key,s.language_code)=(e.tenant_id,e.resource_key,e.language_code) returning s.resource_key), content as (insert into agency.translations(tenant_id,entity_type,entity_id,language_code,field_name,value) select $1::uuid,'listing',l.id,$3,p.key,p.value from agency.listings l join saved s on s.resource_key='listing:'||l.id::text cross join (values('title',$12::text),('description',$13::text)) p(key,value) where l.tenant_id=$1::uuid and $3<>'tr' and $12<>'' and $13<>'' on conflict(tenant_id,entity_type,entity_id,language_code,field_name) do update set value=excluded.value) select jsonb_build_object('saved',count(*)=1,'error',case when count(*)=0 then 'url_conflict' else '' end)::text from saved">>,[T,K,L,P,Title,Desc,Keywords,OgTitle,OgDesc,OgImage,NI,CT,CD]),case Result of <<>>->wisp:json_body(wisp:response(409),<<"{\"saved\":false,\"error\":\"url_conflict\"}">>);_->wisp:json_body(wisp:ok(),Result) end end.
localized_links(D,T,L,B)->
 Rows=try json:decode(q(D,<<"select coalesce(jsonb_agg(jsonb_build_object('source',source_path,'path',path)),'[]')::text from agency.seo_locales where tenant_id=$1::uuid and language_code=$2">>,[T,L])) catch _:_ ->[] end,
 lists:foldl(fun(R,A)->Source=maps:get(<<"source">>,R),P=maps:get(<<"path">>,R),binary:replace(A,<<"href=\"",Source/binary,"\"">>,<<"href=\"",(seo_engine:esc(P))/binary,"\"">>,[global]) end,B,Rows).
