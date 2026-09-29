-module(nexus_agency_secrets).
-export([seal/3, open/3, valid_https/1]).

seal(Value, Key, Context) when byte_size(Key) >= 64 ->
    try
        Nonce = crypto:strong_rand_bytes(12),
        {Cipher, Tag} = crypto:crypto_one_time_aead(
            aes_256_gcm,
            crypto:hash(sha256, Key),
            Nonce,
            Value,
            Context,
            16,
            true
        ),
        {ok, <<"v1:", (base64:encode(<<Nonce/binary, Tag/binary, Cipher/binary>>))/binary>>}
    catch
        _:_ -> {error, nil}
    end;
seal(_, _, _) ->
    {error, nil}.

open(<<"v1:", Encoded/binary>>, Key, Context) when byte_size(Key) >= 64 ->
    try
        <<Nonce:12/binary, Tag:16/binary, Cipher/binary>> = base64:decode(Encoded),
        case crypto:crypto_one_time_aead(
            aes_256_gcm,
            crypto:hash(sha256, Key),
            Nonce,
            Cipher,
            Context,
            Tag,
            false
        ) of
            error -> {error, nil};
            Value -> {ok, Value}
        end
    catch
        _:_ -> {error, nil}
    end;
open(_, _, _) ->
    {error, nil}.

valid_https(Value) ->
    try
        case uri_string:parse(Value) of
            #{scheme := <<"https">>, host := Host} = Parsed when byte_size(Host) > 0 ->
                not maps:is_key(userinfo, Parsed)
                andalso not maps:is_key(fragment, Parsed)
                andalso Host =/= <<"localhost">>
                andalso Host =/= <<"127.0.0.1">>
                andalso Host =/= <<"::1">>;
            _ ->
                false
        end
    catch
        _:_ -> false
    end.
