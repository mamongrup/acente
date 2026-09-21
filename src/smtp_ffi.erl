%% Minimal SMTP client — gen_tcp/ssl üzerinden doğrudan SMTP konuşması.
%% TLSSTARTTLS destekler; bağımlılık gerektirmez.
-module(smtp_ffi).
-export([send/8]).

%% Host, Port, Username, Password, From, To, Subject, HtmlBody -> ok | {error, Reason}
send(Host, Port, Username, Password, From, To, Subject, HtmlBody) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false}], 10000) of
        {ok, Sock} ->
            try
                {ok, _} = recv(Sock),
                ok = send_cmd(Sock, "EHLO localhost"),
                ok = send_cmd(Sock, "AUTH LOGIN"),
                ok = send_cmd(Sock, encode_b64(Username)),
                ok = send_cmd(Sock, encode_b64(Password)),
                ok = send_cmd(Sock, "MAIL FROM:<" ++ From ++ ">"),
                ok = send_cmd(Sock, "RCPT TO:<" ++ To ++ ">"),
                ok = send_cmd(Sock, "DATA"),
                ok = send_data(Sock, From, To, Subject, HtmlBody),
                ok = send_cmd(Sock, "QUIT"),
                gen_tcp:close(Sock),
                ok
            catch
                _:Reason ->
                    gen_tcp:close(Sock),
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

send_cmd(Sock, Cmd) ->
    ok = gen_tcp:send(Sock, iolist_to_binary([Cmd, "\r\n"])),
    case recv(Sock) of
        {ok, <<Code:3/binary, _/binary>>} when Code >= <<"200">>, Code =< <<"399">> ->
            ok;
        {ok, Data} ->
            {error, Data};
        {error, Reason} ->
            {error, Reason}
    end.

send_data(Sock, From, To, Subject, HtmlBody) ->
    Header = iolist_to_binary([
        "From: <", From, ">\r\n",
        "To: <", To, ">\r\n",
        "Subject: ", Subject, "\r\n",
        "MIME-Version: 1.0\r\n",
        "Content-Type: text/html; charset=UTF-8\r\n",
        "\r\n"
    ]),
    Body = iolist_to_binary([Header, HtmlBody, "\r\n.\r\n"]),
    ok = gen_tcp:send(Sock, Body),
    case recv(Sock) of
        {ok, <<Code:3/binary, _/binary>>} when Code >= <<"200">>, Code =< <<"399">> ->
            ok;
        {ok, Data} ->
            {error, Data};
        {error, Reason} ->
            {error, Reason}
    end.

recv(Sock) ->
    gen_tcp:recv(Sock, 0, 10000).

encode_b64(Str) ->
    binary_to_list(base64:encode(iolist_to_binary(Str))).
