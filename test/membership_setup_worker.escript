#!/usr/bin/env escript
main(_) ->
 code:add_paths(filelib:wildcard("build/dev/erlang/*/ebin")),
 {error,_}=smtp_ffi:send(<<"127.0.0.1">>,465,<<"fixture">>,<<"secret">>,<<"sender@example.test\r\nInjected: x">>,<<"receiver@example.test">>,<<"test">>,<<"body">>),
 {ok,L}=gen_tcp:listen(0,[binary,{active,false},{packet,line},{reuseaddr,true}]),{ok,{_,Port}}=inet:sockname(L),
 %% SMTP API only allows known submission ports. A closed permitted TLS port
 %% must return the Gleam Result shape, never crash or leak input credentials.
 {error,Message}=smtp_ffi:send(<<"127.0.0.1">>,465,<<"fixture">>,<<"private-fixture">>,<<"sender@example.test">>,<<"receiver@example.test">>,<<"test">>,<<"body">>),
 true=is_binary(Message),nomatch=binary:match(Message,<<"private-fixture">>),gen_tcp:close(L),true=is_integer(Port),
 Secret= <<"fixture-app-secret-value">>,Body= <<"{\"test\":true}">>,Signature= <<"sha256=",(binary:encode_hex(crypto:mac(hmac,sha256,Secret,Body)))/binary>>,
 true=membership_setup:signature(Secret,Body,Signature),false=membership_setup:signature(Secret,<<"changed">>,Signature),false=membership_setup:signature(Secret,Body,<<"sha256=broken">>),
 %% Reject a server without STARTTLS before any AUTH or credentials.
 Parent=self(),case gen_tcp:listen(587,[binary,{active,false},{packet,line},{reuseaddr,true}]) of
 {ok,Plain}->spawn(fun()->{ok,Sock}=gen_tcp:accept(Plain,5000),gen_tcp:send(Sock,<<"220 fixture\r\n">>),{ok,EHLO}=gen_tcp:recv(Sock,0,5000),gen_tcp:send(Sock,<<"250-fixture\r\n250 SIZE 10000\r\n">>),{ok,Start}=gen_tcp:recv(Sock,0,5000),gen_tcp:send(Sock,<<"500 TLS unsupported\r\n">>),Closed=gen_tcp:recv(Sock,0,5000),Parent!{plaintext,EHLO,Start,Closed},gen_tcp:close(Sock) end),
 {error,_}=smtp_ffi:send(<<"127.0.0.1">>,587,<<"fixture">>,<<"private-fixture">>,<<"sender@example.test">>,<<"receiver@example.test">>,<<"test">>,<<"body">>),
 receive {plaintext,<<"EHLO localhost\r\n">>,<<"STARTTLS\r\n">>,{error,closed}}->ok after 7000->error(tls_required_test) end,gen_tcp:close(Plain);
 {error,eaddrinuse}->io:format("SMTP STARTTLS fixture skipped: local submission port occupied~n") end,
 io:format("SMTP safe-result/header/TLS checks and webhook signatures passed~n").
