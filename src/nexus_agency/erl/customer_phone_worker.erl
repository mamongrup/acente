-module(customer_phone_worker).
-export([run/1, payload/4, classify/1]).
run(Db) ->
 try
  query(Db,<<"select 'ok'::text from agency.customer_expire_email_codes()">>,[]),
  case query(Db,<<"select * from agency.customer_phone_claim()">>,[]) of
   {ok,R} -> lists:foreach(fun(Row)->process(Db,Row) end,element(3,R));
   _ -> ok
  end
 catch _:_ -> ok end,
 nil.
query(Db,Sql,Params) ->
 Q=lists:foldl(fun(V,A)->pog:parameter(A,pog_ffi:coerce(V)) end,pog:'query'(Sql),Params),
 pog:execute(pog:returning(Q,{decoder,fun gleam@dynamic@decode:decode_dynamic/1}),Db).
field(Row,N) ->
 D=gleam@dynamic@decode:at([N],{decoder,fun gleam@dynamic@decode:decode_string/1}),
 {ok,V}=gleam@dynamic@decode:run(Row,D),V.
process(Db,R) ->
 Id=field(R,0),
 Result=try
  T=field(R,1),Phone=field(R,2),Code=field(R,3),PhoneId=field(R,4),Sealed=field(R,5),Template=field(R,6),Lang=field(R,7),Version=field(R,8),
  true=valid(PhoneId,<<"^[0-9]{5,30}$">>),true=valid(Version,<<"^v[0-9]{1,2}\\.[0-9]$">>),
  true=valid(Phone,<<"^\\+[1-9][0-9]{7,14}$">>),true=valid(Code,<<"^[0-9]{8}$">>),
  true=valid(Template,<<"^[a-z0-9_]{1,512}$">>),true=valid(Lang,<<"^[a-z]{2,3}(_[A-Z]{2})?$">>),
  {ok,Token}=nexus_agency@secrets:open_for_tenant(T,<<"whatsapp_token">>,Sealed),
  application:ensure_all_started(inets),application:ensure_all_started(ssl),
  URL=binary_to_list(<<"https://graph.facebook.com/",Version/binary,"/",PhoneId/binary,"/messages">>),
  SSL=[{verify,verify_peer},{cacerts,public_key:cacerts_get()},{customize_hostname_check,[{match_fun,public_key:pkix_verify_hostname_match_fun(https)}]}],
  Response=httpc:request(post,{URL,[{"authorization","Bearer "++binary_to_list(Token)}],"application/json",payload(Phone,Code,Template,Lang)},[{timeout,5000},{connect_timeout,3000},{autoredirect,false},{ssl,SSL}],[{body_format,binary}]),
  case classify(Response) of
   <<"sent">> -> case provider_id(Response) of <<>> -> <<"failed">>;Provider -> case query(Db,<<"select agency.customer_phone_accept($1::uuid,$2)">>,[Id,Provider]) of {ok,_}-> <<"sent">>; _ -> <<"retry">> end end;
   Other -> Other end
 catch _:_ -> <<"failed">> end,
 query(Db,<<"select 'ok'::text from agency.customer_phone_finish($1::uuid,$2)">>,[Id,Result]),ok.
valid(V,Regex)-> re:run(V,Regex,[{capture,none}])=:=match.
classify({ok,{{_,Status,_},_,_}}) when Status>=200,Status<300 -> <<"sent">>;
classify({ok,{{_,Status,_},_,_}}) when Status=:=429;Status>=500 -> <<"retry">>;
classify({error,_})-> <<"retry">>;
classify(_)-> <<"failed">>.
s(V)->gleam@json:string(V).
o(V)->gleam@json:object(V).
a(V)->gleam@json:preprocessed_array(V).
payload(Phone,Code,Template,Lang)->
 To=binary:replace(Phone,<<"+">>,<<>>),
 Param=o([{<<"type">>,s(<<"text">>)},{<<"text">>,s(Code)}]),
 Body=o([{<<"type">>,s(<<"body">>)},{<<"parameters">>,a([Param])}]),
 Button=o([{<<"type">>,s(<<"button">>)},{<<"sub_type">>,s(<<"url">>)},{<<"index">>,s(<<"0">>)},{<<"parameters">>,a([Param])}]),
 gleam@json:to_string(o([{<<"messaging_product">>,s(<<"whatsapp">>)},{<<"to">>,s(To)},{<<"type">>,s(<<"template">>)},{<<"template">>,o([{<<"name">>,s(Template)},{<<"language">>,o([{<<"code">>,s(Lang)}])},{<<"components">>,a([Body,Button])}])}])).

provider_id({ok,{{_,Status,_},_,Body}}) when Status>=200,Status<300 -> try P=json:decode(Body),[M|_]=maps:get(<<"messages">>,P),Id=maps:get(<<"id">>,M),true=is_binary(Id),true=byte_size(Id)>0,true=byte_size(Id)=<255,Id catch _:_ -> <<>> end;
provider_id(_)-> <<>>.
