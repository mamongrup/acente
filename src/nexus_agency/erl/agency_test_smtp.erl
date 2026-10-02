%% Test sahte SMTP sunucusu — smtp_ffi yanıt kodu eşleşmesini gerçek bir
%% soket üzerinden sınamak için.
%%
%% Neden gerçek soket: smtp_ffi, TLS öncesi aşamada gen_tcp üzerinde çalışır
%% (STARTTLS yükseltmesinden hemen önce). expect/3 modül+soket alır, dolayısıyla
%% düz bir loopback bağlantısı üzerinde TLS kurmadan çağrılabilir ve test gerçekten
%% kablo üzerinden yanıt okur.
%%
%% Topoloji bilinçli olarak gerçeğin aynısı: **istemci** (bu süreç) expect/3'ü
%% çağırır, **sunucu** yalnızca yanıt satırlarını yollar. İkisi yer değiştirirse
%% sunucu kendi yazdığı satırı okumaya çalışır ve test yalnızca zaman aşımı görür.
-module(agency_test_smtp).
-export([roundtrip/2, roundtrip_ok/1]).

-define(HOLD_MS, 20000).

%% Sunucu verilen satırları yollar; istemci beklenen kodu okur.
%% Sonuç: {ok, nil} | {error, binary()}.
%%
%% Başarı **cift** `{ok, nil}` olarak döner, çünkü çağıran taraf Gleam
%% `Result(Nil, String)` bekler. smtp_ffi:expect/3 atom `ok` döndürür; atomu
%% doğrudan geçirmek Gleam tarafında Ok olmayan bir değere dönüşür ve
%% "başarılı" yollar testte patlar.
-spec roundtrip([binary()], integer()) -> {ok, nil} | {error, binary()}.
roundtrip(Lines, Want) ->
    {Sock, Cleanup} = with_fake_server(fun(S) ->
        lists:foreach(fun(L) -> ok = gen_tcp:send(S, [L]) end, Lines)
    end),
    try
        smtp_ffi:expect(gen_tcp, Sock, Want),
        {ok, nil}
    catch
        error:{smtp_reply, Got, Expected, Line} ->
            {error, iolist_to_binary(["sunucu ", integer_to_list(Got), " dondu, ",
                                      integer_to_list(Expected), " bekleniyordu: ",
                                      line_text(Line)])};
        error:{smtp_protocol, Line} ->
            {error, iolist_to_binary(["beklenmeyen yanit: ", line_text(Line)])};
        error:reply_limit ->
            {error, <<"cok fazla aralikli yanit">>};
        Class:Reason:Stack ->
            {error, crash(Class, Reason, Stack)}
    after
        Cleanup()
    end.

%% QUIT adımı: herhangi bir 2xx/3xx kabul edilmeli.
-spec roundtrip_ok(binary()) -> {ok, nil} | {error, binary()}.
roundtrip_ok(Line) ->
    {Sock, Cleanup} = with_fake_server(fun(S) -> ok = gen_tcp:send(S, [Line]) end),
    try
        smtp_ffi:expect_ok(gen_tcp, Sock),
        {ok, nil}
    catch
        error:{smtp_protocol, Got} ->
            {error, iolist_to_binary(["beklenmeyen yanit: ", line_text(Got)])};
        error:reply_limit ->
            {error, <<"cok fazla aralikli yanit">>};
        Class:Reason:Stack ->
            {error, crash(Class, Reason, Stack)}
    after
        Cleanup()
    end.

%% Loopback dinleyici + bağlanan istemci soketi. Sunucu tarafı soket kapanana
%% kadar açık kalır; {packet, line} her iki uçta da açık olduğundan satır
%% sınırları sürücü tarafından ayrıştırılır.
with_fake_server(Greet) ->
    {ok, Listen} = gen_tcp:listen(0, [binary, {active, false}, {packet, line},
                                       {reuseaddr, true}, {ip, {127, 0, 0, 1}}]),
    {ok, Port} = inet:port(Listen),
    Acceptor = spawn(fun() ->
        {ok, S} = gen_tcp:accept(Listen, 5000),
        Greet(S),
        receive
            stop -> ok
        after ?HOLD_MS -> ok
        end,
        gen_tcp:close(S)
    end),
    {ok, Sock} = gen_tcp:connect({127, 0, 0, 1}, Port,
                                 [binary, {active, false}, {packet, line}], 5000),
    {Sock, fun() ->
        Acceptor ! stop,
        gen_tcp:close(Sock),
        gen_tcp:close(Listen)
    end}.

%% Yakalanmayan çökme: nedeni **kendi adıyla** bildir. Genel bir "zaman aşımı"
%% mesajı yanıltıcıydı — smtp_ffi içindeki bir `orelse` öncelik hatası badarg
%% fırlatıyor, taklit onu da "zaman aşımı" diye raporluyor ve hata varken test
%% yeşil görünüyordu. Yalnızca recv'in gerçekten zaman aşımına uğradığı durum
%% zaman aşımı sayılır; en üstteki çerçeve okunur, yığın dökülmez.
crash(badmatch, {error, timeout}, _) -> <<"zaman asimi: sunucu yanit vermedi">>;
crash(case_clause, _, _) -> <<"zaman asimi: sunucu yanit vermedi">>;
crash(Class, Reason, Stack) ->
    Top = case Stack of
        [TopFrame | _] -> TopFrame;
        [] -> {unknown, []}
    end,
    iolist_to_binary(io_lib:format("beklenmeyen cokme: ~p:~p (beklenmeyen cerceve: ~p)",
                                   [Class, Reason, Top])).

line_text(Line) ->
    case iolist_to_binary(Line) of
        <<>> -> <<"(bos)">>;
        B -> binary:part(B, 0, min(byte_size(B), 120))
    end.
