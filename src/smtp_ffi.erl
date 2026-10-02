%% SMTP submission with mandatory verified TLS and explicit protocol replies.
%%
%% Every server reply is matched against the code the RFC 5321 step expects.
%% A reply code that is not compared is a silent data-loss bug: the caller
%% (email_sender) marks agency.notifications rows as `sent` on {ok, _}, so a
%% 535 (credentials rejected), 550 (recipient rejected) or 554 (message
%% rejected) would be reported as delivered and never retried.
-module(smtp_ffi).
%% expect/3 ve expect_ok/2 dışarı açıktır: test/smtp_reply_test.gleam gerçek
%% bir soket üzerinden yanıt kodu eşleşmesini sınar (bkz. agency_test_smtp).
-export([send/8, expect/3, expect_ok/2]).

send(Host0,Port,User,Password,From,To,Subject,Html)->
 try
  true=lists:member(Port,[587,465,25]),true=clean(Host0),true=clean(From),true=clean(To),true=clean(Subject),
  Host=binary_to_list(iolist_to_binary(Host0)),application:ensure_all_started(ssl),
  Options=[{verify,verify_peer},{cacerts,public_key:cacerts_get()},{server_name_indication,Host},{customize_hostname_check,[{match_fun,public_key:pkix_verify_hostname_match_fun(https)}]},{active,false},{packet,line},binary],
  case Port of
   465->{ok,S}=ssl:connect(Host,Port,Options,5000),try expect(ssl,S,220),session(S,User,Password,From,To,Subject,Html) after ssl:close(S) end;
   _->{ok,T}=gen_tcp:connect(Host,Port,[binary,{active,false},{packet,line}],5000),try
    expect(gen_tcp,T,220),command(gen_tcp,T,<<"EHLO localhost">>,250),command(gen_tcp,T,<<"STARTTLS">>,220),
    {ok,S}=ssl:connect(T,Options,5000),try session(S,User,Password,From,To,Subject,Html) after ssl:close(S) end
   after gen_tcp:close(T) end
  end,
  {ok,nil}
 catch
  %% Sunucu yanıtı beklenen koddan farklı: adım adı nedir, ne bekleniyordu,
  %% ne geldi? Çağıran bu metni mark_failed(reason) olarak saklar.
  error:{smtp_reply,Got,Want,Line}->{error,smtp_reply_error(Got,Want,Line)};
  error:{smtp_protocol,Line}->{error,protocol_error(Line)};
  error:reply_limit->{error,<<"SMTP sunucusu cok fazla aralikli yanit gonderdi; oturum kapatildi."/utf8>>};
  _:_->{error,<<"SMTP bağlantısı veya kimlik doğrulaması başarısız. Sunucu, port ve TLS ayarlarını kontrol edin."/utf8>>}
 end.

%% Başlık enjeksiyonu: From/To/Subject satır sonu içeremez.
clean(V)->B=iolist_to_binary(V),binary:match(B,<<"\r">>)=:=nomatch andalso binary:match(B,<<"\n">>)=:=nomatch.

command(M,S,Line,Code)->ok=M:send(S,[Line,<<"\r\n">>]),expect(M,S,Code).

%% Kesintisiz yanıtlar (NNN-) tek bir yanıttır: ara satırların kodu
%% atlanır, yalnızca son satırın kodu beklenenle karşılaştırılır.
%%
%% Karşılaştırma `=:=` ile yapılır. `Actual=Want orelse error(...)` yazımı
%% Erlang'da `Actual = (Want orelse error(...))` olarak ayrıştırılır (`=`
%% `orelse`'dan düşük önceliklidir) ve beklenen kodu boolean olmayan bir
%% değere zorlar; sunucu doğru kodlu bile olsa badarg ile patlar.
expect(M,S,Code)->expect(M,S,Code,0).
expect(_,_,_,32)->error(reply_limit);
expect(M,S,Want,N)->
 {ok,Line}=M:recv(S,0,5000),
 case Line of
  <<_,_,_,$-,_/binary>>->expect(M,S,Want,N+1);
  <<A,B,C,$\s,_/binary>>->
   Actual=list_to_integer([A,B,C]),
   case Actual =:= Want of
    true->ok;
    false->error({smtp_reply,Actual,Want,Line})
   end;
  _->error({smtp_protocol,Line})
 end.

%% QUIT: mesaj DATA sonrası 250 ile zaten teslim edilmiştir, kapatma adımı
%% gönderimi geri almaz. Katı 221 beklemek teslim edilmiş iletiyi "başarısız"
%% sayıp yeniden denemeye (mükerrer e-posta) yol açardı; bu yüzden QUIT için
%% 2xx/3xx kabul edilir, 4xx/5xx yine hatadır.
expect_ok(M,S)->expect_ok(M,S,0).
expect_ok(_,_,32)->error(reply_limit);
expect_ok(M,S,N)->
 {ok,Line}=M:recv(S,0,5000),
 case Line of
  <<_,_,_,$-,_/binary>>->expect_ok(M,S,N+1);
  <<A,B,C,$\s,_/binary>> when A>=$2,A=<$3,B>=$0,B=<$9,C>=$0,C=<$9->ok;
  _->error({smtp_protocol,Line})
 end.

session(S,User,Password,From,To,Subject,Html)->
 command(ssl,S,<<"EHLO localhost">>,250),command(ssl,S,<<"AUTH LOGIN">>,334),
 command(ssl,S,base64:encode(iolist_to_binary(User)),334),command(ssl,S,base64:encode(iolist_to_binary(Password)),235),
 command(ssl,S,[<<"MAIL FROM:<">>,From,<<">">>],250),command(ssl,S,[<<"RCPT TO:<">>,To,<<">">>],250),command(ssl,S,<<"DATA">>,354),
 Encoded=base64:encode(iolist_to_binary(Subject)),Body=iolist_to_binary(Html),
 Normal=binary:replace(binary:replace(Body,<<"\r\n">>,<<"\n">>,[global]),<<"\r">>,<<"\n">>,[global]),
 Lines=binary:split(Normal,<<"\n">>,[global]),Safe=lists:join(<<"\r\n">>,[case L of <<$.,_/binary>>-> <<$.,L/binary>>;_->L end || L<-Lines]),
 ok=ssl:send(S,[<<"From: <">>,From,<<">\r\nTo: <">>,To,<<">\r\nSubject: =?UTF-8?B?">>,Encoded,<<"?=\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n">>,Safe,<<"\r\n.\r\n">>]),
 expect(ssl,S,250),ok=ssl:send(S,[<<"QUIT\r\n">>]),ok=expect_ok(ssl,S),ok.

%% Hata metinleri sunucunun kendi yanıtını taşır (kimlik bilgisi içermez):
%% 535/550/554 ayrımı logda görünür kalsın.
smtp_reply_error(Got,Want,Line)->
 iolist_to_binary(["SMTP sunucusu istenen adimi reddetti: ",integer_to_list(Got)," dondu, ",integer_to_list(Want)," bekleniyordu — ",safe_text(Line)]).

protocol_error(Line)->
 iolist_to_binary(["SMTP sunucusu beklenmeyen bir yanit verdi: ",safe_text(Line)]).

%% Yanıt satırını tek satır, makul uzunlukta metne indirger; kontrol
%% karakterleri (özellikle \r\n) loga sızmasın.
safe_text(Line)->
 Flat=binary:replace(binary:replace(iolist_to_binary(Line),<<"\r">>,<<" ">>,[global]),<<"\n">>,<<" ">>,[global]),
 case Flat of <<>>->"(bos yanit)";_->binary:part(Flat,0,min(byte_size(Flat),200)) end.
