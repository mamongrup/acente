%% Test ortam yardımcıları — paralel yürütmeye dayanıklı gleeunit paketi.
%%
%% İki tehlike sınıfı var ve ikisi de süreç-genel durumu mutasyona uğratır:
%%
%% 1) Env değişkenleri (SECRET_KEY_BASE, SECRET_KEY_BASE_PREVIOUS,
%%    CSP_REPORT_ONLY). Test sırrı bırakılırsa aynı süreçte sonraki testler
%%    farklı bir dünya görür (imzalı çerez damgası env SECRET_KEY_BASE'den
%%    türetilir). with_env/3 değişikliği adlandırılmış kilit altında yapar ve
%%    gövde panik atsa bile eski değere geri koyar; en kötü durumda bile
%%    kilit serbest kalır.
%%
%% 2) Paylaşılan DB kullanıcıları (integration-admin@nexus.local). Bu hesap
%%    üzerindeki şifre denemeleri failed_login_attempts sayacını taşır; iki
%%    paralel test aynı hesapta yarışırsa lockout testi başkasının denemelerini
%%    sayar. unique_username/1 her test için ayrı hesap üretir; with_lock/3
%%    lockout gibi hesap-çapraz kesinlik gerektiren testleri serileştirir.
-module(agency_test_env).
-export([integration_pool_name/0]).



-export([with_lock/3, with_env/3, unique_username/1]).

%% Gleam'den name String (binary) gelir; atom da kabul edilir. Kilit anahtarı
%% düz atom olur; gleeunit test adlarıyla çakışmaması için agent_test_env_
%% önekiyle saklanır.
with_lock(Name, Owner, Fun) when is_function(Fun, 0) ->
    Key = binary_to_atom(
        <<"agent_test_env_", (name_to_binary(Name))/binary>>, utf8
    ),
    gleeunit_lock(Key, Owner, Fun).

name_to_binary(Name) when is_binary(Name) -> Name;
name_to_binary(Name) when is_atom(Name) -> atom_to_binary(Name, utf8).

%% Gövdenin sonucunu döndürür (Gleam imzası fn(a, b, fn() -> c) -> c);
%% panik durumunda bile kilit after bloğunda serbest kalır.
gleeunit_lock(Key, _Owner, Fun) ->
    global:set_lock({Key, self()}),
    try Fun()
    after global:del_lock({Key, self()}) end.

%% with_env(Name, [{K, unset | V}], Fun):
%%  - Kilit altında: her K için eski değer kaydedilir, yeni değer set/unset
%%    edilir, Fun() koşar, ensure_all ile eski değerler geri konur. Fun panik
%%    atsa bile env restore edilir ve kilit serbest kalır.
with_env(Name, Updates, Fun) when is_function(Fun, 0) ->
    with_lock(Name, with_env, fun() ->
        Saved = [begin
            Old = os:getenv(env_to_list(K), unset),
            apply_env(K, V),
            {K, Old}
        end || {K, V} <- Updates],
        try Fun()
        after
            lists:foreach(
                fun({K, Old}) -> apply_env(K, Old) end, Saved
            )
        end
    end).

%% Gleam EnvUpdate derlemesi: EnvSet(V) -> {env_set, V}, EnvUnset -> env_unset
%% atomu. `unset` yalnızca with_env'nin "eski değer yoktu" sentinel'idir
%% (os:getenv/2 default'u) ve restore'da değişkeni kaldırır. Eski değer
%% binary/charlist olarak dönerse son başlık set eder.
%%
%% Windows'ta os:putenv/os:unsetenv binary kabul etmez (badarg); envoy_ffi'nin
%% kanıtlanmış davranışıyla aynı şekilde charlist'e çevirerek çağırırız.
apply_env(_K, unset) ->
    os:unsetenv(env_to_list(_K));
apply_env(_K, env_unset) ->
    os:unsetenv(env_to_list(_K));
apply_env(K, {env_set, V}) ->
    os:putenv(env_to_list(K), env_to_list(V));
apply_env(K, V) ->
    os:putenv(env_to_list(K), env_to_list(V)).

env_to_list(V) when is_binary(V) -> unicode:characters_to_list(V);
env_to_list(V) when is_list(V) -> V;
env_to_list(V) when is_atom(V) -> atom_to_list(V).

%% Test başına benzersiz kullanıcı adı: parallel-<tag>-<rand>@nexus.local.
%% Tag Gleam'den binary gelir (atom kabulü savunmacıdır). Bu kullanıcılar
%% fixture insert'üyle test içinde yaratılır ve hesap sayacı yarışlarından
%% muaftır.
unique_username(Tag) ->
    Rand = erlang:unique_integer([positive, monotonic]),
    TagBin = case Tag of
        T when is_binary(T) -> T;
        T when is_atom(T) -> atom_to_binary(T, utf8)
    end,
    <<"parallel-", TagBin/binary, "-", (integer_to_binary(Rand))/binary,
      "@nexus.local">>.

%% One small pool per test VM; repeated router tests must not exhaust PostgreSQL.
integration_pool_name() -> agency_integration_test_db.
