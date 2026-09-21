-module(agency_ffi_http).
-export([
  post_json/3,
  post_json_with_timeout/4,
  get_url/1,
  get_url_with_auth/2,
  post_urlencoded/2,
  post_xml/3
]).

ssl_opts_for_url(UrlStr) ->
  case lists:prefix("https://", UrlStr) of
    true ->
      [
        {verify, verify_peer},
        {depth, 3},
        {customize_hostname_check, [
          {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
        ]}
      ];
    false ->
      []
  end.

clamp_timeout(TimeoutMs) when is_integer(TimeoutMs) ->
  if
    TimeoutMs < 5000 -> 5000;
    TimeoutMs > 180000 -> 180000;
    true -> TimeoutMs
  end;
clamp_timeout(_) -> 30000.

post_json(Url, Body, AuthHeader) when is_binary(Url), is_binary(Body), is_binary(AuthHeader) ->
  post_json_with_timeout(Url, Body, AuthHeader, 45000).

post_json_with_timeout(Url, Body, AuthHeader, TimeoutMs)
  when is_binary(Url), is_binary(Body), is_binary(AuthHeader), is_integer(TimeoutMs) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  T = clamp_timeout(TimeoutMs),
  UrlStr = binary_to_list(Url),
  BodyStr = binary_to_list(Body),
  Headers =
    [
      {"Accept", "application/json"},
      {"User-Agent", "NEXUS-Agency-Platform/2.0"},
      {"Connection", "keep-alive"}
    ]
    ++ case AuthHeader of
      <<>> -> [];
      A -> [{"Authorization", binary_to_list(A)}]
    end,
  Request = {UrlStr, Headers, "application/json; charset=UTF-8", BodyStr},
  HttpOptions = [
    {connect_timeout, 20000},
    {timeout, T},
    {ssl, ssl_opts_for_url(UrlStr)}
  ],
  case httpc:request(post, Request, HttpOptions, []) of
    {ok, {{_, Status, _}, _Headers, RespBody}} ->
      Bin = iolist_to_binary(RespBody),
      case Status >= 200 andalso Status < 300 of
        true -> {ok, Bin};
        false -> {error, Bin}
      end;
    {error, Reason} ->
      {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
  end.

get_url(Url) when is_binary(Url) ->
  get_url_with_auth(Url, <<>>).

get_url_with_auth(Url, AuthHeader) when is_binary(Url), is_binary(AuthHeader) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  UrlStr = binary_to_list(Url),
  Headers =
    [
      {"Accept", "application/json, text/html, */*"},
      {"User-Agent", "NEXUS-Agency-Platform/2.0"}
    ]
    ++ case AuthHeader of
      <<>> -> [];
      A -> [{"Authorization", binary_to_list(A)}]
    end,
  Request = {UrlStr, Headers},
  HttpOptions = [
    {connect_timeout, 15000},
    {timeout, 30000},
    {ssl, ssl_opts_for_url(UrlStr)}
  ],
  case httpc:request(get, Request, HttpOptions, []) of
    {ok, {{_, Status, _}, _Headers, RespBody}} ->
      Bin = iolist_to_binary(RespBody),
      case Status >= 200 andalso Status < 300 of
        true -> {ok, Bin};
        false -> {error, Bin}
      end;
    {error, Reason} ->
      {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
  end.

post_urlencoded(Url, Body) when is_binary(Url), is_binary(Body) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  UrlStr = binary_to_list(Url),
  BodyStr = binary_to_list(Body),
  Request = {UrlStr, [], "application/x-www-form-urlencoded; charset=UTF-8", BodyStr},
  HttpOptions = [{timeout, timer:seconds(25)}, {ssl, ssl_opts_for_url(UrlStr)}],
  case httpc:request(post, Request, HttpOptions, []) of
    {ok, {{_, Status, _}, _Headers, RespBody}} ->
      Bin = iolist_to_binary(RespBody),
      case Status >= 200 andalso Status < 300 of
        true -> {ok, Bin};
        false -> {error, Bin}
      end;
    {error, Reason} ->
      {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
  end.

post_xml(Url, Body, SoapAction) when is_binary(Url), is_binary(Body), is_binary(SoapAction) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  UrlStr = binary_to_list(Url),
  BodyStr = binary_to_list(Body),
  Headers = [
    {"Content-Type", "text/xml; charset=utf-8"},
    {"SOAPAction", binary_to_list(SoapAction)},
    {"Accept", "text/xml, application/xml, */*"},
    {"User-Agent", "NEXUS-Agency-Platform/2.0"}
  ],
  Request = {UrlStr, Headers, "text/xml; charset=utf-8", BodyStr},
  HttpOptions = [
    {connect_timeout, 20000},
    {timeout, 45000},
    {ssl, ssl_opts_for_url(UrlStr)}
  ],
  case httpc:request(post, Request, HttpOptions, []) of
    {ok, {{_, Status, _}, _Headers, RespBody}} ->
      Bin = iolist_to_binary(RespBody),
      case Status >= 200 andalso Status < 300 of
        true -> {ok, Bin};
        false -> {error, Bin}
      end;
    {error, Reason} ->
      {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
  end.
