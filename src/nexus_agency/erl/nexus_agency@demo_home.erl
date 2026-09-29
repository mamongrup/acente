-module('nexus_agency@demo_home').
-export([render/0, rewrite_links/1]).

%% The repository contains the approved Chisfis export.  Serving that source
%% for the public landing page keeps the header, popovers and every homepage
%% section in sync instead of maintaining a second, approximate implementation.
render() ->
    case file:read_file("chisfis-final/index.html") of
        {ok, Html0} ->
            Html1 = binary:replace(Html0, <<"assets/">>, <<"/static/chisfis/">>, [global]),
            Html2 = binary:replace(Html1, <<"/favicon.ico">>, <<"/static/chisfis/favicon.ico">>, [global]),
            Html3 = binary:replace(Html2, <<"/favicon.svg">>, <<"/static/chisfis/favicon.svg">>, [global]),
            Html4 = binary:replace(Html3, <<"/apple-touch-icon.png">>, <<"/static/chisfis/apple-touch-icon.png">>, [global]),
            Html5 = binary:replace(Html4, <<"/site.webmanifest">>, <<"/static/chisfis/site.webmanifest">>, [global]),
            Html6 = binary:replace(Html5, <<"qr.18a2_g5ftijw..webp">>, <<"qr.18a2_g5ftijw.webp">>, [global]),
            %% `chisfis-home` sınıfı ZORUNLU: bridge CSS'in ana sayfaya özel
            %% blokları (hero arama formu yerleşimi, hero sekme hover/odak
            %% halkası, konteyner genişlikleri) `.chisfis-home` altında
            %% kapsanmış. Export'un gövdesinde bu sınıf yok; eklenmezse tüm o
            %% kurallar ölü kalır (sekme hover'ı ve odak halkası hiç oynamaz).
            Html7a = binary:replace(Html6, <<"<body class=\"">>, <<"<body class=\"chisfis-home ">>),
            Html7 = binary:replace(Html7a, <<"<body">>, <<"<body data-nexus-demo-home=\"true\"">>),
            Html8 = binary:replace(Html7, <<"</head>">>, <<"<link rel=\"stylesheet\" href=\"https://use.hugeicons.com/font/icons.css\"><link rel=\"stylesheet\" href=\"/static/chisfis-bridge.css?v=20260926-places1\"><script defer src=\"/static/hugeicons-normalizer.js?v=20260924-hgi1\"></script></head>">>),
            Html9 = binary:replace(Html8, <<"</body>">>, <<"<script src=\"/static/header-popovers.js?v=20260926-benefits1\"></script></body>">>),
            normalize_storefront_search(storefront_hero(optimize_home_images(rewrite_links(Html9))));
        {error, _Reason} ->
            <<"<!doctype html><html><body><h1>NEXUS Agency</h1></body></html>">>
    end.

%% The exported demo starts with four guests and sample September dates, while
%% the storefront search starts with two adults and no selected dates.
normalize_storefront_search(Html) ->
    Replacements = [
        {<<"name=\"guests\" value=\"4\"">>, <<"name=\"guests\" value=\"2\"">>},
        {<<"<span>1</span><input type=\"hidden\" value=\"1\" name=\"guestChildren\"">>, <<"<span>0</span><input type=\"hidden\" value=\"0\" name=\"guestChildren\"">>},
        {<<"<span>1</span><input type=\"hidden\" value=\"1\" name=\"guestInfants\"">>, <<"<span>0</span><input type=\"hidden\" value=\"0\" name=\"guestInfants\"">>},
        {<<"4 misafir"/utf8>>, <<"2 misafir"/utf8>>},
        {<<"16 Eyl - 19 Eyl"/utf8>>, <<"Tarih ekleyin"/utf8>>}
    ],
    lists:foldl(fun({From, To}, Acc) -> binary:replace(Acc, From, To, [global]) end, Html, Replacements).

%% Render the final category controls in the first response. The browser only
%% attaches the "more" menu behaviour; it no longer has to replace demo tabs.
storefront_hero(Html) ->
    Tabs = [{<<"Otel"/utf8>>, <<"/otel">>, <<"hgi-building-03">>},
            {<<"Villa"/utf8>>, <<"/tatil-evi">>, <<"hgi-home-01">>},
            {<<"Yat"/utf8>>, <<"/yat">>, <<"hgi-anchor-point">>},
            {<<"Tur"/utf8>>, <<"/tur">>, <<"hgi-adventure">>},
            {<<"Aktivite"/utf8>>, <<"/aktivite">>, <<"hgi-hot-air-balloon">>},
            {<<"Uçuş"/utf8>>, <<"/ucus">>, <<"hgi-airplane-01">>},
            {<<"Araç"/utf8>>, <<"/arac">>, <<"hgi-car-01">>},
            {<<"Devamı"/utf8>>, <<"/otobus">>, <<"hgi-menu-01">>}],
    Links = erlang:iolist_to_binary([hero_tab(Label, Url, Icon, Index) ||
        {{Label, Url, Icon}, Index} <- lists:zip(Tabs, lists:seq(1, length(Tabs)))]),
    Pattern = <<"(<div[^>]*role=\"tablist\"[^>]*>).*?(</div></div><form)">>,
    case re:run(Html, Pattern, [dotall, {capture, [1, 2], binary}]) of
        {match, [Opening, Closing]} ->
            Replacement = <<Opening/binary, Links/binary, Closing/binary>>,
            translate_home(re:replace(Html, Pattern, Replacement, [dotall, {return, binary}]));
        nomatch -> translate_home(Html)
    end.

%% Keep the first HTML paint in the storefront's default Turkish language.
%% The table is generated from the same dictionaries used by the browser.
translate_home(Html) ->
    case file:read_file("priv/static/home-ssr-tr.tsv") of
        {ok, Data} ->
            Translated = lists:foldl(fun(Line, Acc) ->
                case binary:split(Line, <<"\t">>) of
                    [Encoded_source, Encoded_target] when Encoded_target =/= <<>> ->
                        Source = base64:decode(Encoded_source),
                        Target = base64:decode(Encoded_target),
                        Text = binary:replace(Acc, <<">", Source/binary, "<">>,
                            <<">", Target/binary, "<">>, [global]),
                        Spaced = binary:replace(Text, <<"> ", Source/binary, "<">>,
                            <<"> ", Target/binary, "<">>, [global]),
                        Escaped_source = binary:replace(Source, <<"&">>, <<"&amp;">>, [global]),
                        Escaped = binary:replace(Spaced, <<">", Escaped_source/binary, "<">>,
                            <<">", Target/binary, "<">>, [global]),
                        binary:replace(Escaped, <<"placeholder=\"", Source/binary, "\"">>,
                            <<"placeholder=\"", Target/binary, "\"">>, [global]);
                    _ -> Acc
                end
            end, Html, binary:split(Data, <<"\n">>, [global])),
            translate_home_dynamic(Translated);
        {error, _} -> Html
    end.

translate_home_dynamic(Html) ->
    Months = [{<<"January">>, <<"Ocak"/utf8>>}, {<<"February">>, <<"Şubat"/utf8>>},
        {<<"March">>, <<"Mart"/utf8>>}, {<<"April">>, <<"Nisan"/utf8>>},
        {<<"May">>, <<"Mayıs"/utf8>>}, {<<"June">>, <<"Haziran"/utf8>>},
        {<<"July">>, <<"Temmuz"/utf8>>}, {<<"August">>, <<"Ağustos"/utf8>>},
        {<<"September">>, <<"Eylül"/utf8>>}, {<<"October">>, <<"Ekim"/utf8>>},
        {<<"November">>, <<"Kasım"/utf8>>}, {<<"December">>, <<"Aralık"/utf8>>}],
    Days = [{<<"Sunday">>, <<"Pazar"/utf8>>}, {<<"Monday">>, <<"Pazartesi"/utf8>>},
        {<<"Tuesday">>, <<"Salı"/utf8>>}, {<<"Wednesday">>, <<"Çarşamba"/utf8>>},
        {<<"Thursday">>, <<"Perşembe"/utf8>>}, {<<"Friday">>, <<"Cuma"/utf8>>},
        {<<"Saturday">>, <<"Cumartesi"/utf8>>}],
    Date_html = lists:foldl(fun({English, Turkish}, Acc) ->
        re:replace(Acc, <<">", English/binary, " ([0-9]{4})<">>,
            <<">", Turkish/binary, " \\1<">>, [global, {return, binary}])
    end, Html, Months),
    Week_html = lists:foldl(fun({English, Turkish}, Acc) ->
        binary:replace(Acc, <<">", English/binary, "<">>,
            <<">", Turkish/binary, "<">>, [global])
    end, Date_html, Days),
    Patterns = [{<<"([0-9,]+)\\+ properties">>, <<"\\1+ ilan"/utf8>>},
        {<<"([0-9]+) Guests">>, <<"\\1 misafir"/utf8>>},
        {<<"([0-9]+) minutes drive">>, <<"\\1 dakika sürüş"/utf8>>}],
    Dynamic_html = lists:foldl(fun({Pattern, Replacement}, Acc) ->
        re:replace(Acc, Pattern, Replacement, [global, {return, binary}])
    end, Week_html, Patterns),
    Types = [{<<"Entire cabin · "/utf8>>, <<"Tüm kır evi · "/utf8>>},
        {<<"Holiday home · "/utf8>>, <<"Tatil evi · "/utf8>>},
        {<<"Home stay · "/utf8>>, <<"Ev konaklaması · "/utf8>>},
        {<<"Hotel room · "/utf8>>, <<"Otel odası · "/utf8>>}],
    Type_html = lists:foldl(fun({English, Turkish}, Acc) ->
        binary:replace(Acc, English, Turkish, [global])
    end, Dynamic_html, Types),
    Night_html = binary:replace(Type_html, <<">night<">>, <<">gece<"/utf8>>, [global]),
    binary:replace(Night_html, <<" beds<">>, <<" yatak<"/utf8>>, [global]).

hero_tab(Label, Url, Icon, Index) ->
    Selected = case Index of 1 -> <<"true\" data-selected=\"\"">>; _ -> <<"false\"">> end,
    More = case Index of 8 -> <<" hero-more-tab">>; _ -> <<>> end,
    <<"<a class=\"group/tab flex shrink-0 cursor-pointer items-center text-sm font-medium", More/binary,
      "\" role=\"tab\" aria-selected=\"", Selected/binary, " href=\"", Url/binary,
      "\" aria-label=\"", Label/binary, "\"><i class=\"hgi-stroke ", Icon/binary,
      "\" aria-hidden=\"true\"></i>", Label/binary, "</a>">>.

rewrite_links(Html0) ->
    Replacements = [
        {<<"index.html">>, <<"/">>},
        {<<"stay-categories.html">>, <<"/urunler">>},
        {<<"flight-categories.html">>, <<"/ucus">>},
        {<<"experiences.html">>, <<"/tur">>},
        {<<"car.html">>, <<"/arac">>},
        {<<"flights.html">>, <<"/ucus">>},
        {<<"real-estate.html">>, <<"/tatil-evi">>},
        {<<"listing.html">>, <<"/urunler">>},
        {<<"account.html">>, <<"/account">>},
        {<<"authors.html">>, <<"/urunler">>}
    ],
    lists:foldl(
        fun({From, To}, Html) -> binary:replace(Html, From, To, [global]) end,
        Html0,
        Replacements
    ).

%% Only the landing page uses these smaller variants. Other pages retain the
%% original photos, while the browser decodes fewer pixels during home scroll.
optimize_home_images(Html0) ->
    case file:read_file("priv/static/chisfis/images/home-optimized.txt") of
        {ok, Manifest} ->
            lists:foldl(fun(Line, Html) ->
                case binary:split(Line, <<"|">>) of
                    [Original, Variant] when Original =/= <<>>, Variant =/= <<>> ->
                        Prefix = <<"/static/chisfis/images/">>,
                        binary:replace(Html, <<Prefix/binary, Original/binary>>,
                            <<Prefix/binary, Variant/binary>>, [global]);
                    _ -> Html
                end
            end, Html0, binary:split(Manifest, <<"\n">>, [global]));
        {error, _} -> Html0
    end.
