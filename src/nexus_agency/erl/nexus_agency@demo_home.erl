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
            Html8 = binary:replace(Html7, <<"</head>">>, <<"<link rel=\"stylesheet\" href=\"https://use.hugeicons.com/font/icons.css\"><link rel=\"stylesheet\" href=\"/static/chisfis-bridge.css?v=20260921-languages1\"></head>">>),
            Html9 = binary:replace(Html8, <<"</body>">>, <<"<script src=\"/static/header-popovers.js?v=20260921-languages1\"></script></body>">>),
            rewrite_links(Html9);
        {error, _Reason} ->
            <<"<!doctype html><html><body><h1>NEXUS Agency</h1></body></html>">>
    end.

rewrite_links(Html0) ->
    Replacements = [
        {<<"index.html">>, <<"/">>},
        {<<"stay-categories.html">>, <<"/urunler">>},
        {<<"flight-categories.html">>, <<"/urunler?kategori=flight">>},
        {<<"experiences.html">>, <<"/urunler?kategori=tour">>},
        {<<"car.html">>, <<"/arac">>},
        {<<"flights.html">>, <<"/urunler?kategori=flight">>},
        {<<"real-estate.html">>, <<"/urunler?kategori=holiday_home">>},
        {<<"listing.html">>, <<"/urunler">>},
        {<<"account.html">>, <<"/account">>},
        {<<"authors.html">>, <<"/urunler">>}
    ],
    lists:foldl(
        fun({From, To}, Html) -> binary:replace(Html, From, To, [global]) end,
        Html0,
        Replacements
    ).
