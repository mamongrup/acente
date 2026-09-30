%% Gerçek HTTP GET — denetim uçlarının wisp/simulate ile değil, uygulamanın
%% gerçekten sunduğu yanıtla ölçülmesi için.
%%
%% wisp/simulate, tarayıcının gönderdiği başlıkların bir kısmını atlar ve
%% isteği doğrudan router.handle/3'e verir. Ana sayfa bu yolda
%% CaseClause(Undefined) ile çöküyordu, aynı adres gerçek HTTP üzerinden 200
%% dönüyor. Yani simulate ile yapılan denetim uygulamanın sunmadığı bir yolu
%% ölçüyordu.
%%
%% Yalnızca 200 yanıtlar başarı sayılır. Bir hata durumunda sessizce boş
%% sayfa ölçmek, tam olarak düzeltmeye çalıştığımız sahte güveni geri getirirdi.
-module(agency_test_http).

-export([get/1]).

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
