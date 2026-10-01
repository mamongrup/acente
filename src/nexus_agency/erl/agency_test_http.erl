%% Gerçek HTTP — denetim uçlarının wisp/simulate ile değil, uygulamanın
%% gerçekten sunduğu yanıtla ölçülmesi için.
%%
%% wisp/simulate, tarayıcının gönderdiği başlıkların bir kısmını atlar ve
%% isteği doğrudan router.handle/3'e verir. Ana sayfa bu yolda
%% CaseClause(Undefined) ile çöküyordu, aynı adres gerçek HTTP üzerinden 200
%% dönüyor. Yani simulate ile yapılan denetim uygulamanın sunmadığı bir yolu
%% ölçüyordu.
%%
%% get/1 yalnızca 200 yanıtları başarı sayar: bir hata durumunda sessizce boş
%% sayfa ölçmek, denetimin sahte güven üretmesine yol açar.
%% probe/1 ise /health yoklamasıdır: herhangi bir HTTP durum kodu "sunucu
%% var" demektir; yalnızca bağlantı kurulamaması (econnrefused, nxdomain,
%% timeout) hata döndürür. Böylece yerel kipte kapalı port → [SKIP], CI'da
%% (REQUIRE_LIVE_SERVER=true) yine de gürültülü panic garantisi korunur.
-module(agency_test_http).
-export([get/1, probe/1]).

-spec get(string()) -> {ok, binary()} | {error, term()}.
get(Url) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  case httpc:request(get, {Url, []}, [{timeout, 30000}], [{body_format, binary}]) of
    {ok, {{_Version, 200, _Reason}, _Headers, Body}} ->
      {ok, Body};
    {ok, {{_, Status, _}, _, _}} ->
      {error, {http_status, Status}};
    {error, Reason} ->
      {error, Reason}
  end.

-spec probe(string()) -> {ok, nil} | {error, term()}.
probe(Url) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  case httpc:request(get, {Url, []}, [{timeout, 5000}], []) of
    {ok, {{_Version, _Status, _Reason}, _Headers, _Body}} ->
      {ok, nil};
    {error, Reason} ->
      {error, Reason}
  end.
