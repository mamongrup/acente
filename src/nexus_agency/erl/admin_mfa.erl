-module(admin_mfa).
-export([gate/4, manage/5, totp/2, base32/1]).
query(Db,Sql,Params)->Q=lists:foldl(fun(V,A)->pog:parameter(A,pog_ffi:coerce(V)) end,pog:'query'(Sql),Params),case pog:execute(pog:returning(Q,{decoder,fun gleam@dynamic@decode:decode_dynamic/1}),Db) of
 {error,{postgresql_error,C,N,_}}=E -> io:format("Admin MFA database error: ~s (~s)~n",[C,N]),E;
 {error,E}=Result when is_tuple(E) -> io:format("Admin MFA query error type: ~p~n",[element(1,E)]),Result;
 R -> R end.
f(R,N)->{ok,V}=gleam@dynamic@decode:run(R,gleam@dynamic@decode:at([N],{decoder,fun gleam@dynamic@decode:decode_string/1})),V.
scalar(Db,SQL,P)->case query(Db,SQL,P) of {ok,R}->case element(3,R) of [Row|_]->f(Row,0);_-><<"unavailable">> end;_-><<"unavailable">> end.
read(Db,T,U)->case query(Db,<<"select * from agency.admin_mfa_read($1::uuid,$2::uuid)">>,[T,U]) of {ok,R}->case element(3,R) of [Row|_]->{ok,f(Row,0),f(Row,1)};[]->none end;_->error end.
gate(Db,T,U,Code)->case read(Db,T,U) of none->true;{ok,_,<<"false">>}->true;{ok,Sealed,<<"true">>}->verify(Db,T,U,Sealed,Code);_->false end.
verify(Db,T,U,Sealed,Code)->try
 true=(scalar(Db,<<"select agency.admin_mfa_attempt($1::uuid,$2::uuid)::text">>,[T,U])=:= <<"true">>),
 {ok,Hex}=nexus_agency@secrets:open_for_tenant(T,<<"admin_mfa">>,Sealed),Secret=binary:decode_hex(Hex),Now=erlang:system_time(second) div 30,
 Counters=[C||C<-[Now-1,Now,Now+1],totp(Secret,C)=:=Code],
 case Counters of [C|_]->scalar(Db,<<"select agency.admin_mfa_claim($1::uuid,$2::uuid,$3::text::bigint,'')::text">>,[T,U,integer_to_binary(C)])=:= <<"true">>; []->case re:run(Code,<<"^[a-f0-9]{16}$">>,[{capture,none}]) of match->scalar(Db,<<"select agency.admin_mfa_claim($1::uuid,$2::uuid,-1,$3)::text">>,[T,U,Code])=:= <<"true">>;_->false end end
 catch _:_ -> false end.
manage(Db,T,U,Action,Values)->try
 Password=value(Values,<<"password">>),Code=value(Values,<<"code">>),
 case Action of
 <<"begin">> -> Secret=crypto:strong_rand_bytes(20),{ok,Sealed}=nexus_agency@secrets:seal_for_tenant(T,<<"admin_mfa">>,binary:encode_hex(Secret)),Backups=[string:lowercase(binary:encode_hex(crypto:strong_rand_bytes(8)))||_<-lists:seq(1,8)],Hashes=[string:lowercase(binary:encode_hex(crypto:hash(sha256,B)))||B<-Backups],Array= <<"{",(iolist_to_binary(lists:join(<<",">>,Hashes)))/binary,"}">>,
 case scalar(Db,<<"select agency.admin_mfa_begin($1::uuid,$2::uuid,$3,$4,$5::text::text[])">>,[T,U,Password,Sealed,Array]) of <<"pending">> -> gleam@json:to_string(gleam@json:object([{<<"status">>,gleam@json:string(<<"pending">>)},{<<"secret">>,gleam@json:string(base32(Secret))},{<<"backupCodes">>,gleam@json:preprocessed_array([gleam@json:string(B)||B<-Backups])}])); S->json(S) end;
 <<"enable">> -> case read(Db,T,U) of {ok,Sealed,_}->case verify(Db,T,U,Sealed,Code) of true->json(scalar(Db,<<"select agency.admin_mfa_set($1::uuid,$2::uuid,$3,true)">>,[T,U,Password]));_->json(<<"invalid_code">>) end;_->json(<<"invalid">>) end;
 <<"disable">> -> case read(Db,T,U) of {ok,Sealed,<<"true">>}->case verify(Db,T,U,Sealed,Code) of true->json(scalar(Db,<<"select agency.admin_mfa_set($1::uuid,$2::uuid,$3,false)">>,[T,U,Password]));_->json(<<"invalid_code">>) end;_->json(<<"invalid">>) end;
 _ -> json(<<"invalid">>) end
 catch Class:Reason:Stack -> Kind=case Reason of A when is_atom(A)->A; A when is_tuple(A)->element(1,A);_->other end, Location=case Stack of [{M,F,_,_}|_]->{M,F};_->unknown end,io:format("Admin MFA failure: ~p ~p at ~p~n",[Class,Kind,Location]),json(<<"unavailable">>) end.
json(S)->gleam@json:to_string(gleam@json:object([{<<"status">>,gleam@json:string(S)}])).
value(V,K)->case gleam@list:key_find(V,K) of {ok,S}->S;_-><<>> end.
totp(Secret,Counter)->H=crypto:mac(hmac,sha,Secret,<<Counter:64/unsigned-big>>),Offset=binary:last(H) band 15,<<_:Offset/binary,N:32/unsigned-big,_/binary>>=H,list_to_binary(io_lib:format("~6..0B",[(N band 16#7fffffff) rem 1000000])).
base32(B)->Alphabet= <<"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567">>, << <<(binary:at(Alphabet,N))>> || <<N:5>> <= B >>.
