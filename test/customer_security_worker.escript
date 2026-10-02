#!/usr/bin/env escript
main(_) ->
 code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),application:ensure_all_started(crypto),
 <<"287082">>=admin_mfa:totp(<<"12345678901234567890">>,1),
 <<"GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ">>=admin_mfa:base32(<<"12345678901234567890">>),
 <<"sent">>=customer_phone_worker:classify({ok,{{"HTTP/1.1",200,"OK"},[],<<>>}}),
 <<"retry">>=customer_phone_worker:classify({ok,{{"HTTP/1.1",429,"Rate limit"},[],<<>>}}),
 <<"failed">>=customer_phone_worker:classify({ok,{{"HTTP/1.1",400,"Bad request"},[],<<>>}}),
 Body=customer_phone_worker:payload(<<"+905551234567">>,<<"12345678">>,<<"auth_test">>,<<"tr">>),
 true=(binary:match(Body,<<"905551234567">>)=/=nomatch),true=(binary:match(Body,<<"12345678">>)=/=nomatch),
 io:format("TOTP reference, base32 and WhatsApp adapter tests passed~n").
