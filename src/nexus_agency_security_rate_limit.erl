-module(nexus_agency_security_rate_limit).
-behaviour(gen_server).

-export([limited/3, normalize_ip/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, nexus_agency_security_rate_limits).
-define(MAX_ENTRIES, 10000).

%% The owner serializes admission and increments, including capacity checks.
%% Request workers never mutate the table independently.
limited(Key, Limit, WindowMs) when is_binary(Key), is_integer(Limit), Limit > 0 ->
    Server = ensure_server(),
    gen_server:call(Server, {limited, Key, Limit, WindowMs}, 5000).

normalize_ip(Value) when is_binary(Value), byte_size(Value) =< 64 ->
    case inet:parse_address(binary_to_list(Value)) of
        {ok, Address} -> list_to_binary(inet:ntoa(Address));
        {error, _} -> <<"unknown">>
    end;
normalize_ip(_) -> <<"unknown">>.

ensure_server() ->
    case whereis(?MODULE) of
        undefined ->
            case gen_server:start({local, ?MODULE}, ?MODULE, [], []) of
                {ok, Pid} -> Pid;
                {error, {already_started, Pid}} -> Pid;
                {error, Reason} -> erlang:error({rate_limit_table_start_failed, Reason})
            end;
        Pid -> Pid
    end.

capacity_available(Table, EntryKey, Now) ->
    case ets:member(Table, EntryKey) of
        true -> true;
        false ->
            case ets:info(Table, size) < ?MAX_ENTRIES of
                true -> true;
                false ->
                    ets:select_delete(Table, [
                        {{'_', '_', '$1'}, [{'=<', '$1', Now}], [true]}
                    ]),
                    ets:info(Table, size) < ?MAX_ENTRIES
            end
    end.

init([]) ->
    ets:new(?TABLE, [named_table, public, set,
                     {read_concurrency, true}, {write_concurrency, true}]),
    {ok, #{}}.

handle_call({limited, Key, Limit, WindowMs}, _From, State) ->
    Now = erlang:monotonic_time(millisecond),
    Window = max(1, trunc(WindowMs)),
    Bucket = Now div Window,
    EntryKey = {Key, Bucket},
    ExpiresAt = (Bucket + 1) * Window,
    Blocked = case capacity_available(?TABLE, EntryKey, Now) of
        false -> true;
        true ->
            %% The threshold keeps a sustained attacker from growing a
            %% counter into an arbitrarily large integer.
            Count = ets:update_counter(
                ?TABLE, EntryKey, {2, 1, Limit + 1, Limit + 1},
                {EntryKey, 0, ExpiresAt}
            ),
            Count > Limit
    end,
    {reply, Blocked, State};
handle_call(_Message, _From, State) -> {reply, ok, State}.
handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.
code_change(_OldVersion, State, _Extra) -> {ok, State}.
