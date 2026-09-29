-module(nexus_agency_net).

-export([url_reachable/2]).

url_reachable(Url, TimeoutMs) ->
    try
        case uri_string:parse(to_list(Url)) of
            #{scheme := Scheme, host := Host} = Parsed ->
                Port = maps:get(port, Parsed, default_port(Scheme)),
                reachable(Host, Port, TimeoutMs);
            _ ->
                false
        end
    catch
        _:_ -> false
    end.

reachable(_Host, Port, _TimeoutMs) when not is_integer(Port); Port =< 0 ->
    false;
reachable(Host, Port, TimeoutMs) ->
    case gen_tcp:connect(to_list(Host), Port, [binary, {active, false}], TimeoutMs) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            true;
        _ ->
            false
    end.

default_port("https") -> 443;
default_port(<<"https">>) -> 443;
default_port("http") -> 80;
default_port(<<"http">>) -> 80;
default_port(_) -> 0.

to_list(Value) when is_binary(Value) -> binary_to_list(Value);
to_list(Value) when is_list(Value) -> Value;
to_list(Value) -> Value.
