-module(nexus_agency@router_impl).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([require_session/3, require_session_api/3, handle/3]).
-export_type([catalog_listing_item/0, ai_pool_key/0]).

-type catalog_listing_item() :: {catalog_listing_item, binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()}.

-type ai_pool_key() :: {ai_pool_key, binary(), nexus_agency@ai_client:a_i_config()}.

-file("src\\nexus_agency\\router.gleam", 28).
-spec require_session(pog:connection(), {ok, binary()} | {error, nil}, fun((nexus_agency@auth:session()) -> gleam@http@response:response(wisp:body()))) -> gleam@http@response:response(wisp:body()).
-doc(~" Panel rotaları için oturum middleware'i: geçerli `agency_session` çerezi
 yoksa istek /login'e yönlendirilir, varsa gövde `session` ile çalışır.").
require_session(Db, Token, Body) ->
    case Token of
        {ok, Value} ->
            case nexus_agency@auth:session(Db, Value) of
                {ok, Session} ->
                    case erlang:element(5, Session) of
                        ~"customer" ->
                            _pipe = wisp:response(403),
                            wisp:string_body(_pipe, ~"Müşteri hesabı için vitrin ve rezervasyon akışını kullanın.");

                        _ ->
                            Body(Session)
                    end;

                {error, _} ->
                    wisp:redirect(~"/login")
            end;

        {error, _} ->
            wisp:redirect(~"/login")
    end.

-file("src\\nexus_agency\\router.gleam", 54).
-spec require_session_api(pog:connection(), {ok, binary()} | {error, nil}, fun((nexus_agency@auth:session()) -> gleam@http@response:response(wisp:body()))) -> gleam@http@response:response(wisp:body()).
-doc(~" API rotaları için oturum middleware'i: yönlendirme yerine 401 döner.").
require_session_api(Db, Token, Body) ->
    case Token of
        {ok, Value} ->
            case nexus_agency@auth:session(Db, Value) of
                {ok, Session} ->
                    case erlang:element(5, Session) of
                        ~"customer" ->
                            _pipe = wisp:response(403),
                            wisp:json_body(_pipe, ~"{\"error\":\"Bu işlem müşteri hesabına açık değil.\"}");

                        _ ->
                            Body(Session)
                    end;

                {error, _} ->
                    wisp:response(401)
            end;

        {error, _} ->
            wisp:response(401)
    end.

-file("src\\nexus_agency\\router.gleam", 77).
-spec require_admin(pog:connection(), {ok, binary()} | {error, nil}, fun((nexus_agency@auth:session()) -> gleam@http@response:response(wisp:body()))) -> gleam@http@response:response(wisp:body()).
require_admin(Db, Token, Body) ->
    require_session(Db, Token, fun(Session) ->
        case erlang:element(5, Session) of
            ~"admin" ->
                Body(Session);

            _ ->
                _pipe = wisp:response(403),
                wisp:string_body(_pipe, ~"Yönetici yetkisi gerekli.")
        end
    end).

-file("src\\nexus_agency\\router.gleam", 93).
-spec require_catalog_write(pog:connection(), {ok, binary()} | {error, nil}, fun((nexus_agency@auth:session()) -> gleam@http@response:response(wisp:body()))) -> gleam@http@response:response(wisp:body()).
-doc(~" Catalog write access is available to administrators, staff and suppliers.
 Suppliers are restricted to listings owned by their user in the SQL below;
 staff and administrators retain tenant-wide operational access.").
require_catalog_write(Db, Token, Body) ->
    require_session(Db, Token, fun(Session) ->
        case erlang:element(5, Session) of
            ~"admin" ->
                Body(Session);

            ~"staff" ->
                Body(Session);

            ~"supplier" ->
                Body(Session);

            _ ->
                _pipe = wisp:response(403),
                wisp:string_body(_pipe, ~"Katalog yazma yetkiniz yok.")
        end
    end).

-file("src\\nexus_agency\\router.gleam", 106).
-spec require_campaign_access(pog:connection(), {ok, binary()} | {error, nil}, fun((nexus_agency@auth:session()) -> gleam@http@response:response(wisp:body()))) -> gleam@http@response:response(wisp:body()).
require_campaign_access(Db, Token, Body) ->
    require_session(Db, Token, fun(Session) ->
        case erlang:element(5, Session) of
            ~"admin" ->
                Body(Session);

            ~"supplier" ->
                Body(Session);

            _ ->
                _pipe = wisp:response(403),
                wisp:string_body(_pipe, ~"Kampanya yönetimi yetkiniz yok.")
        end
    end).

-file("src\\nexus_agency\\router.gleam", 124).
-spec require_panel_session(pog:connection(), {ok, binary()} | {error, nil}, binary(), fun((nexus_agency@auth:session()) -> gleam@http@response:response(wisp:body()))) -> gleam@http@response:response(wisp:body()).
require_panel_session(Db, Token, Section, Body) ->
    require_session(Db, Token, fun(Session) ->
        Allowed = case erlang:element(5, Session) of
            ~"admin" ->
                true;

            ~"staff" ->
                (((((((((Section =:= ~"catalog") orelse (Section =:= ~"listings")) orelse (Section =:= ~"media")) orelse (Section =:= ~"reservations")) orelse (Section =:= ~"customers")) orelse (Section =:= ~"offers")) orelse (Section =:= ~"inquiries")) orelse (Section =:= ~"reports")) orelse (Section =:= ~"search-analytics")) orelse (Section =:= ~"abandoned-carts");

            ~"supplier" ->
                (((Section =:= ~"catalog") orelse (Section =:= ~"listings")) orelse (Section =:= ~"media")) orelse (Section =:= ~"supplier-campaigns");

            ~"sub_agency" ->
                (((Section =:= ~"reservations") orelse (Section =:= ~"customers")) orelse (Section =:= ~"offers")) orelse (Section =:= ~"inquiries");

            _ ->
                false
        end,
        case Allowed of
            true ->
                Body(Session);

            false ->
                _pipe = wisp:response(403),
                wisp:string_body(_pipe, ~"Bu panele erişim yetkiniz yok.")
        end
    end).

-file("src\\nexus_agency\\router.gleam", 227).
-spec security_headers(gleam@http@response:response(wisp:body())) -> gleam@http@response:response(wisp:body()).
security_headers(Response) ->
    _pipe = Response,
    _pipe@1 = fun gleam@http@response:set_header/3(_pipe, ~"x-content-type-options", ~"nosniff"),
    _pipe@2 = fun gleam@http@response:set_header/3(_pipe@1, ~"x-frame-options", ~"SAMEORIGIN"),
    _pipe@3 = fun gleam@http@response:set_header/3(_pipe@2, ~"referrer-policy", ~"strict-origin-when-cross-origin"),
    fun gleam@http@response:set_header/3(_pipe@3, ~"permissions-policy", ~"camera=(), microphone=(), geolocation=()").

-file("src\\nexus_agency\\router.gleam", 5732).
-spec public_guests_script() -> lustre@vdom@vnode:element(any()).
%% Misafir sayacı (yetişkin/çocuk/bebek stepper'ı). Aynı bileşen iki yüzeyde:
%% ana sayfanın hero arama formu (chisfis export maketi, `main.js` §4 bağlar)
%% ve buradaki rezervasyon paneli (`.chisfis-guest-range`, bu script bağlar).
%% Header popover'ındaki kopya kaldırıldı — sayaç tek davranış sözleşmesi taşır.
public_guests_script() ->
    lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-guests.js?v=20260921-hero1"), lustre@attribute:attribute(~"defer", ~"defer")], []).

-file("src\\nexus_agency\\router.gleam", 5743).
-spec public_header_popovers_script() -> lustre@vdom@vnode:element(any()).
public_header_popovers_script() ->
    lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/header-popovers.js?v=20260921-links2"), lustre@attribute:attribute(~"defer", ~"defer")], []).

-file("src\\nexus_agency\\router.gleam", 5721).
-spec public_theme_script() -> lustre@vdom@vnode:element(any()).
public_theme_script() ->
    lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-theme.js"), lustre@attribute:attribute(~"defer", ~"defer")], []).

-file("src\\nexus_agency\\router.gleam", 5710).
-spec public_chat_script() -> lustre@vdom@vnode:element(any()).
public_chat_script() ->
    lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-chat.js"), lustre@attribute:attribute(~"defer", ~"defer")], []).

-file("src\\nexus_agency\\router.gleam", 5575).
-spec public_mobile_bottom_bar() -> lustre@vdom@vnode:element(any()).
-doc(~" Şablonun demo alt barı — main.js §18 içeriğini
 Anasayfa · Ara · [sepet] · Hesap · Menü ile değiştirir.").
public_mobile_bottom_bar() ->
    lustre@element:element(~"div", [lustre@attribute:class(~"fixed inset-x-0 bottom-0 z-30 flex items-center gap-6 bg-white/90 px-2.5 py-4 shadow ring-1 shadow-slate-200/80 ring-slate-900/5 backdrop-blur-sm transition-transform lg:hidden dark:bg-neutral-950/90")], [lustre@element:element(~"div", [lustre@attribute:class(~"mx-auto flex w-full max-w-lg justify-around text-center")], [])]).

-file("src\\nexus_agency\\router.gleam", 4263).
-spec public_tenant_query(binary()) -> binary().
public_tenant_query(Tenant_id) ->
    case Tenant_id of
        ~"" ->
            ~"";

        Value ->
            <<"?tenant="/utf8, Value/binary>>
    end.

-file("src\\nexus_agency\\router.gleam", 5553).
-spec public_footer(binary()) -> lustre@vdom@vnode:element(any()).
public_footer(Tenant_id) ->
    Q = public_tenant_query(Tenant_id),
    lustre@element:element(~"div", [], [nexus_agency@chisfis_layout:chisfis_footer(Q), lustre@element:element(~"div", [lustre@attribute:class(~"mobile-favorites")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-favorites.js"), lustre@attribute:attribute(~"defer", ~"defer")], []), nexus_agency@chisfis_layout:chisfis_mobile_bottom_nav()]).

-file("src\\nexus_agency\\router.gleam", 4250).
-spec safe_public_href(binary()) -> binary().
safe_public_href(Value) ->
    Href = gleam@string:trim(Value),
    case ((gleam_stdlib:string_starts_with(Href, ~"/") andalso not gleam_stdlib:string_starts_with(Href, ~"//")) orelse gleam_stdlib:string_starts_with(Href, ~"https://")) orelse gleam_stdlib:string_starts_with(Href, ~"http://") of
        true ->
            Href;

        false ->
            ~"#"
    end.

-file("src\\nexus_agency\\router.gleam", 4110).
-spec cms_block_content_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
cms_block_content_decoder() ->
    gleam@dynamic@decode:optional_field(~"title", ~"", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
        gleam@dynamic@decode:optional_field(~"body", ~"", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Body) ->
            gleam@dynamic@decode:optional_field(~"text", ~"", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Text) ->
                gleam@dynamic@decode:optional_field(~"button_text", ~"", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Button_text) ->
                    gleam@dynamic@decode:optional_field(~"button_url", ~"", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Button_url) ->
                        gleam@dynamic@decode:success({Title, Body, Text, Button_text, Button_url})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 4119).
-spec cms_block_copy(binary(), binary()) -> {binary(), binary(), binary(), binary()}.
cms_block_copy(Content, Fallback) ->
    case gleam@json:parse(Content, cms_block_content_decoder()) of
        {ok, {Title, Body, Text, Button_text, Button_url}} ->
            Resolved_title = case Title of
                ~"" ->
                    Fallback;

                Value ->
                    Value
            end,
            Resolved_body = case Body of
                ~"" ->
                    Text;

                Value@1 ->
                    Value@1
            end,
            {Resolved_title, Resolved_body, Button_text, Button_url};

        {error, _} ->
            {Fallback, ~"", ~"", ~""}
    end.

-file("src\\nexus_agency\\router.gleam", 4211).
-spec public_cms_block({binary(), integer(), binary()}) -> lustre@vdom@vnode:element(any()).
public_cms_block(Row) ->
    {Block_type, _, Raw_content} = Row,
    Fallback = case Block_type of
        ~"hero" ->
            ~"Seyahatinizi keşfedin";

        ~"featured_listings" ->
            ~"Öne çıkan deneyimler";

        ~"category_grid" ->
            ~"Kategorilere göre keşfedin";

        ~"trust_strip" ->
            ~"Güvenle planlayın";

        ~"newsletter" ->
            ~"Yeni fırsatlardan haberdar olun";

        _ ->
            ~"Seyahat ilhamı"
    end,
    {Title, Body, Button_text, Button_url} = cms_block_copy(Raw_content, Fallback),
    Body_node = case Body of
        ~"" ->
            lustre@element:element(~"span", [], []);

        Value ->
            lustre@element:element(~"p", [lustre@attribute:class(~"builder-module-body")], [lustre@element:text(Value)])
    end,
    Action = case (Button_text /= ~"") andalso (Button_url /= ~"") of
        true ->
            lustre@element:element(~"a", [lustre@attribute:class(~"secondary"), lustre@attribute:href(safe_public_href(Button_url))], [lustre@element:text(Button_text)]);

        false ->
            lustre@element:element(~"span", [], [])
    end,
    lustre@element:element(~"article", [lustre@attribute:class(<<"builder-module builder-"/utf8, Block_type/binary>>)], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"NEXUS İÇERİK")]), lustre@element:element(~"h2", [], [lustre@element:text(Title)]), Body_node, Action]).

-file("src\\nexus_agency\\router.gleam", 3864).
-spec page_block_decoder() -> gleam@dynamic@decode:decoder({binary(), integer(), binary()}).
page_block_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Block_type) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_int/1}, fun(Sort_order) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Content) ->
                gleam@dynamic@decode:success({Block_type, Sort_order, Content})
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 4199).
-spec public_cms_blocks(pog:connection(), binary(), binary()) -> list(lustre@vdom@vnode:element(any())).
public_cms_blocks(Db, Slug, Tenant_id) ->
    _pipe = ~"select b.block_type,b.sort_order,b.content::text from agency.page_blocks b join agency.pages p on p.id=b.page_id where p.tenant_id=$1::uuid and p.slug=$2 and p.status='published' order by b.sort_order",
    _pipe@1 = pog:'query'(_pipe),
    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
    _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Slug)),
    _pipe@4 = pog:returning(_pipe@3, page_block_decoder()),
    _pipe@5 = pog:execute(_pipe@4, Db),
    _pipe@6 = gleam@result:map(_pipe@5, fun(Rows) ->
        erlang:element(3, Rows)
    end),
    _pipe@7 = gleam@result:unwrap(_pipe@6, []),
    gleam@list:map(_pipe@7, fun public_cms_block/1).

-file("src\\nexus_agency\\router.gleam", 4422).
-spec public_home_header(binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_home_header(Origin, Tenant_id) ->
    Q = public_tenant_query(Tenant_id),
    %% The reference Chisfis home has one category strip inside the hero
    %% search. Keeping a second strip directly below the header shifts the
    %% hero down and makes the search controls appear duplicated.
    nexus_agency@chisfis_layout:chisfis_header(Origin, Q).

-file("src\\nexus_agency\\router.gleam", 4430).
-spec public_storefront_header(binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_storefront_header(Origin, Tenant_id) ->
    public_home_header(Origin, Tenant_id).

-spec public_catalog_script() -> lustre@vdom@vnode:element(any()).
%% Category landing/detail polish is shared by every public storefront page.
%% Keeping it in the common head also covers the legacy category aliases
%% (/konaklama-kategoriler, /deneyimler, /arac and /ucus).
public_catalog_script() ->
    lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-catalog.js?v=20260921-detail4"), lustre@attribute:attribute(~"defer", ~"defer")], []).

-file("src\\nexus_agency\\router.gleam", 5598).
-spec chisfis_head() -> list(lustre@vdom@vnode:element(any())).
chisfis_head() ->
    [lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"preload"), lustre@attribute:attribute(~"as", ~"font"), lustre@attribute:attribute(~"type", ~"font/woff2"), lustre@attribute:attribute(~"crossorigin", ~"crossorigin"), lustre@attribute:href(~"/static/chisfis/fonts/pxiByp8kv8JHgFVrLCz7Z11lFc-K.woff2")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"/static/chisfis/css/fonts.css")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"https://use.hugeicons.com/font/icons.css")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"/static/chisfis/css/base.css")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"/static/chisfis/css/theme.css"), lustre@attribute:attribute(~"media", ~"print"), lustre@attribute:attribute(~"onload", ~"this.media='all'")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"/static/chisfis/css/custom.css?v=20260920-langtoast2"), lustre@attribute:attribute(~"media", ~"print"), lustre@attribute:attribute(~"onload", ~"this.media='all'")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"/static/chisfis/css/sahra.css"), lustre@attribute:attribute(~"media", ~"only x"), lustre@attribute:attribute(~"onload", ~"if(document.documentElement.classList.contains('sahra'))this.media='all'")], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"stylesheet"), lustre@attribute:href(~"/static/chisfis-bridge.css?v=20260921-shared1")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/theme-boot.js")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/reveal-boot.js?v=20260920-rv1")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/chisfis/js/main.js?v=20260921-modalclose1"), lustre@attribute:attribute(~"defer", ~"defer")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/login-theme.js"), lustre@attribute:attribute(~"defer", ~"defer")], []), public_catalog_script()].

-file("src\\nexus_agency\\router.gleam", 4767).
-spec csrf_token_for(gleam@http@request:request(wisp@internal:connection())) -> binary().
csrf_token_for(Req) ->
    case wisp:get_cookie(Req, ~"agency_csrf", plain_text) of
        {ok, Value} when Value =/= ~"" ->
            Value;

        _ ->
            wisp:random_string(32)
    end.

-file("src\\nexus_agency\\router.gleam", 4190).
-spec public_cms_page_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
public_cms_page_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Slug) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Template) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Seo_title) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Seo_description) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Seo_keywords) ->
                        gleam@dynamic@decode:success({Slug, Template, Seo_title, Seo_description, Seo_keywords})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 4725).
-spec public_tenant_selector_from_host(gleam@http@request:request(wisp@internal:connection())) -> binary().
public_tenant_selector_from_host(Req) ->
    case gleam@list:key_find(erlang:element(3, Req), ~"host") of
        {ok, Host} ->
            _pipe = Host,
            _pipe@1 = gleam@string:split(_pipe, ~":"),
            _pipe@2 = gleam@list:first(_pipe@1),
            gleam@result:unwrap(_pipe@2, ~"");

        {error, _} ->
            ~""
    end.

-file("src\\nexus_agency\\router.gleam", 4714).
-spec public_tenant_selector_without_query(gleam@http@request:request(wisp@internal:connection())) -> binary().
public_tenant_selector_without_query(Req) ->
    case gleam@list:key_find(wisp:get_query(Req), ~"tenant_slug") of
        {ok, Value} ->
            case gleam@string:trim(Value) of
                ~"" ->
                    public_tenant_selector_from_host(Req);

                Trimmed ->
                    Trimmed
            end;

        {error, _} ->
            public_tenant_selector_from_host(Req)
    end.

-file("src\\nexus_agency\\router.gleam", 4702).
-spec public_tenant_selector(gleam@http@request:request(wisp@internal:connection())) -> binary().
public_tenant_selector(Req) ->
    Query = wisp:get_query(Req),
    case gleam@list:key_find(Query, ~"tenant") of
        {ok, Value} ->
            case gleam@string:trim(Value) of
                ~"" ->
                    public_tenant_selector_without_query(Req);

                Trimmed ->
                    Trimmed
            end;

        _ ->
            public_tenant_selector_without_query(Req)
    end.

-file("src\\nexus_agency\\router.gleam", 4743).
-spec public_tenant_id_from_selector(pog:connection(), binary()) -> {ok, binary()} | {error, nil}.
public_tenant_id_from_selector(Db, Selector) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Tenant_id) ->
            gleam@dynamic@decode:success(Tenant_id)
        end)
    end,
    case begin
        _pipe = ~"select coalesce((select id::text from agency.tenants where (lower(slug)=lower($1) or id::text=$1) limit 1),(select t.id::text from agency.tenants t where lower(t.slug)='nexus-demo' and exists(select 1 from agency.listings l where l.tenant_id=t.id and l.status='published') limit 1),(select t.id::text from agency.tenants t where exists(select 1 from agency.listings l where l.tenant_id=t.id and l.status='published') order by t.created_at limit 1),(select id::text from agency.tenants order by created_at limit 1),'')",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Selector)),
        _pipe@3 = pog:returning(_pipe@2, Decoder),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {ok, Value} when Value =/= ~"" ->
                    {ok, Value};

                _ ->
                    {error, nil}
            end;

        {error, _} ->
            {error, nil}
    end.

-file("src\\nexus_agency\\router.gleam", 4736).
-spec public_tenant_id(pog:connection(), gleam@http@request:request(wisp@internal:connection())) -> {ok, binary()} | {error, nil}.
public_tenant_id(Db, Req) ->
    public_tenant_id_from_selector(Db, public_tenant_selector(Req)).

-file("src\\nexus_agency\\router.gleam", 4277).
-spec public_cms_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary(), binary()) -> gleam@http@response:response(wisp:body()).
public_cms_page(Req, Db, Origin, Slug) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Result = begin
        _pipe@1 = ~"select slug,template,coalesce(seo->>'title',''),coalesce(seo->>'description',''),coalesce(seo->>'keywords','') from agency.pages where tenant_id=$1::uuid and slug=$2 and status='published' limit 1",
        _pipe@2 = pog:'query'(_pipe@1),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Tenant_id)),
        _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Slug)),
        _pipe@5 = pog:returning(_pipe@4, public_cms_page_decoder()),
        pog:execute(_pipe@5, Db)
    end,
    case Result of
        {error, _} ->
            _pipe@6 = wisp:response(404),
            wisp:string_body(_pipe@6, ~"Sayfa bulunamadı");

        {ok, Rows} ->
            case gleam@list:first(erlang:element(3, Rows)) of
                {error, _} ->
                    _pipe@7 = wisp:response(404),
                    wisp:string_body(_pipe@7, ~"Sayfa bulunamadı");

                {ok, {Page_slug, Template, Seo_title, Seo_description, Seo_keywords}} ->
                    Resolved_title = case Seo_title of
                        ~"" ->
                            <<Page_slug/binary, " | NEXUS Agency"/utf8>>;

                        Value ->
                            Value
                    end,
                    Resolved_description = case Seo_description of
                        ~"" ->
                            ~"NEXUS Agency ile seyahat seçeneklerini keşfedin ve güvenli rezervasyon yapın.";

                        Value@1 ->
                            Value@1
                    end,
                    Csrf_token = csrf_token_for(Req),
                    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"description"), lustre@attribute:attribute(~"content", Resolved_description)], []), lustre@element:element(~"meta", [lustre@attribute:name(~"keywords"), lustre@attribute:attribute(~"content", Seo_keywords)], []), lustre@element:element(~"meta", [lustre@attribute:attribute(~"property", ~"og:title"), lustre@attribute:attribute(~"content", Resolved_title)], []), lustre@element:element(~"meta", [lustre@attribute:attribute(~"property", ~"og:description"), lustre@attribute:attribute(~"content", Resolved_description)], []), lustre@element:element(~"meta", [lustre@attribute:attribute(~"property", ~"og:type"), lustre@attribute:attribute(~"content", case Template of
                        ~"blog" ->
                            ~"article";

                        _ ->
                            ~"website"
                    end)], []), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"canonical"), lustre@attribute:href(<<<<Origin/binary, "/"/utf8>>/binary, Page_slug/binary>>)], []), lustre@element:element(~"title", [], [lustre@element:text(Resolved_title)]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"cms-public-page")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(case Template of
                        ~"blog" ->
                            ~"GEZİ REHBERİ";

                        _ ->
                            ~"NEXUS İÇERİK"
                    end)]), lustre@element:element(~"h1", [], [lustre@element:text(Resolved_title)]), lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(Resolved_description)]), lustre@element:element(~"section", [lustre@attribute:class(~"published-builder-modules")], public_cms_blocks(Db, Page_slug, Tenant_id))]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
                    _pipe@8 = wisp:ok(),
                    _pipe@9 = wisp:set_cookie(_pipe@8, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
                    wisp:html_body(_pipe@9, lustre@element:to_string(Content))
            end
    end.

-file("src\\nexus_agency\\router.gleam", 9478).
-spec public_flights_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_flights_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Uçuş Bilgileri | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page flights-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"flights-container")], [lustre@element:element(~"h1", [], [lustre@element:text(~"Uçuş Bilgileri")]), lustre@element:element(~"p", [], [lustre@element:text(~"Uçuş bilgileri sayfası geliştirme aşamasındadır.")])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 9437).
-spec public_car_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_car_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Araç Kiralama | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page car-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"car-container")], [lustre@element:element(~"h1", [], [lustre@element:text(~"Araç Kiralama")]), lustre@element:element(~"p", [], [lustre@element:text(~"Araç kiralama sayfası geliştirme aşamasındadır.")])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 9396).
-spec public_authors_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_authors_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Yazarlar | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page authors-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"authors-container")], [lustre@element:element(~"h1", [], [lustre@element:text(~"Yazarlar")]), lustre@element:element(~"p", [], [lustre@element:text(~"Yazarlar sayfası geliştirme aşamasındadır.")])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 9351).
-spec public_real_estate_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_real_estate_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Emlak | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page real-estate-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"real-estate-container")], [lustre@element:element(~"h1", [], [lustre@element:text(~"Emlak")]), lustre@element:element(~"p", [], [lustre@element:text(~"Emlak sayfası geliştirme aşamasındadır.")])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 9306).
-spec public_experiences_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_experiences_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Deneyimler | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page experiences-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"experiences-container")], [lustre@element:element(~"h1", [], [lustre@element:text(~"Deneyimler")]), lustre@element:element(~"p", [], [lustre@element:text(~"Deneyimler sayfası geliştirme aşamasındadır.")])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 9257).
-spec public_stay_categories_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_stay_categories_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Konaklama Kategorileri | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page stay-categories-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"categories-container")], [lustre@element:element(~"h1", [], [lustre@element:text(~"Konaklama Kategorileri")]), lustre@element:element(~"p", [], [lustre@element:text(~"Konaklama kategorileri sayfası geliştirme aşamasındadır.")])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 9021).
-spec public_account_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_account_page(Req, Db, Origin) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Hesabım | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page account-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"container py-16 lg:py-28 space-y-16")], [lustre@element:element(~"div", [lustre@attribute:class(~"max-w-4xl mx-auto text-center")], [lustre@element:element(~"h1", [lustre@attribute:class(~"text-4xl md:text-5xl font-bold")], [lustre@element:text(~"Hesap Yönetimi")]), lustre@element:element(~"p", [lustre@attribute:class(~"text-neutral-500 mt-4 text-lg dark:text-neutral-400")], [lustre@element:text(~"Rezervasyonlarınızı, favori listenizi ve hesap ayarlarınızı yönetin.")])]), lustre@element:element(~"div", [lustre@attribute:class(~"max-w-6xl mx-auto")], [lustre@element:element(~"div", [lustre@attribute:class(~"grid lg:grid-cols-3 gap-8")], [lustre@element:element(~"div", [lustre@attribute:class(~"space-y-6")], [lustre@element:element(~"div", [lustre@attribute:class(~"bg-white dark:bg-neutral-900 rounded-2xl p-6 border border-neutral-200 dark:border-neutral-700")], [lustre@element:element(~"h3", [lustre@attribute:class(~"text-lg font-semibold mb-4")], [lustre@element:text(~"Hesap Menüsü")]), lustre@element:element(~"nav", [lustre@attribute:class(~"space-y-2")], [lustre@element:element(~"a", [lustre@attribute:class(~"flex items-center px-3 py-2 rounded-lg bg-primary-50 text-primary-600 dark:bg-primary-500/10"), lustre@attribute:href(~"#profil")], [lustre@element:text(~"👤 Profil Bilgileri")]), lustre@element:element(~"a", [lustre@attribute:class(~"flex items-center px-3 py-2 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800"), lustre@attribute:href(~"#rezervasyonlar")], [lustre@element:text(~"🏨 Rezervasyonlarım")]), lustre@element:element(~"a", [lustre@attribute:class(~"flex items-center px-3 py-2 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800"), lustre@attribute:href(~"#favoriler")], [lustre@element:text(~"❤️ Favori Listem")]), lustre@element:element(~"a", [lustre@attribute:class(~"flex items-center px-3 py-2 rounded-lg hover:bg-neutral-100 dark:hover:bg-neutral-800"), lustre@attribute:href(~"#ayarlar")], [lustre@element:text(~"⚙️ Hesap Ayarları")])])])]), lustre@element:element(~"div", [lustre@attribute:class(~"lg:col-span-2 space-y-6")], [lustre@element:element(~"div", [lustre@attribute:class(~"bg-white dark:bg-neutral-900 rounded-2xl p-6 border border-neutral-200 dark:border-neutral-700")], [lustre@element:element(~"h2", [lustre@attribute:class(~"text-xl font-semibold mb-6")], [lustre@element:text(~"Profil Bilgileri")]), lustre@element:element(~"div", [lustre@attribute:class(~"flex items-center gap-4 mb-6")], [lustre@element:element(~"div", [lustre@attribute:class(~"w-20 h-20 bg-primary-100 rounded-full flex items-center justify-center text-primary-600 text-2xl")], [lustre@element:text(~"👤")]), lustre@element:element(~"div", [], [lustre@element:element(~"h3", [lustre@attribute:class(~"font-medium text-lg")], [lustre@element:text(~"Kullanıcı Adı")]), lustre@element:element(~"p", [lustre@attribute:class(~"text-neutral-500")], [lustre@element:text(~"user@example.com")])])]), lustre@element:element(~"div", [lustre@attribute:class(~"grid md:grid-cols-2 gap-4")], [lustre@element:element(~"div", [], [lustre@element:element(~"label", [lustre@attribute:class(~"block text-sm font-medium mb-2")], [lustre@element:text(~"Ad Soyad")]), lustre@element:element(~"input", [lustre@attribute:type_(~"text"), lustre@attribute:class(~"w-full px-4 py-2 border border-neutral-200 rounded-lg dark:border-neutral-700 dark:bg-neutral-800"), lustre@attribute:value(~"John Doe")], [])]), lustre@element:element(~"div", [], [lustre@element:element(~"label", [lustre@attribute:class(~"block text-sm font-medium mb-2")], [lustre@element:text(~"Telefon")]), lustre@element:element(~"input", [lustre@attribute:type_(~"tel"), lustre@attribute:class(~"w-full px-4 py-2 border border-neutral-200 rounded-lg dark:border-neutral-700 dark:bg-neutral-800"), lustre@attribute:value(~"+90 555 123 4567")], [])])])]), lustre@element:element(~"div", [lustre@attribute:class(~"bg-white dark:bg-neutral-900 rounded-2xl p-6 border border-neutral-200 dark:border-neutral-700")], [lustre@element:element(~"h2", [lustre@attribute:class(~"text-xl font-semibold mb-6")], [lustre@element:text(~"Son Rezervasyonlar")]), lustre@element:element(~"div", [lustre@attribute:class(~"text-center py-12 text-neutral-500")], [lustre@element:element(~"p", [], [lustre@element:text(~"Henüz rezervasyonunuz bulunmuyor.")]), lustre@element:element(~"a", [lustre@attribute:class(~"inline-block mt-4 px-6 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700"), lustre@attribute:href(~"/urunler")], [lustre@element:text(~"Konaklama Ara")])])])])])])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    wisp:html_body(_pipe@1, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 3387).
-spec query_error_message(pog:query_error()) -> binary().
query_error_message(Error) ->
    case Error of
        {constraint_violated, Message, Constraint, Detail} ->
            <<<<<<<<Message/binary, " "/utf8>>/binary, Constraint/binary>>/binary, " "/utf8>>/binary, Detail/binary>>;

        {postgresql_error, Code, Name, Message@1} ->
            <<<<<<<<Code/binary, " "/utf8>>/binary, Name/binary>>/binary, " "/utf8>>/binary, Message@1/binary>>;

        {unexpected_argument_count, Expected, Got} ->
            <<<<<<"argument count "/utf8, (erlang:integer_to_binary(Expected))/binary>>/binary, "/"/utf8>>/binary, (erlang:integer_to_binary(Got))/binary>>;

        {unexpected_argument_type, Expected@1, Got@1} ->
            <<<<<<"argument type "/utf8, Expected@1/binary>>/binary, "/"/utf8>>/binary, Got@1/binary>>;

        {unexpected_result_type, _} ->
            ~"unexpected result type";

        query_timeout ->
            ~"query timeout";

        connection_unavailable ->
            ~"connection unavailable"
    end.

-file("src\\nexus_agency\\router.gleam", 7209).
-spec iso_date_key(binary()) -> integer().
iso_date_key(Value) ->
    case gleam@string:split(Value, ~"-") of
        [Year, Month, Day] ->
            _pipe = gleam_stdlib:parse_int(<<<<Year/binary, Month/binary>>/binary, Day/binary>>),
            gleam@result:unwrap(_pipe, 0);

        _ ->
            0
    end.

-file("src\\nexus_agency\\router.gleam", 7254).
-spec is_leap_year(integer()) -> boolean().
is_leap_year(Year) ->
    ((Year rem 400) =:= 0) orelse (((Year rem 4) =:= 0) andalso ((Year rem 100) /= 0)).

-file("src\\nexus_agency\\router.gleam", 7242).
-spec days_in_month(integer(), integer()) -> integer().
days_in_month(Year, Month) ->
    case Month of
        2 ->
            case is_leap_year(Year) of
                true ->
                    29;

                false ->
                    28
            end;

        4 ->
            30;

        6 ->
            30;

        9 ->
            30;

        11 ->
            30;

        _ ->
            31
    end.

-file("src\\nexus_agency\\router.gleam", 7216).
-spec iso_date_valid(binary()) -> boolean().
iso_date_valid(Value) ->
    case gleam@string:split(Value, ~"-") of
        [Year_text, Month_text, Day_text] ->
            case gleam_stdlib:parse_int(Year_text) of
                {error, _} ->
                    false;

                {ok, Year} ->
                    case gleam_stdlib:parse_int(Month_text) of
                        {error, _} ->
                            false;

                        {ok, Month} ->
                            case gleam_stdlib:parse_int(Day_text) of
                                {error, _} ->
                                    false;

                                {ok, Day} ->
                                    ((((((string:length(Value) =:= 10) andalso (Year >= 1900)) andalso (Year =< 2200)) andalso (Month >= 1)) andalso (Month =< 12)) andalso (Day >= 1)) andalso (Day =< days_in_month(Year, Month))
                            end
                    end
            end;

        _ ->
            false
    end.

-file("src\\nexus_agency\\router.gleam", 7190).
-spec phone_format_valid(binary()) -> boolean().
phone_format_valid(Value) ->
    Trimmed = gleam@string:trim(Value),
    (Trimmed =:= ~"") orelse (((string:length(Trimmed) >= 7) andalso (string:length(Trimmed) =< 60)) andalso gleam@list:all(gleam@string:to_graphemes(Trimmed), fun(Grapheme) ->
        case Grapheme of
            ~"+" ->
                true;

            ~" " ->
                true;

            ~"-" ->
                true;

            ~"(" ->
                true;

            ~")" ->
                true;

            _ ->
                case gleam_stdlib:parse_int(Grapheme) of
                    {ok, _} ->
                        true;

                    {error, _} ->
                        false
                end
        end
    end)).

-file("src\\nexus_agency\\router.gleam", 3380).
-spec form_value(list({binary(), binary()}), binary()) -> binary().
form_value(Values, Key) ->
    case gleam@list:key_find(Values, Key) of
        {ok, Value} ->
            Value;

        {error, _} ->
            ~""
    end.

-file("src\\nexus_agency\\router.gleam", 4065).
-spec form_int(list({binary(), binary()}), binary()) -> integer().
form_int(Values, Key) ->
    case gleam_stdlib:parse_int(form_value(Values, Key)) of
        {ok, Value} ->
            Value;

        {error, _} ->
            0
    end.

-file("src\\nexus_agency\\router.gleam", 8677).
-spec public_inquiry(gleam@http@request:request(wisp@internal:connection()), pog:connection()) -> gleam@http@response:response(wisp:body()).
public_inquiry(Req, Db) ->
    wisp:require_form(Req, fun(Form) ->
        Name = form_value(erlang:element(2, Form), ~"name"),
        Email = form_value(erlang:element(2, Form), ~"email"),
        Listing_id = form_value(erlang:element(2, Form), ~"listing_id"),
        Phone = form_value(erlang:element(2, Form), ~"phone"),
        Message = form_value(erlang:element(2, Form), ~"message"),
        Idempotency_key = form_value(erlang:element(2, Form), ~"idempotency_key"),
        Tenant_selector = gleam@string:trim(form_value(erlang:element(2, Form), ~"tenant")),
        Csrf_form = form_value(erlang:element(2, Form), ~"csrf_token"),
        Csrf_valid = case wisp:get_cookie(Req, ~"agency_csrf", plain_text) of
            {ok, Value} ->
                (Value /= ~"") andalso (Value =:= Csrf_form);

            {error, _} ->
                false
        end,
        Check_in = form_value(erlang:element(2, Form), ~"check_in"),
        Check_out = form_value(erlang:element(2, Form), ~"check_out"),
        Guests = form_int(erlang:element(2, Form), ~"guest_count"),
        Website = form_value(erlang:element(2, Form), ~"website"),
        Requested_tenant = case Tenant_selector of
            ~"" ->
                _pipe = public_tenant_id(Db, Req),
                gleam@result:unwrap(_pipe, ~"");

            Value@1 ->
                _pipe@1 = public_tenant_id_from_selector(Db, Value@1),
                gleam@result:unwrap(_pipe@1, ~"")
        end,
        Email_valid = (gleam_stdlib:contains_string(Email, ~"@") andalso (string:length(Email) =< 320)) andalso (string:length(Email) >= 5),
        Phone_valid = phone_format_valid(Phone) andalso (Phone /= ~""),
        Contact_valid = Email_valid orelse Phone_valid,
        Fields_valid = ((string:length(Name) =< 160) andalso (string:length(Phone) =< 60)) andalso (string:length(Message) =< 5000),
        Invalid_dates = ((Check_in /= ~"") andalso (Check_out /= ~"")) andalso ((not iso_date_valid(Check_in) orelse not iso_date_valid(Check_out)) orelse (iso_date_key(Check_out) =< iso_date_key(Check_in))),
        case not Csrf_valid of
            true ->
                _pipe@2 = wisp:response(403),
                wisp:string_body(_pipe@2, ~"Güvenlik doğrulaması başarısız.");

            false ->
                case (((((Name =:= ~"") orelse not Contact_valid) orelse not Fields_valid) orelse (Website /= ~"")) orelse (Guests < 1)) orelse Invalid_dates of
                    true ->
                        _pipe@3 = wisp:response(400),
                        wisp:string_body(_pipe@3, ~"Ad ve e-posta veya telefon alanlarını kontrol edin");

                    false ->
                        Result = begin
                            _pipe@4 = pog:'query'(~"insert into agency.public_inquiries(tenant_id, listing_id, full_name, email, phone, message, check_in, check_out, guest_count, idempotency_key)
               select $10::uuid,
                      case when $1 ~ '^[0-9a-fA-F-]{36}$' and exists(select 1 from agency.listings l where l.id=$1::uuid and l.tenant_id=$10::uuid) then nullif($1,'')::uuid end,
                      $2, lower(trim($3)), $4, $5, nullif($6,'')::date, nullif($7,'')::date, $8, nullif($9,'')
               on conflict (idempotency_key) where idempotency_key is not null do nothing"),
                            _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(Listing_id)),
                            _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Name)),
                            _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Email)),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Phone)),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Message)),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Check_in)),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(Check_out)),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Guests)),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(Idempotency_key)),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(Requested_tenant)),
                            pog:execute(_pipe@14, Db)
                        end,
                        case Result of
                            {ok, _} ->
                                _pipe@15 = pog:'query'(~"insert into agency.notifications(tenant_id, channel, template, payload)
                  select $5::uuid,
                         'email', 'new_public_inquiry', jsonb_build_object('email',$2,'phone',$4,'name',$3,'listing_id',nullif($1,''))"),
                                _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(Listing_id)),
                                _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(Email)),
                                _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(Name)),
                                _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(Phone)),
                                _pipe@20 = pog:parameter(_pipe@19, pog_ffi:coerce(Requested_tenant)),
                                _pipe@21 = pog:execute(_pipe@20, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@21),
                                Wants_json = case gleam@list:key_find(erlang:element(3, Req), ~"accept") of
                                    {ok, Value@2} ->
                                        gleam_stdlib:contains_string(Value@2, ~"application/json");

                                    {error, _} ->
                                        false
                                end,
                                case Wants_json of
                                    true ->
                                        _pipe@22 = wisp:ok(),
                                        _pipe@23 = fun gleam@http@response:set_header/3(_pipe@22, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:json_body(_pipe@23, ~"{\"ok\":true,\"message\":\"Talebiniz alındı.\"}");

                                    false ->
                                        wisp:redirect(~"/iletisim?sent=1")
                                end;

                            {error, Error} ->
                                gleam_stdlib:println(<<"Public inquiry insert failed: "/utf8, (query_error_message(Error))/binary>>),
                                case Error of
                                    {postgresql_error, _, _, Message@1} ->
                                        case gleam_stdlib:contains_string(Message@1, ~"rate limit") of
                                            true ->
                                                _pipe@24 = wisp:response(429),
                                                wisp:string_body(_pipe@24, ~"Çok fazla teklif gönderildi. Lütfen daha sonra tekrar deneyin.");

                                            false ->
                                                _pipe@25 = wisp:response(503),
                                                wisp:string_body(_pipe@25, ~"Talep şu anda kaydedilemedi")
                                        end;

                                    _ ->
                                        _pipe@26 = wisp:response(503),
                                        wisp:string_body(_pipe@26, ~"Talep şu anda kaydedilemedi")
                                end
                        end
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 8814).
-spec public_contact_page(gleam@http@request:request(wisp@internal:connection()), binary()) -> gleam@http@response:response(wisp:body()).
public_contact_page(Req, Origin) ->
    Csrf_token = csrf_token_for(Req),
    Tenant_selector = public_tenant_selector(Req),
    Listing_id = case begin
        _pipe = wisp:get_query(Req),
        gleam@list:key_find(_pipe, ~"listing")
    end of
        {ok, Value} ->
            Value;

        {error, _} ->
            ~""
    end,
    Sent = case begin
        _pipe@1 = wisp:get_query(Req),
        gleam@list:key_find(_pipe@1, ~"sent")
    end of
        {ok, Value@1} ->
            Value@1 =:= ~"1";

        {error, _} ->
            false
    end,
    Payment = begin
        _pipe@2 = wisp:get_query(Req),
        _pipe@3 = gleam@list:key_find(_pipe@2, ~"payment"),
        gleam@result:unwrap(_pipe@3, ~"")
    end,
    Notice = case Payment of
        ~"paid" ->
            lustre@element:element(~"p", [lustre@attribute:class(~"success"), lustre@attribute:attribute(~"role", ~"status")], [lustre@element:text(~"Ödemeniz alındı ve rezervasyonunuz onaylandı.")]);

        ~"processing" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"status")], [lustre@element:text(~"Ödeme sonucu henüz kesinleşmedi veya oturumun süresi doldu. Yeniden ödeme yapmadan önce destek ekibimizle iletişime geçin.")]);

        ~"expired_or_processing" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"status")], [lustre@element:text(~"Ödeme sonucu henüz kesinleşmedi veya oturumun süresi doldu. Yeniden ödeme yapmadan önce destek ekibimizle iletişime geçin.")]);

        ~"failed" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"alert")], [lustre@element:text(~"Ödeme tamamlanamadı. Rezervasyonunuzun durumunu öğrenmek için destek ekibimizle iletişime geçin.")]);

        ~"expired" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"alert")], [lustre@element:text(~"Ödeme tamamlanamadı. Rezervasyonunuzun durumunu öğrenmek için destek ekibimizle iletişime geçin.")]);

        ~"missing" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"alert")], [lustre@element:text(~"Ödeme tamamlanamadı. Rezervasyonunuzun durumunu öğrenmek için destek ekibimizle iletişime geçin.")]);

        ~"config" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"alert")], [lustre@element:text(~"Ödeme tamamlanamadı. Rezervasyonunuzun durumunu öğrenmek için destek ekibimizle iletişime geçin.")]);

        ~"verification_failed" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"alert")], [lustre@element:text(~"Ödeme tamamlanamadı. Rezervasyonunuzun durumunu öğrenmek için destek ekibimizle iletişime geçin.")]);

        ~"invalid_callback" ->
            lustre@element:element(~"p", [lustre@attribute:attribute(~"role", ~"alert")], [lustre@element:text(~"Ödeme tamamlanamadı. Rezervasyonunuzun durumunu öğrenmek için destek ekibimizle iletişime geçin.")]);

        _ ->
            case Sent of
                true ->
                    lustre@element:element(~"p", [lustre@attribute:class(~"success")], [lustre@element:text(~"Talebiniz alındı. Seyahat danışmanımız en kısa sürede size ulaşacak.")]);

                false ->
                    lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(~"Tarih ve müsaitlik bilgisi için bize ulaşın.")])
            end
    end,
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"title", [], [lustre@element:text(~"Teklif İste | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page"), lustre@attribute:attribute(~"data-tenant", Tenant_selector)], [public_storefront_header(Origin, Tenant_selector), lustre@element:element(~"main", [lustre@attribute:class(~"contact-page")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"TEKLİF TALEBİ")]), lustre@element:element(~"h1", [], [lustre@element:text(~"Seyahatinizi birlikte planlayalım")]), Notice, lustre@element:element(~"form", [lustre@attribute:attribute(~"method", ~"post"), lustre@attribute:attribute(~"action", ~"/iletisim"), lustre@attribute:class(~"inquiry-form")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"listing_id"), lustre@attribute:value(Listing_id)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"tenant"), lustre@attribute:value(Tenant_selector)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"idempotency_key"), lustre@attribute:value(wisp:random_string(32))], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"csrf_token"), lustre@attribute:value(Csrf_token)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"text"), lustre@attribute:name(~"website"), lustre@attribute:attribute(~"tabindex", ~"-1"), lustre@attribute:attribute(~"autocomplete", ~"off"), lustre@attribute:attribute(~"aria-hidden", ~"true"), lustre@attribute:class(~"hp-field")], []), lustre@element:element(~"label", [], [lustre@element:text(~"Ad soyad"), lustre@element:element(~"input", [lustre@attribute:name(~"name"), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"E-posta"), lustre@element:element(~"input", [lustre@attribute:name(~"email"), lustre@attribute:type_(~"email"), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Telefon"), lustre@element:element(~"input", [lustre@attribute:name(~"phone"), lustre@attribute:type_(~"tel")], [])]), lustre@element:element(~"div", [lustre@attribute:class(~"form-grid-2")], [lustre@element:element(~"label", [], [lustre@element:text(~"Giriş tarihi"), lustre@element:element(~"input", [lustre@attribute:name(~"check_in"), lustre@attribute:type_(~"date")], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Çıkış tarihi"), lustre@element:element(~"input", [lustre@attribute:name(~"check_out"), lustre@attribute:type_(~"date")], [])])]), lustre@element:element(~"label", [], [lustre@element:text(~"Misafir sayısı"), lustre@element:element(~"input", [lustre@attribute:name(~"guest_count"), lustre@attribute:type_(~"number"), lustre@attribute:attribute(~"min", ~"1"), lustre@attribute:attribute(~"value", ~"1")], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Notunuz"), lustre@element:element(~"textarea", [lustre@attribute:name(~"message"), lustre@attribute:attribute(~"rows", ~"5")], [])]), lustre@element:element(~"button", [lustre@attribute:type_(~"submit"), lustre@attribute:class(~"primary")], [lustre@element:text(~"Teklif iste")])]), public_footer(Tenant_selector), public_chat_script(), public_theme_script(), public_header_popovers_script()])])]),
    _pipe@4 = wisp:ok(),
    _pipe@5 = wisp:set_cookie(_pipe@4, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
    wisp:html_body(_pipe@5, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 8413).
-spec save_chat_message(pog:connection(), binary(), binary(), binary(), binary()) -> nil.
save_chat_message(Db, Conversation_id, Sender_name, Body, Direction) ->
    case Conversation_id =:= ~"" of
        true ->
            nil;

        false ->
            _pipe = ~"insert into agency.messages(conversation_id,sender_name,body,direction) values($1::uuid,$2,$3,$4)",
            _pipe@1 = pog:'query'(_pipe),
            _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Conversation_id)),
            _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Sender_name)),
            _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Body)),
            _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(Direction)),
            _pipe@6 = pog:execute(_pipe@5, Db),
            fun(_) ->
                nil
            end(_pipe@6)
    end.

-file("src\\nexus_agency\\router.gleam", 8510).
-spec public_chat_fallback(binary(), binary()) -> binary().
public_chat_fallback(Message, Context) ->
    Product_hint = case gleam@string:trim(Context) =:= ~"" of
        true ->
            ~"size uygun konaklama, ulaşım ve deneyimleri birlikte arayabiliriz";

        false ->
            ~"seçtiğiniz ilan veya bölge için tarih, kişi sayısı ve ulaşım tercihlerinizi netleştirebiliriz"
    end,
    <<<<<<"Memnuniyetle yardımcı olurum. "/utf8, Product_hint/binary>>/binary, ". Lütfen seyahat tarihinizi, kişi sayısını ve yaklaşık bütçenizi yazın; danışmanımız size uygun seçenekleri hazırlasın."/utf8>>/binary, (case gleam@string:trim(Message) =:= ~"" of
        true ->
            ~"";

        false ->
            ~" İletişim bilgilerinizi paylaşırsanız size özel takip de oluşturabiliriz."
    end)/binary>>.

-file("src\\nexus_agency\\router.gleam", 3418).
-spec get_tenant_ai_config(pog:connection(), binary()) -> nexus_agency@ai_client:a_i_config().
get_tenant_ai_config(Db, Tenant_id) ->
    Row = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(K) ->
            gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(V) ->
                gleam@dynamic@decode:success({K, V})
            end)
        end)
    end,
    Settings = case begin
        _pipe = ~"select key, trim(both '\"' from value::text) from agency.settings where tenant_id=$1::uuid and key in ('ai_provider', 'ai_api_key', 'ai_model')",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, Row),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Res} ->
            erlang:element(3, Res);

        {error, _} ->
            []
    end,
    Provider = case gleam@list:key_find(Settings, ~"ai_provider") of
        {ok, P} ->
            P;

        {error, _} ->
            ~"google"
    end,
    Api_key = case gleam@list:key_find(Settings, ~"ai_api_key") of
        {ok, K} ->
            K;

        {error, _} ->
            ~""
    end,
    Model = case gleam@list:key_find(Settings, ~"ai_model") of
        {ok, M} ->
            M;

        {error, _} ->
            nexus_agency@ai_client:default_model(Provider)
    end,
    {a_i_config, Provider, Api_key, Model}.

-file("src\\nexus_agency\\router.gleam", 3469).
-spec ai_pool_count_decoder() -> gleam@dynamic@decode:decoder(integer()).
ai_pool_count_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_int/1}, fun(Count) ->
        gleam@dynamic@decode:success(Count)
    end).

-file("src\\nexus_agency\\router.gleam", 3458).
-spec ai_pool_key_decoder() -> gleam@dynamic@decode:decoder(ai_pool_key()).
ai_pool_key_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Provider) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Api_key) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Model) ->
                    gleam@dynamic@decode:success({ai_pool_key, Id, {a_i_config, Provider, Api_key, Model}})
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3502).
-spec reset_ai_pool_usage(pog:connection(), binary()) -> nil.
reset_ai_pool_usage(Db, Tenant_id) ->
    _pipe = ~"UPDATE agency.ai_key_pool SET daily_used=0,usage_day=current_date,last_error='' WHERE tenant_id=$1::uuid AND usage_day<current_date",
    _pipe@1 = pog:'query'(_pipe),
    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
    _pipe@3 = pog:execute(_pipe@2, Db),
    fun(_) ->
        nil
    end(_pipe@3).

-file("src\\nexus_agency\\router.gleam", 3539).
-spec get_tenant_ai_pool(pog:connection(), binary()) -> list(ai_pool_key()).
get_tenant_ai_pool(Db, Tenant_id) ->
    reset_ai_pool_usage(Db, Tenant_id),
    Available_query = ~"select id::text,provider,api_key_encrypted,coalesce(nullif(model,''),case when provider='google' then 'gemini-2.5-flash' else 'deepseek-chat' end) from agency.ai_key_pool where tenant_id=$1::uuid and active and api_key_encrypted<>'' and (cooldown_until is null or cooldown_until<=now()) and (daily_limit=0 or daily_used<daily_limit) order by case when provider='google' then 0 else 1 end,priority,id",
    case begin
        _pipe = Available_query,
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, ai_pool_key_decoder()),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            case erlang:element(3, Result) of
                [] ->
                    Configured = begin
                        _pipe@4 = ~"select count(*)::int from agency.ai_key_pool where tenant_id=$1::uuid and api_key_encrypted<>''",
                        _pipe@5 = pog:'query'(_pipe@4),
                        _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Tenant_id)),
                        _pipe@7 = pog:returning(_pipe@6, ai_pool_count_decoder()),
                        pog:execute(_pipe@7, Db)
                    end,
                    Has_pool = case Configured of
                        {ok, Value} ->
                            case gleam@list:first(erlang:element(3, Value)) of
                                {ok, Count} ->
                                    Count > 0;

                                {error, _} ->
                                    false
                            end;

                        {error, _} ->
                            false
                    end,
                    case Has_pool of
                        true ->
                            [];

                        false ->
                            Legacy = get_tenant_ai_config(Db, Tenant_id),
                            case erlang:element(3, Legacy) =:= ~"" of
                                true ->
                                    [];

                                false ->
                                    [{ai_pool_key, ~"", Legacy}]
                            end
                    end;

                Rows ->
                    Rows
            end;

        {error, _} ->
            Legacy@1 = get_tenant_ai_config(Db, Tenant_id),
            case erlang:element(3, Legacy@1) =:= ~"" of
                true ->
                    [];

                false ->
                    [{ai_pool_key, ~"", Legacy@1}]
            end
    end.

-file("src\\nexus_agency\\router.gleam", 3593).
-spec ai_quota_error(binary()) -> boolean().
ai_quota_error(Error) ->
    Value = string:lowercase(Error),
    ((((gleam_stdlib:contains_string(Value, ~"quota") orelse gleam_stdlib:contains_string(Value, ~"429")) orelse gleam_stdlib:contains_string(Value, ~"rate")) orelse gleam_stdlib:contains_string(Value, ~"resource exhausted")) orelse gleam_stdlib:contains_string(Value, ~"too many requests")) orelse gleam_stdlib:contains_string(Value, ~"limit").

-file("src\\nexus_agency\\router.gleam", 3624).
-spec ai_pool_mark_failure(pog:connection(), binary(), binary(), binary()) -> nil.
ai_pool_mark_failure(Db, Tenant_id, Id, Error) ->
    case Id =:= ~"" of
        true ->
            nil;

        false ->
            _pipe = ~"UPDATE agency.ai_key_pool SET daily_used=case when usage_day<current_date then 1 else daily_used+1 end,usage_day=current_date,last_error=left($3,500),cooldown_until=case when $4::text='quota' then date_trunc('day',now())+interval '1 day' else now()+interval '10 minutes' end,updated_at=now() WHERE tenant_id=$1::uuid AND id=$2::uuid",
            _pipe@1 = pog:'query'(_pipe),
            _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
            _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Id)),
            _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Error)),
            _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(case ai_quota_error(Error) of
                true ->
                    ~"quota";

                false ->
                    ~"error"
            end)),
            _pipe@6 = pog:execute(_pipe@5, Db),
            fun(_) ->
                nil
            end(_pipe@6)
    end.

-file("src\\nexus_agency\\router.gleam", 3603).
-spec ai_pool_mark_success(pog:connection(), binary(), binary()) -> nil.
ai_pool_mark_success(Db, Tenant_id, Id) ->
    case Id =:= ~"" of
        true ->
            nil;

        false ->
            _pipe = ~"UPDATE agency.ai_key_pool SET daily_used=case when usage_day<current_date then 1 else daily_used+1 end,usage_day=current_date,last_error='',cooldown_until=NULL,updated_at=now() WHERE tenant_id=$1::uuid AND id=$2::uuid",
            _pipe@1 = pog:'query'(_pipe),
            _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
            _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Id)),
            _pipe@4 = pog:execute(_pipe@3, Db),
            fun(Result) ->
                case Result of
                    {ok, _} ->
                        nil;

                    {error, Error} ->
                        gleam_stdlib:println(<<"AI pool success update failed: "/utf8, (query_error_message(Error))/binary>>)
                end
            end(_pipe@4)
    end.

-file("src\\nexus_agency\\router.gleam", 3649).
-spec ai_pool_exhausted_error() -> binary().
ai_pool_exhausted_error() ->
    ~"AI anahtar havuzu tükendi. Gemini günlük kotalarını kontrol edin veya aktif bir DeepSeek yedek anahtarı ekleyin.".

-file("src\\nexus_agency\\router.gleam", 8467).
-spec chat_with_pool(pog:connection(), binary(), list(ai_pool_key()), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
chat_with_pool(Db, Tenant_id, Pool, Context, Message, Lang) ->
    case Pool of
        [] ->
            {error, ai_pool_exhausted_error()};

        [{ai_pool_key, Id, Cfg} | Rest] ->
            System = <<<<<<<<<<"Sen NEXUS Agency'nin profesyonel seyahat danışmanısın. "/utf8, "Müşterinin amacını, bütçesini, tarihini, kişi sayısını ve konumunu anlayarak kısa ve uygulanabilir seçenekler sun. "/utf8>>/binary, "Yalnızca verilen ilan ve bölge gerçeklerini kullan; fiyat, müsaitlik, mesafe veya politika uydurma. "/utf8>>/binary, "Eksik bilgi varsa en fazla üç net soru sor. Konaklama konuşuluyorsa ulaşım, transfer, araç ve aktivite seçeneklerini doğal biçimde hatırlat. "/utf8>>/binary, "Yanıtı sade metin olarak, Türkçe veya istenen dilde ver. Dil: "/utf8>>/binary, Lang/binary>>,
            User = <<<<<<"İlan/bölge bağlamı:\n"/utf8, Context/binary>>/binary, "\n\nMüşteri mesajı:\n"/utf8>>/binary, Message/binary>>,
            case nexus_agency@ai_client:call_llm(Cfg, System, User) of
                {ok, Value} ->
                    Clean = gleam@string:trim(Value),
                    case Clean =:= ~"" of
                        true ->
                            ai_pool_mark_failure(Db, Tenant_id, Id, ~"empty_ai_response"),
                            chat_with_pool(Db, Tenant_id, Rest, Context, Message, Lang);

                        false ->
                            ai_pool_mark_success(Db, Tenant_id, Id),
                            {ok, gleam@string:slice(Clean, 0, 4000)}
                    end;

                {error, Error} ->
                    ai_pool_mark_failure(Db, Tenant_id, Id, Error),
                    chat_with_pool(Db, Tenant_id, Rest, Context, Message, Lang)
            end
    end.

-file("src\\nexus_agency\\router.gleam", 8434).
-spec save_chat_lead(pog:connection(), binary(), binary(), binary(), binary(), binary(), binary(), binary()) -> nil.
save_chat_lead(Db, Tenant_id, Conversation_id, Listing_id, Name, Email, Phone, Message) ->
    case (Email =:= ~"") andalso (Phone =:= ~"") of
        true ->
            nil;

        false ->
            _pipe = ~"with customer as (insert into agency.customers(tenant_id,full_name,email,phone) values($1::uuid,$3,case when $4<>'' then lower($4) else 'chat-' || regexp_replace($5,'[^0-9]','','g') || '@invalid.local' end,$5) on conflict(tenant_id,email) do update set full_name=excluded.full_name,phone=case when excluded.phone='' then agency.customers.phone else excluded.phone end returning id), linked as (update agency.conversations set customer_id=(select id from customer),status='open' where id=$2::uuid returning id) insert into agency.public_inquiries(listing_id,full_name,email,phone,message,status,tenant_id,idempotency_key) select nullif($6,'')::uuid,$3,$4,$5,$7,'new',$1::uuid,'chat:' || $2 on conflict(idempotency_key) where idempotency_key is not null do update set full_name=excluded.full_name,email=excluded.email,phone=excluded.phone,message=excluded.message,listing_id=excluded.listing_id,status='new'",
            _pipe@1 = pog:'query'(_pipe),
            _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
            _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Conversation_id)),
            _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Name)),
            _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(Email)),
            _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Phone)),
            _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Listing_id)),
            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Message)),
            _pipe@9 = pog:execute(_pipe@8, Db),
            fun(Result) ->
                case Result of
                    {ok, _} ->
                        nil;

                    {error, Error} ->
                        gleam_stdlib:println(<<"Chat lead save failed: "/utf8, (query_error_message(Error))/binary>>)
                end
            end(_pipe@9)
    end.

-file("src\\nexus_agency\\router.gleam", 3479).
-spec single_string_decoder() -> gleam@dynamic@decode:decoder(binary()).
single_string_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
        gleam@dynamic@decode:success(Value)
    end).

-file("src\\nexus_agency\\router.gleam", 8373).
-spec create_chat_conversation(pog:connection(), binary(), binary()) -> binary().
create_chat_conversation(Db, Tenant_id, Subject) ->
    case begin
        _pipe = ~"insert into agency.conversations(tenant_id,subject,channel,status) values($1::uuid,$2,'web','open') returning id::text",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Subject)),
        _pipe@4 = pog:returning(_pipe@3, single_string_decoder()),
        pog:execute(_pipe@4, Db)
    end of
        {ok, Result} ->
            _pipe@5 = gleam@list:first(erlang:element(3, Result)),
            gleam@result:unwrap(_pipe@5, ~"");

        {error, _} ->
            ~""
    end.

-file("src\\nexus_agency\\router.gleam", 8391).
-spec chat_conversation_exists(pog:connection(), binary(), binary()) -> boolean().
chat_conversation_exists(Db, Tenant_id, Conversation_id) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_int/1}, fun(Count) ->
            gleam@dynamic@decode:success(Count > 0)
        end)
    end,
    case begin
        _pipe = ~"select count(*)::int from agency.conversations where id=$1::uuid and tenant_id=$2::uuid",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Conversation_id)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Tenant_id)),
        _pipe@4 = pog:returning(_pipe@3, Decoder),
        pog:execute(_pipe@4, Db)
    end of
        {ok, Result} ->
            _pipe@5 = gleam@list:first(erlang:element(3, Result)),
            gleam@result:unwrap(_pipe@5, false);

        {error, _} ->
            false
    end.

-file("src\\nexus_agency\\router.gleam", 7067).
-spec chat_context_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary()}).
chat_context_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Category) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Locality) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Description) ->
                    gleam@dynamic@decode:success({Title, Category, Locality, Description})
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 8526).
-spec public_chat(gleam@http@request:request(wisp@internal:connection()), pog:connection()) -> gleam@http@response:response(wisp:body()).
public_chat(Req, Db) ->
    wisp:require_form(Req, fun(Form) ->
        Name = gleam@string:trim(form_value(erlang:element(2, Form), ~"name")),
        Message = gleam@string:trim(form_value(erlang:element(2, Form), ~"message")),
        Email = gleam@string:trim(form_value(erlang:element(2, Form), ~"email")),
        Phone = gleam@string:trim(form_value(erlang:element(2, Form), ~"phone")),
        Listing_id = gleam@string:trim(form_value(erlang:element(2, Form), ~"listing_id")),
        Tenant_selector = gleam@string:trim(form_value(erlang:element(2, Form), ~"tenant")),
        Conversation_input = gleam@string:trim(form_value(erlang:element(2, Form), ~"conversation_id")),
        Lang = case nexus_agency@i18n:normalize_lang(form_value(erlang:element(2, Form), ~"lang")) of
            ~"tr" ->
                ~"tr";

            Value ->
                Value
        end,
        Csrf_form = form_value(erlang:element(2, Form), ~"csrf_token"),
        Csrf_valid = case wisp:get_cookie(Req, ~"agency_csrf", plain_text) of
            {ok, Value@1} ->
                (Value@1 /= ~"") andalso (Value@1 =:= Csrf_form);

            {error, _} ->
                false
        end,
        Email_valid = (Email =:= ~"") orelse (gleam_stdlib:contains_string(Email, ~"@") andalso (string:length(Email) =< 320)),
        Phone_valid = phone_format_valid(Phone),
        Contact_valid = Email_valid andalso Phone_valid,
        Listing_key = case string:length(Listing_id) =:= 36 of
            true ->
                Listing_id;

            false ->
                ~""
        end,
        Requested_tenant = case Tenant_selector of
            ~"" ->
                _pipe = public_tenant_id(Db, Req),
                gleam@result:unwrap(_pipe, ~"");

            Value@2 ->
                _pipe@1 = public_tenant_id_from_selector(Db, Value@2),
                gleam@result:unwrap(_pipe@1, ~"")
        end,
        case not Csrf_valid of
            true ->
                _pipe@2 = wisp:response(403),
                wisp:json_body(_pipe@2, ~"{\"ok\":false,\"error\":\"Güvenlik doğrulaması başarısız.\"}");

            false ->
                case (((((Name =:= ~"") orelse (string:length(Name) < 2)) orelse (string:length(Name) > 160)) orelse (Message =:= ~"")) orelse (string:length(Message) > 4000)) orelse not Contact_valid of
                    true ->
                        _pipe@3 = wisp:response(400),
                        wisp:json_body(_pipe@3, ~"{\"ok\":false,\"error\":\"Ad ve mesaj alanlarını kontrol edin.\"}");

                    false ->
                        Tenant_result = begin
                            _pipe@4 = ~"select coalesce((select tenant_id::text from agency.listings where id=NULLIF($1,'')::uuid and tenant_id=$2::uuid limit 1),$2)",
                            _pipe@5 = pog:'query'(_pipe@4),
                            _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Listing_key)),
                            _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Requested_tenant)),
                            _pipe@8 = pog:returning(_pipe@7, single_string_decoder()),
                            pog:execute(_pipe@8, Db)
                        end,
                        case Tenant_result of
                            {error, _} ->
                                _pipe@9 = wisp:response(503),
                                wisp:json_body(_pipe@9, ~"{\"ok\":false,\"error\":\"Sohbet servisi şu anda kullanılamıyor.\"}");

                            {ok, Rows} ->
                                Tenant_id = begin
                                    _pipe@10 = gleam@list:first(erlang:element(3, Rows)),
                                    gleam@result:unwrap(_pipe@10, ~"")
                                end,
                                Context_result = begin
                                    _pipe@11 = ~"select coalesce(title,''),coalesce(category,''),coalesce(locality,''),coalesce(description,'') from agency.listings where id=NULLIF($1,'')::uuid and tenant_id=$2::uuid limit 1",
                                    _pipe@12 = pog:'query'(_pipe@11),
                                    _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(Listing_key)),
                                    _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(Tenant_id)),
                                    _pipe@15 = pog:returning(_pipe@14, chat_context_decoder()),
                                    pog:execute(_pipe@15, Db)
                                end,
                                Context = case Context_result of
                                    {ok, Rows@1} ->
                                        case gleam@list:first(erlang:element(3, Rows@1)) of
                                            {ok, Row} ->
                                                <<<<<<<<<<<<<<"Başlık: "/utf8, (erlang:element(1, Row))/binary>>/binary, "\nKategori: "/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, "\nKonum: "/utf8>>/binary, (erlang:element(3, Row))/binary>>/binary, "\nAçıklama: "/utf8>>/binary, (gleam@string:slice(erlang:element(4, Row), 0, 1200))/binary>>;

                                            {error, _} ->
                                                ~""
                                        end;

                                    {error, _} ->
                                        ~""
                                end,
                                Conversation_id = case (string:length(Conversation_input) =:= 36) andalso chat_conversation_exists(Db, Tenant_id, Conversation_input) of
                                    true ->
                                        Conversation_input;

                                    false ->
                                        create_chat_conversation(Db, Tenant_id, ~"AI seyahat danışmanı")
                                end,
                                save_chat_lead(Db, Tenant_id, Conversation_id, Listing_key, Name, Email, Phone, Message),
                                save_chat_message(Db, Conversation_id, Name, Message, ~"inbound"),
                                Reply_result = chat_with_pool(Db, Tenant_id, get_tenant_ai_pool(Db, Tenant_id), Context, Message, Lang),
                                Reply = case Reply_result of
                                    {ok, Value@3} ->
                                        Value@3;

                                    {error, _} ->
                                        public_chat_fallback(Message, Context)
                                end,
                                save_chat_message(Db, Conversation_id, ~"NEXUS AI", Reply, ~"outbound"),
                                Response_body = begin
                                    _pipe@16 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"reply", gleam@json:string(Reply)}, {~"conversationId", gleam@json:string(Conversation_id)}, {~"ai", gleam@json:bool(gleam@result:is_ok(Reply_result))}, {~"needsContact", gleam@json:bool((Email =:= ~"") andalso (Phone =:= ~""))}]),
                                    gleam@json:to_string(_pipe@16)
                                end,
                                _pipe@17 = wisp:ok(),
                                wisp:json_body(_pipe@17, Response_body)
                        end
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 8205).
-spec payment_transition(pog:connection(), binary(), binary(), binary(), binary(), binary()) -> boolean().
payment_transition(Db, Session, Action, Guid, Receipt, Raw) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_bool/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end,
    case begin
        _pipe = ~"select agency.parampos_transition($1::uuid,$2,$3,$4,$5::text::jsonb)",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Session)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Action)),
        _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Guid)),
        _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(Receipt)),
        _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Raw)),
        _pipe@7 = pog:returning(_pipe@6, Decoder),
        pog:execute(_pipe@7, Db)
    end of
        {ok, Rows} ->
            _pipe@8 = gleam@list:first(erlang:element(3, Rows)),
            gleam@result:unwrap(_pipe@8, false);

        {error, _} ->
            false
    end.

-file("src\\nexus_agency\\router.gleam", 7119).
-spec parampos_config_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
parampos_config_decoder() ->
    gleam@dynamic@decode:field(~"client_code", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Client_code) ->
        gleam@dynamic@decode:field(~"username", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Username) ->
            gleam@dynamic@decode:field(~"password", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Password) ->
                gleam@dynamic@decode:field(~"guid", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Guid) ->
                    gleam@dynamic@decode:optional_field(~"endpoint", ~"", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Endpoint) ->
                        gleam@dynamic@decode:success({Client_code, Username, Password, Guid, Endpoint})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 7128).
-spec parampos_config(pog:connection(), binary()) -> {ok, nexus_agency@parampos:config()} | {error, binary()}.
parampos_config(Db, Tenant_id) ->
    Raw_decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end,
    case begin
        _pipe = ~"select credentials::text from agency.integrations where tenant_id=$1::uuid and provider='parampos' and kind='payment' and active limit 1",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, Raw_decoder),
        pog:execute(_pipe@3, Db)
    end of
        {error, _} ->
            {error, ~"parampos_config_query_failed"};

        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {error, _} ->
                    {error, ~"parampos_not_configured"};

                {ok, Raw} ->
                    case gleam@json:parse(Raw, parampos_config_decoder()) of
                        {error, _} ->
                            {error, ~"parampos_bad_config"};

                        {ok, {Client_code, Username, Password, Guid, Endpoint}} ->
                            Service_url = case gleam@string:trim(Endpoint) of
                                ~"" ->
                                    ~"https://testposws.param.com.tr/turkpos.ws/service_turkpos_prod.asmx";

                                Value ->
                                    Value
                            end,
                            case (((Client_code /= ~"") andalso (Username /= ~"")) andalso (Password /= ~"")) andalso (Guid /= ~"") of
                                true ->
                                    {ok, {config, Client_code, Username, Password, Guid, Service_url}};

                                false ->
                                    {error, ~"parampos_not_configured"}
                            end
                    end
            end
    end.

-file("src\\nexus_agency\\router.gleam", 8233).
-spec public_parampos_return(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_parampos_return(Req, Db, Origin) ->
    wisp:require_form(Req, fun(Form) ->
        Md = form_value(erlang:element(2, Form), ~"md"),
        Md_status = form_value(erlang:element(2, Form), ~"mdStatus"),
        Order_id = form_value(erlang:element(2, Form), ~"orderId"),
        Guid = form_value(erlang:element(2, Form), ~"islemGUID"),
        Hash = form_value(erlang:element(2, Form), ~"islemHash"),
        Redirect = fun(Status) ->
            wisp:redirect(<<<<Origin/binary, "/iletisim?payment="/utf8>>/binary, Status/binary>>)
        end,
        Decoder = begin
            gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
                gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Tenant) ->
                    gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                        gleam@dynamic@decode:success({Id, Tenant, Status})
                    end)
                end)
            end)
        end,
        case begin
            _pipe = ~"select id::text,tenant_id::text,status from agency.payment_sessions where order_id=$1::uuid and transaction_guid=$2 and transaction_guid<>''",
            _pipe@1 = pog:'query'(_pipe),
            _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Order_id)),
            _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Guid)),
            _pipe@4 = pog:returning(_pipe@3, Decoder),
            pog:execute(_pipe@4, Db)
        end of
            {error, _} ->
                Redirect(~"invalid_callback");

            {ok, Rows} ->
                case gleam@list:first(erlang:element(3, Rows)) of
                    {error, _} ->
                        Redirect(~"missing");

                    {ok, {Session, Tenant, Status}} ->
                        case parampos_config(Db, Tenant) of
                            {error, _} ->
                                Redirect(~"config");

                            {ok, Config} ->
                                case nexus_agency@parampos:verify_hash(Hash, nexus_agency@parampos:callback_hash(erlang:element(5, Config), Guid, Md, Md_status, Order_id)) of
                                    false ->
                                        Redirect(~"verification_failed");

                                    true ->
                                        case Status of
                                            ~"paid" ->
                                                Redirect(~"paid");

                                            ~"authorized" ->
                                                Redirect(~"processing");

                                            ~"starting" ->
                                                Redirect(~"processing");

                                            ~"failed" ->
                                                Redirect(~"failed");

                                            ~"expired" ->
                                                Redirect(~"expired");

                                            ~"cancelled" ->
                                                Redirect(~"expired");

                                            _ ->
                                                case nexus_agency@parampos:md_success(Md_status) andalso (Md /= ~"") of
                                                    false ->
                                                        case payment_transition(Db, Session, ~"failed_3d", ~"", ~"", ~"{}") of
                                                            true ->
                                                                Redirect(~"failed");

                                                            false ->
                                                                Redirect(~"processing")
                                                        end;

                                                    true ->
                                                        case payment_transition(Db, Session, ~"claim_pay", ~"", ~"", ~"{}") of
                                                            false ->
                                                                Redirect(~"expired_or_processing");

                                                            true ->
                                                                case nexus_agency@parampos:pay(Config, Md, Guid, Order_id) of
                                                                    {error, _} ->
                                                                        Redirect(~"processing");

                                                                    {ok, Payment} ->
                                                                        case nexus_agency@parampos:pay_success(Payment) of
                                                                            false ->
                                                                                _ = payment_transition(Db, Session, ~"failed_pay", ~"", ~"", ~"{}"),
                                                                                Redirect(~"failed");

                                                                            true ->
                                                                                Raw = begin
                                                                                    _pipe@5 = gleam@json:object([{~"receiptId", gleam@json:string(erlang:element(4, Payment))}, {~"bankCode", gleam@json:int(erlang:element(5, Payment))}]),
                                                                                    gleam@json:to_string(_pipe@5)
                                                                                end,
                                                                                case payment_transition(Db, Session, ~"paid", ~"", erlang:element(4, Payment), Raw) of
                                                                                    true ->
                                                                                        Redirect(~"paid");

                                                                                    false ->
                                                                                        Redirect(~"processing")
                                                                                end
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                end
                        end
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 7178).
-spec digits_between(binary(), integer(), integer()) -> boolean().
digits_between(Value, Minimum, Maximum) ->
    Size = string:length(Value),
    ((Size >= Minimum) andalso (Size =< Maximum)) andalso gleam@list:all(gleam@string:to_graphemes(Value), fun(Grapheme) ->
        case gleam_stdlib:parse_int(Grapheme) of
            {ok, _} ->
                true;

            {error, _} ->
                false
        end
    end).

-file("src\\nexus_agency\\router.gleam", 252).
-spec request_client_ip(gleam@http@request:request(wisp@internal:connection())) -> binary().
request_client_ip(Req) ->
    case gleam@list:key_find(erlang:element(3, Req), ~"x-real-ip") of
        {ok, Value} ->
            gleam@string:trim(Value);

        {error, _} ->
            case gleam@list:key_find(erlang:element(3, Req), ~"x-forwarded-for") of
                {ok, Value@1} ->
                    case gleam@string:split(Value@1, ~",") of
                        [First | _] ->
                            gleam@string:trim(First);

                        [] ->
                            ~"0.0.0.0"
                    end;

                {error, _} ->
                    ~"0.0.0.0"
            end
    end.

-file("src\\nexus_agency\\router.gleam", 7472).
-spec amount_minor_display(binary()) -> binary().
amount_minor_display(Amount_minor) ->
    Digits = case gleam_stdlib:parse_int(Amount_minor) of
        {ok, Value} ->
            erlang:integer_to_binary(Value);

        {error, _} ->
            ~"0"
    end,
    Size = string:length(Digits),
    case Size of
        0 ->
            ~"0.00";

        1 ->
            <<"0.0"/utf8, Digits/binary>>;

        2 ->
            <<"0."/utf8, Digits/binary>>;

        _ ->
            <<<<(gleam@string:slice(Digits, 0, Size - 2))/binary, "."/utf8>>/binary, (gleam@string:slice(Digits, Size - 2, 2))/binary>>
    end.

-file("src\\nexus_agency\\router.gleam", 7509).
-spec amount_try(binary()) -> binary().
amount_try(Amount_minor) ->
    amount_minor_display(Amount_minor).

-file("src\\nexus_agency\\router.gleam", 7102).
-spec parampos_session_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary()}).
parampos_session_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Tenant_id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Order_id) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Amount_minor) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Expires_at) ->
                            gleam@dynamic@decode:success({Tenant_id, Order_id, Amount_minor, Currency, Status, Expires_at})
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 7854).
-spec payment_session_data(pog:connection(), binary()) -> {ok, {binary(), binary(), binary(), binary(), binary(), binary()}} | {error, binary()}.
payment_session_data(Db, Session_id) ->
    case begin
        _pipe = ~"select ps.tenant_id::text,ps.order_id::text,ps.amount_minor::text,ps.currency,ps.status,ps.expires_at::text from agency.payment_sessions ps where ps.id=$1::uuid and ps.expires_at>now() and ps.status in ('created','initiated') limit 1",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Session_id)),
        _pipe@3 = pog:returning(_pipe@2, parampos_session_decoder()),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {ok, Row} ->
                    {ok, Row};

                {error, _} ->
                    {error, ~"payment_session_not_found"}
            end;

        {error, _} ->
            {error, ~"payment_session_query_failed"}
    end.

-file("src\\nexus_agency\\router.gleam", 8069).
-spec public_parampos_start(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_parampos_start(Req, Db, Origin) ->
    wisp:require_form(Req, fun(Form) ->
        Session_id = gleam@string:trim(form_value(erlang:element(2, Form), ~"session_id")),
        Csrf_form = form_value(erlang:element(2, Form), ~"csrf_token"),
        Csrf_valid = case wisp:get_cookie(Req, ~"agency_csrf", plain_text) of
            {ok, Value} ->
                (Value /= ~"") andalso (Value =:= Csrf_form);

            {error, _} ->
                false
        end,
        case not Csrf_valid of
            true ->
                _pipe = wisp:response(403),
                wisp:string_body(_pipe, ~"Güvenlik doğrulaması başarısız.");

            false ->
                case payment_session_data(Db, Session_id) of
                    {error, _} ->
                        _pipe@1 = wisp:response(404),
                        wisp:string_body(_pipe@1, ~"Ödeme oturumu bulunamadı veya süresi doldu.");

                    {ok, {Tenant_id, Order_id, Amount_minor, Currency, _, _}} ->
                        case {parampos_config(Db, Tenant_id), Currency /= ~"TRY"} of
                            {{ok, Config}, false} ->
                                Callback = <<Origin/binary, "/api/public/checkout/parampos/return"/utf8>>,
                                Input = {start_input, Order_id, form_value(erlang:element(2, Form), ~"cardOwner"), form_value(erlang:element(2, Form), ~"pan"), form_value(erlang:element(2, Form), ~"expiryMonth"), form_value(erlang:element(2, Form), ~"expiryYear"), form_value(erlang:element(2, Form), ~"cvv"), form_value(erlang:element(2, Form), ~"gsm"), gleam@string:replace(amount_try(Amount_minor), ~".", ~","), Callback, Callback, request_client_ip(Req)},
                                case ((((form_value(erlang:element(2, Form), ~"cardOwner") /= ~"") andalso digits_between(form_value(erlang:element(2, Form), ~"pan"), 15, 19)) andalso digits_between(form_value(erlang:element(2, Form), ~"cvv"), 3, 4)) andalso digits_between(form_value(erlang:element(2, Form), ~"expiryMonth"), 2, 2)) andalso digits_between(form_value(erlang:element(2, Form), ~"expiryYear"), 4, 4) of
                                    false ->
                                        _pipe@2 = wisp:response(400),
                                        wisp:string_body(_pipe@2, ~"Kart bilgileri geçersiz.");

                                    true ->
                                        case payment_transition(Db, Session_id, ~"claim_start", ~"", ~"", ~"{}") of
                                            false ->
                                                _pipe@3 = wisp:response(409),
                                                wisp:string_body(_pipe@3, ~"Ödeme zaten işleniyor veya oturum sona erdi.");

                                            true ->
                                                case nexus_agency@parampos:start(Config, Input) of
                                                    {error, _} ->
                                                        _pipe@4 = wisp:response(502),
                                                        wisp:string_body(_pipe@4, ~"ParamPOS bağlantısı kurulamadı.");

                                                    {ok, Start_result} ->
                                                        case ((erlang:element(2, Start_result) > 0) andalso (erlang:element(4, Start_result) /= ~"")) andalso (erlang:element(6, Start_result) /= ~"") of
                                                            false ->
                                                                _ = payment_transition(Db, Session_id, ~"failed_start", ~"", ~"", ~"{}"),
                                                                _pipe@5 = wisp:response(400),
                                                                wisp:string_body(_pipe@5, <<"3D Secure işlemi başlatılamadı: "/utf8, (erlang:element(3, Start_result))/binary>>);

                                                            true ->
                                                                case payment_transition(Db, Session_id, ~"initiated", erlang:element(6, Start_result), ~"", ~"{}") of
                                                                    false ->
                                                                        _pipe@6 = wisp:response(503),
                                                                        wisp:string_body(_pipe@6, ~"Ödeme kaydı tamamlanamadı; destek ile iletişime geçin.");

                                                                    true ->
                                                                        _pipe@7 = wisp:ok(),
                                                                        _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"text/html; charset=utf-8"),
                                                                        _pipe@9 = fun gleam@http@response:set_header/3(_pipe@8, ~"cache-control", ~"no-store"),
                                                                        wisp:html_body(_pipe@9, erlang:element(4, Start_result))
                                                                end
                                                        end
                                                end
                                        end
                                end;

                            {{ok, _}, true} ->
                                _pipe@10 = wisp:response(400),
                                wisp:string_body(_pipe@10, ~"ParamPOS yalnızca TRY tahsilatı destekler.");

                            {{error, _}, _} ->
                                _pipe@11 = wisp:response(503),
                                wisp:string_body(_pipe@11, ~"ParamPOS ödeme ayarı eksik.")
                        end
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 7874).
-spec public_parampos_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_parampos_page(Req, Db, Origin) ->
    Session_id = case begin
        _pipe = wisp:get_query(Req),
        gleam@list:key_find(_pipe, ~"session")
    end of
        {ok, Value} ->
            Value;

        {error, _} ->
            ~""
    end,
    Csrf_token = csrf_token_for(Req),
    case payment_session_data(Db, Session_id) of
        {error, _} ->
            _pipe@1 = wisp:response(404),
            wisp:string_body(_pipe@1, ~"Ödeme oturumu bulunamadı veya süresi doldu.");

        {ok, {_, _, Amount_minor, Currency, _, _}} ->
            case Currency /= ~"TRY" of
                true ->
                    _pipe@2 = wisp:response(400),
                    wisp:string_body(_pipe@2, ~"ParamPOS yalnızca TRY ile çalışır.");

                false ->
                    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"meta", [lustre@attribute:name(~"robots"), lustre@attribute:attribute(~"content", ~"noindex,nofollow")], []), lustre@element:element(~"title", [], [lustre@element:text(~"Güvenli ödeme | NEXUS Agency")])]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page")], [lustre@element:element(~"main", [lustre@attribute:class(~"booking-page")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"GÜVENLİ ÖDEME")]), lustre@element:element(~"h1", [], [lustre@element:text(~"Rezervasyonunuzu tamamlayın")]), lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(~"Kart bilgileriniz ParamPOS 3D Secure ekranında doğrulanır. Kart bilgileriniz bu sunucuda saklanmaz.")]), lustre@element:element(~"div", [lustre@attribute:class(~"booking-card")], [lustre@element:element(~"strong", [], [lustre@element:text(~"Ödenecek tutar: ₺ "), lustre@element:text(amount_minor_display(Amount_minor))]), lustre@element:element(~"form", [lustre@attribute:method(~"post"), lustre@attribute:action(~"/api/public/checkout/parampos/start"), lustre@attribute:class(~"parampos-card-form")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"session_id"), lustre@attribute:value(Session_id)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"csrf_token"), lustre@attribute:value(Csrf_token)], []), lustre@element:element(~"label", [], [lustre@element:text(~"Kart üzerindeki ad soyad"), lustre@element:element(~"input", [lustre@attribute:name(~"cardOwner"), lustre@attribute:autocomplete(~"cc-name"), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Kart numarası"), lustre@element:element(~"input", [lustre@attribute:name(~"pan"), lustre@attribute:inputmode(~"numeric"), lustre@attribute:autocomplete(~"cc-number"), lustre@attribute:required(true)], [])]), lustre@element:element(~"div", [lustre@attribute:class(~"form-grid-3")], [lustre@element:element(~"label", [], [lustre@element:text(~"Ay"), lustre@element:element(~"input", [lustre@attribute:name(~"expiryMonth"), lustre@attribute:inputmode(~"numeric"), lustre@attribute:placeholder(~"AA"), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Yıl"), lustre@element:element(~"input", [lustre@attribute:name(~"expiryYear"), lustre@attribute:inputmode(~"numeric"), lustre@attribute:placeholder(~"YYYY"), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"CVV"), lustre@element:element(~"input", [lustre@attribute:name(~"cvv"), lustre@attribute:inputmode(~"numeric"), lustre@attribute:autocomplete(~"cc-csc"), lustre@attribute:required(true)], [])])]), lustre@element:element(~"label", [], [lustre@element:text(~"Cep telefonu"), lustre@element:element(~"input", [lustre@attribute:name(~"gsm"), lustre@attribute:inputmode(~"tel"), lustre@attribute:required(true)], [])]), lustre@element:element(~"button", [lustre@attribute:type_(~"submit"), lustre@attribute:class(~"primary")], [lustre@element:text(~"3D Secure ile öde →")])])]), lustre@element:element(~"a", [lustre@attribute:href(<<Origin/binary, "/urunler"/utf8>>)], [lustre@element:text(~"Ürünlere dön")])])])]),
                    _pipe@3 = wisp:ok(),
                    _pipe@4 = wisp:set_cookie(_pipe@3, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
                    wisp:html_body(_pipe@4, lustre@element:to_string(Content))
            end
    end.

-file("src\\nexus_agency\\router.gleam", 7513).
-spec category_price_unit(binary()) -> binary().
category_price_unit(Category) ->
    case string:lowercase(Category) of
        ~"hotel" ->
            ~"gece";

        ~"holiday_home" ->
            ~"gece";

        ~"villa" ->
            ~"gece";

        ~"yacht" ->
            ~"gece";

        ~"car" ->
            ~"gün";

        ~"flight_bus" ->
            ~"kişi";

        ~"ferry" ->
            ~"kişi";

        ~"cruise" ->
            ~"kişi";

        ~"cinema" ->
            ~"kişi";

        ~"event" ->
            ~"kişi";

        ~"restaurant" ->
            ~"masa";

        ~"sunbed" ->
            ~"gün";

        ~"transfer" ->
            ~"transfer";

        _ ->
            ~"hizmet"
    end.

-file("src\\nexus_agency\\router.gleam", 7491).
-spec currency_symbol(binary()) -> binary().
currency_symbol(Currency) ->
    case string:uppercase(gleam@string:trim(Currency)) of
        ~"TRY" ->
            ~"₺";

        ~"USD" ->
            ~"$";

        ~"EUR" ->
            ~"€";

        ~"GBP" ->
            ~"£";

        ~"JPY" ->
            ~"¥";

        ~"CNY" ->
            ~"¥";

        ~"RUB" ->
            ~"₽";

        ~"INR" ->
            ~"₹";

        ~"KRW" ->
            ~"₩";

        ~"AED" ->
            ~"د.إ";

        ~"SAR" ->
            ~"﷼";

        ~"CHF" ->
            ~"₣";

        _ ->
            Currency
    end.

-file("src\\nexus_agency\\router.gleam", 7083).
-spec public_checkout_listing_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary()}).
public_checkout_listing_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Locality) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Category) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Price_minor) ->
                            gleam@dynamic@decode:success({Id, Title, Locality, Category, Currency, Price_minor})
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 7549).
-spec public_checkout_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_checkout_page(Req, Db, Origin) ->
    Checkout_query = wisp:get_query(Req),
    Listing_id = case begin
        _pipe = Checkout_query,
        gleam@list:key_find(_pipe, ~"listing")
    end of
        {ok, Value} ->
            gleam@string:trim(Value);

        {error, _} ->
            ~""
    end,
    Prefilled_check_in = case begin
        _pipe@1 = Checkout_query,
        gleam@list:key_find(_pipe@1, ~"check_in")
    end of
        {ok, Value@1} ->
            gleam@string:trim(Value@1);

        {error, _} ->
            ~""
    end,
    Prefilled_check_out = case begin
        _pipe@2 = Checkout_query,
        gleam@list:key_find(_pipe@2, ~"check_out")
    end of
        {ok, Value@2} ->
            gleam@string:trim(Value@2);

        {error, _} ->
            ~""
    end,
    Prefilled_guests = case begin
        _pipe@3 = Checkout_query,
        gleam@list:key_find(_pipe@3, ~"guests")
    end of
        {ok, Value@3} ->
            case gleam_stdlib:parse_int(Value@3) of
                {ok, Number} when (Number >= 1) andalso (Number =< 50) ->
                    erlang:integer_to_binary(Number);

                _ ->
                    ~"2"
            end;

        {error, _} ->
            ~"2"
    end,
    Csrf_token = csrf_token_for(Req),
    Tenant_id = begin
        _pipe@4 = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe@4, ~"")
    end,
    Result = begin
        _pipe@5 = ~"select id::text,title,locality,category,currency,price_minor::text from agency.listings where id=$1::uuid and tenant_id=$2::uuid and status='published' limit 1",
        _pipe@6 = pog:'query'(_pipe@5),
        _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Listing_id)),
        _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Tenant_id)),
        _pipe@9 = pog:returning(_pipe@8, public_checkout_listing_decoder()),
        pog:execute(_pipe@9, Db)
    end,
    case Result of
        {error, _} ->
            _pipe@10 = wisp:response(503),
            wisp:string_body(_pipe@10, ~"Ürün bilgisi alınamadı");

        {ok, Rows} ->
            case gleam@list:first(erlang:element(3, Rows)) of
                {error, _} ->
                    _pipe@11 = wisp:response(404),
                    wisp:string_body(_pipe@11, ~"Ürün bulunamadı veya yayında değil");

                {ok, {Id, Title, Locality, Category, Currency, Price_minor}} ->
                    case Currency /= ~"TRY" of
                        true ->
                            _pipe@12 = wisp:response(400),
                            wisp:string_body(_pipe@12, ~"Bu ürün için çevrim içi ödeme şu anda yalnızca TRY ile kullanılabilir.");

                        false ->
                            Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"meta", [lustre@attribute:name(~"robots"), lustre@attribute:attribute(~"content", ~"noindex,nofollow")], []), lustre@element:element(~"title", [], [lustre@element:text(<<"Rezervasyon | "/utf8, Title/binary>>)]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"booking-page checkout-page")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"GÜVENLİ REZERVASYON")]), lustre@element:element(~"h1", [], [lustre@element:text(~"Rezervasyonunuzu oluşturun")]), lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(<<<<Title/binary, " · "/utf8>>/binary, Locality/binary>>)]), lustre@element:element(~"div", [lustre@attribute:class(~"booking-card")], [lustre@element:element(~"div", [lustre@attribute:class(~"booking-card-price")], [lustre@element:element(~"strong", [lustre@attribute:attribute(~"data-price-minor", Price_minor), lustre@attribute:attribute(~"data-price-cur", string:uppercase(gleam@string:trim(Currency)))], [lustre@element:text(<<<<(currency_symbol(Currency))/binary, " "/utf8>>/binary, (amount_minor_display(Price_minor))/binary>>)]), lustre@element:element(~"span", [], [lustre@element:text(<<" / "/utf8, (category_price_unit(Category))/binary>>)])]), lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(~"Bilgilerinizi gönderin; ödeme adımına güvenli biçimde yönlendirileceksiniz.")]), lustre@element:element(~"form", [lustre@attribute:method(~"post"), lustre@attribute:action(~"/api/public/checkout/start"), lustre@attribute:class(~"checkout-form"), lustre@attribute:attribute(~"data-checkout-form", ~"true")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"listing_id"), lustre@attribute:value(Id)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"tenant"), lustre@attribute:value(Tenant_id)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"csrf_token"), lustre@attribute:value(Csrf_token)], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"idempotency_key"), lustre@attribute:value(<<"checkout-"/utf8, (wisp:random_string(32))/binary>>)], []), lustre@element:element(~"label", [], [lustre@element:text(~"Ad soyad"), lustre@element:element(~"input", [lustre@attribute:name(~"name"), lustre@attribute:autocomplete(~"name"), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"E-posta"), lustre@element:element(~"input", [lustre@attribute:name(~"email"), lustre@attribute:type_(~"email"), lustre@attribute:autocomplete(~"email")], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Telefon (e-posta veya telefon zorunlu)"), lustre@element:element(~"input", [lustre@attribute:name(~"phone"), lustre@attribute:type_(~"tel"), lustre@attribute:autocomplete(~"tel")], [])]), lustre@element:element(~"div", [lustre@attribute:class(~"form-grid-2")], [lustre@element:element(~"label", [], [lustre@element:text(~"Giriş tarihi"), lustre@element:element(~"input", [lustre@attribute:name(~"check_in"), lustre@attribute:type_(~"date"), lustre@attribute:value(Prefilled_check_in), lustre@attribute:required(true)], [])]), lustre@element:element(~"label", [], [lustre@element:text(~"Çıkış tarihi"), lustre@element:element(~"input", [lustre@attribute:name(~"check_out"), lustre@attribute:type_(~"date"), lustre@attribute:value(Prefilled_check_out), lustre@attribute:required(true)], [])])]), lustre@element:element(~"label", [], [lustre@element:text(~"Misafir sayısı"), lustre@element:element(~"input", [lustre@attribute:name(~"guest_count"), lustre@attribute:type_(~"number"), lustre@attribute:attribute(~"min", ~"1"), lustre@attribute:attribute(~"max", ~"50"), lustre@attribute:attribute(~"value", Prefilled_guests), lustre@attribute:required(true)], [])]), lustre@element:element(~"p", [lustre@attribute:class(~"checkout-error"), lustre@attribute:attribute(~"aria-live", ~"polite")], []), lustre@element:element(~"button", [lustre@attribute:type_(~"submit"), lustre@attribute:class(~"primary")], [lustre@element:text(~"Ödeme adımına geç →")])])]), lustre@element:element(~"a", [lustre@attribute:href(<<<<<<Origin/binary, "/urunler/"/utf8>>/binary, Id/binary>>/binary, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Ürüne dön")])]), public_footer(Tenant_id), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-checkout.js"), lustre@attribute:attribute(~"defer", ~"defer")], [])])]),
                            _pipe@13 = wisp:ok(),
                            _pipe@14 = wisp:set_cookie(_pipe@13, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
                            wisp:html_body(_pipe@14, lustre@element:to_string(Content))
                    end
            end
    end.

-file("src\\nexus_agency\\router.gleam", 7258).
-spec payment_session_id_decoder() -> gleam@dynamic@decode:decoder(binary()).
payment_session_id_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:success(Id)
    end).

-file("src\\nexus_agency\\router.gleam", 7093).
-spec checkout_order_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
checkout_order_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Number) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Reservation_id) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Amount_minor) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                        gleam@dynamic@decode:success({Id, Number, Reservation_id, Amount_minor, Currency})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 7525).
-spec checkout_dates_blocked(pog:connection(), binary(), binary(), binary()) -> boolean().
checkout_dates_blocked(Db, Listing_id, Check_in, Check_out) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_int/1}, fun(Count) ->
            gleam@dynamic@decode:success(Count > 0)
        end)
    end,
    case begin
        _pipe = ~"select count(*)::int from agency.availability where listing_id=$1::uuid and day>=NULLIF($2,'')::date and day<NULLIF($3,'')::date and (closed or units_available<1)",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Listing_id)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Check_in)),
        _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Check_out)),
        _pipe@5 = pog:returning(_pipe@4, Decoder),
        pog:execute(_pipe@5, Db)
    end of
        {ok, Result} ->
            _pipe@6 = gleam@list:first(erlang:element(3, Result)),
            gleam@result:unwrap(_pipe@6, false);

        {error, _} ->
            true
    end.

-file("src\\nexus_agency\\router.gleam", 7075).
-spec checkout_listing_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary()}).
checkout_listing_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Tenant_id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Price_minor) ->
                    gleam@dynamic@decode:success({Tenant_id, Title, Currency, Price_minor})
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 7263).
-spec public_checkout_start(gleam@http@request:request(wisp@internal:connection()), pog:connection()) -> gleam@http@response:response(wisp:body()).
public_checkout_start(Req, Db) ->
    wisp:require_form(Req, fun(Form) ->
        Listing_id = gleam@string:trim(form_value(erlang:element(2, Form), ~"listing_id")),
        Tenant_selector = gleam@string:trim(form_value(erlang:element(2, Form), ~"tenant")),
        Name = gleam@string:trim(form_value(erlang:element(2, Form), ~"name")),
        Email = string:lowercase(gleam@string:trim(form_value(erlang:element(2, Form), ~"email"))),
        Phone = gleam@string:trim(form_value(erlang:element(2, Form), ~"phone")),
        Check_in = gleam@string:trim(form_value(erlang:element(2, Form), ~"check_in")),
        Check_out = gleam@string:trim(form_value(erlang:element(2, Form), ~"check_out")),
        Guest_count = form_int(erlang:element(2, Form), ~"guest_count"),
        Idempotency_key = gleam@string:trim(form_value(erlang:element(2, Form), ~"idempotency_key")),
        Csrf_form = form_value(erlang:element(2, Form), ~"csrf_token"),
        Csrf_valid = case wisp:get_cookie(Req, ~"agency_csrf", plain_text) of
            {ok, Value} ->
                (Value /= ~"") andalso (Value =:= Csrf_form);

            {error, _} ->
                false
        end,
        Valid_dates = ((iso_date_valid(Check_in) andalso iso_date_valid(Check_out)) andalso (Check_in /= Check_out)) andalso (iso_date_key(Check_out) > iso_date_key(Check_in)),
        Email_valid = (Email =:= ~"") orelse (gleam_stdlib:contains_string(Email, ~"@") andalso (string:length(Email) =< 320)),
        Phone_valid = phone_format_valid(Phone),
        Contact_valid = (Email_valid andalso Phone_valid) andalso ((Email /= ~"") orelse (Phone /= ~"")),
        case not Csrf_valid of
            true ->
                _pipe = wisp:response(403),
                wisp:json_body(_pipe, ~"{\"ok\":false,\"error\":\"Güvenlik doğrulaması başarısız.\"}");

            false ->
                case (((((((((Listing_id =:= ~"") orelse (string:length(Listing_id) /= 36)) orelse (Idempotency_key =:= ~"")) orelse (string:length(Idempotency_key) > 120)) orelse (Name =:= ~"")) orelse (string:length(Name) > 160)) orelse not Contact_valid) orelse (Guest_count < 1)) orelse (Guest_count > 50)) orelse not Valid_dates of
                    true ->
                        _pipe@1 = wisp:response(400),
                        wisp:json_body(_pipe@1, ~"{\"ok\":false,\"error\":\"Rezervasyon bilgilerini kontrol edin.\"}");

                    false ->
                        Public_tenant = case Tenant_selector of
                            ~"" ->
                                _pipe@2 = public_tenant_id(Db, Req),
                                gleam@result:unwrap(_pipe@2, ~"");

                            Value@1 ->
                                _pipe@3 = public_tenant_id_from_selector(Db, Value@1),
                                gleam@result:unwrap(_pipe@3, ~"")
                        end,
                        Listing_result = begin
                            _pipe@4 = ~"select tenant_id::text,title,currency,price_minor::text from agency.listings where id=$1::uuid and tenant_id=$2::uuid and status='published' limit 1",
                            _pipe@5 = pog:'query'(_pipe@4),
                            _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Listing_id)),
                            _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Public_tenant)),
                            _pipe@8 = pog:returning(_pipe@7, checkout_listing_decoder()),
                            pog:execute(_pipe@8, Db)
                        end,
                        case Listing_result of
                            {error, _} ->
                                _pipe@9 = wisp:response(503),
                                wisp:json_body(_pipe@9, ~"{\"ok\":false,\"error\":\"Ürün bilgisi alınamadı.\"}");

                            {ok, Rows} ->
                                case gleam@list:first(erlang:element(3, Rows)) of
                                    {error, _} ->
                                        _pipe@10 = wisp:response(404),
                                        wisp:json_body(_pipe@10, ~"{\"ok\":false,\"error\":\"Ürün bulunamadı veya yayında değil.\"}");

                                    {ok, {Tenant_id, Title, Currency, _}} ->
                                        case checkout_dates_blocked(Db, Listing_id, Check_in, Check_out) of
                                            true ->
                                                _pipe@11 = wisp:response(409),
                                                wisp:json_body(_pipe@11, ~"{\"ok\":false,\"error\":\"Seçtiğiniz tarihlerde bu ürün müsait değil.\"}");

                                            false ->
                                                case string:uppercase(Currency) /= ~"TRY" of
                                                    true ->
                                                        _pipe@12 = wisp:response(400),
                                                        wisp:json_body(_pipe@12, ~"{\"ok\":false,\"error\":\"ParamPOS tahsilatı yalnızca TRY ile yapılabilir.\"}");

                                                    false ->
                                                        Reference = <<"NX-"/utf8, (string:uppercase(wisp:random_string(10)))/binary>>,
                                                        Order_result = begin
                                                            _pipe@13 = ~"select id::text,number,reservation_id::text,total_minor::text,currency from agency.checkout_order($1::uuid,$2,$3,$4,$5::uuid,$6,$7::text::date,$8::text::date,$9::int,$10)",
                                                            _pipe@14 = pog:'query'(_pipe@13),
                                                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(Tenant_id)),
                                                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(Name)),
                                                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(Email)),
                                                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(Phone)),
                                                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(Listing_id)),
                                                            _pipe@20 = pog:parameter(_pipe@19, pog_ffi:coerce(Reference)),
                                                            _pipe@21 = pog:parameter(_pipe@20, pog_ffi:coerce(Check_in)),
                                                            _pipe@22 = pog:parameter(_pipe@21, pog_ffi:coerce(Check_out)),
                                                            _pipe@23 = pog:parameter(_pipe@22, pog_ffi:coerce(Guest_count)),
                                                            _pipe@24 = pog:parameter(_pipe@23, pog_ffi:coerce(Idempotency_key)),
                                                            _pipe@25 = pog:returning(_pipe@24, checkout_order_decoder()),
                                                            pog:execute(_pipe@25, Db)
                                                        end,
                                                        case Order_result of
                                                            {error, Error} ->
                                                                gleam_stdlib:println(<<"Checkout order insert failed: "/utf8, (query_error_message(Error))/binary>>),
                                                                _pipe@26 = wisp:response(503),
                                                                wisp:json_body(_pipe@26, ~"{\"ok\":false,\"error\":\"Rezervasyon oluşturulamadı.\"}");

                                                            {ok, Order_rows} ->
                                                                case gleam@list:first(erlang:element(3, Order_rows)) of
                                                                    {error, _} ->
                                                                        _pipe@27 = wisp:response(409),
                                                                        wisp:json_body(_pipe@27, ~"{\"ok\":false,\"error\":\"Rezervasyon zaten işleniyor veya oluşturulamadı.\"}");

                                                                    {ok, {Order_id, Order_number, _, Amount_minor, Order_currency}} ->
                                                                        case begin
                                                                            _pipe@28 = ~"select agency.checkout_session($1::uuid,$2::uuid)::text",
                                                                            _pipe@29 = pog:'query'(_pipe@28),
                                                                            _pipe@30 = pog:parameter(_pipe@29, pog_ffi:coerce(Tenant_id)),
                                                                            _pipe@31 = pog:parameter(_pipe@30, pog_ffi:coerce(Order_id)),
                                                                            _pipe@32 = pog:returning(_pipe@31, payment_session_id_decoder()),
                                                                            pog:execute(_pipe@32, Db)
                                                                        end of
                                                                            {error, _} ->
                                                                                _pipe@33 = wisp:response(503),
                                                                                wisp:json_body(_pipe@33, ~"{\"ok\":false,\"error\":\"Ödeme oturumu oluşturulamadı.\"}");

                                                                            {ok, Session_rows} ->
                                                                                case gleam@list:first(erlang:element(3, Session_rows)) of
                                                                                    {error, _} ->
                                                                                        _pipe@34 = wisp:response(503),
                                                                                        wisp:json_body(_pipe@34, ~"{\"ok\":false,\"error\":\"Ödeme oturumu oluşturulamadı.\"}");

                                                                                    {ok, Session_id} ->
                                                                                        Body = begin
                                                                                            _pipe@35 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"orderNumber", gleam@json:string(Order_number)}, {~"sessionId", gleam@json:string(Session_id)}, {~"title", gleam@json:string(Title)}, {~"amountMinor", gleam@json:string(Amount_minor)}, {~"currency", gleam@json:string(Order_currency)}, {~"paymentUrl", gleam@json:string(<<"/odeme/parampos?session="/utf8, (gleam_stdlib:percent_encode(Session_id))/binary>>)}]),
                                                                                            gleam@json:to_string(_pipe@35)
                                                                                        end,
                                                                                        _pipe@36 = wisp:ok(),
                                                                                        wisp:json_body(_pipe@36, Body)
                                                                                end
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                end
                        end
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 4136).
-spec published_category_modules(pog:connection(), binary(), binary()) -> list(lustre@vdom@vnode:element(any())).
published_category_modules(Db, Category_slug, Tenant_id) ->
    case begin
        _pipe = ~"select b.block_type,b.sort_order,b.content::text from agency.page_blocks b join agency.pages p on p.id=b.page_id where p.tenant_id=$1::uuid and p.status='published' and (p.slug=$2 or p.slug='category-' || $2 or p.seo->>'category_scope'=$2) order by b.sort_order",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Category_slug)),
        _pipe@4 = pog:returning(_pipe@3, page_block_decoder()),
        pog:execute(_pipe@4, Db)
    end of
        {ok, Result} ->
            _pipe@5 = erlang:element(3, Result),
            gleam@list:map(_pipe@5, fun(Row) ->
                {Block_type, _, Raw_content} = Row,
                {Title, Body, Button_text, Button_url} = cms_block_copy(Raw_content, case Block_type of
                    ~"hero" ->
                        ~"Bölgenizi keşfedin";

                    ~"featured_listings" ->
                        ~"Bu kategoride öne çıkanlar";

                    ~"category_grid" ->
                        ~"Yakın kategorileri keşfedin";

                    ~"trust_strip" ->
                        ~"Güvenle planlayın";

                    ~"newsletter" ->
                        ~"Yeni fırsatlardan haberdar olun";

                    _ ->
                        ~"Seyahat ilhamı"
                end),
                lustre@element:element(~"article", [lustre@attribute:class(<<"builder-module builder-"/utf8, Block_type/binary>>)], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"NEXUS İÇERİK")]), lustre@element:element(~"h2", [], [lustre@element:text(Title)]), case Body of
                    ~"" ->
                        lustre@element:element(~"span", [], []);

                    Value ->
                        lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(Value)])
                end, case (Button_url /= ~"") andalso (Button_text /= ~"") of
                    true ->
                        lustre@element:element(~"a", [lustre@attribute:class(~"secondary"), lustre@attribute:href(safe_public_href(Button_url))], [lustre@element:text(Button_text)]);

                    false ->
                        lustre@element:element(~"span", [], [])
                end])
            end);

        {error, _} ->
            []
    end.

-file("src\\nexus_agency\\router.gleam", 4610).
-spec public_category_canonical(binary()) -> binary().
public_category_canonical(Slug) ->
    case string:lowercase(gleam@string:trim(Slug)) of
        ~"villa" ->
            ~"holiday_home";

        ~"flight_bus" ->
            ~"flight";

        ~"hajj" ->
            ~"pilgrimage";

        ~"sunbed" ->
            ~"beach";

        Value ->
            Value
    end.

-spec public_category_name(binary()) -> binary().
public_category_name(Slug) ->
    case public_category_canonical(Slug) of
        ~"hotel" ->
            ~"Oteller";

        ~"holiday_home" ->
            ~"Tatil evleri";

        ~"yacht" ->
            ~"Yat ve tekne deneyimleri";

        ~"tour" ->
            ~"Turlar";

        ~"activity" ->
            ~"Aktiviteler";

        ~"flight" ->
            ~"Uçuş";

        ~"bus" ->
            ~"Otobüs";

        ~"transfer" ->
            ~"Transfer";

        ~"ferry" ->
            ~"Feribot";

        ~"cruise" ->
            ~"Kruvaziyer";

        ~"car" ->
            ~"Araç kiralama";

        ~"event" ->
            ~"Etkinlikler";

        ~"restaurant" ->
            ~"Restoranlar";

        ~"cinema" ->
            ~"Sinema";

        ~"visa" ->
            ~"Vize hizmetleri";

        ~"pilgrimage" ->
            ~"Hac ve Umre";

        ~"beach" ->
            ~"Plaj ve şezlong";

        _ ->
            ~"Seyahat seçenekleri"
    end.

-file("src\\nexus_agency\\router.gleam", 6484).
-spec public_product_card({binary(), binary(), binary(), binary(), any(), binary(), integer(), binary()}, binary()) -> lustre@vdom@vnode:element(any()).
public_product_card(Row, Tenant_id) ->
    {Id, Title, Category, Locality, _, Currency, Price, Images} = Row,
    lustre@element:element(~"article", [lustre@attribute:class(~"product-card")], [lustre@element:element(~"div", [lustre@attribute:class(~"product-card-media"), lustre@attribute:attribute(~"data-images", Images)], [lustre@element:element(~"button", [lustre@attribute:class(~"card-favorite"), lustre@attribute:type_(~"button"), lustre@attribute:attribute(~"aria-label", ~"Favorilere ekle")], [lustre@element:text(~"♡")])]), lustre@element:element(~"div", [lustre@attribute:class(~"product-card-body")], [lustre@element:element(~"span", [lustre@attribute:class(~"card-type")], [lustre@element:text(<<(public_category_name(Category))/binary, (case Locality of
        ~"" ->
            ~"";

        _ ->
            <<" · "/utf8, Locality/binary>>
    end)/binary>>)]), lustre@element:element(~"h2", [], [lustre@element:element(~"a", [lustre@attribute:href(<<<<<<"/urunler/"/utf8, Id/binary>>/binary, "?tenant="/utf8>>/binary, Tenant_id/binary>>)], [lustre@element:text(Title)])]), lustre@element:element(~"div", [lustre@attribute:class(~"card-divider")], []), lustre@element:element(~"div", [lustre@attribute:class(~"card-price-row")], [lustre@element:element(~"div", [lustre@attribute:class(~"card-price")], [lustre@element:element(~"strong", [lustre@attribute:attribute(~"data-price-minor", erlang:integer_to_binary(Price)), lustre@attribute:attribute(~"data-price-cur", string:uppercase(gleam@string:trim(Currency)))], [lustre@element:text(<<<<(currency_symbol(Currency))/binary, " "/utf8>>/binary, (amount_minor_display(erlang:integer_to_binary(Price)))/binary>>)]), lustre@element:element(~"span", [lustre@attribute:class(~"card-price-unit")], [lustre@element:text(<<"/ "/utf8, (category_price_unit(Category))/binary>>)])]), lustre@element:element(~"span", [lustre@attribute:class(~"card-rating")], [lustre@element:text(~"★ 4.9")])])])]).

-file("src\\nexus_agency\\router.gleam", 5743).
-spec public_listing_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), integer(), binary()}).
public_listing_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Category) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Locality) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Description) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_int/1}, fun(Price) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Images) ->
                                    gleam@dynamic@decode:success({Id, Title, Category, Locality, Description, Currency, Price, Images})
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 5764).
-spec public_category_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary(), binary()) -> gleam@http@response:response(wisp:body()).
public_category_page(Req, Db, Origin, Category_slug) ->
    Category = public_category_canonical(Category_slug),
    Category_title = public_category_name(Category),
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Cards = case begin
        _pipe@1 = ~"select id::text, title, category, locality, description, currency, price_minor::int, coalesce(images::text,'[]') from agency.listings where tenant_id=$1::uuid and status='published' and category=$2 order by updated_at desc limit 100",
        _pipe@2 = pog:'query'(_pipe@1),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Tenant_id)),
        _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Category)),
        _pipe@5 = pog:returning(_pipe@4, public_listing_decoder()),
        pog:execute(_pipe@5, Db)
    end of
        {ok, Rows} ->
            case erlang:element(3, Rows) of
                [] ->
                    [lustre@element:element(~"p", [lustre@attribute:class(~"muted empty-state")], [lustre@element:text(~"Bu kategoride yayınlanmış ürün bulunmuyor. Danışmanlarımız sizin için seçenekleri hazırlayabilir.")])];

                Values ->
                    _pipe@6 = Values,
                    gleam@list:map(_pipe@6, fun(Row) ->
                        public_product_card(Row, Tenant_id)
                    end)
            end;

        {error, _} ->
            [lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(~"Ürünler şu anda yüklenemiyor.")])]
    end,
    Builder_modules = published_category_modules(Db, Category, Tenant_id),
    Csrf_token = csrf_token_for(Req),
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"meta", [lustre@attribute:name(~"description"), lustre@attribute:attribute(~"content", <<Category_title/binary, " için seçilmiş seyahat seçenekleri ve güvenli rezervasyon"/utf8>>)], []), lustre@element:element(~"title", [], [lustre@element:text(<<Category_title/binary, " | NEXUS Agency"/utf8>>)]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page category-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [], [lustre@element:element(~"section", [lustre@attribute:class(~"category-hero")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"KATEGORİ")]), lustre@element:element(~"h1", [], [lustre@element:text(Category_title)]), lustre@element:element(~"p", [lustre@attribute:class(~"muted")], [lustre@element:text(~"İhtiyacınıza uygun seçenekleri karşılaştırın; tarih ve kişi sayınıza göre hızlıca rezervasyon oluşturun.")]), lustre@element:element(~"img", [lustre@attribute:class(~"category-hero-image"), lustre@attribute:attribute(~"src", ~"/static/chisfis/images/hero-right.webp"), lustre@attribute:attribute(~"alt", Category_title), lustre@attribute:attribute(~"loading", ~"eager")], []), lustre@element:element(~"a", [lustre@attribute:class(~"primary"), lustre@attribute:href(<<"/iletisim"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Uzman desteği al")])]), lustre@element:element(~"section", [lustre@attribute:class(~"published-builder-modules")], Builder_modules), lustre@element:element(~"section", [lustre@attribute:class(~"category-listings")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading")], [lustre@element:element(~"h2", [], [lustre@element:text(<<Category_title/binary, " seçenekleri"/utf8>>)]), lustre@element:element(~"a", [lustre@attribute:href(<<<<<<"/urunler?kategori="/utf8, Category/binary>>/binary, "&tenant="/utf8>>/binary, Tenant_id/binary>>)], [lustre@element:text(~"Filtreli listeyi aç →")])]), lustre@element:element(~"div", [lustre@attribute:class(~"product-grid")], Cards)]), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-listings.js"), lustre@attribute:attribute(~"defer", ~"defer")], [])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@7 = wisp:ok(),
    _pipe@8 = wisp:set_cookie(_pipe@7, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
    wisp:html_body(_pipe@8, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 6545).
-spec chisfis_guest_picker() -> lustre@vdom@vnode:element(any()).
-doc(~" Şablondaki misafir seçici: \"N misafir\" tetikleyici + rounded panel;
 Adults (13+), Children (2–12), Infants (0–2) satırları, her biri −/+/değer.
 JS toplamı gizli `guests` alanına yazar (rezervasyon formu aynı alanı okur).").
chisfis_guest_picker() ->
    Stepper = fun(Label, Sub, Key, Initial) ->
        lustre@element:element(~"div", [lustre@attribute:class(~"guest-stepper")], [lustre@element:element(~"div", [lustre@attribute:class(~"guest-stepper-info")], [lustre@element:element(~"span", [lustre@attribute:class(~"guest-stepper-label")], [lustre@element:text(Label)]), lustre@element:element(~"span", [lustre@attribute:class(~"guest-stepper-sub")], [lustre@element:text(Sub)])]), lustre@element:element(~"div", [lustre@attribute:class(~"guest-stepper-controls")], [lustre@element:element(~"button", [lustre@attribute:type_(~"button"), lustre@attribute:class(~"guest-stepper-btn"), lustre@attribute:attribute(~"data-step", ~"-1"), lustre@attribute:attribute(~"data-target", Key), lustre@attribute:attribute(~"aria-label", <<Label/binary, " azalt"/utf8>>)], [lustre@element:text(~"−")]), lustre@element:element(~"span", [lustre@attribute:class(~"guest-stepper-value"), lustre@attribute:attribute(~"data-guest-count", Key)], [lustre@element:text(erlang:integer_to_binary(Initial))]), lustre@element:element(~"button", [lustre@attribute:type_(~"button"), lustre@attribute:class(~"guest-stepper-btn"), lustre@attribute:attribute(~"data-step", ~"1"), lustre@attribute:attribute(~"data-target", Key), lustre@attribute:attribute(~"aria-label", <<Label/binary, " artır"/utf8>>)], [lustre@element:text(~"+")])])])
    end,
    lustre@element:element(~"div", [lustre@attribute:class(~"chisfis-guest-range")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"guests"), lustre@attribute:value(~"2"), lustre@attribute:attribute(~"data-guests-total", ~"")], []), lustre@element:element(~"button", [lustre@attribute:type_(~"button"), lustre@attribute:class(~"chisfis-guest-trigger"), lustre@attribute:attribute(~"aria-expanded", ~"false"), lustre@attribute:attribute(~"aria-haspopup", ~"dialog")], [lustre@element:element(~"span", [lustre@attribute:class(~"chisfis-guest-icon")], [lustre@element:text(~"👤")]), lustre@element:element(~"span", [lustre@attribute:class(~"chisfis-guest-texts")], [lustre@element:element(~"span", [lustre@attribute:class(~"chisfis-guest-value")], [lustre@element:text(~"2 misafir")]), lustre@element:element(~"span", [lustre@attribute:class(~"chisfis-guest-sub")], [lustre@element:text(~"Misafirler")])])]), lustre@element:element(~"div", [lustre@attribute:class(~"chisfis-guest-panel")], [Stepper(~"Yetişkin", ~"13 yaş ve üzeri", ~"adults", 2), Stepper(~"Çocuk", ~"2–12 yaş", ~"children", 0), Stepper(~"Bebek", ~"0–2 yaş", ~"infants", 0)])]).

-file("src\\nexus_agency\\router.gleam", 6625).
-spec chisfis_date_range_picker() -> lustre@vdom@vnode:element(any()).
chisfis_date_range_picker() ->
    lustre@element:element(~"div", [lustre@attribute:class(~"chisfis-date-range")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"check_in")], []), lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"check_out")], []), lustre@element:element(~"button", [lustre@attribute:type_(~"button"), lustre@attribute:class(~"chisfis-date-trigger"), lustre@attribute:attribute(~"aria-expanded", ~"false"), lustre@attribute:attribute(~"aria-haspopup", ~"dialog")], [lustre@element:element(~"span", [lustre@attribute:class(~"chisfis-date-icon")], [lustre@element:text(~"📅")]), lustre@element:element(~"span", [lustre@attribute:class(~"chisfis-date-value")], [lustre@element:text(~"Tarih seçin")])]), lustre@element:element(~"div", [lustre@attribute:class(~"chisfis-date-panel")], [lustre@element:element(~"div", [lustre@attribute:class(~"datepicker"), lustre@attribute:attribute(~"aria-label", ~"Tarih aralığı seç")], [])])]).

-file("src\\nexus_agency\\router.gleam", 6659).
-spec public_product_detail_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary(), binary()) -> gleam@http@response:response(wisp:body()).
public_product_detail_page(Req, Db, Origin, Listing_id) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Result = begin
        _pipe@1 = pog:'query'(~"select id::text, title, category, locality, description, currency, price_minor::int, coalesce(images::text,'[]') from agency.listings where id::text = $1 and tenant_id=$2::uuid and status = 'published' limit 1"),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Listing_id)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Tenant_id)),
        _pipe@4 = pog:returning(_pipe@3, public_listing_decoder()),
        pog:execute(_pipe@4, Db)
    end,
    case Result of
        {ok, Rows} ->
            case gleam@list:first(erlang:element(3, Rows)) of
                {error, _} ->
                    _pipe@5 = wisp:response(404),
                    wisp:string_body(_pipe@5, ~"Ürün bulunamadı");

                {ok, {Id, Title, Category, Locality, Description, Currency, Price, Images}} ->
                    Csrf_token = csrf_token_for(Req),
                    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"meta", [lustre@attribute:name(~"description"), lustre@attribute:attribute(~"content", <<Title/binary, " | NEXUS Agency"/utf8>>)], []), lustre@element:element(~"meta", [lustre@attribute:attribute(~"property", ~"og:title"), lustre@attribute:attribute(~"content", Title)], []), lustre@element:element(~"meta", [lustre@attribute:attribute(~"property", ~"og:description"), lustre@attribute:attribute(~"content", Description)], []), lustre@element:element(~"meta", [lustre@attribute:attribute(~"property", ~"og:type"), lustre@attribute:attribute(~"content", ~"product")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"twitter:card"), lustre@attribute:attribute(~"content", ~"summary_large_image")], []), lustre@element:unsafe_raw_html(~"", ~"script", [lustre@attribute:attribute(~"type", ~"application/ld+json")], begin
                        _pipe@6 = gleam@json:object([{~"@context", gleam@json:string(~"https://schema.org")}, {~"@type", gleam@json:string(~"Product")}, {~"name", gleam@json:string(Title)}, {~"description", gleam@json:string(Description)}, {~"category", gleam@json:string(Category)}, {~"offers", gleam@json:object([{~"@type", gleam@json:string(~"Offer")}, {~"priceCurrency", gleam@json:string(Currency)}, {~"price", gleam@json:float(erlang:float(Price) / 100.0)}, {~"availability", gleam@json:string(~"https://schema.org/InStock")}])}]),
                        gleam@json:to_string(_pipe@6)
                    end), lustre@element:element(~"title", [], [lustre@element:text(<<Title/binary, " | NEXUS Agency"/utf8>>)]), lustre@element:element(~"link", [lustre@attribute:attribute(~"rel", ~"canonical"), lustre@attribute:href(<<<<<<Origin/binary, "/urunler/"/utf8>>/binary, Id/binary>>/binary, (public_tenant_query(Tenant_id))/binary>>)], []) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(<<"product-detail category-"/utf8, Category/binary>>)], [lustre@element:element(~"nav", [lustre@attribute:class(~"detail-breadcrumb"), lustre@attribute:attribute(~"aria-label", ~"Sayfa yolu")], [lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Ürünler")]), lustre@element:element(~"span", [], [lustre@element:text(~"/")]), lustre@element:element(~"span", [], [lustre@element:text(public_category_name(Category))])]), lustre@element:element(~"div", [lustre@attribute:class(~"detail-gallery"), lustre@attribute:attribute(~"data-images", Images)], []), lustre@element:element(~"div", [lustre@attribute:class(~"listingSection__wrap")], [lustre@element:element(~"button", [lustre@attribute:class(~"detail-favorite"), lustre@attribute:type_(~"button"), lustre@attribute:attribute(~"aria-label", ~"Favorilere ekle")], [lustre@element:text(~"♡")]), lustre@element:element(~"div", [lustre@attribute:class(~"flex flex-col items-start gap-y-6")], [lustre@element:element(~"span", [lustre@attribute:class(~"detail-badge")], [lustre@element:text(public_category_name(Category))]), lustre@element:element(~"h1", [], [lustre@element:text(Title)]), lustre@element:element(~"div", [lustre@attribute:class(~"detail-meta-row")], [lustre@element:element(~"span", [lustre@attribute:class(~"detail-rating")], [lustre@element:text(~"★ 4.9")]), lustre@element:element(~"span", [lustre@attribute:class(~"detail-meta-dot")], [lustre@element:text(~"·")]), lustre@element:element(~"span", [lustre@attribute:class(~"detail-location")], [lustre@element:text(Locality)])]), lustre@element:element(~"div", [lustre@attribute:class(~"share-actions")], [lustre@element:element(~"a", [lustre@attribute:class(~"secondary"), lustre@attribute:href(<<<<<<<<<<<<<<"https://wa.me/?text="/utf8, Title/binary>>/binary, " - "/utf8>>/binary, Origin/binary>>/binary, "/urunler/"/utf8>>/binary, Id/binary>>/binary, "?tenant="/utf8>>/binary, Tenant_id/binary>>)], [lustre@element:text(~"WhatsApp'ta paylaş")]), lustre@element:element(~"button", [lustre@attribute:class(~"secondary"), lustre@attribute:type_(~"button"), lustre@attribute:attribute(~"onclick", ~"navigator.clipboard.writeText(location.href);this.textContent='Bağlantı kopyalandı'")], [lustre@element:text(~"Bağlantıyı kopyala")])])])]), lustre@element:element(~"div", [lustre@attribute:class(~"listingSection__wrap")], [lustre@element:element(~"div", [lustre@attribute:class(~"product-description")], [lustre@element:text(Description)])]), lustre@element:element(~"div", [lustre@attribute:class(~"listingSection__wrap")], [lustre@element:element(~"a", [lustre@attribute:class(~"secondary"), lustre@attribute:href(<<<<<<<<<<"/urunler?kategori="/utf8, Category/binary>>/binary, "&konum="/utf8>>/binary, Locality/binary>>/binary, "&tenant="/utf8>>/binary, Tenant_id/binary>>)], [lustre@element:text(~"Benzer ürünleri keşfet")])]), lustre@element:element(~"section", [lustre@attribute:class(~"listingSection__wrap")], [lustre@element:element(~"h2", [], [lustre@element:text(~"Yaklaşan müsaitlik")]), lustre@element:element(~"div", [lustre@attribute:id(~"public-availability"), lustre@attribute:attribute(~"data-listing-id", Id), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [lustre@element:text(~"Yükleniyor…")])]), lustre@element:element(~"div", [lustre@attribute:class(~"grow")], [lustre@element:element(~"div", [lustre@attribute:class(~"sticky top-8")], [lustre@element:element(~"div", [lustre@attribute:class(~"listingSection__wrap sm:shadow-xl")], [lustre@element:element(~"div", [lustre@attribute:class(~"flex items-end text-2xl font-semibold sm:text-3xl"), lustre@attribute:attribute(~"data-price-minor", erlang:integer_to_binary(Price)), lustre@attribute:attribute(~"data-price-cur", string:uppercase(gleam@string:trim(Currency)))], [lustre@element:text(<<<<(currency_symbol(Currency))/binary, " "/utf8>>/binary, (amount_minor_display(erlang:integer_to_binary(Price)))/binary>>), lustre@element:element(~"span", [lustre@attribute:class(~"text-base font-normal text-neutral-500 dark:text-neutral-400 ms-1")], [lustre@element:text(<<" / "/utf8, (category_price_unit(Category))/binary>>)])]), lustre@element:element(~"form", [lustre@attribute:method(~"get"), lustre@attribute:action(<<"/rezervasyon?tenant="/utf8, Tenant_id/binary>>), lustre@attribute:class(~"flex flex-col rounded-3xl border border-neutral-200 dark:border-neutral-700 mt-4"), lustre@attribute:attribute(~"id", ~"booking-form")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"listing"), lustre@attribute:value(Id)], []), chisfis_date_range_picker(), lustre@element:element(~"div", [lustre@attribute:class(~"w-full border-b border-neutral-200 dark:border-neutral-700")], []), chisfis_guest_picker(), lustre@element:element(~"div", [lustre@attribute:class(~"p-3 border-t border-neutral-200 dark:border-neutral-700")], [lustre@element:element(~"button", [lustre@attribute:type_(~"submit"), lustre@attribute:class(~"w-full rounded-xl bg-primary-600 hover:bg-primary-700 text-white font-semibold py-3.5 text-base transition")], [lustre@element:text(~"Müsaitlik ve teklif iste")])])]), lustre@element:element(~"small", [lustre@attribute:class(~"muted")], [lustre@element:text(~"Ücretsiz teklif · Ön ödeme koşulları danışmanınız tarafından paylaşılır")])])])]), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-availability.js"), lustre@attribute:attribute(~"defer", ~"defer")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-detail.js?v=20260921-gallery2"), lustre@attribute:attribute(~"defer", ~"defer")], []), public_guests_script(), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])])]),
                    _pipe@7 = wisp:ok(),
                    _pipe@8 = wisp:set_cookie(_pipe@7, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
                    wisp:html_body(_pipe@8, lustre@element:to_string(Content))
            end;

        {error, _} ->
            _pipe@9 = wisp:response(503),
            wisp:string_body(_pipe@9, ~"Ürünler şu anda yüklenemiyor")
    end.

-file("src\\nexus_agency\\router.gleam", 4270).
-spec public_tenant_amp_query(binary()) -> binary().
public_tenant_amp_query(Tenant_id) ->
    case Tenant_id of
        ~"" ->
            ~"";

        Value ->
            <<"&tenant="/utf8, Value/binary>>
    end.

-file("src\\nexus_agency\\router.gleam", 5919).
-spec public_products_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_products_page(Req, Db, Origin) ->
    Query = wisp:get_query(Req),
    Search = case begin
        _pipe = Query,
        gleam@list:key_find(_pipe, ~"q")
    end of
        {ok, Value} ->
            Value;

        {error, _} ->
            ~""
    end,
    Locality = case begin
        _pipe@1 = Query,
        gleam@list:key_find(_pipe@1, ~"konum")
    end of
        {ok, Value@1} ->
            Value@1;

        {error, _} ->
            ~""
    end,
    Category = case begin
        _pipe@2 = Query,
        gleam@list:key_find(_pipe@2, ~"kategori")
    end of
        {ok, Value@2} ->
            public_category_canonical(Value@2);

        {error, _} ->
            ~""
    end,
    Tenant_id = begin
        _pipe@3 = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe@3, ~"")
    end,
    Cards = case begin
        _pipe@4 = pog:'query'(~"select id::text, title, category, locality, description, currency, price_minor::int, coalesce(images::text,'[]') from agency.listings where tenant_id=$1::uuid and status = 'published' and ($2 = '' or title ilike '%' || $2 || '%' or description ilike '%' || $2 || '%') and ($3 = '' or locality ilike '%' || $3 || '%') and ($4 = '' or category = $4) order by updated_at desc limit 100"),
        _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(Tenant_id)),
        _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Search)),
        _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Locality)),
        _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Category)),
        _pipe@9 = pog:returning(_pipe@8, public_listing_decoder()),
        pog:execute(_pipe@9, Db)
    end of
        {error, _} ->
            [lustre@element:element(~"p", [lustre@attribute:class(~"empty-state")], [lustre@element:text(~"Ürünler şu anda yüklenemiyor.")])];

        {ok, Result} ->
            case gleam@list:is_empty(erlang:element(3, Result)) of
                true ->
                    [lustre@element:element(~"p", [lustre@attribute:class(~"empty-state")], [lustre@element:text(~"Yayınlanmış ürün bulunamadı.")])];

                false ->
                    gleam@list:map(erlang:element(3, Result), fun(Row) ->
                        public_product_card(Row, Tenant_id)
                    end)
            end
    end,
    Csrf_token = csrf_token_for(Req),
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"description"), lustre@attribute:attribute(~"content", ~"NEXUS Agency ile otel, villa ve seyahat ürünlerini keşfedin.")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"title", [], [lustre@element:text(~"Ürünler | NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-page"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_storefront_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(<<"products-page category-"/utf8, Category/binary>>)], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"SEYAHAT ENVANTERİ")]), lustre@element:element(~"nav", [lustre@attribute:class(~"listing-breadcrumb"), lustre@attribute:attribute(~"aria-label", ~"Sayfa yolu")], lists:append([lustre@element:element(~"a", [lustre@attribute:href(<<"/"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Ana Sayfa")]), lustre@element:element(~"span", [lustre@attribute:class(~"listing-breadcrumb-sep")], [lustre@element:text(~">")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Ürünler")])], case Category of
        ~"" ->
            [];

        Cat ->
            [lustre@element:element(~"span", [lustre@attribute:class(~"listing-breadcrumb-sep")], [lustre@element:text(~">")]), lustre@element:element(~"span", [lustre@attribute:class(~"listing-breadcrumb-current")], [lustre@element:text(public_category_name(Cat))])]
    end)), lustre@element:element(~"h1", [], [lustre@element:text(~"Size uygun ürünü keşfedin")]), lustre@element:element(~"p", [], [lustre@element:text(~"NEXUS ağı ve bağımsız tedarikçilerden yayınlanan güncel ürünler.")]), lustre@element:element(~"div", [lustre@attribute:class(~"listing-filter-panel"), lustre@attribute:attribute(~"data-filter-panel", ~"")], [lustre@element:element(~"button", [lustre@attribute:class(~"listing-filter-toggle"), lustre@attribute:type_(~"button"), lustre@attribute:attribute(~"aria-expanded", ~"false"), lustre@attribute:attribute(~"aria-controls", ~"listing-filter-body")], [lustre@element:element(~"span", [lustre@attribute:class(~"listing-filter-toggle-icon")], [lustre@element:text(~"🔍")]), lustre@element:element(~"span", [], [lustre@element:text(~"Filtre ve Arama")]), lustre@element:element(~"span", [lustre@attribute:class(~"listing-filter-toggle-chevron")], [lustre@element:text(~"▾")])]), lustre@element:element(~"div", [lustre@attribute:class(~"listing-filter-body"), lustre@attribute:id(~"listing-filter-body")], [lustre@element:element(~"form", [lustre@attribute:method(~"get"), lustre@attribute:class(~"product-search")], [lustre@element:element(~"input", [lustre@attribute:type_(~"hidden"), lustre@attribute:name(~"tenant"), lustre@attribute:value(Tenant_id)], []), lustre@element:element(~"input", [lustre@attribute:name(~"q"), lustre@attribute:attribute(~"value", Search), lustre@attribute:attribute(~"placeholder", ~"Otel, tatil evi veya tur ara")], []), lustre@element:element(~"input", [lustre@attribute:name(~"konum"), lustre@attribute:attribute(~"value", Locality), lustre@attribute:attribute(~"placeholder", ~"Konum: Kaş, Bodrum...")], []), lustre@element:element(~"select", [lustre@attribute:name(~"kategori")], [lustre@element:element(~"option", [lustre@attribute:value(~"")], [lustre@element:text(~"Tüm kategoriler")]), lustre@element:element(~"option", [lustre@attribute:value(~"hotel")], [lustre@element:text(~"Otel")]), lustre@element:element(~"option", [lustre@attribute:value(~"holiday_home")], [lustre@element:text(~"Tatil Evi")]), lustre@element:element(~"option", [lustre@attribute:value(~"tour")], [lustre@element:text(~"Tur")]), lustre@element:element(~"option", [lustre@attribute:value(~"activity")], [lustre@element:text(~"Aktivite")]), lustre@element:element(~"option", [lustre@attribute:value(~"yacht")], [lustre@element:text(~"Yat")]), lustre@element:element(~"option", [lustre@attribute:value(~"flight")], [lustre@element:text(~"Uçuş")]), lustre@element:element(~"option", [lustre@attribute:value(~"bus")], [lustre@element:text(~"Otobüs")]), lustre@element:element(~"option", [lustre@attribute:value(~"car")], [lustre@element:text(~"Araç")]), lustre@element:element(~"option", [lustre@attribute:value(~"transfer")], [lustre@element:text(~"Transfer")]), lustre@element:element(~"option", [lustre@attribute:value(~"ferry")], [lustre@element:text(~"Feribot")]), lustre@element:element(~"option", [lustre@attribute:value(~"cruise")], [lustre@element:text(~"Kruvaziyer")]), lustre@element:element(~"option", [lustre@attribute:value(~"event")], [lustre@element:text(~"Etkinlik")]), lustre@element:element(~"option", [lustre@attribute:value(~"restaurant")], [lustre@element:text(~"Restoran")]), lustre@element:element(~"option", [lustre@attribute:value(~"cinema")], [lustre@element:text(~"Sinema")]), lustre@element:element(~"option", [lustre@attribute:value(~"visa")], [lustre@element:text(~"Vize")]), lustre@element:element(~"option", [lustre@attribute:value(~"pilgrimage")], [lustre@element:text(~"Hac & Umre")]), lustre@element:element(~"option", [lustre@attribute:value(~"beach")], [lustre@element:text(~"Plaj")])]), lustre@element:element(~"button", [lustre@attribute:type_(~"submit"), lustre@attribute:class(~"primary")], [lustre@element:text(~"Ara")])]), lustre@element:element(~"nav", [lustre@attribute:class(~"product-category-pills"), lustre@attribute:attribute(~"aria-label", ~"Kategori filtreleri")], [lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler"/utf8, (public_tenant_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Tümü")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=hotel"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"hotel" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Otel")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=holiday_home"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"holiday_home" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Tatil Evi")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=tour"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"tour" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Turlar")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=activity"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"activity" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Aktiviteler")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=yacht"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"yacht" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Yat")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=flight"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"flight" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Uçuş")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=car"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"car" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Araç")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=transfer"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"transfer" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Transfer")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=ferry"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"ferry" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Feribot")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=cruise"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"cruise" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Kruvaziyer")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=event"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"event" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Etkinlik")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=restaurant"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"restaurant" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Restoran")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=cinema"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"cinema" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Sinema")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=visa"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"visa" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Vize")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=pilgrimage"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"pilgrimage" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Hac & Umre")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler?kategori=beach"/utf8, (public_tenant_amp_query(Tenant_id))/binary>>), lustre@attribute:class(case Category of
        ~"beach" ->
            ~"active";

        _ ->
            ~""
    end)], [lustre@element:text(~"Plaj")])])])]), lustre@element:element(~"div", [lustre@attribute:class(~"products-toolbar")], [lustre@element:element(~"span", [], [lustre@element:text(~"Seçiminize uygun seçenekler")]), lustre@element:element(~"select", [lustre@attribute:class(~"products-sort"), lustre@attribute:attribute(~"aria-label", ~"Sıralama")], [lustre@element:element(~"option", [lustre@attribute:value(~"recommended")], [lustre@element:text(~"Önerilenler")]), lustre@element:element(~"option", [lustre@attribute:value(~"price")], [lustre@element:text(~"Fiyata göre")]), lustre@element:element(~"option", [lustre@attribute:value(~"recent")], [lustre@element:text(~"Yeni eklenenler")])])]), lustre@element:element(~"section", [lustre@attribute:class(~"product-grid")], Cards), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-listings.js"), lustre@attribute:attribute(~"defer", ~"defer")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-search.js"), lustre@attribute:attribute(~"defer", ~"defer")], []), lustre@element:element(~"script", [lustre@attribute:attribute(~"src", ~"/static/public-category-nav.js"), lustre@attribute:attribute(~"defer", ~"defer")], []), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])])]),
    _pipe@10 = wisp:ok(),
    _pipe@11 = wisp:set_cookie(_pipe@10, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
    wisp:html_body(_pipe@11, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 4470).
-spec public_home_how_card(binary(), binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_home_how_card(Image, Title, Body) ->
    lustre@element:element(~"article", [lustre@attribute:class(~"home-how-card")], [lustre@element:element(~"img", [lustre@attribute:attribute(~"src", Image), lustre@attribute:attribute(~"alt", ~""), lustre@attribute:attribute(~"loading", ~"lazy"), lustre@attribute:attribute(~"decoding", ~"async"), lustre@attribute:attribute(~"width", ~"96"), lustre@attribute:attribute(~"height", ~"96")], []), lustre@element:element(~"h3", [], [lustre@element:text(Title)]), lustre@element:element(~"p", [], [lustre@element:text(Body)])]).

-file("src\\nexus_agency\\router.gleam", 4509).
-spec public_home_testimonial(binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_home_testimonial(Quote, Author) ->
    lustre@element:element(~"article", [lustre@attribute:class(~"testimonial-card")], [lustre@element:element(~"div", [lustre@attribute:class(~"testimonial-stars"), lustre@attribute:attribute(~"aria-label", ~"5 yıldız")], [lustre@element:text(~"★★★★★")]), lustre@element:element(~"blockquote", [], [lustre@element:text(<<<<"“"/utf8, Quote/binary>>/binary, "”"/utf8>>)]), lustre@element:element(~"strong", [], [lustre@element:text(Author)])]).

-file("src\\nexus_agency\\router.gleam", 4489).
-spec public_home_blog_card(binary(), binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_home_blog_card(Image, Title, Body) ->
    lustre@element:element(~"article", [lustre@attribute:class(~"home-blog-card")], [lustre@element:element(~"img", [lustre@attribute:attribute(~"src", Image), lustre@attribute:attribute(~"alt", Title), lustre@attribute:attribute(~"loading", ~"lazy")], []), lustre@element:element(~"div", [lustre@attribute:class(~"home-blog-card-copy")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"SEYAHAT FİKRİ")]), lustre@element:element(~"h3", [], [lustre@element:text(Title)]), lustre@element:element(~"p", [], [lustre@element:text(Body)]), lustre@element:element(~"a", [lustre@attribute:href(~"/#home-blog")], [lustre@element:text(~"Devamını oku →")])])]).

-file("src\\nexus_agency\\router.gleam", 4567).
-spec public_featured_card(binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_featured_card(Image, Type_label, Beds, Name, Location, Price, Minor, Rating, Reviews) ->
    lustre@element:element(~"article", [lustre@attribute:class(~"featured-card")], [lustre@element:element(~"div", [lustre@attribute:class(~"featured-card-img")], [lustre@element:element(~"img", [lustre@attribute:attribute(~"src", Image), lustre@attribute:attribute(~"alt", Name), lustre@attribute:attribute(~"loading", ~"lazy"), lustre@attribute:attribute(~"decoding", ~"async")], []), lustre@element:element(~"span", [lustre@attribute:class(~"featured-card-type")], [lustre@element:text(Type_label)])]), lustre@element:element(~"div", [lustre@attribute:class(~"featured-card-body")], [lustre@element:element(~"span", [lustre@attribute:class(~"featured-card-beds")], [lustre@element:text(Beds)]), lustre@element:element(~"h3", [], [lustre@element:text(Name)]), lustre@element:element(~"p", [lustre@attribute:class(~"featured-card-location")], [lustre@element:text(Location)]), lustre@element:element(~"div", [lustre@attribute:class(~"featured-card-footer")], [lustre@element:element(~"span", [lustre@attribute:class(~"featured-card-price"), lustre@attribute:attribute(~"data-price-minor", Minor), lustre@attribute:attribute(~"data-price-cur", ~"TRY")], [lustre@element:text(Price), lustre@element:element(~"span", [lustre@attribute:class(~"featured-card-price-unit")], [lustre@element:text(~"/gece")])]), lustre@element:element(~"span", [lustre@attribute:class(~"featured-card-rating")], [lustre@element:text(<<"★ "/utf8, Rating/binary>>), lustre@element:element(~"span", [lustre@attribute:class(~"featured-card-reviews")], [lustre@element:text(<<<<" ("/utf8, Reviews/binary>>/binary, ")"/utf8>>)])])])])]).

-file("src\\nexus_agency\\router.gleam", 4559).
-spec public_benefit_card(binary(), binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_benefit_card(Icon, Title, Body) ->
    lustre@element:element(~"article", [lustre@attribute:class(~"benefit-card")], [lustre@element:element(~"span", [lustre@attribute:class(~"benefit-icon")], [lustre@element:text(Icon)]), lustre@element:element(~"h3", [], [lustre@element:text(Title)]), lustre@element:element(~"p", [], [lustre@element:text(Body)])]).

-file("src\\nexus_agency\\router.gleam", 4523).
-spec public_adventure_card(binary(), binary(), binary(), binary()) -> lustre@vdom@vnode:element(any()).
public_adventure_card(Image, City, Count, Suffix) ->
    lustre@element:element(~"a", [lustre@attribute:class(~"adventure-card"), lustre@attribute:href(~"/urunler")], [lustre@element:element(~"img", [lustre@attribute:attribute(~"src", Image), lustre@attribute:attribute(~"alt", City), lustre@attribute:attribute(~"loading", ~"lazy"), lustre@attribute:attribute(~"decoding", ~"async")], []), lustre@element:element(~"div", [lustre@attribute:class(~"adventure-card-overlay")], [lustre@element:element(~"span", [lustre@attribute:class(~"adventure-card-count")], [lustre@element:text(<<"+"/utf8, Count/binary>>)]), lustre@element:element(~"span", [lustre@attribute:class(~"adventure-card-suffix")], [lustre@element:text(Suffix)]), lustre@element:element(~"strong", [lustre@attribute:class(~"adventure-card-city")], [lustre@element:text(City)])])]).

-file("src\\nexus_agency\\router.gleam", 4436).
-spec hero_search_tab(binary(), binary(), binary(), boolean()) -> lustre@vdom@vnode:element(any()).
hero_search_tab(Q, Category, Label, Selected) ->
    Base_attrs = [lustre@attribute:class(~"group/tab flex shrink-0 cursor-pointer items-center text-sm font-medium text-neutral-500 hover:text-neutral-700 focus-visible:outline-hidden data-[selected]:text-neutral-950 lg:text-base dark:hover:text-neutral-400 dark:data-[selected]:text-neutral-100"), lustre@attribute:href(<<<<"/kategori/"/utf8, Category/binary>>/binary, Q/binary>>), lustre@attribute:attribute(~"role", ~"tab"), lustre@attribute:attribute(~"aria-selected", case Selected of
        true ->
            ~"true";

        false ->
            ~"false"
    end), lustre@attribute:attribute(~"tabindex", case Selected of
        true ->
            ~"0";

        false ->
            ~"-1"
    end)],
    Attrs = case Selected of
        true ->
            lists:append(Base_attrs, [lustre@attribute:attribute(~"data-selected", ~"")]);

        false ->
            Base_attrs
    end,
    lustre@element:element(~"a", Attrs, [lustre@element:element(~"div", [lustre@attribute:class(~"me-1.5 hidden size-2.5 rounded-full bg-neutral-950 group-data-[selected]/tab:block xl:me-2 dark:bg-neutral-100")], []), lustre@element:element(~"span", [], [lustre@element:text(Label)])]).

-file("src\\nexus_agency\\router.gleam", 4076).
-spec published_home_modules(pog:connection(), binary()) -> list(lustre@vdom@vnode:element(any())).
published_home_modules(Db, Tenant_id) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Block_type) ->
            gleam@dynamic@decode:success(Block_type)
        end)
    end,
    case begin
        _pipe = pog:'query'(~"select b.block_type from agency.page_blocks b join agency.pages p on p.id=b.page_id where p.tenant_id=$1::uuid and p.slug in ('home','home-global') and p.status='published' order by b.sort_order"),
        _pipe@1 = pog:parameter(_pipe, pog_ffi:coerce(Tenant_id)),
        _pipe@2 = pog:returning(_pipe@1, Decoder),
        pog:execute(_pipe@2, Db)
    end of
        {ok, Result} ->
            _pipe@3 = erlang:element(3, Result),
            gleam@list:map(_pipe@3, fun(Kind) ->
                lustre@element:element(~"article", [lustre@attribute:class(<<"builder-module builder-"/utf8, Kind/binary>>)], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"NEXUS SEÇKİSİ")]), lustre@element:element(~"h2", [], [lustre@element:text(case Kind of
                    ~"hero" ->
                        ~"Seyahatinizi keşfedin";

                    ~"featured_listings" ->
                        ~"Öne çıkan deneyimler";

                    ~"category_grid" ->
                        ~"Kategorilere göre keşfedin";

                    ~"trust_strip" ->
                        ~"Güvenle planlayın";

                    ~"newsletter" ->
                        ~"Yeni fırsatlardan haberdar olun";

                    _ ->
                        ~"Size ilham verecek içerikler"
                end)])])
            end);

        {error, _} ->
            []
    end.

-file("src\\nexus_agency\\router.gleam", 4774).
-spec demo_home_page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
demo_home_page(Req, Db, Origin) ->
    Demo = nexus_agency@demo_home:render(),
    case {binary:match(Demo, <<"<main ">>), binary:match(Demo, <<"</main>">>)} of
                {{Main_start, _}, {Main_end, _}} when Main_end > Main_start ->
                    Tenant_id = case gleam_stdlib:contains_string(Origin, ~"localhost") of
                        true -> ~"";
                        false -> gleam@result:unwrap(public_tenant_id(Db, Req), ~"")
                    end,
                    Csrf_token = csrf_token_for(Req),
                    Main_length = Main_end + erlang:byte_size(<<"</main>">>) - Main_start,
                    Main = nexus_agency@demo_home:rewrite_links(binary:part(Demo, Main_start, Main_length)),
                    Head = lustre@element:to_string(lustre@element:element(~"head", [], [
                        lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []),
                        lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []),
                        lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []),
                        lustre@element:element(~"title", [], [lustre@element:text(~"NEXUS Agency")]) | chisfis_head()
                    ])),
                    Header = lustre@element:to_string(public_storefront_header(Origin, Tenant_id)),
                    Footer = lustre@element:to_string(public_footer(Tenant_id)),
                    Scripts = [public_chat_script(), public_theme_script(), public_header_popovers_script()],
                    Script_html = erlang:iolist_to_binary([lustre@element:to_string(Script) || Script <- Scripts]),
                    Html = <<"<!doctype html><html lang=\"tr\">", Head/binary, "<body class=\"chisfis-home\" data-tenant=\"", Tenant_id/binary, "\">", Header/binary, Main/binary, Footer/binary, Script_html/binary, "</body></html>">>,
                    Response = wisp:set_cookie(wisp:ok(), Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
                    wisp:html_body(Response, Html);
        _ -> wisp:html_body(wisp:ok(), <<"<!doctype html><html lang=\"tr\"><body><h1>Ana sayfa geçici olarak kullanılamıyor</h1></body></html>">>)
    end.

-spec page(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
page(Req, Db, Origin) ->
    Tenant_id = case gleam_stdlib:contains_string(Origin, ~"localhost") of
        true ->
            ~"";

        false ->
            _pipe = public_tenant_id(Db, Req),
            gleam@result:unwrap(_pipe, ~"")
    end,
    Builder_modules = case Tenant_id =:= ~"" of
        true ->
            [];

        false ->
            published_home_modules(Db, Tenant_id)
    end,
    Q = public_tenant_query(Tenant_id),
    Csrf_token = csrf_token_for(Req),
    Content = lustre@element:element(~"html", [lustre@attribute:attribute(~"lang", ~"tr")], [lustre@element:element(~"head", [], [lustre@element:element(~"meta", [lustre@attribute:attribute(~"charset", ~"utf-8")], []), lustre@element:element(~"meta", [lustre@attribute:name(~"csrf-token"), lustre@attribute:attribute(~"content", Csrf_token)], []), lustre@element:element(~"meta", [lustre@attribute:name(~"viewport"), lustre@attribute:attribute(~"content", ~"width=device-width, initial-scale=1")], []), lustre@element:element(~"title", [], [lustre@element:text(~"NEXUS Agency")]) | chisfis_head()]), lustre@element:element(~"body", [lustre@attribute:class(~"chisfis-home"), lustre@attribute:attribute(~"data-tenant", Tenant_id)], [public_home_header(Origin, Tenant_id), lustre@element:element(~"main", [lustre@attribute:class(~"relative overflow-hidden")], [lustre@element:element(~"div", [lustre@attribute:class(~"absolute inset-x-0 md:top-10 xl:top-40 min-h-0 pl-20 py-24 flex overflow-hidden -z-10")], [lustre@element:element(~"span", [lustre@attribute:class(~"block h-72 w-72 rounded-full bg-[#ef233c] opacity-10 mix-blend-multiply blur-3xl filter lg:h-96 lg:w-96")], []), lustre@element:element(~"span", [lustre@attribute:class(~"nc-animation-delay-2000 mt-40 -ml-20 block h-72 w-72 rounded-full bg-[#04868b] opacity-10 mix-blend-multiply blur-3xl filter lg:h-96 lg:w-96")], [])]), lustre@element:element(~"div", [lustre@attribute:class(~"relative container mb-24 flex flex-col gap-y-24 lg:mb-28 lg:gap-y-32")], [lustre@element:element(~"div", [lustre@attribute:class(~"relative flex flex-col-reverse pt-10 lg:flex-col lg:pt-28")], [lustre@element:element(~"div", [lustre@attribute:class(~"flex flex-col lg:flex-row")], [lustre@element:element(~"div", [lustre@attribute:class(~"relative flex w-full flex-col items-start gap-y-8 pb-16 lg:pe-10 lg:pt-12 lg:pb-60 xl:gap-y-10 xl:pe-14")], [lustre@element:element(~"h1", [lustre@attribute:class(~"text-5xl/[1.15] font-medium tracking-tight text-pretty xl:text-7xl/[1.1]")], [lustre@element:text(~"Bizimle Keşfedin")]), lustre@element:element(~"p", [lustre@attribute:class(~"max-w-xl text-base text-neutral-500 sm:text-xl dark:text-neutral-400")], [lustre@element:text(~"Yurtiçi ve yurtdışı deneyimleri, konaklamayı ve ulaşımı tek yerden güvenle planlayın.")]), lustre@element:element(~"a", [lustre@attribute:class(~"sm:text-base/normal relative isolate inline-flex shrink-0 items-center justify-center gap-x-2.5 rounded-full border px-[calc(--spacing(4)-1px)] py-[calc(--spacing(2.5)-1px)] sm:px-[calc(--spacing(5)-1px)] sm:text-sm/6 border-transparent bg-neutral-950 text-white hover:bg-neutral-800 dark:bg-white dark:text-neutral-950 dark:hover:bg-neutral-200"), lustre@attribute:href(<<"/urunler"/utf8, Q/binary>>)], [lustre@element:text(~"Aramaya başla")]), lustre@element:element(~"div", [lustre@attribute:class(~"absolute start-0 bottom-4 hidden w-screen max-w-4xl lg:block xl:max-w-6xl")], [lustre@element:element(~"div", [lustre@attribute:class(~"hero-search-form")], [lustre@element:element(~"div", [], [lustre@element:element(~"div", [lustre@attribute:class(~"ms-3 mb-8 flex sm:gap-x-6 xl:ms-10 xl:gap-x-10"), lustre@attribute:attribute(~"role", ~"tablist"), lustre@attribute:attribute(~"aria-orientation", ~"horizontal")], [hero_search_tab(Q, ~"hotel", ~"Oteller", true), hero_search_tab(Q, ~"holiday_home", ~"Tatil evleri", false), hero_search_tab(Q, ~"tour", ~"Deneyimler", false), hero_search_tab(Q, ~"car", ~"Araçlar", false), hero_search_tab(Q, ~"flight", ~"Uçuşlar", false), hero_search_tab(Q, ~"bus", ~"Otobüs", false)])]), lustre@element:element(~"form", [lustre@attribute:class(~"relative z-10 flex w-full rounded-full bg-white shadow-xl dark:bg-neutral-800 dark:shadow-2xl"), lustre@attribute:attribute(~"action", <<"/urunler"/utf8, Q/binary>>), lustre@attribute:attribute(~"method", ~"get")], [lustre@element:element(~"div", [lustre@attribute:class(~"group relative z-10 flex hero-search-form__field-after flex-5/12")], [lustre@element:element(~"div", [lustre@attribute:class(~"relative z-10 shrink-0 w-full cursor-pointer flex items-center gap-x-3 focus:outline-hidden text-start px-7 py-4 xl:px-8 xl:py-6")], [lustre@element:element(~"div", [lustre@attribute:class(~"grow")], [lustre@element:element(~"input", [lustre@attribute:class(~"block w-full truncate border-none bg-transparent p-0 font-semibold placeholder-neutral-800 focus:placeholder-neutral-300 focus:ring-0 focus:outline-hidden dark:placeholder-neutral-200 text-base xl:text-lg"), lustre@attribute:name(~"konum"), lustre@attribute:attribute(~"placeholder", ~"Konum"), lustre@attribute:attribute(~"autocomplete", ~"off"), lustre@attribute:attribute(~"aria-label", ~"Nereye gidiyorsunuz?")], []), lustre@element:element(~"div", [lustre@attribute:class(~"mt-0.5 text-start text-sm font-light text-neutral-400")], [lustre@element:element(~"span", [lustre@attribute:class(~"line-clamp-1")], [lustre@element:text(~"Nereye gidiyorsunuz?")])])])])]), lustre@element:element(~"div", [lustre@attribute:class(~"group relative z-10 flex flex-5/12")], [lustre@element:element(~"div", [lustre@attribute:class(~"relative z-10 shrink-0 w-full cursor-pointer flex items-center gap-x-3 text-start px-7 py-4 xl:px-8 xl:py-6")], [lustre@element:element(~"div", [lustre@attribute:class(~"grow")], [lustre@element:element(~"input", [lustre@attribute:class(~"block w-full border-none bg-transparent p-0 font-semibold text-base xl:text-lg dark:text-white"), lustre@attribute:name(~"check_in"), lustre@attribute:attribute(~"type", ~"date"), lustre@attribute:attribute(~"aria-label", ~"Tarih")], []), lustre@element:element(~"div", [lustre@attribute:class(~"mt-0.5 text-start text-sm font-light text-neutral-400")], [lustre@element:element(~"span", [lustre@attribute:class(~"line-clamp-1")], [lustre@element:text(~"Tarihlerinizi seçin")])])])])]), lustre@element:element(~"button", [lustre@attribute:class(~"absolute z-10 top-1/2 flex -translate-y-1/2 items-center justify-center rounded-full bg-primary-600 text-neutral-50 hover:bg-primary-700 focus:outline-hidden cursor-pointer size-16 end-2 xl:end-4"), lustre@attribute:type_(~"submit"), lustre@attribute:attribute(~"aria-label", ~"Ara")], [lustre@element:element(~"svg", [lustre@attribute:class(~"size-6"), lustre@attribute:attribute(~"viewBox", ~"0 0 24 24"), lustre@attribute:attribute(~"fill", ~"none"), lustre@attribute:attribute(~"stroke", ~"currentColor"), lustre@attribute:attribute(~"stroke-width", ~"1.5")], [lustre@element:element(~"path", [lustre@attribute:attribute(~"d", ~"M17 17L21 21M19 11C19 6.58172 15.4183 3 11 3C6.58172 3 3 6.58172 3 11C3 15.4183 6.58172 19 11 19C15.4183 19 19 15.4183 19 11Z"), lustre@attribute:attribute(~"stroke-linecap", ~"round"), lustre@attribute:attribute(~"stroke-linejoin", ~"round")], [])])])])])])]), lustre@element:element(~"div", [lustre@attribute:class(~"w-full")], [lustre@element:element(~"img", [lustre@attribute:class(~"w-full"), lustre@attribute:attribute(~"src", ~"/static/chisfis/images/hero-right.webp"), lustre@attribute:attribute(~"alt", ~"Türkiye'de unutulmaz seyahat deneyimi"), lustre@attribute:attribute(~"loading", ~"eager")], [])])])])])]), lustre@element:element(~"section", [lustre@attribute:class(~"published-builder-modules")], Builder_modules), lustre@element:element(~"section", [lustre@attribute:class(~"home-trust-strip")], [lustre@element:element(~"span", [], [lustre@element:text(~"Binlerce seyahat deneyimi")]), lustre@element:element(~"span", [], [lustre@element:text(~"Güvenli rezervasyon")]), lustre@element:element(~"span", [], [lustre@element:text(~"Yerel uzman desteği")]), lustre@element:element(~"span", [], [lustre@element:text(~"Esnek iptal seçenekleri")])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-adventure")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading centered")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"MACERAYA ÇIKALIM")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Dünyanın en güzel yerlerini keşfedin")])]), lustre@element:element(~"div", [lustre@attribute:class(~"adventure-grid")], [public_adventure_card(~"/static/chisfis/images/4.0w6tqzlhplq.q.webp", ~"İstanbul, Türkiye", ~"12,500", ~"+ konaklama"), public_adventure_card(~"/static/chisfis/images/5.0-cyep_wbo5i3.webp", ~"Bodrum, Türkiye", ~"3,200", ~"+ konaklama"), public_adventure_card(~"/static/chisfis/images/6.15d7hd4mb~4yd.webp", ~"Kapadokya, Türkiye", ~"1,800", ~"+ konaklama"), public_adventure_card(~"/static/chisfis/images/HIW1.0pyy~70or-44f.webp", ~"Antalya, Türkiye", ~"8,400", ~"+ konaklama"), public_adventure_card(~"/static/chisfis/images/HIW2.webp", ~"Alanya, Türkiye", ~"4,600", ~"+ konaklama"), public_adventure_card(~"/static/chisfis/images/HIW3.10ja0mcrcg_7_.webp", ~"Fethiye, Türkiye", ~"2,900", ~"+ konaklama")]), lustre@element:element(~"div", [lustre@attribute:class(~"adventure-cta")], [lustre@element:element(~"a", [lustre@attribute:class(~"home-cta-btn"), lustre@attribute:href(<<"/urunler"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Daha fazlasını keşfet →")])])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-benefits")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading centered")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"AVANTAJLAR")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Neden bizi tercih etmelisiniz?")])]), lustre@element:element(~"div", [lustre@attribute:class(~"benefits-grid")], [public_benefit_card(~"📢", ~"Etkili reklam", ~"Ücretsiz ilan vererek kiralama mülkünüzü ön masraf olmadan tanıtabilirsiniz."), public_benefit_card(~"🌍", ~"Geniş kitle", ~"Dünya genelinde milyonlarca kişi benzersiz konaklama arıyor."), public_benefit_card(~"🔒", ~"Güvenli ve basit", ~"Chisfis ilanı, çevrimiçi rezervasyon ve ödeme için güvenli ve kolay bir yol sunar.")])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-featured")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"ÖNE ÇIKAN YERLER")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Kullanıcı yorumlarına göre seçildi")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Tümünü gör →")])]), lustre@element:element(~"div", [lustre@attribute:class(~"featured-grid")], [public_featured_card(~"/static/chisfis/images/4.0w6tqzlhplq.q.webp", ~"Oda", ~"4 Yatak", ~"Bodrum Deniz Manzaralı Süit", ~"Bodrum, Muğla", ~"₺2.800", ~"280000", ~"4.8", ~"28"), public_featured_card(~"/static/chisfis/images/5.0-cyep_wbo5i3.webp", ~"Villa", ~"6 Yatak", ~"Özel Havuzlu Tatil Evi", ~"Fethiye, Muğla", ~"₺5.200", ~"520000", ~"4.4", ~"198"), public_featured_card(~"/static/chisfis/images/6.15d7hd4mb~4yd.webp", ~"Kabin", ~"3 Yatak", ~"Dağ Evinde Huzurlu Konaklama", ~"Kapadokya, Nevşehir", ~"₺3.400", ~"340000", ~"4.9", ~"56"), public_featured_card(~"/static/chisfis/images/HIW1.0pyy~70or-44f.webp", ~"Oda", ~"2 Yatak", ~"Antalya Resort & Spa", ~"Kemer, Antalya", ~"₺4.100", ~"410000", ~"4.7", ~"340")])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-discovery")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"İLHAM ALIN")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Bir sonraki kaçamağınızı keşfedin")]), lustre@element:element(~"a", [lustre@attribute:href(<<"/urunler"/utf8, (public_tenant_query(Tenant_id))/binary>>)], [lustre@element:text(~"Tümünü gör →")])]), lustre@element:element(~"div", [lustre@attribute:class(~"discovery-grid")], [lustre@element:element(~"a", [lustre@attribute:href(<<"/kategori/hotel"/utf8, (public_tenant_query(Tenant_id))/binary>>), lustre@attribute:class(~"discovery-card discovery-card-large")], [lustre@element:element(~"span", [], [lustre@element:text(~"Otel ve resortlar")]), lustre@element:element(~"strong", [], [lustre@element:text(~"Konforu yeniden keşfedin")])]), lustre@element:element(~"a", [lustre@attribute:href(<<"/kategori/holiday_home"/utf8, (public_tenant_query(Tenant_id))/binary>>), lustre@attribute:class(~"discovery-card")], [lustre@element:element(~"span", [], [lustre@element:text(~"Tatil Evleri")]), lustre@element:element(~"strong", [], [lustre@element:text(~"Kendi alanınızda dinlenin")])]), lustre@element:element(~"a", [lustre@attribute:href(<<"/kategori/tour"/utf8, (public_tenant_query(Tenant_id))/binary>>), lustre@attribute:class(~"discovery-card")], [lustre@element:element(~"span", [], [lustre@element:text(~"Deneyimler")]), lustre@element:element(~"strong", [], [lustre@element:text(~"Yereli yaşayın")])])])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-blog"), lustre@attribute:id(~"home-blog")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"GEZİ REHBERİ")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Bir sonraki rotanıza ilham")]), lustre@element:element(~"a", [lustre@attribute:href(<<<<"/"/utf8, (public_tenant_query(Tenant_id))/binary>>/binary, "#home-blog"/utf8>>)], [lustre@element:text(~"Tüm yazılar →")])]), lustre@element:element(~"div", [lustre@attribute:class(~"home-blog-grid")], [public_home_blog_card(~"/static/chisfis/images/4.0w6tqzlhplq.q.webp", ~"Türkiye'nin en güzel rotaları", ~"Keşfedilmeyi bekleyen kıyılar, şehirler ve seyahat ipuçları."), public_home_blog_card(~"/static/chisfis/images/5.0-cyep_wbo5i3.webp", ~"Deniz ve kıyı tatil rehberi", ~"Mavi bayraklı plajlar ve sakin koylar için seçtiklerimiz."), public_home_blog_card(~"/static/chisfis/images/6.15d7hd4mb~4yd.webp", ~"Doğa kaçamakları", ~"Kamp, yürüyüş ve doğayla baş başa bir hafta sonu planı.")])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-host-cta")], [lustre@element:element(~"div", [], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"TEDARİKÇİLERE")]), lustre@element:element(~"h2", [], [lustre@element:text(~"İlanınızı ekleyin, daha çok gezgine ulaşın")]), lustre@element:element(~"p", [], [lustre@element:text(~"Otel, tur, villa, tekne veya araç hizmetinizi NEXUS ağına taşıyın; ilanınızı kolayca yönetin.")]), lustre@element:element(~"a", [lustre@attribute:class(~"primary"), lustre@attribute:href(<<Origin/binary, "/login"/utf8>>)], [lustre@element:text(~"Ücretsiz ilan ver →")])]), lustre@element:element(~"img", [lustre@attribute:attribute(~"src", ~"/static/chisfis/images/BecomeAnAuthorImg.webp"), lustre@attribute:attribute(~"alt", ~"NEXUS'a ilan ekleyin"), lustre@attribute:attribute(~"loading", ~"lazy")], [])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-testimonials")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading centered")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"MİSAFİRLERİMİZ NE DİYOR?")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Seyahat edenlerin gerçek yorumları")]), lustre@element:element(~"p", [], [lustre@element:text(~"Planını bizimle yapan gezginlerin deneyimlerinden ilham alın.")])]), lustre@element:element(~"div", [lustre@attribute:class(~"testimonial-grid")], [public_home_testimonial(~"Harika bir deneyimdi; her şey çok kolay ve şeffaftı.", ~"Ayşe K."), public_home_testimonial(~"Fiyat ve hizmet dengesi çok iyi, destek ekibi çok hızlı.", ~"Mehmet T."), public_home_testimonial(~"Rezervasyonumuz sorunsuz tamamlandı, tekrar kullanacağız.", ~"Zeynep A.")])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-how-it-works")], [lustre@element:element(~"div", [lustre@attribute:class(~"home-section-heading centered")], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"NASIL ÇALIŞIR")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Sakin olun, seyahatin keyfini çıkarın")]), lustre@element:element(~"p", [], [lustre@element:text(~"Planınızı birkaç adımda tamamlayın; gerisini uzman ekibimiz takip etsin.")])]), lustre@element:element(~"div", [lustre@attribute:class(~"home-how-grid")], [public_home_how_card(~"/static/chisfis/images/HIW1.0pyy~70or-44f.webp", ~"Rezervasyon yapın", ~"İhtiyacınıza uygun konaklama ve deneyimi seçin."), public_home_how_card(~"/static/chisfis/images/HIW2.webp", ~"Akıllı planlayın", ~"Ulaşım, transfer ve ek hizmetleri tek seferde ekleyin."), public_home_how_card(~"/static/chisfis/images/HIW3.10ja0mcrcg_7_.webp", ~"Daha çok keşfedin", ~"Güvenli ödeme ve yerel destekle yolculuğun tadını çıkarın.")])]), lustre@element:element(~"section", [lustre@attribute:class(~"home-newsletter")], [lustre@element:element(~"div", [], [lustre@element:element(~"span", [lustre@attribute:class(~"eyebrow")], [lustre@element:text(~"SEYAHAT İLHAMINI KAÇIRMAYIN")]), lustre@element:element(~"h2", [], [lustre@element:text(~"Yeni fırsatlar ve rotalar gelen kutunuzda")]), lustre@element:element(~"p", [], [lustre@element:text(~"Bölgenize özel kampanyaları ve seçilmiş seyahat fikirlerini paylaşalım.")])]), lustre@element:element(~"form", [lustre@attribute:class(~"newsletter-form"), lustre@attribute:attribute(~"action", ~"/iletisim"), lustre@attribute:attribute(~"method", ~"get")], [lustre@element:element(~"input", [lustre@attribute:name(~"email"), lustre@attribute:attribute(~"type", ~"email"), lustre@attribute:attribute(~"required", ~"required"), lustre@attribute:attribute(~"placeholder", ~"E-posta adresiniz"), lustre@attribute:attribute(~"aria-label", ~"E-posta adresiniz")], []), lustre@element:element(~"button", [lustre@attribute:class(~"primary"), lustre@attribute:attribute(~"type", ~"submit")], [lustre@element:text(~"Katıl")])])]), public_footer(Tenant_id), public_chat_script(), public_theme_script(), public_header_popovers_script()])]),
    _pipe@1 = wisp:ok(),
    _pipe@2 = wisp:set_cookie(_pipe@1, Req, ~"agency_csrf", Csrf_token, plain_text, 3600),
    wisp:html_body(_pipe@2, lustre@element:to_string(Content)).

-file("src\\nexus_agency\\router.gleam", 3369).
-spec id_decoder() -> gleam@dynamic@decode:decoder(binary()).
id_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:success(Id)
    end).

-file("src\\nexus_agency\\router.gleam", 4657).
-spec listing_sitemap_urls(pog:connection(), binary(), binary()) -> binary().
listing_sitemap_urls(Db, Origin, Tenant_id) ->
    case begin
        _pipe = ~"select id::text from agency.listings where tenant_id=$1::uuid and status='published' order by updated_at desc limit 5000",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, id_decoder()),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            _pipe@4 = erlang:element(3, Result),
            _pipe@5 = gleam@list:map(_pipe@4, fun(Id) ->
                <<<<<<<<"<url><loc>"/utf8, Origin/binary>>/binary, "/urunler/"/utf8>>/binary, Id/binary>>/binary, "</loc></url>"/utf8>>
            end),
            gleam@string:join(_pipe@5, ~"");

        {error, _} ->
            ~""
    end.

-file("src\\nexus_agency\\router.gleam", 4675).
-spec cms_sitemap_urls(pog:connection(), binary(), binary()) -> binary().
cms_sitemap_urls(Db, Origin, Tenant_id) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Slug) ->
            gleam@dynamic@decode:success(Slug)
        end)
    end,
    case begin
        _pipe = ~"select slug from agency.pages where tenant_id=$1::uuid and status='published' order by slug",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, Decoder),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            _pipe@4 = erlang:element(3, Result),
            _pipe@5 = gleam@list:map(_pipe@4, fun(Slug) ->
                <<<<<<<<"<url><loc>"/utf8, Origin/binary>>/binary, "/"/utf8>>/binary, Slug/binary>>/binary, "</loc></url>"/utf8>>
            end),
            gleam@string:join(_pipe@5, ~"");

        {error, _} ->
            ~""
    end.

-file("src\\nexus_agency\\router.gleam", 4632).
-spec category_sitemap_urls(binary()) -> binary().
category_sitemap_urls(Origin) ->
    _pipe = [~"hotel", ~"holiday_home", ~"yacht", ~"tour", ~"activity", ~"flight", ~"car", ~"cruise", ~"pilgrimage", ~"visa", ~"ferry", ~"transfer", ~"beach", ~"cinema", ~"event", ~"restaurant", ~"bus"],
    _pipe@1 = gleam@list:map(_pipe, fun(Slug) ->
        <<<<<<<<"<url><loc>"/utf8, Origin/binary>>/binary, "/kategori/"/utf8>>/binary, Slug/binary>>/binary, "</loc></url>"/utf8>>
    end),
    gleam@string:join(_pipe@1, ~"").

-file("src\\nexus_agency\\router.gleam", 9619).
-spec search_intent(gleam@http@request:request(wisp@internal:connection()), pog:connection()) -> gleam@http@response:response(wisp:body()).
search_intent(Req, Db) ->
    Raw = case begin
        _pipe = wisp:get_query(Req),
        gleam@list:key_find(_pipe, ~"q")
    end of
        {ok, Value} ->
            Value;

        {error, _} ->
            ~""
    end,
    Text = string:lowercase(Raw),
    Category = case {gleam_stdlib:contains_string(Text, ~"villa"), gleam_stdlib:contains_string(Text, ~"otel") orelse gleam_stdlib:contains_string(Text, ~"hotel"), gleam_stdlib:contains_string(Text, ~"tur") orelse gleam_stdlib:contains_string(Text, ~"safari"), gleam_stdlib:contains_string(Text, ~"aktivite") orelse gleam_stdlib:contains_string(Text, ~"dalış")} of
        {true, _, _, _} ->
            ~"holiday_home";

        {false, true, _, _} ->
            ~"hotel";

        {false, false, true, _} ->
            ~"tour";

        {false, false, false, true} ->
            ~"activity";

        {false, false, false, false} ->
            ~""
    end,
    Known_locations = [~"kaş", ~"bodrum", ~"antalya", ~"istanbul", ~"kapadokya", ~"fethiye", ~"göcek", ~"çeşme"],
    Location = case gleam@list:find(Known_locations, fun(Value@1) ->
        gleam_stdlib:contains_string(Text, Value@1)
    end) of
        {ok, Value@1} ->
            Value@1;

        {error, _} ->
            ~""
    end,
    _pipe@1 = pog:'query'(~"insert into agency.public_search_events(query_text, detected_category, detected_location) values ($1, $2, $3)"),
    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Raw)),
    _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Category)),
    _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Location)),
    _pipe@5 = pog:execute(_pipe@4, Db),
    fun(_) ->
        nil
    end(_pipe@5),
    _pipe@6 = wisp:ok(),
    wisp:json_body(_pipe@6, begin
        _pipe@7 = gleam@json:object([{~"query", gleam@json:string(Raw)}, {~"category", gleam@json:string(Category)}, {~"location", gleam@json:string(Location)}]),
        gleam@json:to_string(_pipe@7)
    end).

-file("src\\nexus_agency\\router.gleam", 9589).
-spec public_availability(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_availability(Req, Db, Listing_id) ->
    Tenant_id = begin
        _pipe = public_tenant_id(Db, Req),
        gleam@result:unwrap(_pipe, ~"")
    end,
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end,
    case begin
        _pipe@1 = pog:'query'(~"select coalesce(json_agg(json_build_object('day', a.day::text, 'available', a.units_available, 'total', a.units_total, 'closed', a.closed) order by a.day)::text, '[]') from agency.availability a join agency.listings l on l.id = a.listing_id where a.listing_id = $1::uuid and l.tenant_id=$2::uuid and l.status = 'published' and a.day >= current_date and a.day < current_date + 365"),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Listing_id)),
        _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Tenant_id)),
        _pipe@4 = pog:returning(_pipe@3, Decoder),
        pog:execute(_pipe@4, Db)
    end of
        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {ok, Payload} ->
                    _pipe@5 = wisp:ok(),
                    wisp:json_body(_pipe@5, Payload);

                {error, _} ->
                    _pipe@6 = wisp:ok(),
                    wisp:json_body(_pipe@6, ~"[]")
            end;

        {error, _} ->
            _pipe@7 = wisp:response(503),
            wisp:json_body(_pipe@7, ~"{\"error\":\"Müsaitlik okunamadı\"}")
    end.

-file("src\\nexus_agency\\router.gleam", 3104).
-spec section_links(binary()) -> list({binary(), binary()}).
section_links(Section) ->
    case Section of
        ~"catalog" ->
            [{~"/admin/catalog#catalog-workspace", ~"Yeni hizmet/ilan"}, {~"/admin/regions", ~"Bölge seç"}, {~"/admin", ~"Genel bakış"}];

        ~"listings" ->
            [{~"/admin/catalog#catalog-workspace", ~"Yeni hizmet/ilan"}, {~"/admin/regions", ~"Bölge seç"}, {~"/admin", ~"Genel bakış"}];

        ~"regions" ->
            [{~"/admin/regions#regions-workspace", ~"Yeni bölge"}, {~"/admin/catalog", ~"Kataloğa geç"}];

        ~"languages" ->
            [{~"/admin/languages", ~"Dil kayıtları"}, {~"/admin/languages", ~"AI çeviri kuyruğu"}];

        ~"currencies" ->
            [{~"/admin/currencies", ~"Para birimi kayıtları"}, {~"/admin/currencies#currency-settings", ~"Kur ayarları"}];

        ~"categories" ->
            [{~"/admin/categories#categories-workspace", ~"Yeni kategori"}, {~"/admin/regions", ~"Bölge bağlantısı"}];

        ~"cms" ->
            [{~"/admin/cms", ~"Yeni sayfa"}, {~"/admin/cms", ~"Yeni blog"}];

        ~"campaigns" ->
            [{~"/admin/campaigns", ~"Yeni kampanya"}, {~"/admin/campaigns", ~"Kuponlar"}];

        ~"supplier-campaigns" ->
            [{~"/admin/supplier-campaigns?audience=supplier#campaigns-workspace", ~"Yeni tedarikçi kampanyası"}, {~"/admin/campaigns?audience=all#campaigns-workspace", ~"Ortak kampanyalar"}];

        ~"integrations" ->
            [{~"/admin/integrations", ~"ParamPOS"}, {~"/admin/integrations", ~"OTA bağlantıları"}, {~"/admin/settings", ~"SMTP ve bildirimler"}];

        ~"ai" ->
            [{~"/admin/ai", ~"AI sağlayıcıları"}, {~"/admin/ai", ~"Alan atamaları"}, {~"/admin/ai", ~"Çeviri kuyruğu"}];

        ~"reports" ->
            [{~"/admin/reports", ~"Satış raporu"}, {~"/admin/reports", ~"Denetim logları"}, {~"/admin/reports", ~"Sistem sağlığı"}];

        ~"reservations" ->
            [{~"/admin/reservations#reservations-workspace", ~"Yeni rezervasyon"}, {~"/admin/customers", ~"Müşteriler"}];

        ~"customers" ->
            [{~"/admin/reservations", ~"Rezervasyonlar"}, {~"/admin/team", ~"Ekip"}];

        ~"team" ->
            [{~"/admin/team", ~"Ekip listesi"}, {~"/admin/settings", ~"Ayarlar"}];

        ~"settings" ->
            [{~"/admin/settings", ~"Profil ve marka ayarları"}, {~"/admin/languages", ~"Dil yönetimi"}, {~"/admin/currencies", ~"Para birimleri"}, {~"/", ~"Acente sitesini görüntüle"}];

        ~"media" ->
            [{~"/admin/catalog", ~"Katalog"}, {~"/admin", ~"Genel bakış"}];

        ~"abandoned-carts" ->
            [{~"/admin/reservations", ~"Rezervasyonlar"}, {~"/admin/customers", ~"Müşteriler"}];

        ~"sub-agencies" ->
            [{~"/admin/team", ~"Ekip ve üyeler"}, {~"/admin/reservations", ~"Rezervasyonlar"}];

        ~"popups" ->
            [{~"/admin/campaigns", ~"Kampanyalar"}, {~"/admin/cms", ~"CMS içerikleri"}];

        ~"offers" ->
            [{~"/admin/reservations", ~"Rezervasyonlar"}, {~"/admin/customers", ~"Müşteriler"}];

        ~"inquiries" ->
            [{~"/admin/inquiries/data", ~"Açık talepleri yenile"}, {~"/admin/reservations", ~"Rezervasyona dönüştür"}, {~"/admin/customers", ~"Müşteriler"}];

        ~"notifications" ->
            [{~"/admin/notifications/data", ~"Bildirimleri yenile"}, {~"/admin/inquiries", ~"Teklif talepleri"}];

        ~"search-analytics" ->
            [{~"/admin/search-analytics/data", ~"Analizi yenile"}, {~"/admin/catalog", ~"Katalogu iyileştir"}];

        _ ->
            [{~"/admin", ~"Genel bakış"}]
    end.

-file("src\\nexus_agency\\router.gleam", 3060).
-spec section_intro(binary()) -> binary().
section_intro(Section) ->
    case Section of
        ~"catalog" ->
            ~"Otel, Tatil Evi, Yat, Tur, Aktivite, Uçuş, Araç ve tüm hizmet envanterinizi yönetin.";

        ~"listings" ->
            ~"Otel, Tatil Evi, Yat, Tur, Aktivite, Uçuş, Araç ve tüm hizmet envanterinizi yönetin.";

        ~"reservations" ->
            ~"Teklif, opsiyon ve rezervasyon süreçlerini takip edin.";

        ~"customers" ->
            ~"Müşteri profilleri, talepleri ve rezervasyon geçmişi.";

        ~"regions" ->
            ~"Ülke, şehir ve alt bölgeleri SEO uyumlu olarak yönetin.";

        ~"languages" ->
            ~"Sınırsız dil ve çeviri içeriklerini yönetin.";

        ~"currencies" ->
            ~"Para birimlerini, kurları ve yüzde düzeltmelerini yönetin.";

        ~"categories" ->
            ~"Kategori, alt kategori ve zorunlu ilan alanlarını yönetin.";

        ~"cms" ->
            ~"Sayfa, blog, medya, menü ve popup içeriklerini yönetin.";

        ~"campaigns" ->
            ~"Kampanyalar, erken rezervasyon, son dakika ve indirim kuponları.";

        ~"supplier-campaigns" ->
            ~"Tedarikçilerin kendi ürünlerine tanımladığı kampanyaları ve kuponları yönetin.";

        ~"integrations" ->
            ~"ParamPOS, transfer, araç kiralama, mesajlaşma, sosyal medya ve harita bağlantıları.";

        ~"ai" ->
            ~"AI sağlayıcılarını, blog yazma ve sosyal medya otomasyonunu yönetin.";

        ~"reports" ->
            ~"Satış, rezervasyon, senkronizasyon ve denetim raporları.";

        ~"team" ->
            ~"Ekip üyelerini ve görev yetkilerini yönetin.";

        ~"settings" ->
            ~"Marka, ödeme, NEXUS bağlantısı ve bildirim ayarları.";

        ~"media" ->
            ~"Fotoğrafları düzenleyin, kırpın, filtreleyin ve WebP/AVIF formatlarına dönüştürün.";

        ~"abandoned-carts" ->
            ~"Bekleyen sepetleri izleyin, müşterilere SMS ve E-posta ile hatırlatma gönderin.";

        ~"sub-agencies" ->
            ~"B2B alt acente ve tedarikçi ağınızı, komisyonları ve yetkileri yönetin.";

        ~"popups" ->
            ~"Duyuru, kampanya, çerez onay pencereleri ve reklam banner alanlarını yönetin.";

        ~"offers" ->
            ~"Rezervasyon öncesi teklif ve onay formu oluşturun, tek tıkla WhatsApp ve E-posta ile paylaşın.";

        ~"inquiries" ->
            ~"Public vitrinden gelen müşteri teklif taleplerini takip edin ve satışa dönüştürün.";

        ~"notifications" ->
            ~"E-posta, SMS, WhatsApp ve diğer operasyon bildirimlerinin durumunu izleyin.";

        ~"search-analytics" ->
            ~"Müşterilerin aradığı konum ve ürün türlerini analiz edin.";

        _ ->
            ~"Operasyon alanını yönetin."
    end.

-file("src\\nexus_agency\\router.gleam", 3030).

-file("src\\nexus_agency\\router.gleam", 4044).
-spec offer_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
offer_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Reference_code) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Customer) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Listing) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Total_minor) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Dates_text) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                                    gleam@dynamic@decode:success({Id, Reference_code, Customer, Listing, Total_minor, Currency, Dates_text, Status})
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 4033).
-spec popup_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
popup_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Kind) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Content) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Button_text) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Delay_seconds) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                                gleam@dynamic@decode:success({Id, Title, Kind, Content, Button_text, Delay_seconds, Status})
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 4022).
-spec abandoned_cart_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
abandoned_cart_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Contact) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Count) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Total) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Updated_at) ->
                                gleam@dynamic@decode:success({Id, Name, Contact, Count, Total, Currency, Updated_at})
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3991).
-spec agency_display_name(pog:connection(), binary()) -> binary().
-doc(~" Tenant görünen adı (email/PDF başlığı) — brand_name, yoksa legal_name,
 o da yoksa \"Acente\".").
agency_display_name(Db, Tenant_id) ->
    case begin
        _pipe = ~"select coalesce(nullif(brand_name,''),nullif(legal_name,''),'Acente') from agency.tenants where id=$1::uuid",
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, gleam@dynamic@decode:at([0], {decoder, fun gleam@dynamic@decode:decode_string/1})),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            case erlang:element(3, Result) of
                [Name | _] ->
                    Name;

                _ ->
                    ~"Acente"
            end;

        {error, _} ->
            ~"Acente"
    end.

-file("src\\nexus_agency\\router.gleam", 3982).
-spec int_series(list({binary(), binary(), binary(), binary(), binary(), binary()}), fun(({binary(), binary(), binary(), binary(), binary(), binary()}) -> binary())) -> list(integer()).
int_series(Rows, Pick) ->
    gleam@list:map(Rows, fun(Row) ->
        _pipe = Pick(Row),
        _pipe@1 = gleam_stdlib:parse_int(_pipe),
        gleam@result:unwrap(_pipe@1, 0)
    end).

-file("src\\nexus_agency\\router.gleam", 3934).
-spec series_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary()}).
-doc(~" 14 günlük sparkline serisi: (etiket, published, pending, upcoming, contacts)").
series_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Label) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Published) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Pending) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Upcoming) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Contacts) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Conversion) ->
                            gleam@dynamic@decode:success({Label, Published, Pending, Upcoming, Contacts, Conversion})
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3947).
-spec fetch_series(pog:connection(), binary()) -> {ok, nexus_agency@weekly_digest:digest()} | {error, nil}.
-doc(~" Serileri çekip haftalık özete derler (dashboard/series ile aynı SQL —
 tek kaynak, çift hesap yok). JSON/PDF/email endpoint'leri ortak kullanır.").
fetch_series(Db, Tenant_id) ->
    Series_sql = <<<<<<<<<<<<<<"with days as (select generate_series(current_date - 13, current_date, interval '1 day')::date as d) "/utf8, "select to_char(d,'MM-DD') as label, "/utf8>>/binary, "(select count(*) from agency.listings l where l.tenant_id=$1::uuid and l.status='published' and l.created_at::date <= d)::text, "/utf8>>/binary, "(select count(*) from agency.reservations r where r.tenant_id=$1::uuid and r.status in ('inquiry','option') and r.created_at::date = d)::text, "/utf8>>/binary, "(select count(*) from agency.reservations r where r.tenant_id=$1::uuid and r.check_in = d + 7)::text, "/utf8>>/binary, "(select count(*) from agency.contact_requests c where c.tenant_id=$1::uuid and c.created_at::date = d)::text, "/utf8>>/binary, "(select coalesce(round(100.0*count(*) filter (where r2.status in ('confirmed','completed'))/nullif(count(*),0)),0) from agency.reservations r2 where r2.tenant_id=$1::uuid and r2.created_at::date = d)::text "/utf8>>/binary, "from days order by d"/utf8>>,
    case begin
        _pipe = Series_sql,
        _pipe@1 = pog:'query'(_pipe),
        _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
        _pipe@3 = pog:returning(_pipe@2, series_decoder()),
        pog:execute(_pipe@3, Db)
    end of
        {ok, Result} ->
            Rows = erlang:element(3, Result),
            nexus_agency@weekly_digest:build(gleam@list:map(Rows, fun(Row) ->
                erlang:element(1, Row)
            end), int_series(Rows, fun(Row) ->
                erlang:element(2, Row)
            end), int_series(Rows, fun(Row) ->
                erlang:element(3, Row)
            end), int_series(Rows, fun(Row) ->
                erlang:element(4, Row)
            end), int_series(Rows, fun(Row) ->
                erlang:element(5, Row)
            end), int_series(Rows, fun(Row) ->
                erlang:element(6, Row)
            end));

        {error, _} ->
            {error, nil}
    end.

-file("src\\nexus_agency\\router.gleam", 4008).
-spec series_array(list({binary(), binary(), binary(), binary(), binary(), binary()}), fun(({binary(), binary(), binary(), binary(), binary(), binary()}) -> binary())) -> gleam@json:json().
series_array(Rows, Pick) ->
    _pipe = Rows,
    _pipe@1 = gleam@list:map(_pipe, fun(Row) ->
        gleam@json:int(begin
            _pipe@2 = Pick(Row),
            _pipe@3 = gleam_stdlib:parse_int(_pipe@2),
            gleam@result:unwrap(_pipe@3, 0)
        end)
    end),
    gleam@json:preprocessed_array(_pipe@1).

-file("src\\nexus_agency\\router.gleam", 3924).
-spec dashboard_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
dashboard_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Published) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Pending) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Upcoming) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Contacts) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Nexus) ->
                        gleam@dynamic@decode:success({Published, Pending, Upcoming, Contacts, Nexus})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3914).
-spec report_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary()}).
report_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Published) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Reservations) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Customers) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Contacts) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Tasks) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Audits) ->
                            gleam@dynamic@decode:success({Published, Reservations, Customers, Contacts, Tasks, Audits})
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3893).
-spec team_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
team_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Email) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Membership) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Login) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Created_at) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Permissions) ->
                                    gleam@dynamic@decode:success({Id, Name, Email, Membership, Status, Login, Created_at, Permissions})
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3887).
-spec campaign_data_decoder() -> gleam@dynamic@decode:decoder({binary(), binary()}).
campaign_data_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Campaigns) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Coupons) ->
            gleam@dynamic@decode:success({Campaigns, Coupons})
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3871).
-spec ai_provider_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary()}).
ai_provider_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Provider) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Model) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Configured) ->
                    gleam@dynamic@decode:success({Provider, Model, Status, Configured})
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3879).
-spec supervisor_status_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary()}).
supervisor_status_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Queued) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Failed) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Checked_at) ->
                    gleam@dynamic@decode:success({Status, Queued, Failed, Checked_at})
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3474).
-spec ai_pool_data_decoder() -> gleam@dynamic@decode:decoder(binary()).
ai_pool_data_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Data) ->
        gleam@dynamic@decode:success(Data)
    end).

-file("src\\nexus_agency\\router.gleam", 4072).
-spec form_bool(list({binary(), binary()}), binary()) -> boolean().
form_bool(Values, Key) ->
    form_value(Values, Key) =:= ~"true".

-file("src\\nexus_agency\\router.gleam", 3510).
-spec save_ai_pool_key(pog:connection(), binary(), binary(), binary(), binary(), binary(), integer(), integer(), boolean()) -> nil.
save_ai_pool_key(Db, Tenant_id, Provider, Label, Api_key, Model, Priority, Daily_limit, Active) ->
    Safe_limit = case Daily_limit < 0 of
        true ->
            0;

        false ->
            Daily_limit
    end,
    _pipe = ~"INSERT INTO agency.ai_key_pool(tenant_id,provider,label,api_key_encrypted,model,priority,daily_limit,active,updated_at) VALUES($1::uuid,$2,$3,$4,$5,$6,$7,$8,now()) ON CONFLICT(tenant_id,provider,label) DO UPDATE SET api_key_encrypted=case when excluded.api_key_encrypted='' then agency.ai_key_pool.api_key_encrypted else excluded.api_key_encrypted end,model=case when excluded.model='' then agency.ai_key_pool.model else excluded.model end,priority=excluded.priority,daily_limit=excluded.daily_limit,active=excluded.active,updated_at=now()",
    _pipe@1 = pog:'query'(_pipe),
    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
    _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Provider)),
    _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Label)),
    _pipe@5 = pog:parameter(_pipe@4, pog_ffi:coerce(Api_key)),
    _pipe@6 = pog:parameter(_pipe@5, pog_ffi:coerce(Model)),
    _pipe@7 = pog:parameter(_pipe@6, pog_ffi:coerce(Priority)),
    _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Safe_limit)),
    _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Active)),
    _pipe@10 = pog:execute(_pipe@9, Db),
    fun(_) ->
        nil
    end(_pipe@10).

-file("src\\nexus_agency\\router.gleam", 3854).
-spec page_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary()}).
page_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Slug) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Template) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Seo_title) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Published_at) ->
                            gleam@dynamic@decode:success({Id, Slug, Template, Status, Seo_title, Published_at})
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3849).
-spec integration_test_decoder() -> gleam@dynamic@decode:decoder(binary()).
integration_test_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
        gleam@dynamic@decode:success(Value)
    end).

-file("src\\nexus_agency\\router.gleam", 3841).
-spec integration_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary()}).
integration_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Provider) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Kind) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Configured) ->
                    gleam@dynamic@decode:success({Provider, Kind, Status, Configured})
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3494).
-spec connection_result_json(boolean(), binary(), binary()) -> binary().
connection_result_json(Ok, Key, Value) ->
    _pipe = gleam@json:object([{~"ok", gleam@json:bool(Ok)}, {Key, gleam@json:string(Value)}]),
    gleam@json:to_string(_pipe).

-file("src\\nexus_agency\\router.gleam", 3487).
-spec connection_request_id(binary()) -> binary().
connection_request_id(Raw) ->
    case gleam@string:split(Raw, ~"\"requestId\":\"") of
        [_, Tail] ->
            _pipe = gleam@list:first(gleam@string:split(Tail, ~"\"")),
            gleam@result:unwrap(_pipe, ~"");

        _ ->
            ~""
    end.

-file("src\\nexus_agency\\router.gleam", 4017).
-spec settings_decoder() -> gleam@dynamic@decode:decoder(binary()).
settings_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Settings) ->
        gleam@dynamic@decode:success(Settings)
    end).

-file("src\\nexus_agency\\router.gleam", 3403).
-spec save_setting(pog:connection(), binary(), binary(), binary()) -> nil.
save_setting(Db, Tenant_id, Key, Value) ->
    _pipe = ~"INSERT INTO agency.settings(tenant_id,key,value,updated_at) VALUES($1::uuid,$2,to_jsonb($3::text),now()) ON CONFLICT(tenant_id,key) DO UPDATE SET value=excluded.value,updated_at=now()",
    _pipe@1 = pog:'query'(_pipe),
    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Tenant_id)),
    _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Key)),
    _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Value)),
    _pipe@5 = pog:execute(_pipe@4, Db),
    fun(_) ->
        nil
    end(_pipe@5).

-file("src\\nexus_agency\\router.gleam", 3374).
-spec options_decoder() -> gleam@dynamic@decode:decoder({binary(), binary()}).
options_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Listings) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Customers) ->
            gleam@dynamic@decode:success({Listings, Customers})
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 9705).
-spec convert_inquiry(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
convert_inquiry(Req, Db, Tenant_id) ->
    wisp:require_form(Req, fun(Form) ->
        Inquiry_id = form_value(erlang:element(2, Form), ~"id"),
        case Inquiry_id =:= ~"" of
            true ->
                _pipe = wisp:response(400),
                wisp:string_body(_pipe, ~"Talep kimliği zorunludur");

            false ->
                Result = begin
                    _pipe@1 = pog:'query'(~"select coalesce(agency.convert_public_inquiry($1::uuid,$2::uuid),'')"),
                    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Inquiry_id)),
                    _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Tenant_id)),
                    _pipe@4 = pog:returning(_pipe@3, id_decoder()),
                    pog:execute(_pipe@4, Db)
                end,
                case Result of
                    {ok, Query_result} ->
                        case gleam@list:first(erlang:element(3, Query_result)) of
                            {ok, Reference} ->
                                case Reference =:= ~"" of
                                    true ->
                                        _pipe@5 = wisp:response(409),
                                        wisp:string_body(_pipe@5, ~"Talep rezervasyona dönüştürülemedi");

                                    false ->
                                        wisp:redirect(~"/admin/inquiries")
                                end;

                            {error, _} ->
                                _pipe@6 = wisp:response(409),
                                wisp:string_body(_pipe@6, ~"Talep rezervasyona dönüştürülemedi")
                        end;

                    {error, _} ->
                        _pipe@7 = wisp:response(409),
                        wisp:string_body(_pipe@7, ~"Talep rezervasyona dönüştürülemedi")
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 9672).
-spec update_inquiry_status(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
update_inquiry_status(Req, Db, Tenant_id) ->
    wisp:require_form(Req, fun(Form) ->
        Inquiry_id = form_value(erlang:element(2, Form), ~"id"),
        Status = form_value(erlang:element(2, Form), ~"status"),
        Valid_status = (((Status =:= ~"new") orelse (Status =:= ~"contacted")) orelse (Status =:= ~"converted")) orelse (Status =:= ~"closed"),
        case (Inquiry_id =:= ~"") orelse not Valid_status of
            true ->
                _pipe = wisp:response(400),
                wisp:string_body(_pipe, ~"Geçersiz talep veya durum");

            false ->
                Result = begin
                    _pipe@1 = pog:'query'(~"update agency.public_inquiries i set status = $1 where i.id = $2::uuid and i.tenant_id = $3::uuid"),
                    _pipe@2 = pog:parameter(_pipe@1, pog_ffi:coerce(Status)),
                    _pipe@3 = pog:parameter(_pipe@2, pog_ffi:coerce(Inquiry_id)),
                    _pipe@4 = pog:parameter(_pipe@3, pog_ffi:coerce(Tenant_id)),
                    pog:execute(_pipe@4, Db)
                end,
                case Result of
                    {ok, _} ->
                        wisp:redirect(~"/admin/inquiries");

                    {error, _} ->
                        _pipe@5 = wisp:response(503),
                        wisp:string_body(_pipe@5, ~"Talep durumu güncellenemedi")
                end
        end
    end).

-file("src\\nexus_agency\\router.gleam", 9566).
-spec search_analytics_data(pog:connection()) -> gleam@http@response:response(wisp:body()).
search_analytics_data(Db) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end,
    case begin
        _pipe = pog:'query'(~"select coalesce(json_agg(x order by x.searches desc)::text, '[]') from (select detected_category category, detected_location location, count(*) searches from agency.public_search_events where created_at >= now() - interval '30 days' group by detected_category, detected_location limit 100) x"),
        _pipe@1 = pog:returning(_pipe, Decoder),
        pog:execute(_pipe@1, Db)
    end of
        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {ok, Payload} ->
                    _pipe@2 = wisp:ok(),
                    wisp:json_body(_pipe@2, Payload);

                {error, _} ->
                    _pipe@3 = wisp:ok(),
                    wisp:json_body(_pipe@3, ~"[]")
            end;

        {error, _} ->
            _pipe@4 = wisp:response(503),
            wisp:json_body(_pipe@4, ~"{\"error\":\"Arama analitiği okunamadı\"}")
    end.

-file("src\\nexus_agency\\router.gleam", 9542).
-spec notifications_data(pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
notifications_data(Db, Tenant_id) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end,
    case begin
        _pipe = pog:'query'(~"select coalesce(json_agg(x order by x.created_at desc)::text, '[]') from (select id::text, channel, template, status, coalesce(payload->>'email',payload->>'phone','') recipient, created_at::text, attempts, coalesce(last_error,'') last_error, coalesce(scheduled_at::text,'') scheduled_at, coalesce(sent_at::text,'') sent_at from agency.notifications where tenant_id = $1::uuid order by created_at desc limit 200) x"),
        _pipe@1 = pog:parameter(_pipe, pog_ffi:coerce(Tenant_id)),
        _pipe@2 = pog:returning(_pipe@1, Decoder),
        pog:execute(_pipe@2, Db)
    end of
        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {ok, Payload} ->
                    _pipe@3 = wisp:ok(),
                    wisp:json_body(_pipe@3, Payload);

                {error, _} ->
                    _pipe@4 = wisp:ok(),
                    wisp:json_body(_pipe@4, ~"[]")
            end;

        {error, _} ->
            _pipe@5 = wisp:response(503),
            wisp:json_body(_pipe@5, ~"{\"error\":\"Bildirimler okunamadı\"}")
    end.

-file("src\\nexus_agency\\router.gleam", 9519).
-spec public_inquiries_data(pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
public_inquiries_data(Db, Tenant_id) ->
    Decoder = begin
        gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end,
    case begin
        _pipe = pog:'query'(~"select coalesce(json_agg(x order by x.created_at desc)::text, '[]') from (select i.id::text, i.listing_id::text, i.full_name, i.email, i.phone, i.message, i.status, i.check_in::text, i.check_out::text, i.guest_count, i.created_at::text, coalesce(l.title,'') listing_title from agency.public_inquiries i left join agency.listings l on l.id=i.listing_id where i.status <> 'closed' and i.tenant_id = $1::uuid limit 200) x"),
        _pipe@1 = pog:parameter(_pipe, pog_ffi:coerce(Tenant_id)),
        _pipe@2 = pog:returning(_pipe@1, Decoder),
        pog:execute(_pipe@2, Db)
    end of
        {ok, Result} ->
            case gleam@list:first(erlang:element(3, Result)) of
                {ok, Payload} ->
                    _pipe@3 = wisp:ok(),
                    wisp:json_body(_pipe@3, Payload);

                {error, _} ->
                    _pipe@4 = wisp:ok(),
                    wisp:json_body(_pipe@4, ~"[]")
            end;

        {error, _} ->
            _pipe@5 = wisp:response(503),
            wisp:json_body(_pipe@5, ~"{\"error\":\"Talepler okunamadı\"}")
    end.

-file("src\\nexus_agency\\router.gleam", 3342).
-spec reservation_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
reservation_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Reference) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Listing) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Customer) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Check_in) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Check_out) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Guests) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Total) ->
                                    gleam@dynamic@decode:field(8, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                                        gleam@dynamic@decode:field(9, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                                            gleam@dynamic@decode:field(10, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Payment_status) ->
                                                gleam@dynamic@decode:success({Id, Reference, Listing, Customer, Check_in, Check_out, Guests, Total, Currency, Status, Payment_status})
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3220).
-spec customer_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
customer_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Email) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Phone) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Created_at) ->
                        gleam@dynamic@decode:success({Id, Name, Email, Phone, Created_at})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3239).
-spec language_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary()}).
language_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Code) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Native_name) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Default_label) ->
                        gleam@dynamic@decode:success({Code, Name, Native_name, Status, Default_label})
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3321).
-spec category_field_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
category_field_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Category) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Category_code) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Key) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Label) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Field_type) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Required) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Sort_order) ->
                                    gleam@dynamic@decode:success({Id, Category, Category_code, Key, Label, Field_type, Required, Sort_order})
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3300).
-spec category_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary(), binary(), binary()}).
category_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Parent) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Code) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Slug) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Description) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Sort_order) ->
                                    gleam@dynamic@decode:success({Id, Parent, Code, Name, Slug, Description, Status, Sort_order})
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3294).
-spec listing_operations_decoder() -> gleam@dynamic@decode:decoder({binary(), binary()}).
listing_operations_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Rates) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Availability) ->
            gleam@dynamic@decode:success({Rates, Availability})
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 3265).
-spec listing_decoder() -> gleam@dynamic@decode:decoder(catalog_listing_item()).
listing_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Code) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Category) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Title) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Locality) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Currency) ->
                            gleam@dynamic@decode:field(6, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Price_minor) ->
                                gleam@dynamic@decode:field(7, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                                    gleam@dynamic@decode:field(8, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Description) ->
                                        gleam@dynamic@decode:field(9, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Images) ->
                                            gleam@dynamic@decode:field(10, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Amenities) ->
                                                gleam@dynamic@decode:field(11, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Metadata) ->
                                                    gleam@dynamic@decode:success({catalog_listing_item, Id, Code, Category, Title, Locality, Currency, Price_minor, Status, Description, Images, Amenities, Metadata})
                                                end)
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 10335).
-spec keywords_json(binary()) -> gleam@json:json().
keywords_json(Value) ->
    _pipe = Value,
    _pipe@1 = gleam@string:split(_pipe, ~","),
    _pipe@2 = gleam@list:map(_pipe@1, fun gleam@string:trim/1),
    _pipe@3 = gleam@list:filter(_pipe@2, fun(Item) ->
        Item /= ~""
    end),
    gleam@json:array(_pipe@3, fun gleam@json:string/1).

-file("src\\nexus_agency\\router.gleam", 10343).
-spec slug_from_title(binary()) -> binary().
slug_from_title(Value) ->
    _pipe = Value,
    _pipe@1 = string:lowercase(_pipe),
    _pipe@2 = gleam@string:replace(_pipe@1, ~"ç", ~"c"),
    _pipe@3 = gleam@string:replace(_pipe@2, ~"ğ", ~"g"),
    _pipe@4 = gleam@string:replace(_pipe@3, ~"ı", ~"i"),
    _pipe@5 = gleam@string:replace(_pipe@4, ~"ö", ~"o"),
    _pipe@6 = gleam@string:replace(_pipe@5, ~"ş", ~"s"),
    _pipe@7 = gleam@string:replace(_pipe@6, ~"ü", ~"u"),
    _pipe@8 = gleam@string:replace(_pipe@7, ~" ", ~"-"),
    _pipe@9 = gleam@string:replace(_pipe@8, ~"/", ~"-"),
    _pipe@10 = gleam@string:replace(_pipe@9, ~"&", ~"-"),
    _pipe@11 = gleam@string:replace(_pipe@10, ~"?", ~""),
    gleam@string:replace(_pipe@11, ~".", ~"").

-file("src\\nexus_agency\\router.gleam", 3724).
-spec generate_seo_from_pool(pog:connection(), binary(), list(ai_pool_key()), binary(), binary(), binary()) -> {ok, {binary(), binary(), binary()}} | {error, binary()}.
generate_seo_from_pool(Db, Tenant_id, Pool, Category, Title, Description) ->
    case Pool of
        [] ->
            {error, ai_pool_exhausted_error()};

        [{ai_pool_key, Id, Cfg} | Rest] ->
            case nexus_agency@ai_client:generate_seo(Cfg, Category, Title, Description) of
                {ok, Value} ->
                    ai_pool_mark_success(Db, Tenant_id, Id),
                    {ok, Value};

                {error, Error} ->
                    ai_pool_mark_failure(Db, Tenant_id, Id, Error),
                    generate_seo_from_pool(Db, Tenant_id, Rest, Category, Title, Description)
            end
    end.

-file("src\\nexus_agency\\router.gleam", 3707).
-spec generate_seo_with_pool(pog:connection(), binary(), binary(), binary(), binary()) -> {ok, {binary(), binary(), binary()}} | {error, binary()}.
generate_seo_with_pool(Db, Tenant_id, Category, Title, Description) ->
    generate_seo_from_pool(Db, Tenant_id, get_tenant_ai_pool(Db, Tenant_id), Category, Title, Description).

-file("src\\nexus_agency\\router.gleam", 10260).
-spec generate_title_from_pool(pog:connection(), binary(), list(ai_pool_key()), binary(), binary(), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
generate_title_from_pool(Db, Tenant_id, Pool, Context, Title, Description, Action, Custom_prompt) ->
    case Pool of
        [] ->
            {error, ai_pool_exhausted_error()};

        [{ai_pool_key, Id, Cfg} | Rest] ->
            Style = case Action of
                ~"luxury" ->
                    ~"lüks ve seçkin";

                ~"seo" ->
                    ~"arama niyeti ve SEO odaklı";

                ~"catchy" ->
                    ~"dikkat çekici ve dönüşüm odaklı";

                ~"short" ->
                    ~"kısa ve net";

                ~"custom" ->
                    gleam@string:trim(Custom_prompt);

                _ ->
                    ~"doğal, güven veren ve ilham verici"
            end,
            System = <<<<<<<<"Sen seyahat sektöründe kıdemli bir editörsün. "/utf8, "İlan başlığını "/utf8>>/binary, Style/binary>>/binary, " bir biçimde yeniden yaz. Yalnızca tek satır başlık döndür; HTML, emoji, tırnak, fiyat veya doğrulanmamış özellik ekleme. "/utf8>>/binary, "Başlıktaki gerçek konum ve ürün türünü koru."/utf8>>,
            User = <<<<<<<<<<"Kategori/bağlam: "/utf8, Context/binary>>/binary, "\nMevcut başlık: "/utf8>>/binary, Title/binary>>/binary, "\nAçıklama (gerçek bilgiler için):\n"/utf8>>/binary, (gleam@string:slice(Description, 0, 800))/binary>>,
            case nexus_agency@ai_client:call_llm(Cfg, System, User) of
                {ok, Value} ->
                    Clean = gleam@string:trim(Value),
                    case Clean =:= ~"" of
                        true ->
                            ai_pool_mark_failure(Db, Tenant_id, Id, ~"empty_ai_response"),
                            generate_title_from_pool(Db, Tenant_id, Rest, Context, Title, Description, Action, Custom_prompt);

                        false ->
                            ai_pool_mark_success(Db, Tenant_id, Id),
                            {ok, gleam@string:slice(Clean, 0, 160)}
                    end;

                {error, Error} ->
                    ai_pool_mark_failure(Db, Tenant_id, Id, Error),
                    generate_title_from_pool(Db, Tenant_id, Rest, Context, Title, Description, Action, Custom_prompt)
            end
    end.

-file("src\\nexus_agency\\router.gleam", 10239).
-spec generate_title_with_pool(pog:connection(), binary(), binary(), binary(), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
generate_title_with_pool(Db, Tenant_id, Context, Title, Description, Action, Custom_prompt) ->
    generate_title_from_pool(Db, Tenant_id, get_tenant_ai_pool(Db, Tenant_id), Context, Title, Description, Action, Custom_prompt).

-file("src\\nexus_agency\\router.gleam", 10190).
-spec handle_ai_content_enhance(pog:connection(), binary(), binary(), binary(), binary(), binary(), binary(), binary()) -> {ok, gleam@json:json()} | {error, binary()}.
handle_ai_content_enhance(Db, Tenant_id, Mode, Context, Raw_title, Raw_desc, Action, Prompt) ->
    Title = case gleam@string:trim(Raw_title) of
        ~"" ->
            ~"Özel Destinasyon";

        Value ->
            Value
    end,
    case Mode of
        ~"title" ->
            _pipe = generate_title_with_pool(Db, Tenant_id, Context, Title, Raw_desc, Action, Prompt),
            gleam@result:map(_pipe, fun(Value@1) ->
                gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"title", gleam@json:string(Value@1)}])
            end);

        ~"seo" ->
            case generate_seo_with_pool(Db, Tenant_id, Context, Title, Raw_desc) of
                {ok, {Seo_title, Seo_description, Keywords}} ->
                    {ok, gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"seo_title", gleam@json:string(Seo_title)}, {~"seo_description", gleam@json:string(Seo_description)}, {~"slug", gleam@json:string(slug_from_title(Seo_title))}, {~"keywords", keywords_json(Keywords)}])};

                {error, Error} ->
                    {error, Error}
            end;

        _ ->
            {error, ~"Geçersiz AI içerik modu."}
    end.

-file("src\\nexus_agency\\router.gleam", 3818).
-spec translate_all_from_pool(pog:connection(), binary(), list(ai_pool_key()), binary(), binary()) -> {ok, binary()} | {error, binary()}.
translate_all_from_pool(Db, Tenant_id, Pool, Title, Description) ->
    case Pool of
        [] ->
            {error, ai_pool_exhausted_error()};

        [{ai_pool_key, Id, Cfg} | Rest] ->
            case nexus_agency@ai_client:translate_listing_all(Cfg, Title, Description) of
                {ok, Value} ->
                    ai_pool_mark_success(Db, Tenant_id, Id),
                    {ok, Value};

                {error, Error} ->
                    ai_pool_mark_failure(Db, Tenant_id, Id, Error),
                    translate_all_from_pool(Db, Tenant_id, Rest, Title, Description)
            end
    end.

-file("src\\nexus_agency\\router.gleam", 3803).
-spec translate_all_with_pool(pog:connection(), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
translate_all_with_pool(Db, Tenant_id, Title, Description) ->
    translate_all_from_pool(Db, Tenant_id, get_tenant_ai_pool(Db, Tenant_id), Title, Description).

-file("src\\nexus_agency\\router.gleam", 3772).
-spec translate_from_pool(pog:connection(), binary(), list(ai_pool_key()), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
translate_from_pool(Db, Tenant_id, Pool, Content, Source_lang, Target_lang) ->
    case Pool of
        [] ->
            {error, ai_pool_exhausted_error()};

        [{ai_pool_key, Id, Cfg} | Rest] ->
            case nexus_agency@ai_client:translate_content(Cfg, Content, Source_lang, Target_lang) of
                {ok, Value} ->
                    ai_pool_mark_success(Db, Tenant_id, Id),
                    {ok, Value};

                {error, Error} ->
                    ai_pool_mark_failure(Db, Tenant_id, Id, Error),
                    translate_from_pool(Db, Tenant_id, Rest, Content, Source_lang, Target_lang)
            end
    end.

-file("src\\nexus_agency\\router.gleam", 3755).
-spec translate_with_pool(pog:connection(), binary(), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
translate_with_pool(Db, Tenant_id, Content, Source_lang, Target_lang) ->
    translate_from_pool(Db, Tenant_id, get_tenant_ai_pool(Db, Tenant_id), Content, Source_lang, Target_lang).

-file("src\\nexus_agency\\router.gleam", 3672).
-spec generate_description_from_pool(pog:connection(), binary(), list(ai_pool_key()), binary(), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
generate_description_from_pool(Db, Tenant_id, Pool, Category, Title, Attributes, Lang) ->
    case Pool of
        [] ->
            {error, ai_pool_exhausted_error()};

        [{ai_pool_key, Id, Cfg} | Rest] ->
            case nexus_agency@ai_client:generate_description(Cfg, Category, Title, Attributes, Lang) of
                {ok, Value} ->
                    ai_pool_mark_success(Db, Tenant_id, Id),
                    {ok, Value};

                {error, Error} ->
                    ai_pool_mark_failure(Db, Tenant_id, Id, Error),
                    generate_description_from_pool(Db, Tenant_id, Rest, Category, Title, Attributes, Lang)
            end
    end.

-file("src\\nexus_agency\\router.gleam", 3653).
-spec generate_description_with_pool(pog:connection(), binary(), binary(), binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
generate_description_with_pool(Db, Tenant_id, Category, Title, Attributes, Lang) ->
    generate_description_from_pool(Db, Tenant_id, get_tenant_ai_pool(Db, Tenant_id), Category, Title, Attributes, Lang).

-file("src\\nexus_agency\\router.gleam", 9741).
-spec handle_ai_import_listing(binary(), binary(), binary()) -> gleam@json:json().
handle_ai_import_listing(Raw_url, Raw_text, Raw_category) ->
    Combined = string:lowercase(<<<<<<<<Raw_url/binary, " "/utf8>>/binary, Raw_text/binary>>/binary, " "/utf8>>/binary, Raw_category/binary>>),
    Is_hotel = ((gleam_stdlib:contains_string(Combined, ~"otel") orelse gleam_stdlib:contains_string(Combined, ~"hotel")) orelse gleam_stdlib:contains_string(Combined, ~"resort")) orelse gleam_stdlib:contains_string(Combined, ~"pansiyon"),
    Is_villa = (gleam_stdlib:contains_string(Combined, ~"villa") orelse gleam_stdlib:contains_string(Combined, ~"tatil evi")) orelse gleam_stdlib:contains_string(Combined, ~"bungalov"),
    Is_yacht = ((gleam_stdlib:contains_string(Combined, ~"yat") orelse gleam_stdlib:contains_string(Combined, ~"gulet")) orelse gleam_stdlib:contains_string(Combined, ~"tekne")) orelse gleam_stdlib:contains_string(Combined, ~"katamaran"),
    Is_tour = (gleam_stdlib:contains_string(Combined, ~"tur") orelse gleam_stdlib:contains_string(Combined, ~"safari")) orelse gleam_stdlib:contains_string(Combined, ~"rafting"),
    Is_activity = (gleam_stdlib:contains_string(Combined, ~"aktivite") orelse gleam_stdlib:contains_string(Combined, ~"yamaç")) orelse gleam_stdlib:contains_string(Combined, ~"dalış"),
    Is_transfer = gleam_stdlib:contains_string(Combined, ~"transfer") orelse gleam_stdlib:contains_string(Combined, ~"vip transfer"),
    Is_car = (gleam_stdlib:contains_string(Combined, ~"araç") orelse gleam_stdlib:contains_string(Combined, ~"araba")) orelse gleam_stdlib:contains_string(Combined, ~"rent a car"),
    Is_ferry = gleam_stdlib:contains_string(Combined, ~"feribot") orelse gleam_stdlib:contains_string(Combined, ~"ferry"),
    Cat = case {Is_hotel, Is_villa, Is_yacht, Is_tour, Is_activity, Is_transfer, Is_car, Is_ferry} of
        {true, _, _, _, _, _, _, _} ->
            ~"hotel";

        {_, true, _, _, _, _, _, _} ->
            ~"holiday_home";

        {_, _, true, _, _, _, _, _} ->
            ~"yacht";

        {_, _, _, true, _, _, _, _} ->
            ~"tour";

        {_, _, _, _, true, _, _, _} ->
            ~"activity";

        {_, _, _, _, _, true, _, _} ->
            ~"transfer";

        {_, _, _, _, _, _, true, _} ->
            ~"car";

        {_, _, _, _, _, _, _, true} ->
            ~"ferry";

        {_, _, _, _, _, _, _, _} ->
            case Raw_category of
                ~"" ->
                    ~"hotel";

                C ->
                    C
            end
    end,
    Is_yalikavak = gleam_stdlib:contains_string(Combined, ~"yalıkavak") orelse gleam_stdlib:contains_string(Combined, ~"yalikavak"),
    Is_bodrum = ((gleam_stdlib:contains_string(Combined, ~"bodrum") orelse gleam_stdlib:contains_string(Combined, ~"türkbükü")) orelse gleam_stdlib:contains_string(Combined, ~"gümüşlük")) orelse gleam_stdlib:contains_string(Combined, ~"torba"),
    Is_kalkan = gleam_stdlib:contains_string(Combined, ~"kalkan") orelse gleam_stdlib:contains_string(Combined, ~"islamlar"),
    Is_kas = gleam_stdlib:contains_string(Combined, ~"kaş") orelse gleam_stdlib:contains_string(Combined, ~"kas"),
    Is_oludeniz = (gleam_stdlib:contains_string(Combined, ~"ölüdeniz") orelse gleam_stdlib:contains_string(Combined, ~"oludeniz")) orelse gleam_stdlib:contains_string(Combined, ~"fethiye"),
    Is_gocek = gleam_stdlib:contains_string(Combined, ~"göcek") orelse gleam_stdlib:contains_string(Combined, ~"gocek"),
    Is_alacati = ((gleam_stdlib:contains_string(Combined, ~"alaçatı") orelse gleam_stdlib:contains_string(Combined, ~"alacati")) orelse gleam_stdlib:contains_string(Combined, ~"çeşme")) orelse gleam_stdlib:contains_string(Combined, ~"cesme"),
    Is_kapadokya = ((gleam_stdlib:contains_string(Combined, ~"kapadokya") orelse gleam_stdlib:contains_string(Combined, ~"göreme")) orelse gleam_stdlib:contains_string(Combined, ~"goreme")) orelse gleam_stdlib:contains_string(Combined, ~"uçhisar"),
    Is_sapanca = gleam_stdlib:contains_string(Combined, ~"sapanca") orelse gleam_stdlib:contains_string(Combined, ~"kırkpınar"),
    Is_antalya = (gleam_stdlib:contains_string(Combined, ~"antalya") orelse gleam_stdlib:contains_string(Combined, ~"kemer")) orelse gleam_stdlib:contains_string(Combined, ~"belek"),
    Is_istanbul = gleam_stdlib:contains_string(Combined, ~"istanbul") orelse gleam_stdlib:contains_string(Combined, ~"boğaz"),
    {Locality, City_name} = case {Is_yalikavak, Is_bodrum, Is_kalkan, Is_kas, Is_oludeniz, Is_gocek, Is_alacati, Is_kapadokya, Is_sapanca, Is_antalya, Is_istanbul} of
        {true, _, _, _, _, _, _, _, _, _, _} ->
            {~"Yalıkavak, Bodrum, Muğla", ~"Bodrum Yalıkavak"};

        {_, true, _, _, _, _, _, _, _, _, _} ->
            {~"Torba / Bodrum Merkez, Muğla", ~"Bodrum"};

        {_, _, true, _, _, _, _, _, _, _, _} ->
            {~"Kalkan, Kaş, Antalya", ~"Kalkan"};

        {_, _, _, true, _, _, _, _, _, _, _} ->
            {~"Kaş Merkez, Antalya", ~"Kaş"};

        {_, _, _, _, true, _, _, _, _, _, _} ->
            {~"Ölüdeniz, Fethiye, Muğla", ~"Fethiye Ölüdeniz"};

        {_, _, _, _, _, true, _, _, _, _, _} ->
            {~"Göcek Koyu, Fethiye, Muğla", ~"Göcek"};

        {_, _, _, _, _, _, true, _, _, _, _} ->
            {~"Alaçatı, Çeşme, İzmir", ~"Alaçatı"};

        {_, _, _, _, _, _, _, true, _, _, _} ->
            {~"Göreme, Kapadokya, Nevşehir", ~"Kapadokya"};

        {_, _, _, _, _, _, _, _, true, _, _} ->
            {~"Kırkpınar, Sapanca, Sakarya", ~"Sapanca"};

        {_, _, _, _, _, _, _, _, _, true, _} ->
            {~"Belek / Kemer, Antalya", ~"Antalya Belek"};

        {_, _, _, _, _, _, _, _, _, _, true} ->
            {~"Beşiktaş, İstanbul", ~"İstanbul"};

        {_, _, _, _, _, _, _, _, _, _, _} ->
            {~"Muğla / Antalya, Türkiye", ~"Ege & Akdeniz"}
    end,
    Code_prefix = case Cat of
        ~"holiday_home" ->
            ~"VIL-";

        ~"yacht" ->
            ~"YAT-";

        ~"tour" ->
            ~"TUR-";

        ~"activity" ->
            ~"AKT-";

        ~"transfer" ->
            ~"TRF-";

        ~"car" ->
            ~"ARC-";

        _ ->
            ~"HTL-"
    end,
    Random_suffix = string:uppercase(wisp:random_string(4)),
    Code = <<Code_prefix/binary, Random_suffix/binary>>,
    Hotel_room_types = [gleam@json:object([{~"id", gleam@json:string(~"1")}, {~"title", gleam@json:string(~"Standart Kara / Bahçe Manzaralı Oda")}, {~"size_m2", gleam@json:string(~"28")}, {~"adults", gleam@json:string(~"2")}, {~"children", gleam@json:string(~"1")}, {~"bed", gleam@json:string(~"1 Çift Kişilik")}, {~"view_type", gleam@json:string(~"Kara / Bahçe")}, {~"count", gleam@json:string(~"80")}]), gleam@json:object([{~"id", gleam@json:string(~"2")}, {~"title", gleam@json:string(~"Deluxe Panoramik Deniz Manzaralı Oda")}, {~"size_m2", gleam@json:string(~"38")}, {~"adults", gleam@json:string(~"3")}, {~"children", gleam@json:string(~"1")}, {~"bed", gleam@json:string(~"1 Çift + 1 Tek Kişilik")}, {~"view_type", gleam@json:string(~"Deniz Manzaralı")}, {~"count", gleam@json:string(~"60")}]), gleam@json:object([{~"id", gleam@json:string(~"3")}, {~"title", gleam@json:string(~"Aile Süiti (Family Suite - 2 Odalı)")}, {~"size_m2", gleam@json:string(~"54")}, {~"adults", gleam@json:string(~"4")}, {~"children", gleam@json:string(~"2")}, {~"bed", gleam@json:string(~"1 Çift + 2 Tek Kişilik")}, {~"view_type", gleam@json:string(~"Deniz & Havuz")}, {~"count", gleam@json:string(~"30")}]), gleam@json:object([{~"id", gleam@json:string(~"4")}, {~"title", gleam@json:string(~"Balayı & King Suite (Jakuzili)")}, {~"size_m2", gleam@json:string(~"46")}, {~"adults", gleam@json:string(~"2")}, {~"children", gleam@json:string(~"0")}, {~"bed", gleam@json:string(~"1 King Bed + Jakuzi")}, {~"view_type", gleam@json:string(~"Panoramik Deniz")}, {~"count", gleam@json:string(~"10")}])],
    {Title, Price_minor, Guests, Bedrooms, Beds, Bathrooms, Pool_dimensions, Sheltered_pool, Cleaning_fee, Min_stay} = case Cat of
        ~"hotel" ->
            {<<City_name/binary, " Resort & Spa (Ultra Her Şey Dahil)"/utf8>>, 1850000, ~"2", ~"0", ~"0", ~"0", ~"3 Açık Havuz + 1 Aquapark + 1 Kapalı Termal", ~"false", ~"0", ~"1"};

        ~"holiday_home" ->
            {<<City_name/binary, " Panoramik Deniz Manzaralı & Sonsuzluk Havuzlu Lüks Villa"/utf8>>, 2500000, ~"8", ~"4", ~"5", ~"4", ~"5x10m Derinlik: 1.55m (Özel Sonsuzluk Havuzu)", ~"true", ~"2500", ~"3"};

        ~"yacht" ->
            {<<City_name/binary, " Özel Koylarda Lüks Mavi Yolculuk Gulet & Yat"/utf8>>, 4500000, ~"10", ~"5", ~"6", ~"5", ~"Deniz Merdiveni & Geniş Yüzme Platformu", ~"false", ~"0", ~"3"};

        ~"tour" ->
            {<<City_name/binary, " VIP Rehberli Özel Günlük Keşif & Doğa Turu"/utf8>>, 350000, ~"15", ~"0", ~"0", ~"0", ~"Yok", ~"false", ~"0", ~"1"};

        ~"activity" ->
            {<<City_name/binary, " Profesyonel Eğitmenli VIP Yamaç Paraşütü & Dalış Deneyimi"/utf8>>, 280000, ~"4", ~"0", ~"0", ~"0", ~"Yok", ~"false", ~"0", ~"1"};

        ~"transfer" ->
            {<<City_name/binary, " Havalimanı - Otel VIP Mercedes Maybach Transfer"/utf8>>, 190000, ~"6", ~"0", ~"0", ~"0", ~"Yok", ~"false", ~"0", ~"1"};

        _ ->
            {<<City_name/binary, " Deluxe Otel & Spa Tesisi"/utf8>>, 1850000, ~"2", ~"0", ~"0", ~"0", ~"Açık & Isıtmalı Kapalı Termal Havuz", ~"false", ~"0", ~"1"}
    end,
    Amenities = case Cat of
        ~"hotel" ->
            [~"private_beach", ~"open_pool", ~"aquapark", ~"heated_indoor_pool", ~"spa_hamam", ~"alacarte", ~"kids_club", ~"all_inclusive_bar", ~"reception_24h", ~"fitness", ~"valet_parking", ~"room_service", ~"wifi"];

        ~"holiday_home" ->
            [~"pool", ~"sheltered", ~"jacuzzi", ~"sea_view", ~"wifi", ~"bbq", ~"fireplace", ~"ac", ~"parking", ~"ev_charge", ~"sunset_terrace"];

        ~"yacht" ->
            [~"wifi", ~"sea_view", ~"ac", ~"boat_pier", ~"breakfast", ~"smart_tv", ~"generator"];

        ~"tour" ->
            [~"wifi", ~"breakfast", ~"ac"];

        ~"activity" ->
            [~"wifi", ~"breakfast", ~"ac"];

        _ ->
            [~"private_beach", ~"open_pool", ~"aquapark", ~"spa_hamam", ~"alacarte", ~"wifi"]
    end,
    Images = case Cat of
        ~"hotel" ->
            [~"https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1571896349842-33c89424de2d?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=1200&q=80"];

        ~"holiday_home" ->
            [~"https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1613977257363-707ba9348227?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80"];

        ~"yacht" ->
            [~"https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80"];

        ~"tour" ->
            [~"https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80"];

        ~"activity" ->
            [~"https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80"];

        _ ->
            [~"https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&w=1200&q=80", ~"https://images.unsplash.com/photo-1590490360182-c33d57733427?auto=format&fit=crop&w=1200&q=80"]
    end,
    Description = case Cat of
        ~"hotel" ->
            <<<<"Ege ve Akdeniz'in kesiştiği eşsiz "/utf8, Locality/binary>>/binary, " bölgesinde, denize sıfır konumda yer alan 5 yıldızlı lüks tesisimiz, Ultra Her Şey Dahil konseptiyle misafirlerine rüya gibi bir tatil sunmaktadır.\n\nMavi bayraklı özel kum plajı, iskelesi, açık ve kapalı yüzme havuzları, aquaparkı ve Türk hamamlı spa merkezi ile her yaşa hitap eden ayrıcalıklar barındırır. Dünya mutfaklarından lezzetler sunan alakart restoranlarımız, çocuklara özel Mini Club ve gün boyu süren animasyon etkinlikleri ile ailenizle unutulmaz anlar yaşayacaksınız."/utf8>>;

        _ ->
            <<<<"Akdeniz'in en seçkin lokasyonlarından "/utf8, Locality/binary>>/binary, " bölgesinde konumlanan bu ayrıcalıklı mülk, konuklarına unutulmaz bir tatil deneyimi vadediyor. Modern mimari, panoramik gün batımı manzarası, yüksek mahremiyet ve birinci sınıf donanımlarla tasarlanmıştır.\n\nÖzel havuz terası, ferah yaşam alanları ve lüks yatak odaları ile hem balayı çiftleri hem de kalabalık aileler için kusursuz bir konfor sunmaktadır. Yüksek hızlı Wi-Fi, klima, tam donanımlı mutfak ve acente destek hizmetlerimiz 7/24 misafirlerimizin hizmetindedir."/utf8>>
    end,
    Cancellation_policy = case Cat of
        ~"hotel" ->
            ~"Giriş tarihinden 48 saat öncesine kadar %100 kesintisiz iade hakkı.";

        _ ->
            ~"Giriş tarihinden 14 gün öncesine kadar %100 kesintisiz iade hakkı. Son 7 güne kadar %50 iade."
    end,
    gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"code", gleam@json:string(Code)}, {~"title", gleam@json:string(Title)}, {~"category", gleam@json:string(Cat)}, {~"locality", gleam@json:string(Locality)}, {~"price_minor", gleam@json:int(Price_minor)}, {~"currency", gleam@json:string(~"TRY")}, {~"status", gleam@json:string(~"published")}, {~"hotel_stars", gleam@json:string(~"5_star")}, {~"board_type", gleam@json:string(~"uai")}, {~"hotel_total_rooms", gleam@json:string(~"180")}, {~"hotel_total_beds", gleam@json:string(~"420")}, {~"hotel_pools_count", gleam@json:string(~"3 Açık Havuz, 1 Aquapark, 1 Kapalı Termal")}, {~"beach_distance", gleam@json:string(~"zero")}, {~"airport_distance", gleam@json:string(~"32 km")}, {~"pricing_model", gleam@json:string(~"per_room")}, {~"child_policy_1", gleam@json:string(~"free_0_12")}, {~"child_policy_2_discount", gleam@json:string(~"%50 İndirimli")}, {~"check_in_time", gleam@json:string(~"14:00")}, {~"check_out_time", gleam@json:string(~"12:00")}, {~"room_types", gleam@json:array(Hotel_room_types, fun(X) ->
        X
    end)}, {~"guests", gleam@json:string(Guests)}, {~"bedrooms", gleam@json:string(Bedrooms)}, {~"beds", gleam@json:string(Beds)}, {~"bathrooms", gleam@json:string(Bathrooms)}, {~"pool_dimensions", gleam@json:string(Pool_dimensions)}, {~"sheltered_pool", gleam@json:string(Sheltered_pool)}, {~"cleaning_fee", gleam@json:string(Cleaning_fee)}, {~"min_stay_days", gleam@json:string(Min_stay)}, {~"commission_percent", gleam@json:string(~"15.00")}, {~"deposit_percent", gleam@json:string(~"35.00")}, {~"owner_name", gleam@json:string(~"Acente Portföy Yöneticisi")}, {~"owner_phone", gleam@json:string(~"+90 532 100 20 30")}, {~"amenities", gleam@json:array(Amenities, fun gleam@json:string/1)}, {~"images", gleam@json:array(Images, fun gleam@json:string/1)}, {~"description", gleam@json:string(Description)}, {~"cancellation_policy", gleam@json:string(Cancellation_policy)}]).

-file("src\\nexus_agency\\router.gleam", 3229).
-spec region_decoder() -> gleam@dynamic@decode:decoder({binary(), binary(), binary(), binary(), binary(), binary()}).
region_decoder() ->
    gleam@dynamic@decode:field(0, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Id) ->
        gleam@dynamic@decode:field(1, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Name) ->
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Slug) ->
                gleam@dynamic@decode:field(3, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Country_code) ->
                    gleam@dynamic@decode:field(4, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Status) ->
                        gleam@dynamic@decode:field(5, {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Created_at) ->
                            gleam@dynamic@decode:success({Id, Name, Slug, Country_code, Status, Created_at})
                        end)
                    end)
                end)
            end)
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 267).
-spec dispatch(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
dispatch(Req, Db, Origin) ->
    wisp:rescue_crashes(fun() ->
        wisp:serve_static(Req, ~"/static", ~"priv/static", fun() ->
            Token = wisp:get_cookie(Req, ~"agency_session", signed),
            Lang = case begin
                _pipe = wisp:get_query(Req),
                gleam@list:key_find(_pipe, ~"lang")
            end of
                {ok, L} ->
                    nexus_agency@i18n:normalize_lang(L);

                {error, _} ->
                    case wisp:get_cookie(Req, ~"agency_lang", plain_text) of
                        {ok, L@1} ->
                            nexus_agency@i18n:normalize_lang(L@1);

                        {error, _} ->
                            ~"tr"
                    end
            end,
            Active_cat = case begin
                _pipe@1 = wisp:get_query(Req),
                gleam@list:key_find(_pipe@1, ~"cat")
            end of
                {ok, C} ->
                    C;

                {error, _} ->
                    ~""
            end,
            case {erlang:element(2, Req), fun gleam@http@request:path_segments/1(Req)} of
                {get, [~"set-lang", New_lang]} ->
                    Referer = case gleam@list:key_find(erlang:element(3, Req), ~"referer") of
                        {ok, Ref} ->
                            Ref;

                        {error, _} ->
                            ~"/admin"
                    end,
                    _pipe@2 = wisp:redirect(Referer),
                    wisp:set_cookie(_pipe@2, Req, ~"agency_lang", nexus_agency@i18n:normalize_lang(New_lang), plain_text, 31536000);

                {get, [~"login"]} ->
                    _pipe@3 = wisp:ok(),
                    wisp:html_body(_pipe@3, nexus_agency@panel:login_page(~"", Lang));

                {post, [~"login"]} ->
                    wisp:require_form(Req, fun(Form) ->
                        Session_token = wisp:random_string(48),
                        case nexus_agency@auth:login_with_tenant(Db, form_value(erlang:element(2, Form), ~"email"), form_value(erlang:element(2, Form), ~"password"), Session_token, form_value(erlang:element(2, Form), ~"tenant_slug")) of
                            {ok, Session} ->
                                Destination = case erlang:element(5, Session) of
                                    ~"customer" ->
                                        ~"/";

                                    _ ->
                                        ~"/admin"
                                end,
                                _pipe@4 = wisp:redirect(Destination),
                                _pipe@5 = wisp:set_cookie(_pipe@4, Req, ~"agency_session", Session_token, signed, 28800),
                                gleam@http@response:set_cookie(_pipe@5, ~"nexus_csrf", nexus_agency@csrf:token_for(Session_token), begin
                                    _record = gleam@http@cookie:defaults(http),
                                    {attributes, {some, 28800}, erlang:element(3, _record), erlang:element(4, _record), erlang:element(5, _record), false, erlang:element(7, _record)}
                                end);

                            {error, Error_type} ->
                                Error_message = case Error_type of
                                    invalid_credentials ->
                                        ~"E-posta veya parola hatalı.";

                                    account_locked ->
                                        ~"Hesap çok fazla başarısız deneme nedeniyle geçici olarak kilitlendi. Lütfen 15 dakika sonra tekrar deneyin.";

                                    ambiguous_account ->
                                        ~"Bu e-posta birden fazla acente hesabında kayıtlı. Giriş için acente kodu veya alan adıyla hesabınızı netleştirin.";

                                    database_error ->
                                        ~"Bir hata oluştu. Lütfen tekrar deneyin."
                                end,
                                _pipe@6 = wisp:response(401),
                                wisp:html_body(_pipe@6, nexus_agency@panel:login_page(Error_message, Lang))
                        end
                    end);

                {post, [~"logout"]} ->
                    case Token of
                        {ok, Value} ->
                            nexus_agency@auth:logout(Db, Value);

                        {error, _} ->
                            nil
                    end,
                    _pipe@4 = wisp:redirect(~"/login"),
                    _pipe@5 = wisp:set_cookie(_pipe@4, Req, ~"agency_session", ~"", signed, 0),
                    gleam@http@response:set_cookie(_pipe@5, ~"nexus_csrf", ~"", begin
                        _record = gleam@http@cookie:defaults(http),
                        {attributes, {some, 0}, erlang:element(3, _record), erlang:element(4, _record), erlang:element(5, _record), false, erlang:element(7, _record)}
                    end);

                {get, [~"admin"]} ->
                    require_session(Db, Token, fun(Session) ->
                        _pipe@6 = wisp:ok(),
                        wisp:html_body(_pipe@6, nexus_agency@panel:dashboard(Session, Lang, Active_cat))
                    end);

                {get, [~"admin", Section]} ->
                    require_panel_session(Db, Token, Section, fun(Session) ->
                        _pipe@6 = wisp:ok(),
                        wisp:html_body(_pipe@6, nexus_agency@panel:section(Session, Section, section_intro(Section), section_links(Section), Lang, Active_cat))
                    end);

                {get, [~"admin", ~"holiday-home", Module]} ->
                    require_panel_session(Db, Token, ~"catalog", fun(Session) ->
                        _pipe@6 = wisp:ok(),
                        wisp:html_body(_pipe@6, nexus_agency@panel:holiday_home_manager_page(Session, Module, Lang))
                    end);

                {post, [~"admin", ~"regions"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Query = ~"INSERT INTO agency.regions(tenant_id,parent_id,name,slug,country_code,description,latitude,longitude,seo_title,seo_description) VALUES($1::uuid,NULLIF($2,'')::uuid,$3,$4,$5,$6,NULLIF($7,'')::numeric,NULLIF($8,'')::numeric,$9,$10) ON CONFLICT(tenant_id,slug) DO UPDATE SET parent_id=excluded.parent_id,name=excluded.name,description=excluded.description,latitude=excluded.latitude,longitude=excluded.longitude,seo_title=excluded.seo_title,seo_description=excluded.seo_description,updated_at=now()",
                            _pipe@6 = Query,
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"parent_id"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"slug"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"country_code"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"description"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"latitude"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"longitude"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_title"))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_description"))),
                            _pipe@18 = pog:execute(_pipe@17, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/regions")
                            end(_pipe@18)
                        end)
                    end);

                {get, [~"admin", ~"regions", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select id::text,name,slug,country_code::text,case when active then 'Aktif' else 'Pasif' end,to_char(created_at,'YYYY-MM-DD HH24:MI') from agency.regions where tenant_id=$1::uuid order by name",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, region_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"name", gleam@json:string(erlang:element(2, Row))}, {~"slug", gleam@json:string(erlang:element(3, Row))}, {~"countryCode", gleam@json:string(erlang:element(4, Row))}, {~"status", gleam@json:string(erlang:element(5, Row))}, {~"createdAt", gleam@json:string(erlang:element(6, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Bölgeler okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"languages"]} ->
                    require_admin(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.languages(code,name,native_name,active,is_default) VALUES(lower($1),$2,$3,$4,false) ON CONFLICT(code) DO UPDATE SET name=excluded.name,native_name=excluded.native_name,active=excluded.active",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"code"))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"native_name"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_bool(erlang:element(2, Form), ~"active"))),
                            _pipe@12 = pog:execute(_pipe@11, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/languages")
                            end(_pipe@12)
                        end)
                    end);

                {post, [~"admin", ~"catalog", ~"ai-import"]} ->
                    require_session_api(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            Url = form_value(erlang:element(2, Form), ~"url"),
                            Text = form_value(erlang:element(2, Form), ~"text"),
                            Category = form_value(erlang:element(2, Form), ~"category"),
                            Extracted = handle_ai_import_listing(Url, Text, Category),
                            _pipe@6 = Extracted,
                            _pipe@7 = gleam@json:to_string(_pipe@6),
                            fun(Body) ->
                                _pipe@8 = wisp:ok(),
                                _pipe@9 = fun gleam@http@response:set_header/3(_pipe@8, ~"content-type", ~"application/json; charset=utf-8"),
                                wisp:string_body(_pipe@9, Body)
                            end(_pipe@7)
                        end)
                    end);

                {post, [~"api", ~"ai", ~"generate-content"]} ->
                    require_session_api(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Category = form_value(erlang:element(2, Form), ~"category"),
                            Title = form_value(erlang:element(2, Form), ~"title"),
                            Attributes = form_value(erlang:element(2, Form), ~"attributes"),
                            Target_lang = case form_value(erlang:element(2, Form), ~"lang") of
                                ~"" ->
                                    ~"tr";

                                L@2 ->
                                    L@2
                            end,
                            case generate_description_with_pool(Db, erlang:element(2, Session), Category, Title, Attributes, Target_lang) of
                                {ok, Html} ->
                                    Res = begin
                                        _pipe@6 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"html", gleam@json:string(Html)}]),
                                        gleam@json:to_string(_pipe@6)
                                    end,
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@8, Res);

                                {error, Err} ->
                                    Res@1 = begin
                                        _pipe@9 = gleam@json:object([{~"ok", gleam@json:bool(false)}, {~"error", gleam@json:string(Err)}]),
                                        gleam@json:to_string(_pipe@9)
                                    end,
                                    _pipe@10 = wisp:response(500),
                                    _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@11, Res@1)
                            end
                        end)
                    end);

                {post, [~"api", ~"ai", ~"generate-seo"]} ->
                    require_session_api(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Category = form_value(erlang:element(2, Form), ~"category"),
                            Title = form_value(erlang:element(2, Form), ~"title"),
                            Description = form_value(erlang:element(2, Form), ~"description"),
                            case generate_seo_with_pool(Db, erlang:element(2, Session), Category, Title, Description) of
                                {ok, {Seo_title, Seo_desc, Keywords}} ->
                                    Res = begin
                                        _pipe@6 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"title", gleam@json:string(Seo_title)}, {~"description", gleam@json:string(Seo_desc)}, {~"keywords", gleam@json:string(Keywords)}]),
                                        gleam@json:to_string(_pipe@6)
                                    end,
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@8, Res);

                                {error, Err} ->
                                    Res@1 = begin
                                        _pipe@9 = gleam@json:object([{~"ok", gleam@json:bool(false)}, {~"error", gleam@json:string(Err)}]),
                                        gleam@json:to_string(_pipe@9)
                                    end,
                                    _pipe@10 = wisp:response(500),
                                    _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@11, Res@1)
                            end
                        end)
                    end);

                {post, [~"api", ~"ai", ~"translate"]} ->
                    require_session_api(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Content = form_value(erlang:element(2, Form), ~"content"),
                            Source_lang = form_value(erlang:element(2, Form), ~"source_lang"),
                            Target_lang = form_value(erlang:element(2, Form), ~"target_lang"),
                            case translate_with_pool(Db, erlang:element(2, Session), Content, Source_lang, Target_lang) of
                                {ok, Translated} ->
                                    Res = begin
                                        _pipe@6 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"translated", gleam@json:string(Translated)}, {~"target_lang", gleam@json:string(Target_lang)}]),
                                        gleam@json:to_string(_pipe@6)
                                    end,
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@8, Res);

                                {error, Err} ->
                                    Res@1 = begin
                                        _pipe@9 = gleam@json:object([{~"ok", gleam@json:bool(false)}, {~"error", gleam@json:string(Err)}]),
                                        gleam@json:to_string(_pipe@9)
                                    end,
                                    _pipe@10 = wisp:response(500),
                                    _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@11, Res@1)
                            end
                        end)
                    end);

                {post, [~"api", ~"ai", ~"translate-all"]} ->
                    require_session_api(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Title = form_value(erlang:element(2, Form), ~"title"),
                            Description = form_value(erlang:element(2, Form), ~"description"),
                            case translate_all_with_pool(Db, erlang:element(2, Session), Title, Description) of
                                {ok, Json_str} ->
                                    Res = <<<<"{\"ok\":true,\"translations\":"/utf8, Json_str/binary>>/binary, "}"/utf8>>,
                                    _pipe@6 = wisp:ok(),
                                    _pipe@7 = fun gleam@http@response:set_header/3(_pipe@6, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@7, Res);

                                {error, Err} ->
                                    Res@1 = begin
                                        _pipe@8 = gleam@json:object([{~"ok", gleam@json:bool(false)}, {~"error", gleam@json:string(Err)}]),
                                        gleam@json:to_string(_pipe@8)
                                    end,
                                    _pipe@9 = wisp:response(500),
                                    _pipe@10 = fun gleam@http@response:set_header/3(_pipe@9, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@10, Res@1)
                            end
                        end)
                    end);

                {post, [~"api", ~"ai", ~"test"]} ->
                    require_admin(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            Provider = form_value(erlang:element(2, Form), ~"provider"),
                            Api_key = form_value(erlang:element(2, Form), ~"api_key"),
                            Model = form_value(erlang:element(2, Form), ~"model"),
                            Cfg = {a_i_config, Provider, Api_key, Model},
                            case nexus_agency@ai_client:test_connection(Cfg) of
                                {ok, Msg} ->
                                    Res = begin
                                        _pipe@6 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"message", gleam@json:string(<<<<<<"Bağlantı Başarılı ("/utf8, (erlang:element(2, Cfg))/binary>>/binary, "): "/utf8>>/binary, Msg/binary>>)}]),
                                        gleam@json:to_string(_pipe@6)
                                    end,
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@8, Res);

                                {error, Err} ->
                                    Res@1 = begin
                                        _pipe@9 = gleam@json:object([{~"ok", gleam@json:bool(false)}, {~"error", gleam@json:string(<<"Bağlantı Hatası: "/utf8, Err/binary>>)}]),
                                        gleam@json:to_string(_pipe@9)
                                    end,
                                    _pipe@10 = wisp:ok(),
                                    _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@11, Res@1)
                            end
                        end)
                    end);

                {post, [~"admin", ~"ai", ~"content-enhance"]} ->
                    require_session_api(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Mode = form_value(erlang:element(2, Form), ~"mode"),
                            Context = form_value(erlang:element(2, Form), ~"context"),
                            Title = form_value(erlang:element(2, Form), ~"title"),
                            Description = form_value(erlang:element(2, Form), ~"description"),
                            Action = form_value(erlang:element(2, Form), ~"action"),
                            Prompt = form_value(erlang:element(2, Form), ~"prompt"),
                            case handle_ai_content_enhance(Db, erlang:element(2, Session), Mode, Context, Title, Description, Action, Prompt) of
                                {ok, Enhanced} ->
                                    _pipe@6 = Enhanced,
                                    _pipe@7 = gleam@json:to_string(_pipe@6),
                                    fun(Body) ->
                                        _pipe@8 = wisp:ok(),
                                        _pipe@9 = fun gleam@http@response:set_header/3(_pipe@8, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@9, Body)
                                    end(_pipe@7);

                                {error, Error} ->
                                    _pipe@8 = wisp:response(503),
                                    _pipe@9 = fun gleam@http@response:set_header/3(_pipe@8, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:json_body(_pipe@9, begin
                                        _pipe@10 = gleam@json:object([{~"ok", gleam@json:bool(false)}, {~"error", gleam@json:string(Error)}]),
                                        gleam@json:to_string(_pipe@10)
                                    end)
                            end
                        end)
                    end);

                {post, [~"admin", ~"catalog"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Raw_code = form_value(erlang:element(2, Form), ~"code"),
                            Final_code = case gleam@string:trim(Raw_code) of
                                ~"" ->
                                    <<<<(string:uppercase(form_value(erlang:element(2, Form), ~"category")))/binary, "-"/utf8>>/binary, (gleam@string:slice(erlang:element(2, Session), 0, 8))/binary>>;

                                C@1 ->
                                    C@1
                            end,
                            _pipe@6 = ~"INSERT INTO agency.listings(
              tenant_id,code,category,title,locality,description,currency,price_minor,status,source,
              metadata,images,amenities,owner_info,cancellation_policy,owner_user_id
            ) VALUES(
              $1::uuid,upper($2),$3,$4,$5,$6,coalesce((select cur.code from agency.currencies cur where cur.code=upper($7) limit 1),'TRY'),$8,
              case when $9='published' and exists (
                select 1 from agency.category_fields f
                join agency.categories c on c.id=f.category_id
                where c.tenant_id=$1::uuid and c.code=$3 and f.required
                  and nullif(trim(coalesce(case when $44 ~ '^\\s*\\{' then ($44::jsonb->'contract_fields'->>f.field_key) else null end,'')),'') is null
              ) then 'draft' else $9 end,'manual',
              jsonb_build_object(
                'pool_dimensions',$10::text,'sheltered_pool',$11::text,'cleaning_fee',$12::text,
                'min_stay_days',$13::text,'commission_percent',$14::text,'deposit_percent',$15::text,
                'ministry_license_no',$16::text,'ical_offset_days',$17::text,
                'guests',$18::text,'bedrooms',$19::text,'beds',$20::text,'bathrooms',$21::text,'ical_url',$22::text,
                'hotel_stars',$28::text,'board_type',$29::text,'hotel_total_rooms',$30::text,'hotel_total_beds',$31::text,
                'hotel_pools_count',$32::text,'beach_distance',$33::text,'airport_distance',$34::text,
                'pricing_model',$35::text,'child_policy_1',$36::text,'child_policy_2_discount',$37::text,
                'check_in_time',$38::text,'check_out_time',$39::text,
                'room_types',case when $40 ~ '^\\s*\\[' then $40::jsonb else '[]'::jsonb end,
                'seo_title',$41::text,'seo_description',$42::text,'slug',$43::text,
                'contract_required_complete',not exists (
                  select 1 from agency.category_fields f
                  join agency.categories c on c.id=f.category_id
                  where c.tenant_id=$1::uuid and c.code=$3 and f.required
                    and nullif(trim(coalesce(case when $44 ~ '^\\s*\\{' then ($44::jsonb->'contract_fields'->>f.field_key) else null end,'')),'') is null
                ),
                'extra_metadata',case when $44 ~ '^\\s*\\{' then $44::jsonb else '{}'::jsonb end
              ),
              case when $23 ~ '^\\s*\\[' then $23::jsonb else '[]'::jsonb end,
              case when $24 ~ '^\\s*\\[' then $24::jsonb else '[]'::jsonb end,
              jsonb_build_object('name',$25::text,'phone',$26::text),
              jsonb_build_object('policy',$27::text),
              $45::uuid
            ) ON CONFLICT(tenant_id,code) DO UPDATE SET
              category=excluded.category,title=excluded.title,locality=excluded.locality,
              description=excluded.description,currency=excluded.currency,price_minor=excluded.price_minor,
              status=excluded.status,metadata=agency.listings.metadata||excluded.metadata,
              images=case when jsonb_array_length(excluded.images)>0 then excluded.images else agency.listings.images end,
              amenities=case when jsonb_array_length(excluded.amenities)>0 then excluded.amenities else agency.listings.amenities end,
              owner_info=excluded.owner_info,cancellation_policy=excluded.cancellation_policy,
              owner_user_id=coalesce(agency.listings.owner_user_id,excluded.owner_user_id),updated_at=now()
              WHERE agency.listings.owner_user_id=$45::uuid OR $46 in ('admin','staff')",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Final_code)),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"category"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"title"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"locality"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"description"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"currency"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"price_minor"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"status"))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"pool_dimensions"))),
                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"sheltered_pool"))),
                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"cleaning_fee"))),
                            _pipe@20 = pog:parameter(_pipe@19, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"min_stay_days"))),
                            _pipe@21 = pog:parameter(_pipe@20, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"commission_percent"))),
                            _pipe@22 = pog:parameter(_pipe@21, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"deposit_percent"))),
                            _pipe@23 = pog:parameter(_pipe@22, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ministry_license_no"))),
                            _pipe@24 = pog:parameter(_pipe@23, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ical_offset_days"))),
                            _pipe@25 = pog:parameter(_pipe@24, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"guests"))),
                            _pipe@26 = pog:parameter(_pipe@25, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"bedrooms"))),
                            _pipe@27 = pog:parameter(_pipe@26, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"beds"))),
                            _pipe@28 = pog:parameter(_pipe@27, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"bathrooms"))),
                            _pipe@29 = pog:parameter(_pipe@28, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ical_url"))),
                            _pipe@30 = pog:parameter(_pipe@29, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"images") of
                                ~"" ->
                                    ~"[]";

                                Val ->
                                    case gleam_stdlib:string_starts_with(Val, ~"[") of
                                        true ->
                                            Val;

                                        false ->
                                            ~"[]"
                                    end
                            end)),
                            _pipe@31 = pog:parameter(_pipe@30, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"amenities") of
                                ~"" ->
                                    ~"[]";

                                Val@1 ->
                                    case gleam_stdlib:string_starts_with(Val@1, ~"[") of
                                        true ->
                                            Val@1;

                                        false ->
                                            ~"[]"
                                    end
                            end)),
                            _pipe@32 = pog:parameter(_pipe@31, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"owner_name"))),
                            _pipe@33 = pog:parameter(_pipe@32, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"owner_phone"))),
                            _pipe@34 = pog:parameter(_pipe@33, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"cancellation_policy"))),
                            _pipe@35 = pog:parameter(_pipe@34, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_stars"))),
                            _pipe@36 = pog:parameter(_pipe@35, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"board_type"))),
                            _pipe@37 = pog:parameter(_pipe@36, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_total_rooms"))),
                            _pipe@38 = pog:parameter(_pipe@37, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_total_beds"))),
                            _pipe@39 = pog:parameter(_pipe@38, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_pools_count"))),
                            _pipe@40 = pog:parameter(_pipe@39, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"beach_distance"))),
                            _pipe@41 = pog:parameter(_pipe@40, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"airport_distance"))),
                            _pipe@42 = pog:parameter(_pipe@41, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"pricing_model"))),
                            _pipe@43 = pog:parameter(_pipe@42, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"child_policy_1"))),
                            _pipe@44 = pog:parameter(_pipe@43, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"child_policy_2_discount"))),
                            _pipe@45 = pog:parameter(_pipe@44, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"check_in_time"))),
                            _pipe@46 = pog:parameter(_pipe@45, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"check_out_time"))),
                            _pipe@47 = pog:parameter(_pipe@46, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"room_types") of
                                ~"" ->
                                    ~"[]";

                                Val@2 ->
                                    case gleam_stdlib:string_starts_with(Val@2, ~"[") of
                                        true ->
                                            Val@2;

                                        false ->
                                            ~"[]"
                                    end
                            end)),
                            _pipe@48 = pog:parameter(_pipe@47, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_title"))),
                            _pipe@49 = pog:parameter(_pipe@48, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_description"))),
                            _pipe@50 = pog:parameter(_pipe@49, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"slug"))),
                            _pipe@51 = pog:parameter(_pipe@50, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"extra_metadata") of
                                ~"" ->
                                    ~"{}";

                                Val@3 ->
                                    case gleam_stdlib:string_starts_with(Val@3, ~"{") of
                                        true ->
                                            Val@3;

                                        false ->
                                            ~"{}"
                                    end
                            end)),
                            _pipe@52 = pog:parameter(_pipe@51, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@53 = pog:parameter(_pipe@52, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@54 = pog:execute(_pipe@53, Db),
                            fun(Res) ->
                                case Res of
                                    {ok, _} ->
                                        nil;

                                    {error, E} ->
                                        gleam_stdlib:println(<<"CATALOG INSERT ERROR: "/utf8, (gleam@string:inspect(E))/binary>>)
                                end,
                                wisp:redirect(~"/admin/catalog")
                            end(_pipe@54)
                        end)
                    end);

                {post, [~"admin", ~"listings"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Raw_code = form_value(erlang:element(2, Form), ~"code"),
                            Final_code = case gleam@string:trim(Raw_code) of
                                ~"" ->
                                    <<<<(string:uppercase(form_value(erlang:element(2, Form), ~"category")))/binary, "-"/utf8>>/binary, (gleam@string:slice(erlang:element(2, Session), 0, 8))/binary>>;

                                C@1 ->
                                    C@1
                            end,
                            _pipe@6 = ~"INSERT INTO agency.listings(
              tenant_id,code,category,title,locality,description,currency,price_minor,status,source,
              metadata,images,amenities,owner_info,cancellation_policy,owner_user_id
            ) VALUES(
              $1::uuid,upper($2),$3,$4,$5,$6,coalesce((select cur.code from agency.currencies cur where cur.code=upper($7) limit 1),'TRY'),$8,
              case when $9='published' and exists (
                select 1 from agency.category_fields f
                join agency.categories c on c.id=f.category_id
                where c.tenant_id=$1::uuid and c.code=$3 and f.required
                  and nullif(trim(coalesce(case when $44 ~ '^\\s*\\{' then ($44::jsonb->'contract_fields'->>f.field_key) else null end,'')),'') is null
              ) then 'draft' else $9 end,'manual',
              jsonb_build_object(
                'pool_dimensions',$10::text,'sheltered_pool',$11::text,'cleaning_fee',$12::text,
                'min_stay_days',$13::text,'commission_percent',$14::text,'deposit_percent',$15::text,
                'ministry_license_no',$16::text,'ical_offset_days',$17::text,
                'guests',$18::text,'bedrooms',$19::text,'beds',$20::text,'bathrooms',$21::text,'ical_url',$22::text,
                'hotel_stars',$28::text,'board_type',$29::text,'hotel_total_rooms',$30::text,'hotel_total_beds',$31::text,
                'hotel_pools_count',$32::text,'beach_distance',$33::text,'airport_distance',$34::text,
                'pricing_model',$35::text,'child_policy_1',$36::text,'child_policy_2_discount',$37::text,
                'check_in_time',$38::text,'check_out_time',$39::text,
                'room_types',case when $40 ~ '^\\s*\\[' then $40::jsonb else '[]'::jsonb end,
                'seo_title',$41::text,'seo_description',$42::text,'slug',$43::text,
                'contract_required_complete',not exists (
                  select 1 from agency.category_fields f
                  join agency.categories c on c.id=f.category_id
                  where c.tenant_id=$1::uuid and c.code=$3 and f.required
                    and nullif(trim(coalesce(case when $44 ~ '^\\s*\\{' then ($44::jsonb->'contract_fields'->>f.field_key) else null end,'')),'') is null
                ),
                'extra_metadata',case when $44 ~ '^\\s*\\{' then $44::jsonb else '{}'::jsonb end
              ),
              case when $23 ~ '^\\s*\\[' then $23::jsonb else '[]'::jsonb end,
              case when $24 ~ '^\\s*\\[' then $24::jsonb else '[]'::jsonb end,
              jsonb_build_object('name',$25::text,'phone',$26::text),
              jsonb_build_object('policy',$27::text),
              $45::uuid
            ) ON CONFLICT(tenant_id,code) DO UPDATE SET
              category=excluded.category,title=excluded.title,locality=excluded.locality,
              description=excluded.description,currency=excluded.currency,price_minor=excluded.price_minor,
              status=excluded.status,metadata=agency.listings.metadata||excluded.metadata,
              images=case when jsonb_array_length(excluded.images)>0 then excluded.images else agency.listings.images end,
              amenities=case when jsonb_array_length(excluded.amenities)>0 then excluded.amenities else agency.listings.amenities end,
              owner_info=excluded.owner_info,cancellation_policy=excluded.cancellation_policy,
              owner_user_id=coalesce(agency.listings.owner_user_id,excluded.owner_user_id),updated_at=now()
              WHERE agency.listings.owner_user_id=$45::uuid OR $46 in ('admin','staff')",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Final_code)),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"category"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"title"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"locality"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"description"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"currency"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"price_minor"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"status"))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"pool_dimensions"))),
                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"sheltered_pool"))),
                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"cleaning_fee"))),
                            _pipe@20 = pog:parameter(_pipe@19, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"min_stay_days"))),
                            _pipe@21 = pog:parameter(_pipe@20, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"commission_percent"))),
                            _pipe@22 = pog:parameter(_pipe@21, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"deposit_percent"))),
                            _pipe@23 = pog:parameter(_pipe@22, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ministry_license_no"))),
                            _pipe@24 = pog:parameter(_pipe@23, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ical_offset_days"))),
                            _pipe@25 = pog:parameter(_pipe@24, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"guests"))),
                            _pipe@26 = pog:parameter(_pipe@25, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"bedrooms"))),
                            _pipe@27 = pog:parameter(_pipe@26, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"beds"))),
                            _pipe@28 = pog:parameter(_pipe@27, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"bathrooms"))),
                            _pipe@29 = pog:parameter(_pipe@28, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ical_url"))),
                            _pipe@30 = pog:parameter(_pipe@29, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"images") of
                                ~"" ->
                                    ~"[]";

                                Val ->
                                    case gleam_stdlib:string_starts_with(Val, ~"[") of
                                        true ->
                                            Val;

                                        false ->
                                            ~"[]"
                                    end
                            end)),
                            _pipe@31 = pog:parameter(_pipe@30, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"amenities") of
                                ~"" ->
                                    ~"[]";

                                Val@1 ->
                                    case gleam_stdlib:string_starts_with(Val@1, ~"[") of
                                        true ->
                                            Val@1;

                                        false ->
                                            ~"[]"
                                    end
                            end)),
                            _pipe@32 = pog:parameter(_pipe@31, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"owner_name"))),
                            _pipe@33 = pog:parameter(_pipe@32, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"owner_phone"))),
                            _pipe@34 = pog:parameter(_pipe@33, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"cancellation_policy"))),
                            _pipe@35 = pog:parameter(_pipe@34, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_stars"))),
                            _pipe@36 = pog:parameter(_pipe@35, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"board_type"))),
                            _pipe@37 = pog:parameter(_pipe@36, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_total_rooms"))),
                            _pipe@38 = pog:parameter(_pipe@37, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_total_beds"))),
                            _pipe@39 = pog:parameter(_pipe@38, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"hotel_pools_count"))),
                            _pipe@40 = pog:parameter(_pipe@39, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"beach_distance"))),
                            _pipe@41 = pog:parameter(_pipe@40, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"airport_distance"))),
                            _pipe@42 = pog:parameter(_pipe@41, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"pricing_model"))),
                            _pipe@43 = pog:parameter(_pipe@42, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"child_policy_1"))),
                            _pipe@44 = pog:parameter(_pipe@43, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"child_policy_2_discount"))),
                            _pipe@45 = pog:parameter(_pipe@44, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"check_in_time"))),
                            _pipe@46 = pog:parameter(_pipe@45, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"check_out_time"))),
                            _pipe@47 = pog:parameter(_pipe@46, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"room_types") of
                                ~"" ->
                                    ~"[]";

                                Val@2 ->
                                    case gleam_stdlib:string_starts_with(Val@2, ~"[") of
                                        true ->
                                            Val@2;

                                        false ->
                                            ~"[]"
                                    end
                            end)),
                            _pipe@48 = pog:parameter(_pipe@47, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_title"))),
                            _pipe@49 = pog:parameter(_pipe@48, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_description"))),
                            _pipe@50 = pog:parameter(_pipe@49, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"slug"))),
                            _pipe@51 = pog:parameter(_pipe@50, pog_ffi:coerce(case form_value(erlang:element(2, Form), ~"extra_metadata") of
                                ~"" ->
                                    ~"{}";

                                Val@3 ->
                                    case gleam_stdlib:string_starts_with(Val@3, ~"{") of
                                        true ->
                                            Val@3;

                                        false ->
                                            ~"{}"
                                    end
                            end)),
                            _pipe@52 = pog:parameter(_pipe@51, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@53 = pog:parameter(_pipe@52, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@54 = pog:execute(_pipe@53, Db),
                            fun(Res) ->
                                case Res of
                                    {ok, _} ->
                                        nil;

                                    {error, E} ->
                                        gleam_stdlib:println(<<"CATALOG INSERT ERROR: "/utf8, (gleam@string:inspect(E))/binary>>)
                                end,
                                wisp:redirect(~"/admin/catalog")
                            end(_pipe@54)
                        end)
                    end);

                {get, [~"admin", ~"catalog", ~"fields"]} ->
                    require_panel_session(Db, Token, ~"catalog", fun(Session) ->
                        Category = case begin
                            _pipe@6 = wisp:get_query(Req),
                            gleam@list:key_find(_pipe@6, ~"category")
                        end of
                            {ok, Value} ->
                                public_category_canonical(Value);

                            {error, _} ->
                                ~"hotel"
                        end,
                        case begin
                            _pipe@7 = ~"select coalesce(json_agg(json_build_object('key',f.field_key,'label',f.label,'type',f.field_type,'required',f.required,'options',coalesce(f.options,'[]'::jsonb),'sortOrder',f.sort_order) order by f.sort_order,f.label)::text,'[]') from agency.category_fields f join agency.categories c on c.id=f.category_id where c.tenant_id=$1::uuid and c.code=$2",
                            _pipe@8 = pog:'query'(_pipe@7),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Category)),
                            _pipe@11 = pog:returning(_pipe@10, single_string_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                Body = case gleam@list:first(erlang:element(3, Result)) of
                                    {ok, Value@1} ->
                                        Value@1;

                                    {error, _} ->
                                        ~"[]"
                                end,
                                fun(Body@1) ->
                                    _pipe@12 = wisp:ok(),
                                    _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@13, Body@1)
                                end(Body);

                            {error, _} ->
                                _pipe@12 = wisp:response(500),
                                wisp:json_body(_pipe@12, ~"{\"error\":\"Kategori alanları okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"catalog", ~"data"]} ->
                    require_panel_session(Db, Token, ~"catalog", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select id::text,code,category,title,locality,currency,price_minor::text,status,coalesce(description,''),coalesce(images::text,'[]'),coalesce(amenities::text,'[]'),coalesce(metadata::text,'{}') from agency.listings where tenant_id=$1::uuid and ($2 in ('admin','staff') or owner_user_id=$3::uuid) order by updated_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, listing_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                _pipe@12 = erlang:element(3, Result),
                                _pipe@13 = gleam@json:array(_pipe@12, fun(Item) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(2, Item))}, {~"code", gleam@json:string(erlang:element(3, Item))}, {~"category", gleam@json:string(erlang:element(4, Item))}, {~"title", gleam@json:string(erlang:element(5, Item))}, {~"locality", gleam@json:string(erlang:element(6, Item))}, {~"currency", gleam@json:string(erlang:element(7, Item))}, {~"priceMinor", gleam@json:string(erlang:element(8, Item))}, {~"status", gleam@json:string(erlang:element(9, Item))}, {~"description", gleam@json:string(erlang:element(10, Item))}, {~"images", gleam@json:string(erlang:element(11, Item))}, {~"amenities", gleam@json:string(erlang:element(12, Item))}, {~"metadata", gleam@json:string(erlang:element(13, Item))}])
                                end),
                                _pipe@14 = gleam@json:to_string(_pipe@13),
                                fun(Body) ->
                                    _pipe@15 = wisp:ok(),
                                    _pipe@16 = fun gleam@http@response:set_header/3(_pipe@15, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@16, Body)
                                end(_pipe@14);

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Katalog verileri okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"listings", ~"data"]} ->
                    require_panel_session(Db, Token, ~"catalog", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select id::text,code,category,title,locality,currency,price_minor::text,status,coalesce(description,''),coalesce(images::text,'[]'),coalesce(amenities::text,'[]'),coalesce(metadata::text,'{}') from agency.listings where tenant_id=$1::uuid and ($2 in ('admin','staff') or owner_user_id=$3::uuid) order by updated_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, listing_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                _pipe@12 = erlang:element(3, Result),
                                _pipe@13 = gleam@json:array(_pipe@12, fun(Item) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(2, Item))}, {~"code", gleam@json:string(erlang:element(3, Item))}, {~"category", gleam@json:string(erlang:element(4, Item))}, {~"title", gleam@json:string(erlang:element(5, Item))}, {~"locality", gleam@json:string(erlang:element(6, Item))}, {~"currency", gleam@json:string(erlang:element(7, Item))}, {~"priceMinor", gleam@json:string(erlang:element(8, Item))}, {~"status", gleam@json:string(erlang:element(9, Item))}, {~"description", gleam@json:string(erlang:element(10, Item))}, {~"images", gleam@json:string(erlang:element(11, Item))}, {~"amenities", gleam@json:string(erlang:element(12, Item))}, {~"metadata", gleam@json:string(erlang:element(13, Item))}])
                                end),
                                _pipe@14 = gleam@json:to_string(_pipe@13),
                                fun(Body) ->
                                    _pipe@15 = wisp:ok(),
                                    _pipe@16 = fun gleam@http@response:set_header/3(_pipe@15, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@16, Body)
                                end(_pipe@14);

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Katalog verileri okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"catalog", ~"delete"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Listing_id = form_value(erlang:element(2, Form), ~"id"),
                            _pipe@6 = ~"DELETE FROM agency.listings WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Listing_id)),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@12 = pog:execute(_pipe@11, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/catalog")
                            end(_pipe@12)
                        end)
                    end);

                {post, [~"admin", ~"listings", ~"delete"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Listing_id = form_value(erlang:element(2, Form), ~"id"),
                            _pipe@6 = ~"DELETE FROM agency.listings WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Listing_id)),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@12 = pog:execute(_pipe@11, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/catalog")
                            end(_pipe@12)
                        end)
                    end);

                {post, [~"admin", ~"preferences", ~"theme"]} ->
                    require_session(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            case form_value(erlang:element(2, Form), ~"theme") of
                                Theme when ((((Theme =:= ~"dark") orelse (Theme =:= ~"light")) orelse (Theme =:= ~"midnight")) orelse (Theme =:= ~"sahra")) orelse (Theme =:= ~"auto") ->
                                    _pipe@6 = ~"UPDATE agency.users SET theme_preference=$1 WHERE id=$2::uuid AND tenant_id=$3::uuid",
                                    _pipe@7 = pog:'query'(_pipe@6),
                                    _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Theme)),
                                    _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(3, Session))),
                                    _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(2, Session))),
                                    _pipe@11 = pog:execute(_pipe@10, Db),
                                    fun(_) ->
                                        wisp:response(204)
                                    end(_pipe@11);

                                _ ->
                                    _pipe@12 = wisp:response(400),
                                    wisp:string_body(_pipe@12, ~"Geçersiz tema anahtarı")
                            end
                        end)
                    end);

                {post, [~"admin", ~"preferences", ~"wizard"]} ->
                    require_session(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Wizard_json = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    erlang:element(1, Pair) =:= ~"prefs"
                                end),
                                _pipe@8 = gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end),
                                _pipe@9 = gleam@list:first(_pipe@8),
                                gleam@result:unwrap(_pipe@9, ~"")
                            end,
                            Safe_json = case Wizard_json =:= ~"" of
                                true ->
                                    ~"null";

                                false ->
                                    Wizard_json
                            end,
                            _pipe@10 = ~"UPDATE agency.users SET wizard_prefs=$1::jsonb WHERE id=$2::uuid AND tenant_id=$3::uuid",
                            _pipe@11 = pog:'query'(_pipe@10),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Safe_json)),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@15 = pog:execute(_pipe@14, Db),
                            fun(_) ->
                                wisp:response(204)
                            end(_pipe@15)
                        end)
                    end);

                {post, [~"admin", ~"catalog", ~"bulk-delete"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"DELETE FROM agency.listings WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/catalog")
                        end)
                    end);

                {post, [~"admin", ~"listings", ~"bulk-delete"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"DELETE FROM agency.listings WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/catalog")
                        end)
                    end);

                {post, [~"admin", ~"customers", ~"bulk-delete"]} ->
                    require_panel_session(Db, Token, ~"customers", fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"DELETE FROM agency.customers WHERE tenant_id=$1::uuid AND id=$2::uuid",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:execute(_pipe@12, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@13)
                            end),
                            wisp:redirect(~"/admin/customers#customers-workspace")
                        end)
                    end);

                {post, [~"admin", ~"reservations", ~"bulk-delete"]} ->
                    require_panel_session(Db, Token, ~"reservations", fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"DELETE FROM agency.reservations r WHERE r.tenant_id=$1::uuid AND r.id=$2::uuid AND ($3 in ('admin','staff','sub_agency') OR EXISTS (SELECT 1 FROM agency.listings l WHERE l.id=r.listing_id AND l.owner_user_id=$4::uuid))",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/reservations#reservations-workspace")
                        end)
                    end);

                {post, [~"admin", ~"inquiries", ~"bulk-delete"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"DELETE FROM agency.public_inquiries WHERE tenant_id=$1::uuid AND id=$2::uuid AND status<>'closed'",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:execute(_pipe@12, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@13)
                            end),
                            wisp:redirect(~"/admin/inquiries#inquiries-workspace")
                        end)
                    end);

                {post, [~"admin", ~"languages", ~"bulk-delete"]} ->
                    require_admin(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"DELETE FROM agency.languages WHERE code=$1 AND is_default=false",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(Id)),
                                _pipe@12 = pog:execute(_pipe@11, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@12)
                            end),
                            wisp:redirect(~"/admin/languages#languages-workspace")
                        end)
                    end);

                {post, [~"admin", ~"catalog", ~"bulk-publish"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"UPDATE agency.listings SET status='published',updated_at=now() WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/catalog")
                        end)
                    end);

                {post, [~"admin", ~"listings", ~"bulk-publish"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"UPDATE agency.listings SET status='published',updated_at=now() WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/catalog")
                        end)
                    end);

                {post, [~"admin", ~"catalog", ~"bulk-unpublish"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"UPDATE agency.listings SET status='draft',updated_at=now() WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/catalog")
                        end)
                    end);

                {post, [~"admin", ~"listings", ~"bulk-unpublish"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"UPDATE agency.listings SET status='draft',updated_at=now() WHERE tenant_id=$1::uuid AND (id::text=$2 OR code=$2) AND ($3 in ('admin','staff') OR owner_user_id=$4::uuid)",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Id)),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@15 = pog:execute(_pipe@14, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@15)
                            end),
                            wisp:redirect(~"/admin/catalog")
                        end)
                    end);

                {post, [~"admin", ~"languages", ~"bulk-publish"]} ->
                    require_admin(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"UPDATE agency.languages SET active=true WHERE code=$1",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(Id)),
                                _pipe@12 = pog:execute(_pipe@11, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@12)
                            end),
                            wisp:redirect(~"/admin/languages#languages-workspace")
                        end)
                    end);

                {post, [~"admin", ~"languages", ~"bulk-unpublish"]} ->
                    require_admin(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            Ids = begin
                                _pipe@6 = erlang:element(2, Form),
                                _pipe@7 = gleam@list:filter(_pipe@6, fun(Pair) ->
                                    (erlang:element(1, Pair) =:= ~"ids") andalso (erlang:element(2, Pair) /= ~"")
                                end),
                                gleam@list:map(_pipe@7, fun(Pair) ->
                                    erlang:element(2, Pair)
                                end)
                            end,
                            _pipe@8 = Ids,
                            gleam@list:each(_pipe@8, fun(Id) ->
                                _pipe@9 = ~"UPDATE agency.languages SET active=false WHERE code=$1 AND is_default=false",
                                _pipe@10 = pog:'query'(_pipe@9),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(Id)),
                                _pipe@12 = pog:execute(_pipe@11, Db),
                                fun(_) ->
                                    nil
                                end(_pipe@12)
                            end),
                            wisp:redirect(~"/admin/languages#languages-workspace")
                        end)
                    end);

                {post, [~"admin", ~"catalog", ~"rates"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.rate_plans(listing_id,name,currency,base_minor,commission_percent,deposit_percent,min_nights,cancellation_policy,active) SELECT $1::uuid,$2,upper($3),$4,$5::text::numeric,$6::text::numeric,$7,jsonb_build_object('text',$8::text),$9::text::boolean WHERE EXISTS (SELECT 1 FROM agency.listings l WHERE l.id=$1::uuid AND l.tenant_id=$10::uuid AND ($11 in ('admin','staff') OR l.owner_user_id=$12::uuid)) AND EXISTS (SELECT 1 FROM agency.currencies cur WHERE cur.code=upper($3))",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"listing_id"))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"currency"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"base_minor"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"commission_percent"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"deposit_percent"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"min_nights"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"cancellation_policy"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@20 = pog:execute(_pipe@19, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/catalog#pricing")
                            end(_pipe@20)
                        end)
                    end);

                {post, [~"admin", ~"listings", ~"rates"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.rate_plans(listing_id,name,currency,base_minor,commission_percent,deposit_percent,min_nights,cancellation_policy,active) SELECT $1::uuid,$2,upper($3),$4,$5::text::numeric,$6::text::numeric,$7,jsonb_build_object('text',$8::text),$9::text::boolean WHERE EXISTS (SELECT 1 FROM agency.listings l WHERE l.id=$1::uuid AND l.tenant_id=$10::uuid AND ($11 in ('admin','staff') OR l.owner_user_id=$12::uuid)) AND EXISTS (SELECT 1 FROM agency.currencies cur WHERE cur.code=upper($3))",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"listing_id"))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"currency"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"base_minor"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"commission_percent"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"deposit_percent"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"min_nights"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"cancellation_policy"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@20 = pog:execute(_pipe@19, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/catalog#pricing")
                            end(_pipe@20)
                        end)
                    end);

                {post, [~"admin", ~"catalog", ~"availability"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.availability(listing_id,day,units_total,units_available,closed) SELECT $1::uuid,$2::date,$3,$4,$5::text::boolean WHERE EXISTS (SELECT 1 FROM agency.listings l WHERE l.id=$1::uuid AND l.tenant_id=$6::uuid AND ($7 in ('admin','staff') OR l.owner_user_id=$8::uuid)) ON CONFLICT(listing_id,day) DO UPDATE SET units_total=excluded.units_total,units_available=excluded.units_available,closed=excluded.closed",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"listing_id"))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"day"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"units_total"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"units_available"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"closed"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@16 = pog:execute(_pipe@15, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/catalog#availability")
                            end(_pipe@16)
                        end)
                    end);

                {post, [~"admin", ~"listings", ~"availability"]} ->
                    require_catalog_write(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.availability(listing_id,day,units_total,units_available,closed) SELECT $1::uuid,$2::date,$3,$4,$5::text::boolean WHERE EXISTS (SELECT 1 FROM agency.listings l WHERE l.id=$1::uuid AND l.tenant_id=$6::uuid AND ($7 in ('admin','staff') OR l.owner_user_id=$8::uuid)) ON CONFLICT(listing_id,day) DO UPDATE SET units_total=excluded.units_total,units_available=excluded.units_available,closed=excluded.closed",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"listing_id"))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"day"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"units_total"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"units_available"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"closed"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@16 = pog:execute(_pipe@15, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/catalog#availability")
                            end(_pipe@16)
                        end)
                    end);

                {get, [~"admin", ~"catalog", ~"operations-data"]} ->
                    require_panel_session(Db, Token, ~"catalog", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select coalesce((select json_agg(json_build_object('listing',l.title,'name',r.name,'currency',r.currency,'baseMinor',r.base_minor::text,'commission',r.commission_percent::text,'deposit',r.deposit_percent::text,'minNights',r.min_nights::text,'status',case when r.active then 'Aktif' else 'Pasif' end) order by l.title,r.name) from agency.rate_plans r join agency.listings l on l.id=r.listing_id where l.tenant_id=$1::uuid and ($2 in ('admin','staff') or l.owner_user_id=$3::uuid)),'[]'::json)::text,coalesce((select json_agg(json_build_object('listing',l.title,'day',a.day::text,'total',a.units_total::text,'available',a.units_available::text,'status',case when a.closed then 'Kapalı' else 'Satışta' end) order by a.day desc,l.title) from agency.availability a join agency.listings l on l.id=a.listing_id where l.tenant_id=$1::uuid and ($2 in ('admin','staff') or l.owner_user_id=$3::uuid)),'[]'::json)::text",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, listing_operations_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Query_result} ->
                                case gleam@list:first(erlang:element(3, Query_result)) of
                                    {ok, Row} ->
                                        _pipe@12 = wisp:ok(),
                                        _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@13, <<<<<<<<"{\"rates\":"/utf8, (erlang:element(1, Row))/binary>>/binary, ",\"availability\":"/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, "}"/utf8>>);

                                    {error, _} ->
                                        _pipe@14 = wisp:ok(),
                                        wisp:json_body(_pipe@14, ~"{\"rates\":[],\"availability\":[]}")
                                end;

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Katalog operasyonları okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"listings", ~"operations-data"]} ->
                    require_panel_session(Db, Token, ~"catalog", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select coalesce((select json_agg(json_build_object('listing',l.title,'name',r.name,'currency',r.currency,'baseMinor',r.base_minor::text,'commission',r.commission_percent::text,'deposit',r.deposit_percent::text,'minNights',r.min_nights::text,'status',case when r.active then 'Aktif' else 'Pasif' end) order by l.title,r.name) from agency.rate_plans r join agency.listings l on l.id=r.listing_id where l.tenant_id=$1::uuid and ($2 in ('admin','staff') or l.owner_user_id=$3::uuid)),'[]'::json)::text,coalesce((select json_agg(json_build_object('listing',l.title,'day',a.day::text,'total',a.units_total::text,'available',a.units_available::text,'status',case when a.closed then 'Kapalı' else 'Satışta' end) order by a.day desc,l.title) from agency.availability a join agency.listings l on l.id=a.listing_id where l.tenant_id=$1::uuid and ($2 in ('admin','staff') or l.owner_user_id=$3::uuid)),'[]'::json)::text",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, listing_operations_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Query_result} ->
                                case gleam@list:first(erlang:element(3, Query_result)) of
                                    {ok, Row} ->
                                        _pipe@12 = wisp:ok(),
                                        _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@13, <<<<<<<<"{\"rates\":"/utf8, (erlang:element(1, Row))/binary>>/binary, ",\"availability\":"/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, "}"/utf8>>);

                                    {error, _} ->
                                        _pipe@14 = wisp:ok(),
                                        wisp:json_body(_pipe@14, ~"{\"rates\":[],\"availability\":[]}")
                                end;

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Katalog operasyonları okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"categories"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.categories(tenant_id,parent_id,code,name,slug,description,active,sort_order) VALUES($1::uuid,NULLIF($2,'')::uuid,upper($3),$4,$5,$6,$7::text::boolean,$8) ON CONFLICT(tenant_id,slug) DO UPDATE SET parent_id=excluded.parent_id,code=excluded.code,name=excluded.name,description=excluded.description,active=excluded.active,sort_order=excluded.sort_order",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"parent_id"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"code"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"slug"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"description"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"sort_order"))),
                            _pipe@16 = pog:execute(_pipe@15, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/categories")
                            end(_pipe@16)
                        end)
                    end);

                {get, [~"admin", ~"categories", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select c.id::text,coalesce(p.name,''),c.code,c.name,c.slug,c.description,case when c.active then 'Aktif' else 'Pasif' end,c.sort_order::text from agency.categories c left join agency.categories p on p.id=c.parent_id where c.tenant_id=$1::uuid order by c.sort_order,c.name",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, category_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"parent", gleam@json:string(erlang:element(2, Row))}, {~"code", gleam@json:string(erlang:element(3, Row))}, {~"name", gleam@json:string(erlang:element(4, Row))}, {~"slug", gleam@json:string(erlang:element(5, Row))}, {~"description", gleam@json:string(erlang:element(6, Row))}, {~"status", gleam@json:string(erlang:element(7, Row))}, {~"sortOrder", gleam@json:string(erlang:element(8, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Kategoriler okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"categories", ~"fields"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.category_fields(category_id,field_key,label,field_type,required,options,sort_order) SELECT $1::uuid,$2,$3,$4,$5::text::boolean,jsonb_build_object('values',$6::text),$7 WHERE EXISTS (SELECT 1 FROM agency.categories c WHERE c.id=$1::uuid AND c.tenant_id=$8::uuid) ON CONFLICT(category_id,field_key) DO UPDATE SET label=excluded.label,field_type=excluded.field_type,required=excluded.required,options=excluded.options,sort_order=excluded.sort_order",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"category_id"))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"field_key"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"label"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"field_type"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"required"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"options"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"sort_order"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@16 = pog:execute(_pipe@15, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/categories#category-fields")
                            end(_pipe@16)
                        end)
                    end);

                {get, [~"admin", ~"categories", ~"fields-data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select f.id::text,c.name,c.code,f.field_key,f.label,f.field_type,case when f.required then 'Zorunlu' else 'Opsiyonel' end,f.sort_order::text from agency.category_fields f join agency.categories c on c.id=f.category_id where c.tenant_id=$1::uuid order by c.sort_order,c.name,f.sort_order,f.label",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, category_field_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"category", gleam@json:string(erlang:element(2, Row))}, {~"categoryCode", gleam@json:string(erlang:element(3, Row))}, {~"key", gleam@json:string(erlang:element(4, Row))}, {~"label", gleam@json:string(erlang:element(5, Row))}, {~"type", gleam@json:string(erlang:element(6, Row))}, {~"required", gleam@json:string(erlang:element(7, Row))}, {~"sortOrder", gleam@json:string(erlang:element(8, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Kategori alanları okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"languages", ~"data"]} ->
                    require_admin(Db, Token, fun(_) ->
                        case begin
                            _pipe@6 = ~"select code,name,native_name,case when active then 'Aktif' else 'Pasif' end,case when is_default then 'Varsayılan' else '' end from agency.languages order by is_default desc,name",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:returning(_pipe@7, language_decoder()),
                            pog:execute(_pipe@8, Db)
                        end of
                            {ok, Result} ->
                                _pipe@9 = erlang:element(3, Result),
                                _pipe@10 = gleam@json:array(_pipe@9, fun(Row) ->
                                    gleam@json:object([{~"code", gleam@json:string(erlang:element(1, Row))}, {~"name", gleam@json:string(erlang:element(2, Row))}, {~"nativeName", gleam@json:string(erlang:element(3, Row))}, {~"status", gleam@json:string(erlang:element(4, Row))}, {~"defaultLabel", gleam@json:string(erlang:element(5, Row))}])
                                end),
                                _pipe@11 = gleam@json:to_string(_pipe@10),
                                fun(Body) ->
                                    _pipe@12 = wisp:ok(),
                                    _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@13, Body)
                                end(_pipe@11);

                            {error, _} ->
                                _pipe@12 = wisp:response(500),
                                wisp:json_body(_pipe@12, ~"{\"error\":\"Diller okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"customers"]} ->
                    require_panel_session(Db, Token, ~"customers", fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Full_name = gleam@string:trim(form_value(erlang:element(2, Form), ~"full_name")),
                            Email = string:lowercase(gleam@string:trim(form_value(erlang:element(2, Form), ~"email"))),
                            Phone = gleam@string:trim(form_value(erlang:element(2, Form), ~"phone")),
                            Valid_email = (Email =:= ~"") orelse ((string:length(Email) >= 5) andalso gleam_stdlib:contains_string(Email, ~"@")),
                            Valid_phone = (Phone =:= ~"") orelse (string:length(Phone) >= 7),
                            case (((Full_name =:= ~"") orelse ((Email =:= ~"") andalso (Phone =:= ~""))) orelse not Valid_email) orelse not Valid_phone of
                                true ->
                                    _pipe@6 = wisp:response(400),
                                    wisp:string_body(_pipe@6, ~"Ad ve geçerli bir e-posta veya telefon zorunludur.");

                                false ->
                                    _pipe@7 = ~"INSERT INTO agency.customers(tenant_id,full_name,email,phone) VALUES($1::uuid,$2,NULLIF(lower(trim($3)),''),$4) ON CONFLICT(tenant_id,email) DO UPDATE SET full_name=excluded.full_name,phone=excluded.phone",
                                    _pipe@8 = pog:'query'(_pipe@7),
                                    _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                                    _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Full_name)),
                                    _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(Email)),
                                    _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Phone)),
                                    _pipe@13 = pog:execute(_pipe@12, Db),
                                    fun(Result) ->
                                        case Result of
                                            {ok, _} ->
                                                wisp:redirect(~"/admin/customers");

                                            {error, _} ->
                                                _pipe@14 = wisp:response(409),
                                                wisp:string_body(_pipe@14, ~"Müşteri kaydedilemedi.")
                                        end
                                    end(_pipe@13)
                            end
                        end)
                    end);

                {get, [~"admin", ~"customers", ~"data"]} ->
                    require_panel_session(Db, Token, ~"customers", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select id::text,full_name,coalesce(email,''),phone,to_char(created_at,'YYYY-MM-DD HH24:MI') from agency.customers c where c.tenant_id=$1::uuid and ($2 in ('admin','staff','sub_agency') or exists (select 1 from agency.reservations r join agency.listings l on l.id=r.listing_id where r.customer_id=c.id and l.owner_user_id=$3::uuid)) order by created_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, customer_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                _pipe@12 = erlang:element(3, Result),
                                _pipe@13 = gleam@json:array(_pipe@12, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"name", gleam@json:string(erlang:element(2, Row))}, {~"email", gleam@json:string(erlang:element(3, Row))}, {~"phone", gleam@json:string(erlang:element(4, Row))}, {~"createdAt", gleam@json:string(erlang:element(5, Row))}])
                                end),
                                _pipe@14 = gleam@json:to_string(_pipe@13),
                                fun(Body) ->
                                    _pipe@15 = wisp:ok(),
                                    _pipe@16 = fun gleam@http@response:set_header/3(_pipe@15, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@16, Body)
                                end(_pipe@14);

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Müşteriler okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"reservations"]} ->
                    require_panel_session(Db, Token, ~"reservations", fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Insert_result = begin
                                _pipe@6 = ~"INSERT INTO agency.reservations(tenant_id,listing_id,customer_id,reference_code,check_in,check_out,guest_count,total_minor,currency,status) SELECT $1::uuid,NULLIF($2,'')::uuid,NULLIF($3,'')::uuid,$4,NULLIF($5,'')::date,NULLIF($6,'')::date,$7,$8,upper($9),$10 WHERE (NULLIF($2,'') IS NULL OR EXISTS (SELECT 1 FROM agency.listings l WHERE l.id=NULLIF($2,'')::uuid AND l.tenant_id=$1::uuid AND ($11 in ('admin','staff','sub_agency') OR l.owner_user_id=$12::uuid))) AND (NULLIF($3,'') IS NULL OR EXISTS (SELECT 1 FROM agency.customers c WHERE c.id=NULLIF($3,'')::uuid AND c.tenant_id=$1::uuid)) AND EXISTS (SELECT 1 FROM agency.currencies cur WHERE cur.code=upper($9)) AND $10 IN ('inquiry','option','confirmed','cancelled','completed') RETURNING id::text",
                                _pipe@7 = pog:'query'(_pipe@6),
                                _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"listing_id"))),
                                _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"customer_id"))),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"reference_code"))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"check_in"))),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"check_out"))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"guest_count"))),
                                _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"total_minor"))),
                                _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"currency"))),
                                _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"status"))),
                                _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(erlang:element(5, Session))),
                                _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(erlang:element(3, Session))),
                                _pipe@20 = pog:returning(_pipe@19, id_decoder()),
                                pog:execute(_pipe@20, Db)
                            end,
                            case Insert_result of
                                {ok, Result} ->
                                    case gleam@list:is_empty(erlang:element(3, Result)) of
                                        true ->
                                            _pipe@21 = wisp:response(422),
                                            wisp:html_body(_pipe@21, nexus_agency@panel:section(Session, ~"reservations", ~"İlan, müşteri, para birimi veya rezervasyon durumu geçersiz.", section_links(~"reservations"), Lang, Active_cat));

                                        false ->
                                            wisp:redirect(~"/admin/reservations")
                                    end;

                                {error, Error} ->
                                    case Error of
                                        {constraint_violated, Message, Constraint, Detail} ->
                                            gleam_stdlib:println(<<<<<<<<<<"Reservation insert failed: "/utf8, Message/binary>>/binary, " "/utf8>>/binary, Constraint/binary>>/binary, " "/utf8>>/binary, Detail/binary>>);

                                        {postgresql_error, Code, Name, Message@1} ->
                                            gleam_stdlib:println(<<<<<<<<<<"Reservation insert failed: "/utf8, Code/binary>>/binary, " "/utf8>>/binary, Name/binary>>/binary, " "/utf8>>/binary, Message@1/binary>>);

                                        {unexpected_argument_count, Expected, Got} ->
                                            gleam_stdlib:println(<<<<<<"Reservation insert failed: expected "/utf8, (erlang:integer_to_binary(Expected))/binary>>/binary, " params, got "/utf8>>/binary, (erlang:integer_to_binary(Got))/binary>>);

                                        {unexpected_argument_type, Expected@1, Got@1} ->
                                            gleam_stdlib:println(<<<<<<"Reservation insert failed: "/utf8, Expected@1/binary>>/binary, " / "/utf8>>/binary, Got@1/binary>>);

                                        {unexpected_result_type, _} ->
                                            gleam_stdlib:println(~"Reservation insert failed: result type");

                                        query_timeout ->
                                            gleam_stdlib:println(~"Reservation insert failed: timeout");

                                        connection_unavailable ->
                                            gleam_stdlib:println(~"Reservation insert failed: database unavailable")
                                    end,
                                    _pipe@22 = wisp:response(422),
                                    wisp:html_body(_pipe@22, nexus_agency@panel:section(Session, ~"reservations", ~"Rezervasyon kaydı oluşturulamadı. Zorunlu alanları kontrol edin.", section_links(~"reservations"), Lang, Active_cat))
                            end
                        end)
                    end);

                {get, [~"admin", ~"reservations", ~"data"]} ->
                    require_panel_session(Db, Token, ~"reservations", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select r.id::text,r.reference_code,coalesce(l.title,''),coalesce(c.full_name,''),coalesce(to_char(r.check_in,'YYYY-MM-DD'),''),coalesce(to_char(r.check_out,'YYYY-MM-DD'),''),r.guest_count::text,r.total_minor::text,r.currency,r.status,r.payment_status from agency.reservations r left join agency.listings l on l.id=r.listing_id left join agency.customers c on c.id=r.customer_id where r.tenant_id=$1::uuid and ($2 in ('admin','staff','sub_agency') or l.owner_user_id=$3::uuid) order by r.created_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, reservation_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                _pipe@12 = erlang:element(3, Result),
                                _pipe@13 = gleam@json:array(_pipe@12, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"reference", gleam@json:string(erlang:element(2, Row))}, {~"listing", gleam@json:string(erlang:element(3, Row))}, {~"customer", gleam@json:string(erlang:element(4, Row))}, {~"checkIn", gleam@json:string(erlang:element(5, Row))}, {~"checkOut", gleam@json:string(erlang:element(6, Row))}, {~"guests", gleam@json:string(erlang:element(7, Row))}, {~"total", gleam@json:string(erlang:element(8, Row))}, {~"currency", gleam@json:string(erlang:element(9, Row))}, {~"status", gleam@json:string(erlang:element(10, Row))}, {~"paymentStatus", gleam@json:string(erlang:element(11, Row))}])
                                end),
                                _pipe@14 = gleam@json:to_string(_pipe@13),
                                fun(Body) ->
                                    _pipe@15 = wisp:ok(),
                                    _pipe@16 = fun gleam@http@response:set_header/3(_pipe@15, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@16, Body)
                                end(_pipe@14);

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Rezervasyonlar okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"inquiries", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        public_inquiries_data(Db, erlang:element(2, Session))
                    end);

                {get, [~"admin", ~"notifications", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        notifications_data(Db, erlang:element(2, Session))
                    end);

                {post, [~"admin", ~"notifications", ~"retry"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Notification_id = form_value(erlang:element(2, Form), ~"id"),
                            _pipe@6 = ~"update agency.notifications set status='queued',next_attempt_at=null,last_error='' where tenant_id=$1::uuid and id=$2::uuid and status='failed'",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Notification_id)),
                            _pipe@10 = pog:execute(_pipe@9, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/notifications#notifications-workspace")
                            end(_pipe@10)
                        end)
                    end);

                {get, [~"admin", ~"search-analytics", ~"data"]} ->
                    require_admin(Db, Token, fun(_) ->
                        search_analytics_data(Db)
                    end);

                {post, [~"admin", ~"inquiries", ~"status"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        update_inquiry_status(Req, Db, erlang:element(2, Session))
                    end);

                {post, [~"admin", ~"inquiries", ~"convert"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        convert_inquiry(Req, Db, erlang:element(2, Session))
                    end);

                {get, [~"admin", ~"reservations", ~"options"]} ->
                    require_panel_session(Db, Token, ~"reservations", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select coalesce((select json_agg(json_build_object('id',l.id::text,'name',l.title) order by l.title) from agency.listings l where l.tenant_id=$1::uuid and ($2 in ('admin','staff','sub_agency') or l.owner_user_id=$3::uuid)),'[]'::json)::text,coalesce((select json_agg(json_build_object('id',c.id::text,'name',c.full_name) order by c.full_name) from agency.customers c where c.tenant_id=$1::uuid and ($2 in ('admin','staff','sub_agency') or exists (select 1 from agency.reservations r join agency.listings l on l.id=r.listing_id where r.customer_id=c.id and l.owner_user_id=$3::uuid))),'[]'::json)::text",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(erlang:element(3, Session))),
                            _pipe@11 = pog:returning(_pipe@10, options_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Query_result} ->
                                case gleam@list:first(erlang:element(3, Query_result)) of
                                    {ok, Row} ->
                                        _pipe@12 = wisp:ok(),
                                        _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@13, <<<<<<<<"{\"listings\":"/utf8, (erlang:element(1, Row))/binary>>/binary, ",\"customers\":"/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, "}"/utf8>>);

                                    {error, _} ->
                                        _pipe@14 = wisp:ok(),
                                        wisp:json_body(_pipe@14, ~"{\"listings\":[],\"customers\":[]}")
                                end;

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Seçenekler okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"currencies"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Currency_query = ~"INSERT INTO agency.currencies(code,name,symbol,rate,adjustment_percent,active,updated_at) VALUES(upper($1),$2,$3,$4::text::numeric,$5::text::numeric,$6::text::boolean,now()) ON CONFLICT(code) DO UPDATE SET name=excluded.name,symbol=excluded.symbol,rate=excluded.rate,adjustment_percent=excluded.adjustment_percent,active=excluded.active,updated_at=now()",
                            _ = begin
                                _pipe@6 = Currency_query,
                                _pipe@7 = pog:'query'(_pipe@6),
                                _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"code"))),
                                _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                                _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"symbol"))),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"rate"))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"adjustment_percent"))),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                                pog:execute(_pipe@13, Db)
                            end,
                            Schedule_query = ~"INSERT INTO agency.currency_update_schedules(tenant_id,provider,first_run_at,second_run_at,active) VALUES($1::uuid,$2,$3::text::time,$4::text::time,true) ON CONFLICT(tenant_id) DO UPDATE SET provider=excluded.provider,first_run_at=excluded.first_run_at,second_run_at=excluded.second_run_at,active=true",
                            _pipe@14 = Schedule_query,
                            _pipe@15 = pog:'query'(_pipe@14),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"rate_provider"))),
                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"first_run_at"))),
                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"second_run_at"))),
                            _pipe@20 = pog:execute(_pipe@19, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/currencies")
                            end(_pipe@20)
                        end)
                    end);

                {post, [~"admin", ~"currencies", ~"delete"]} ->
                    require_admin(Db, Token, fun(_) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"DELETE FROM agency.currencies cur WHERE cur.code=upper($1) AND cur.code<>'TRY' AND NOT EXISTS (SELECT 1 FROM agency.listings l WHERE l.currency=cur.code) AND NOT EXISTS (SELECT 1 FROM agency.rate_plans rp WHERE rp.currency=cur.code) AND NOT EXISTS (SELECT 1 FROM agency.reservations r WHERE r.currency=cur.code)",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"code"))),
                            _pipe@9 = pog:execute(_pipe@8, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/currencies")
                            end(_pipe@9)
                        end)
                    end);

                {post, [~"admin", ~"currencies", ~"refresh"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        _pipe@6 = ~"INSERT INTO agency.task_runs(tenant_id,task_name,status,payload) VALUES($1::uuid,'currency.refresh','queued','{}'::jsonb)",
                        _pipe@7 = pog:'query'(_pipe@6),
                        _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                        _pipe@9 = pog:execute(_pipe@8, Db),
                        fun(_) ->
                            wisp:redirect(~"/admin/currencies#currency-settings")
                        end(_pipe@9)
                    end);

                {post, [~"admin", ~"settings"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            All_keys = [~"brand_name", ~"contact_email", ~"contact_phone", ~"whatsapp", ~"address", ~"logo_url", ~"logo_dark_url", ~"favicon_url", ~"default_language", ~"default_currency", ~"tursab_no", ~"tursab_verify_url", ~"tax_office", ~"tax_no", ~"active_payment_gateway", ~"parampos_client_code", ~"parampos_username", ~"parampos_password", ~"parampos_guid", ~"bank_iban_try", ~"bank_iban_eur", ~"bank_iban_usd", ~"bank_iban_gbp", ~"bank_instructions", ~"cash_payment_enabled", ~"ai_provider", ~"ai_api_key", ~"ai_model", ~"ai_temperature", ~"ai_auto_seo_enabled", ~"netgsm_usercode", ~"netgsm_password", ~"netgsm_header", ~"sms_template_booking", ~"sms_template_reminder", ~"sms_enabled", ~"tcmb_auto_sync", ~"currency_spread_percent", ~"ga4_measurement_id", ~"gtm_id", ~"meta_pixel_id", ~"tiktok_pixel_id", ~"google_maps_api_key", ~"map_default_lat", ~"map_default_lng", ~"map_default_zoom", ~"smtp_host", ~"smtp_username", ~"smtp_password", ~"integration_endpoint", ~"contract_distance_selling", ~"contract_cancellation_refund", ~"contract_privacy_policy", ~"contract_cookie_policy", ~"contract_templates_json", ~"contract_general_json", ~"ai_chat_enabled", ~"ai_followup_enabled", ~"ai_cross_sell_enabled", ~"ai_region_content_enabled", ~"social_meta_account", ~"social_global_account", ~"social_language_routing"],
                            gleam@list:each(All_keys, fun(K) ->
                                case gleam@list:key_find(erlang:element(2, Form), K) of
                                    {ok, V} ->
                                        save_setting(Db, erlang:element(2, Session), K, V);

                                    {error, _} ->
                                        nil
                                end
                            end),
                            Is_ajax = case gleam@list:key_find(erlang:element(3, Req), ~"accept") of
                                {ok, Acc} ->
                                    gleam_stdlib:contains_string(Acc, ~"application/json");

                                {error, _} ->
                                    false
                            end,
                            case Is_ajax of
                                true ->
                                    Res = begin
                                        _pipe@6 = gleam@json:object([{~"ok", gleam@json:bool(true)}, {~"message", gleam@json:string(~"Ayarlar başarıyla kaydedildi.")}]),
                                        gleam@json:to_string(_pipe@6)
                                    end,
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@8, Res);

                                false ->
                                    wisp:redirect(~"/admin/settings#settings-workspace")
                            end
                        end)
                    end);

                {post, [~"admin", ~"social"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Network = string:lowercase(gleam@string:trim(form_value(erlang:element(2, Form), ~"network"))),
                            Language_code = nexus_agency@i18n:normalize_lang(form_value(erlang:element(2, Form), ~"language_code")),
                            case (((Network =:= ~"instagram") orelse (Network =:= ~"facebook")) orelse (Network =:= ~"threads")) orelse (Network =:= ~"pinterest") of
                                false ->
                                    _pipe@6 = wisp:response(400),
                                    wisp:string_body(_pipe@6, ~"Geçersiz sosyal ağ seçimi.");

                                true ->
                                    Query = ~"INSERT INTO agency.social_posts(tenant_id,entity_type,entity_id,network,content,status,scheduled_at,metadata) VALUES($1::uuid,'manual',gen_random_uuid(),$2,$3,'queued',NULLIF($4,'')::timestamptz,jsonb_build_object('language',$5,'media_url',$6))",
                                    _pipe@7 = Query,
                                    _pipe@8 = pog:'query'(_pipe@7),
                                    _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                                    _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Network)),
                                    _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(<<<<<<"["/utf8, Language_code/binary>>/binary, "] "/utf8>>/binary, (form_value(erlang:element(2, Form), ~"content"))/binary>>)),
                                    _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"scheduled_at"))),
                                    _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(Language_code)),
                                    _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"media_url"))),
                                    _pipe@15 = pog:execute(_pipe@14, Db),
                                    fun(_) ->
                                        wisp:redirect(~"/admin/ai#ai-workspace")
                                    end(_pipe@15)
                            end
                        end)
                    end);

                {get, [~"admin", ~"settings", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select coalesce(json_object_agg(key,value),'{}'::json)::text from agency.settings where tenant_id=$1::uuid and key not in ('parampos_password','smtp_password','ai_api_key','netgsm_password')",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, settings_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                case gleam@list:first(erlang:element(3, Result)) of
                                    {ok, Row} ->
                                        _pipe@10 = wisp:ok(),
                                        _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@11, Row);

                                    {error, _} ->
                                        _pipe@12 = wisp:ok(),
                                        wisp:json_body(_pipe@12, ~"{}")
                                end;

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Ayarlar okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"integrations"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.integrations(tenant_id,provider,kind,credentials,active) VALUES($1::uuid,$2,$3,jsonb_build_object('client_code',$4,'username',$5,'password',$6,'guid',$7,'host',$8,'endpoint',$9,'api_key',$10,'provider_name',$11,'agency_code',$12,'token',$13,'margin_percent',$14,'netgsm_user',$15,'netgsm_pass',$16,'netgsm_header',$17,'whatsapp_phone_id',$18,'whatsapp_token',$19,'access_token',$20,'page_id',$21,'instagram_id',$22,'threads_user_id',$23,'pinterest_token',$24,'pinterest_board_id',$25),$26::text::boolean) ON CONFLICT(tenant_id,provider,kind) DO UPDATE SET credentials=agency.integrations.credentials || coalesce((select jsonb_object_agg(k,v) from jsonb_each_text(excluded.credentials) where v <> ''),'{}'::jsonb),active=excluded.active",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"provider"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"kind"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"client_code"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"username"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"password"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"guid"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"host"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"endpoint"))),
                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"api_key"))),
                            _pipe@18 = pog:parameter(_pipe@17, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"provider_name"))),
                            _pipe@19 = pog:parameter(_pipe@18, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"agency_code"))),
                            _pipe@20 = pog:parameter(_pipe@19, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"token"))),
                            _pipe@21 = pog:parameter(_pipe@20, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"margin_percent"))),
                            _pipe@22 = pog:parameter(_pipe@21, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"netgsm_user"))),
                            _pipe@23 = pog:parameter(_pipe@22, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"netgsm_pass"))),
                            _pipe@24 = pog:parameter(_pipe@23, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"netgsm_header"))),
                            _pipe@25 = pog:parameter(_pipe@24, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"whatsapp_phone_id"))),
                            _pipe@26 = pog:parameter(_pipe@25, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"whatsapp_token"))),
                            _pipe@27 = pog:parameter(_pipe@26, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"access_token"))),
                            _pipe@28 = pog:parameter(_pipe@27, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"page_id"))),
                            _pipe@29 = pog:parameter(_pipe@28, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"instagram_id"))),
                            _pipe@30 = pog:parameter(_pipe@29, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"threads_user_id"))),
                            _pipe@31 = pog:parameter(_pipe@30, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"pinterest_token"))),
                            _pipe@32 = pog:parameter(_pipe@31, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"pinterest_board_id"))),
                            _pipe@33 = pog:parameter(_pipe@32, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@34 = pog:execute(_pipe@33, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/integrations")
                            end(_pipe@34)
                        end)
                    end);

                {post, [~"admin", ~"nexus", ~"connection-request"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Endpoint = gleam@string:trim(form_value(erlang:element(2, Form), ~"endpoint")),
                            Api_key = gleam@string:trim(form_value(erlang:element(2, Form), ~"api_key")),
                            Agency_id = case gleam@string:trim(form_value(erlang:element(2, Form), ~"agency_code")) of
                                ~"" ->
                                    erlang:element(2, Session);

                                Value@1 ->
                                    Value@1
                            end,
                            Agency_name = begin
                                _pipe@6 = ~"select coalesce(brand_name,legal_name,'NEXUS Agency') from agency.tenants where id=$1::uuid",
                                _pipe@7 = pog:'query'(_pipe@6),
                                _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@9 = pog:returning(_pipe@8, single_string_decoder()),
                                _pipe@10 = pog:execute(_pipe@9, Db),
                                fun(Value@2) ->
                                    case Value@2 of
                                        {ok, Result} ->
                                            case gleam@list:first(erlang:element(3, Result)) of
                                                {ok, Name} ->
                                                    Name;

                                                {error, _} ->
                                                    ~"NEXUS Agency"
                                            end;

                                        {error, _} ->
                                            ~"NEXUS Agency"
                                    end
                                end(_pipe@10)
                            end,
                            case (Endpoint =:= ~"") orelse (Api_key =:= ~"") of
                                true ->
                                    _pipe@11 = wisp:response(400),
                                    wisp:json_body(_pipe@11, ~"{\"ok\":false,\"error\":\"NEXUS bağlantı adresi ve API anahtarı gerekli.\"}");

                                false ->
                                    Url = <<<<<<<<<<<<Endpoint/binary, "/v1/agency/connection-request?agency_id="/utf8>>/binary, (gleam_stdlib:percent_encode(Agency_id))/binary>>/binary, "&agency_name="/utf8>>/binary, (gleam_stdlib:percent_encode(Agency_name))/binary>>/binary, "&agency_endpoint="/utf8>>/binary, (gleam_stdlib:percent_encode(Origin))/binary>>,
                                    case agency_ffi_http:post_json_with_timeout(Url, ~"{}", <<"Bearer "/utf8, Api_key/binary>>, 12000) of
                                        {ok, Raw} ->
                                            Accepted = gleam_stdlib:contains_string(Raw, ~"\"ok\":true"),
                                            Status = case Accepted of
                                                true ->
                                                    ~"pending";

                                                false ->
                                                    ~"error"
                                            end,
                                            Message = case Accepted of
                                                true ->
                                                    ~"Bağlantı isteği NEXUS incelemesine gönderildi.";

                                                false ->
                                                    <<"NEXUS isteği kabul etmedi: "/utf8, (gleam@string:slice(Raw, 0, 300))/binary>>
                                            end,
                                            Remote_id = connection_request_id(Raw),
                                            _pipe@12 = ~"INSERT INTO agency.nexus_connection_requests(tenant_id,remote_request_id,status,message,updated_at) VALUES($1::uuid,$2,$3,$4,now()) ON CONFLICT(tenant_id) DO UPDATE SET remote_request_id=excluded.remote_request_id,status=excluded.status,message=excluded.message,updated_at=now()",
                                            _pipe@13 = pog:'query'(_pipe@12),
                                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(erlang:element(2, Session))),
                                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(Remote_id)),
                                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(Status)),
                                            _pipe@17 = pog:parameter(_pipe@16, pog_ffi:coerce(Message)),
                                            _pipe@18 = pog:execute(_pipe@17, Db),
                                            fun(_) ->
                                                Body = connection_result_json(true, ~"message", Message),
                                                case Accepted of
                                                    true ->
                                                        _pipe@19 = wisp:ok(),
                                                        wisp:json_body(_pipe@19, Body);

                                                    false ->
                                                        _pipe@20 = wisp:response(502),
                                                        wisp:json_body(_pipe@20, connection_result_json(false, ~"error", Message))
                                                end
                                            end(_pipe@18);

                                        {error, Error} ->
                                            Message@1 = <<"NEXUS bağlantı isteği başarısız: "/utf8, Error/binary>>,
                                            _pipe@19 = ~"INSERT INTO agency.nexus_connection_requests(tenant_id,status,message,updated_at) VALUES($1::uuid,'error',$2,now()) ON CONFLICT(tenant_id) DO UPDATE SET status='error',message=excluded.message,updated_at=now()",
                                            _pipe@20 = pog:'query'(_pipe@19),
                                            _pipe@21 = pog:parameter(_pipe@20, pog_ffi:coerce(erlang:element(2, Session))),
                                            _pipe@22 = pog:parameter(_pipe@21, pog_ffi:coerce(Message@1)),
                                            _pipe@23 = pog:execute(_pipe@22, Db),
                                            fun(_) ->
                                                _pipe@24 = wisp:response(502),
                                                wisp:json_body(_pipe@24, connection_result_json(false, ~"error", Message@1))
                                            end(_pipe@23)
                                    end
                            end
                        end)
                    end);

                {get, [~"admin", ~"integrations", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select provider,kind,case when active then 'Aktif' else 'Pasif' end,case when not exists(select 1 from jsonb_each_text(credentials) where value <> '') then 'Hayır' else 'Evet' end from agency.integrations where tenant_id=$1::uuid order by provider,kind",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, integration_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"provider", gleam@json:string(erlang:element(1, Row))}, {~"kind", gleam@json:string(erlang:element(2, Row))}, {~"status", gleam@json:string(erlang:element(3, Row))}, {~"configured", gleam@json:string(erlang:element(4, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Entegrasyonlar okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"integrations", ~"test"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        Query = wisp:get_query(Req),
                        Provider = case gleam@list:key_find(Query, ~"provider") of
                            {ok, Value@1} ->
                                Value@1;

                            {error, _} ->
                                ~""
                        end,
                        Kind = case gleam@list:key_find(Query, ~"kind") of
                            {ok, Value@2} ->
                                Value@2;

                            {error, _} ->
                                ~""
                        end,
                        case begin
                            _pipe@6 = ~"select case when active and exists(select 1 from jsonb_each_text(credentials) where value <> '') then 'true' else 'false' end from agency.integrations where tenant_id=$1::uuid and provider=$2 and kind=$3 limit 1",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(Provider)),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Kind)),
                            _pipe@11 = pog:returning(_pipe@10, integration_test_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                case gleam@list:first(erlang:element(3, Result)) of
                                    {ok, Value@3} ->
                                        _pipe@12 = wisp:ok(),
                                        wisp:json_body(_pipe@12, <<<<<<<<"{\"ok\":"/utf8, Value@3/binary>>/binary, ",\"provider\":\""/utf8>>/binary, Provider/binary>>/binary, "\"}"/utf8>>);

                                    {error, _} ->
                                        _pipe@13 = wisp:ok(),
                                        wisp:json_body(_pipe@13, ~"{\"ok\":false,\"error\":\"Bağlantı kaydı bulunamadı\"}")
                                end;

                            {error, _} ->
                                _pipe@14 = wisp:response(500),
                                wisp:json_body(_pipe@14, ~"{\"ok\":false,\"error\":\"Bağlantı testi başarısız\"}")
                        end
                    end);

                {post, [~"admin", ~"cms"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Page_result = begin
                                _pipe@6 = ~"WITH upsert AS (INSERT INTO agency.pages AS target(tenant_id,slug,template,status,seo,published_at) VALUES($1::uuid,$2,$3,$4,jsonb_build_object('title',$5::text,'description',$6::text,'keywords',$7::text,'category_scope',$8::text),case when $4='published' then now() else null end) ON CONFLICT(tenant_id,slug) DO UPDATE SET template=excluded.template,status=excluded.status,seo=excluded.seo,published_at=case when excluded.status='published' then coalesce(target.published_at,now()) else null end RETURNING id), removed AS (DELETE FROM agency.page_blocks WHERE page_id=(SELECT id FROM upsert)), added AS (INSERT INTO agency.page_blocks(page_id,block_type,sort_order,content) SELECT (SELECT id FROM upsert), coalesce(x->>'type','rich_text'), (row_number() over () - 1)::int, coalesce(x - 'type','{}'::jsonb) FROM jsonb_array_elements(CASE WHEN jsonb_typeof($9::jsonb)='array' THEN $9::jsonb ELSE '[]'::jsonb END) x RETURNING id) SELECT 1",
                                _pipe@7 = pog:'query'(_pipe@6),
                                _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                                _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"slug"))),
                                _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"template"))),
                                _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"status"))),
                                _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_title"))),
                                _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_description"))),
                                _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"seo_keywords"))),
                                _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"category_scope"))),
                                _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"blocks_json"))),
                                pog:execute(_pipe@16, Db)
                            end,
                            case Page_result of
                                {ok, _} ->
                                    wisp:redirect(~"/admin/cms");

                                {error, Error} ->
                                    case Error of
                                        {constraint_violated, Message, Constraint, Detail} ->
                                            gleam_stdlib:println(<<<<<<<<<<"CMS page insert failed: "/utf8, Message/binary>>/binary, " "/utf8>>/binary, Constraint/binary>>/binary, " "/utf8>>/binary, Detail/binary>>);

                                        {postgresql_error, Code, Name, Message@1} ->
                                            gleam_stdlib:println(<<<<<<<<<<"CMS page insert failed: "/utf8, Code/binary>>/binary, " "/utf8>>/binary, Name/binary>>/binary, " "/utf8>>/binary, Message@1/binary>>);

                                        {unexpected_argument_count, Expected, Got} ->
                                            gleam_stdlib:println(<<<<<<"CMS page insert failed: expected "/utf8, (erlang:integer_to_binary(Expected))/binary>>/binary, " params, got "/utf8>>/binary, (erlang:integer_to_binary(Got))/binary>>);

                                        {unexpected_argument_type, Expected@1, Got@1} ->
                                            gleam_stdlib:println(<<<<<<"CMS page insert failed: "/utf8, Expected@1/binary>>/binary, " / "/utf8>>/binary, Got@1/binary>>);

                                        {unexpected_result_type, _} ->
                                            gleam_stdlib:println(~"CMS page insert failed: result type");

                                        query_timeout ->
                                            gleam_stdlib:println(~"CMS page insert failed: timeout");

                                        connection_unavailable ->
                                            gleam_stdlib:println(~"CMS page insert failed: database unavailable")
                                    end,
                                    _pipe@17 = wisp:response(422),
                                    wisp:html_body(_pipe@17, nexus_agency@panel:section(Session, ~"cms", ~"Sayfa kaydedilemedi. Slug ve yayın alanlarını kontrol edin.", section_links(~"cms"), Lang, Active_cat))
                            end
                        end)
                    end);

                {get, [~"admin", ~"cms", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select id::text,slug,template,status,coalesce(seo->>'title',''),coalesce(to_char(published_at,'YYYY-MM-DD HH24:MI'),'') from agency.pages where tenant_id=$1::uuid order by slug",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, page_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"slug", gleam@json:string(erlang:element(2, Row))}, {~"template", gleam@json:string(erlang:element(3, Row))}, {~"status", gleam@json:string(erlang:element(4, Row))}, {~"seoTitle", gleam@json:string(erlang:element(5, Row))}, {~"publishedAt", gleam@json:string(erlang:element(6, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"CMS sayfaları okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"cms", ~"blocks"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        Slug = case begin
                            _pipe@6 = wisp:get_query(Req),
                            gleam@list:key_find(_pipe@6, ~"slug")
                        end of
                            {ok, Value@1} ->
                                Value@1;

                            {error, _} ->
                                ~""
                        end,
                        case begin
                            _pipe@7 = ~"select b.block_type,b.sort_order,b.content::text from agency.page_blocks b join agency.pages p on p.id=b.page_id where p.tenant_id=$1::uuid and p.slug=$2 order by b.sort_order",
                            _pipe@8 = pog:'query'(_pipe@7),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Slug)),
                            _pipe@11 = pog:returning(_pipe@10, page_block_decoder()),
                            pog:execute(_pipe@11, Db)
                        end of
                            {ok, Result} ->
                                _pipe@12 = erlang:element(3, Result),
                                _pipe@13 = gleam@json:array(_pipe@12, fun(Row) ->
                                    gleam@json:object([{~"type", gleam@json:string(erlang:element(1, Row))}, {~"sortOrder", gleam@json:int(erlang:element(2, Row))}, {~"content", gleam@json:string(erlang:element(3, Row))}])
                                end),
                                _pipe@14 = gleam@json:to_string(_pipe@13),
                                fun(Body) ->
                                    _pipe@15 = wisp:ok(),
                                    _pipe@16 = fun gleam@http@response:set_header/3(_pipe@15, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@16, Body)
                                end(_pipe@14);

                            {error, _} ->
                                _pipe@15 = wisp:response(500),
                                wisp:json_body(_pipe@15, ~"{\"error\":\"Sayfa modülleri okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"ai", ~"key-pool"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Indexes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                            gleam@list:each(Indexes, fun(Index) ->
                                Suffix = erlang:integer_to_binary(Index),
                                Label = <<"Gemini "/utf8, Suffix/binary>>,
                                save_ai_pool_key(Db, erlang:element(2, Session), ~"google", Label, form_value(erlang:element(2, Form), <<<<"gemini_"/utf8, Suffix/binary>>/binary, "_key"/utf8>>), form_value(erlang:element(2, Form), <<<<"gemini_"/utf8, Suffix/binary>>/binary, "_model"/utf8>>), Index, form_int(erlang:element(2, Form), <<<<"gemini_"/utf8, Suffix/binary>>/binary, "_limit"/utf8>>), form_bool(erlang:element(2, Form), <<<<"gemini_"/utf8, Suffix/binary>>/binary, "_active"/utf8>>))
                            end),
                            save_ai_pool_key(Db, erlang:element(2, Session), ~"deepseek", ~"DeepSeek yedek", form_value(erlang:element(2, Form), ~"deepseek_key"), form_value(erlang:element(2, Form), ~"deepseek_model"), 100, form_int(erlang:element(2, Form), ~"deepseek_limit"), form_bool(erlang:element(2, Form), ~"deepseek_active")),
                            _pipe@6 = wisp:ok(),
                            _pipe@7 = fun gleam@http@response:set_header/3(_pipe@6, ~"content-type", ~"application/json; charset=utf-8"),
                            wisp:json_body(_pipe@7, ~"{\"ok\":true,\"message\":\"AI anahtar havuzu kaydedildi.\"}")
                        end)
                    end);

                {get, [~"admin", ~"ai", ~"key-pool", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        _pipe@6 = ~"UPDATE agency.ai_key_pool SET daily_used=0,usage_day=current_date,last_error='' WHERE tenant_id=$1::uuid AND usage_day<current_date",
                        _pipe@7 = pog:'query'(_pipe@6),
                        _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                        _pipe@9 = pog:execute(_pipe@8, Db),
                        fun(_) ->
                            _pipe@10 = ~"select coalesce(json_agg(json_build_object('id',id::text,'provider',provider,'label',label,'model',model,'configured',api_key_encrypted<>'','maskedKey',case when api_key_encrypted='' then '' else '••••••••' || right(api_key_encrypted,4) end,'priority',priority,'dailyUsed',daily_used,'dailyLimit',daily_limit,'active',active,'lastError',last_error,'cooldownUntil',coalesce(to_char(cooldown_until,'YYYY-MM-DD HH24:MI:SS'),'')) order by priority,id),'[]'::json)::text from agency.ai_key_pool where tenant_id=$1::uuid",
                            _pipe@11 = pog:'query'(_pipe@10),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@13 = pog:returning(_pipe@12, ai_pool_data_decoder()),
                            _pipe@14 = pog:execute(_pipe@13, Db),
                            fun(Result) ->
                                case Result of
                                    {ok, Query_result} ->
                                        case gleam@list:first(erlang:element(3, Query_result)) of
                                            {ok, Row} ->
                                                _pipe@15 = wisp:ok(),
                                                _pipe@16 = fun gleam@http@response:set_header/3(_pipe@15, ~"content-type", ~"application/json; charset=utf-8"),
                                                wisp:string_body(_pipe@16, Row);

                                            {error, _} ->
                                                _pipe@17 = wisp:ok(),
                                                wisp:json_body(_pipe@17, ~"[]")
                                        end;

                                    {error, _} ->
                                        _pipe@18 = wisp:response(500),
                                        wisp:json_body(_pipe@18, ~"{\"error\":\"AI anahtar havuzu okunamadı\"}")
                                end
                            end(_pipe@14)
                        end(_pipe@9)
                    end);

                {post, [~"admin", ~"ai"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.ai_providers(tenant_id,provider,model,token_encrypted,active) VALUES($1::uuid,$2,$3,$4,$5::text::boolean) ON CONFLICT(tenant_id,provider,model) DO UPDATE SET token_encrypted=case when excluded.token_encrypted='' then agency.ai_providers.token_encrypted else excluded.token_encrypted end,active=excluded.active",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"provider"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"model"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"api_key"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@13 = pog:execute(_pipe@12, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/ai")
                            end(_pipe@13)
                        end)
                    end);

                {post, [~"admin", ~"ai", ~"supervisor"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.task_runs(tenant_id,task_name,status,payload) VALUES($1::uuid,'ai.supervisor','queued',jsonb_build_object('enabled',$2::text='true','interval',$3::text))",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"enabled"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"interval"))),
                            _pipe@11 = pog:execute(_pipe@10, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/ai#ai-workspace")
                            end(_pipe@11)
                        end)
                    end);

                {get, [~"admin", ~"ai", ~"supervisor", ~"status"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select coalesce((select status from agency.health_checks where tenant_id=$1::uuid and component='ai.supervisor' order by checked_at desc limit 1),'unknown'),(select count(*)::text from agency.task_runs where tenant_id=$1::uuid and task_name='ai.supervisor' and status='queued'),(select count(*)::text from agency.task_runs where tenant_id=$1::uuid and status='failed'),coalesce((select to_char(checked_at,'YYYY-MM-DD HH24:MI:SS') from agency.health_checks where tenant_id=$1::uuid and component='ai.supervisor' order by checked_at desc limit 1),'')",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, supervisor_status_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Query_result} ->
                                case gleam@list:first(erlang:element(3, Query_result)) of
                                    {ok, Row} ->
                                        _pipe@10 = gleam@json:object([{~"status", gleam@json:string(erlang:element(1, Row))}, {~"queued", gleam@json:string(erlang:element(2, Row))}, {~"failed", gleam@json:string(erlang:element(3, Row))}, {~"checkedAt", gleam@json:string(erlang:element(4, Row))}]),
                                        _pipe@11 = gleam@json:to_string(_pipe@10),
                                        fun(Body) ->
                                            _pipe@12 = wisp:ok(),
                                            _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                            wisp:string_body(_pipe@13, Body)
                                        end(_pipe@11);

                                    {error, _} ->
                                        _pipe@12 = wisp:ok(),
                                        wisp:json_body(_pipe@12, ~"{\"status\":\"unknown\",\"queued\":0,\"failed\":0,\"checkedAt\":\"\"}")
                                end;

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"AI Müdür durumu okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"ai", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select provider,model,case when active then 'Aktif' else 'Pasif' end,case when token_encrypted='' then 'Hayır' else 'Evet' end from agency.ai_providers where tenant_id=$1::uuid order by active desc,provider,model",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, ai_provider_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"provider", gleam@json:string(erlang:element(1, Row))}, {~"model", gleam@json:string(erlang:element(2, Row))}, {~"status", gleam@json:string(erlang:element(3, Row))}, {~"configured", gleam@json:string(erlang:element(4, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"AI sağlayıcıları okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"campaigns"]} ->
                    require_campaign_access(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Audience = case {erlang:element(5, Session), form_value(erlang:element(2, Form), ~"campaign_audience")} of
                                {~"supplier", _} ->
                                    ~"supplier";

                                {_, Value@1} ->
                                    Value@1
                            end,
                            _pipe@6 = ~"INSERT INTO agency.campaigns(tenant_id,name,kind,starts_at,ends_at,discount_percent,active,rules) VALUES($1::uuid,$2,$3,NULLIF($4,'')::timestamp,NULLIF($5,'')::timestamp,NULLIF($6,'')::numeric,$7::text::boolean,jsonb_build_object('note',$8::text,'audience',case when $9 in ('agency','supplier') then $9 else 'all' end))",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"name"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"kind"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"starts_at"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ends_at"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"discount_percent"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"note"))),
                            _pipe@16 = pog:parameter(_pipe@15, pog_ffi:coerce(Audience)),
                            _pipe@17 = pog:execute(_pipe@16, Db),
                            fun(_) ->
                                Target = case Audience of
                                    ~"supplier" ->
                                        ~"/admin/supplier-campaigns?audience=supplier#campaigns-workspace";

                                    ~"agency" ->
                                        ~"/admin/campaigns?audience=agency#campaigns-workspace";

                                    _ ->
                                        ~"/admin/campaigns#campaigns-workspace"
                                end,
                                wisp:redirect(Target)
                            end(_pipe@17)
                        end)
                    end);

                {post, [~"admin", ~"campaigns", ~"coupons"]} ->
                    require_campaign_access(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Audience = case {erlang:element(5, Session), form_value(erlang:element(2, Form), ~"coupon_audience")} of
                                {~"supplier", _} ->
                                    ~"supplier";

                                {_, Value@1} ->
                                    Value@1
                            end,
                            _pipe@6 = ~"INSERT INTO agency.coupons(tenant_id,code,discount_percent,usage_limit,starts_at,ends_at,active,audience) VALUES($1::uuid,upper($2),NULLIF($3,'')::numeric,NULLIF($4,'')::int,NULLIF($5,'')::timestamp,NULLIF($6,'')::timestamp,$7::text::boolean,case when $8 in ('agency','supplier') then $8 else 'all' end) ON CONFLICT(tenant_id,code) DO UPDATE SET discount_percent=excluded.discount_percent,usage_limit=excluded.usage_limit,starts_at=excluded.starts_at,ends_at=excluded.ends_at,active=excluded.active,audience=excluded.audience",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"code"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"discount_percent"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"usage_limit"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"starts_at"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"ends_at"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"active"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(Audience)),
                            _pipe@16 = pog:execute(_pipe@15, Db),
                            fun(_) ->
                                Target = case Audience of
                                    ~"supplier" ->
                                        ~"/admin/supplier-campaigns?audience=supplier#coupons";

                                    ~"agency" ->
                                        ~"/admin/campaigns?audience=agency#coupons";

                                    _ ->
                                        ~"/admin/campaigns#coupons"
                                end,
                                wisp:redirect(Target)
                            end(_pipe@16)
                        end)
                    end);

                {get, [~"admin", ~"campaigns", ~"data"]} ->
                    require_campaign_access(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select coalesce((select json_agg(json_build_object('name',name,'kind',kind,'audience',coalesce(rules->>'audience','all'),'startsAt',coalesce(to_char(starts_at,'YYYY-MM-DD HH24:MI'),''),'endsAt',coalesce(to_char(ends_at,'YYYY-MM-DD HH24:MI'),''),'discount',coalesce(discount_percent::text,''),'status',case when active then 'Aktif' else 'Pasif' end) order by starts_at desc nulls last) from agency.campaigns where tenant_id=$1::uuid and ($2 <> 'supplier' or coalesce(rules->>'audience','all')='supplier')),'[]'::json)::text,coalesce((select json_agg(json_build_object('code',code,'audience',coalesce(audience,'all'),'discount',coalesce(discount_percent::text,''),'usageLimit',coalesce(usage_limit::text,'Sınırsız'),'usedCount',used_count::text,'endsAt',coalesce(to_char(ends_at,'YYYY-MM-DD HH24:MI'),''),'status',case when active then 'Aktif' else 'Pasif' end) order by code) from agency.coupons where tenant_id=$1::uuid and ($2 <> 'supplier' or audience='supplier')),'[]'::json)::text",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(5, Session))),
                            _pipe@10 = pog:returning(_pipe@9, campaign_data_decoder()),
                            pog:execute(_pipe@10, Db)
                        end of
                            {ok, Result} ->
                                case gleam@list:first(erlang:element(3, Result)) of
                                    {ok, Row} ->
                                        _pipe@11 = wisp:ok(),
                                        _pipe@12 = fun gleam@http@response:set_header/3(_pipe@11, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@12, <<<<<<<<"{\"campaigns\":"/utf8, (erlang:element(1, Row))/binary>>/binary, ",\"coupons\":"/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, "}"/utf8>>);

                                    {error, _} ->
                                        _pipe@13 = wisp:ok(),
                                        wisp:json_body(_pipe@13, ~"{\"campaigns\":[],\"coupons\":[]}")
                                end;

                            {error, _} ->
                                _pipe@14 = wisp:response(500),
                                wisp:json_body(_pipe@14, ~"{\"error\":\"Kampanyalar okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"team"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Email = string:lowercase(gleam@string:trim(form_value(erlang:element(2, Form), ~"email"))),
                            Display_name = gleam@string:trim(form_value(erlang:element(2, Form), ~"display_name")),
                            Membership = form_value(erlang:element(2, Form), ~"membership_type"),
                            Active = form_value(erlang:element(2, Form), ~"active"),
                            Password = form_value(erlang:element(2, Form), ~"password"),
                            Valid_membership = ((((Membership =:= ~"admin") orelse (Membership =:= ~"staff")) orelse (Membership =:= ~"supplier")) orelse (Membership =:= ~"sub_agency")) orelse (Membership =:= ~"customer"),
                            Valid_active = (Active =:= ~"true") orelse (Active =:= ~"false"),
                            case ((((Email =:= ~"") orelse (Display_name =:= ~"")) orelse not Valid_membership) orelse not Valid_active) orelse ((Password /= ~"") andalso (string:length(Password) < 8)) of
                                true ->
                                    _pipe@6 = wisp:response(400),
                                    wisp:string_body(_pipe@6, ~"Ad, e-posta, üyelik tipi ve durum geçerli olmalı; parola en az 8 karakter olmalı.");

                                false ->
                                    _pipe@7 = ~"with u as (insert into agency.users(tenant_id,email,display_name,membership_type,active,password_hash) values($1::uuid,$2,$3,$4,$5,case when $6='' then null else crypt($6,gen_salt('bf')) end) on conflict(tenant_id,email) do update set display_name=excluded.display_name,membership_type=excluded.membership_type,active=excluded.active,password_hash=case when $6='' then agency.users.password_hash else crypt($6,gen_salt('bf')) end returning id,tenant_id,membership_type), r as (insert into agency.roles(tenant_id,code,name,permissions) select u.tenant_id,u.membership_type,case u.membership_type when 'admin' then 'Yönetici' when 'staff' then 'Personel' when 'supplier' then 'Tedarikçi' when 'sub_agency' then 'Alt acente' else 'Müşteri' end,case u.membership_type when 'admin' then '[\"*\"]'::jsonb when 'staff' then '[\"dashboard.read\",\"catalog.read\",\"catalog.write\",\"reservations.read\",\"reservations.write\",\"customers.read\",\"customers.write\",\"inquiries.read\",\"inquiries.write\",\"reports.read\"]'::jsonb when 'supplier' then '[\"dashboard.read\",\"catalog.read\",\"catalog.write\",\"campaigns.supplier\"]'::jsonb when 'sub_agency' then '[\"dashboard.read\",\"catalog.read\",\"reservations.read\",\"reservations.write\",\"customers.read\",\"customers.write\",\"inquiries.read\"]'::jsonb else '[\"storefront.read\",\"booking.create\",\"inquiries.create\"]'::jsonb end from u on conflict(tenant_id,code) do update set name=excluded.name,permissions=excluded.permissions returning id), link as (insert into agency.user_roles(user_id,role_id) select u.id,r.id from u cross join r on conflict(user_id,role_id) do nothing) select 1",
                                    _pipe@8 = pog:'query'(_pipe@7),
                                    _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                                    _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(Email)),
                                    _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(Display_name)),
                                    _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(Membership)),
                                    _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(Active =:= ~"true")),
                                    _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(Password)),
                                    _pipe@15 = pog:execute(_pipe@14, Db),
                                    fun(Result) ->
                                        case Result of
                                            {ok, _} ->
                                                wisp:redirect(~"/admin/team");

                                            {error, Error} ->
                                                gleam_stdlib:println(<<"Team member save failed: "/utf8, (query_error_message(Error))/binary>>),
                                                _pipe@16 = wisp:response(409),
                                                wisp:string_body(_pipe@16, ~"Üye kaydedilemedi.")
                                        end
                                    end(_pipe@15)
                            end
                        end)
                    end);

                {get, [~"admin", ~"team", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select u.id::text,u.display_name,u.email,u.membership_type,case when u.active then 'Aktif' else 'Pasif' end,case when u.password_hash is null then 'Parola bekliyor' else 'Giriş hazır' end,to_char(u.created_at,'YYYY-MM-DD HH24:MI'),coalesce(r.permissions,'[]'::jsonb)::text from agency.users u left join agency.roles r on r.tenant_id=u.tenant_id and r.code=u.membership_type where u.tenant_id=$1::uuid order by u.active desc,u.display_name",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, team_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"name", gleam@json:string(erlang:element(2, Row))}, {~"email", gleam@json:string(erlang:element(3, Row))}, {~"membership", gleam@json:string(erlang:element(4, Row))}, {~"status", gleam@json:string(erlang:element(5, Row))}, {~"login", gleam@json:string(erlang:element(6, Row))}, {~"createdAt", gleam@json:string(erlang:element(7, Row))}, {~"permissions", gleam@json:string(erlang:element(8, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Ekip okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"reports", ~"data"]} ->
                    require_panel_session(Db, Token, ~"reports", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select (select count(*)::text from agency.listings where tenant_id=$1::uuid and status='published'),(select count(*)::text from agency.reservations where tenant_id=$1::uuid),(select count(*)::text from agency.customers where tenant_id=$1::uuid),(select count(*)::text from agency.contact_requests where tenant_id=$1::uuid and status='new'),coalesce((select json_agg(json_build_object('task',task_name,'status',status,'attempt',attempt,'finishedAt',coalesce(to_char(finished_at,'YYYY-MM-DD HH24:MI'),''),'error',error) order by coalesce(started_at,now()) desc) from (select * from agency.task_runs where tenant_id=$1::uuid order by coalesce(started_at,now()) desc limit 20) t),'[]'::json)::text,coalesce((select json_agg(json_build_object('action',action,'entity',entity_type,'createdAt',to_char(created_at,'YYYY-MM-DD HH24:MI')) order by created_at desc) from (select * from agency.audit_logs where tenant_id=$1::uuid order by created_at desc limit 20) a),'[]'::json)::text",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, report_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                case gleam@list:first(erlang:element(3, Result)) of
                                    {ok, Row} ->
                                        _pipe@10 = wisp:ok(),
                                        _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@11, <<<<<<<<<<<<<<<<<<<<<<<<"{\"publishedListings\":"/utf8, (erlang:element(1, Row))/binary>>/binary, ",\"reservations\":"/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, ",\"customers\":"/utf8>>/binary, (erlang:element(3, Row))/binary>>/binary, ",\"newContacts\":"/utf8>>/binary, (erlang:element(4, Row))/binary>>/binary, ",\"tasks\":"/utf8>>/binary, (erlang:element(5, Row))/binary>>/binary, ",\"audits\":"/utf8>>/binary, (erlang:element(6, Row))/binary>>/binary, "}"/utf8>>);

                                    {error, _} ->
                                        _pipe@12 = wisp:ok(),
                                        wisp:json_body(_pipe@12, ~"{\"publishedListings\":0,\"reservations\":0,\"customers\":0,\"newContacts\":0,\"tasks\":[],\"audits\":[]}")
                                end;

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Raporlar okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"dashboard", ~"data"]} ->
                    require_session(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select published_listings::text,pending_reservations::text,upcoming_reservations::text,new_contact_requests::text,case when t.nexus_connected then 'Bağlı' else 'Bağlantı bekliyor' end from agency.dashboard_metrics d join agency.tenants t on t.id=d.tenant_id where d.tenant_id=$1::uuid",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, dashboard_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                case gleam@list:first(erlang:element(3, Result)) of
                                    {ok, Row} ->
                                        _pipe@10 = wisp:ok(),
                                        _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"application/json; charset=utf-8"),
                                        wisp:string_body(_pipe@11, <<<<<<<<<<<<<<<<<<<<"{\"published\":"/utf8, (erlang:element(1, Row))/binary>>/binary, ",\"pending\":"/utf8>>/binary, (erlang:element(2, Row))/binary>>/binary, ",\"upcoming\":"/utf8>>/binary, (erlang:element(3, Row))/binary>>/binary, ",\"contacts\":"/utf8>>/binary, (erlang:element(4, Row))/binary>>/binary, ",\"nexus\":\""/utf8>>/binary, (erlang:element(5, Row))/binary>>/binary, "\"}"/utf8>>);

                                    {error, _} ->
                                        _pipe@12 = wisp:ok(),
                                        wisp:json_body(_pipe@12, ~"{\"published\":0,\"pending\":0,\"upcoming\":0,\"contacts\":0,\"nexus\":\"Bağlantı bekliyor\"}")
                                end;

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Genel bakış okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"dashboard", ~"series"]} ->
                    require_session(Db, Token, fun(Session) ->
                        Days = case begin
                            _pipe@6 = wisp:get_query(Req),
                            gleam@list:key_find(_pipe@6, ~"days")
                        end of
                            {ok, Raw} ->
                                case gleam_stdlib:parse_int(Raw) of
                                    {ok, N} ->
                                        case N of
                                            7 ->
                                                7;

                                            30 ->
                                                30;

                                            _ ->
                                                14
                                        end;

                                    {error, _} ->
                                        14
                                end;

                            {error, _} ->
                                14
                        end,
                        Start_offset = erlang:integer_to_binary(Days - 1),
                        Series_sql = <<<<<<<<<<<<<<<<<<"with days as (select generate_series(current_date - "/utf8, Start_offset/binary>>/binary, ", current_date, interval '1 day')::date as d) "/utf8>>/binary, "select to_char(d,'MM-DD') as label, "/utf8>>/binary, "(select count(*) from agency.listings l where l.tenant_id=$1::uuid and l.status='published' and l.created_at::date <= d)::text, "/utf8>>/binary, "(select count(*) from agency.reservations r where r.tenant_id=$1::uuid and r.status in ('inquiry','option') and r.created_at::date = d)::text, "/utf8>>/binary, "(select count(*) from agency.reservations r where r.tenant_id=$1::uuid and r.check_in = d + 7)::text, "/utf8>>/binary, "(select count(*) from agency.contact_requests c where c.tenant_id=$1::uuid and c.created_at::date = d)::text, "/utf8>>/binary, "(select coalesce(round(100.0*count(*) filter (where r2.status in ('confirmed','completed'))/nullif(count(*),0)),0) from agency.reservations r2 where r2.tenant_id=$1::uuid and r2.created_at::date = d)::text "/utf8>>/binary, "from days order by d"/utf8>>,
                        case begin
                            _pipe@7 = Series_sql,
                            _pipe@8 = pog:'query'(_pipe@7),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@10 = pog:returning(_pipe@9, series_decoder()),
                            pog:execute(_pipe@10, Db)
                        end of
                            {ok, Result} ->
                                _pipe@11 = wisp:ok(),
                                _pipe@12 = fun gleam@http@response:set_header/3(_pipe@11, ~"content-type", ~"application/json; charset=utf-8"),
                                wisp:string_body(_pipe@12, begin
                                    _pipe@13 = gleam@json:object([{~"labels", gleam@json:array(erlang:element(3, Result), fun(Row) ->
                                        gleam@json:string(erlang:element(1, Row))
                                    end)}, {~"published", series_array(erlang:element(3, Result), fun(Row) ->
                                        erlang:element(2, Row)
                                    end)}, {~"pending", series_array(erlang:element(3, Result), fun(Row) ->
                                        erlang:element(3, Row)
                                    end)}, {~"upcoming", series_array(erlang:element(3, Result), fun(Row) ->
                                        erlang:element(4, Row)
                                    end)}, {~"contacts", series_array(erlang:element(3, Result), fun(Row) ->
                                        erlang:element(5, Row)
                                    end)}, {~"conversion", series_array(erlang:element(3, Result), fun(Row) ->
                                        erlang:element(6, Row)
                                    end)}]),
                                    gleam@json:to_string(_pipe@13)
                                end);

                            {error, E} ->
                                gleam_stdlib:println(<<"SERIES ERROR: "/utf8, (gleam@string:inspect(E))/binary>>),
                                _pipe@14 = wisp:response(500),
                                wisp:json_body(_pipe@14, ~"{\"error\":\"Seriler okunamadı\"}")
                        end
                    end);

                {get, [~"admin", ~"reports", ~"weekly-digest"]} ->
                    require_session(Db, Token, fun(Session) ->
                        _pipe@6 = fetch_series(Db, erlang:element(2, Session)),
                        fun(Picked) ->
                            case Picked of
                                {ok, Digest_data} ->
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@8, begin
                                        _pipe@9 = nexus_agency@weekly_digest:build_json(Digest_data),
                                        gleam@json:to_string(_pipe@9)
                                    end);

                                {error, _} ->
                                    _pipe@10 = wisp:response(500),
                                    wisp:json_body(_pipe@10, ~"{\"error\":\"Özet derlenemedi\"}")
                            end
                        end(_pipe@6)
                    end);

                {get, [~"admin", ~"reports", ~"weekly-digest", ~"pdf"]} ->
                    require_session(Db, Token, fun(Session) ->
                        Agency_name = agency_display_name(Db, erlang:element(2, Session)),
                        _pipe@6 = fetch_series(Db, erlang:element(2, Session)),
                        fun(Picked) ->
                            case Picked of
                                {ok, Digest_data} ->
                                    _pipe@7 = wisp:ok(),
                                    _pipe@8 = fun gleam@http@response:set_header/3(_pipe@7, ~"content-type", ~"text/html; charset=utf-8"),
                                    wisp:string_body(_pipe@8, nexus_agency@weekly_digest:print_html(Digest_data, Agency_name));

                                {error, _} ->
                                    _pipe@9 = wisp:response(500),
                                    wisp:string_body(_pipe@9, ~"Özet derlenemedi")
                            end
                        end(_pipe@6)
                    end);

                {post, [~"admin", ~"reports", ~"weekly-digest", ~"email"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            To_addr = begin
                                _pipe@6 = form_value(erlang:element(2, Form), ~"to"),
                                gleam@string:trim(_pipe@6)
                            end,
                            Subject = form_value(erlang:element(2, Form), ~"subject"),
                            case (To_addr /= ~"") andalso gleam_stdlib:contains_string(To_addr, ~"@") of
                                false ->
                                    _pipe@7 = wisp:response(400),
                                    wisp:string_body(_pipe@7, ~"Geçerli bir alıcı e-postası gerekli");

                                true ->
                                    _pipe@8 = fetch_series(Db, erlang:element(2, Session)),
                                    fun(Picked) ->
                                        case Picked of
                                            {error, _} ->
                                                _pipe@9 = wisp:response(500),
                                                wisp:json_body(_pipe@9, ~"{\"error\":\"Özet derlenemedi\"}");

                                            {ok, Digest_data} ->
                                                Agency_name = agency_display_name(Db, erlang:element(2, Session)),
                                                Payload = gleam@json:object([{~"to", gleam@json:string(To_addr)}, {~"subject", gleam@json:string(Subject)}, {~"html", gleam@json:string(nexus_agency@weekly_digest:email_html(Digest_data, Agency_name))}]),
                                                Insert = begin
                                                    _pipe@10 = ~"insert into agency.notifications(tenant_id,user_id,channel,template,payload,status) values ($1::uuid,$2::uuid,'email','weekly_digest',$3::jsonb,'queued')",
                                                    _pipe@11 = pog:'query'(_pipe@10),
                                                    _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(erlang:element(2, Session))),
                                                    _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(erlang:element(3, Session))),
                                                    _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(gleam@json:to_string(Payload))),
                                                    _pipe@15 = pog:returning(_pipe@14, gleam@dynamic@decode:at([0], {decoder, fun gleam@dynamic@decode:decode_string/1})),
                                                    pog:execute(_pipe@15, Db)
                                                end,
                                                case Insert of
                                                    {ok, _} ->
                                                        _pipe@16 = wisp:response(201),
                                                        wisp:json_body(_pipe@16, <<<<"{\"ok\":true,\"queued\":true,\"to\":\""/utf8, To_addr/binary>>/binary, "\"}"/utf8>>);

                                                    {error, _} ->
                                                        _pipe@17 = wisp:response(500),
                                                        wisp:json_body(_pipe@17, ~"{\"error\":\"Kuyruğa alınamadı\"}")
                                                end
                                        end
                                    end(_pipe@8)
                            end
                        end)
                    end);

                {get, [~"admin", ~"abandoned-carts", ~"data"]} ->
                    require_panel_session(Db, Token, ~"abandoned-carts", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select c.id::text,coalesce(u.full_name,'Misafir'),coalesce(u.phone,coalesce(u.email,'-')),count(ci.id)::text,coalesce((sum(ci.total_minor)/100)::text,'0'),coalesce(c.currency,'TRY'),to_char(c.created_at,'YYYY-MM-DD HH24:MI') from agency.carts c left join agency.customers u on u.id=c.customer_id left join agency.cart_items ci on ci.cart_id=c.id where c.tenant_id=$1::uuid and c.status in ('active','abandoned') group by c.id,u.full_name,u.phone,u.email,c.currency,c.created_at order by c.created_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, abandoned_cart_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"customerName", gleam@json:string(erlang:element(2, Row))}, {~"customerContact", gleam@json:string(erlang:element(3, Row))}, {~"itemCount", gleam@json:string(erlang:element(4, Row))}, {~"totalMinor", gleam@json:string(erlang:element(5, Row))}, {~"currency", gleam@json:string(erlang:element(6, Row))}, {~"lastActivity", gleam@json:string(erlang:element(7, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Sepetler okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"abandoned-carts", ~"notify"]} ->
                    require_panel_session(Db, Token, ~"abandoned-carts", fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            Cart_id = form_value(erlang:element(2, Form), ~"cart_id"),
                            _pipe@6 = ~"WITH cart AS (SELECT c.id,c.tenant_id,coalesce(u.full_name,'Misafir') AS name,coalesce(u.email,'') AS email,coalesce(u.phone,'') AS phone FROM agency.carts c LEFT JOIN agency.customers u ON u.id=c.customer_id WHERE c.id=$1::uuid AND c.tenant_id=$2::uuid AND c.status IN ('active','abandoned')), eligible AS (SELECT cart.* FROM cart WHERE pg_try_advisory_xact_lock(hashtext(cart.id::text)) AND (phone<>'' OR email<>'') AND NOT EXISTS (SELECT 1 FROM agency.abandoned_cart_notifications n WHERE n.cart_id=cart.id AND n.sent_at>now()-interval '24 hours')), audit AS (INSERT INTO agency.abandoned_cart_notifications(cart_id,channel,status) SELECT id,case when phone<>'' then 'sms' else 'email' end,'queued' FROM eligible), queued AS (INSERT INTO agency.notifications(tenant_id,channel,template,payload) SELECT tenant_id,case when phone<>'' then 'sms' else 'email' end,'abandoned_cart',jsonb_build_object('cart_id',id::text,'name',name,'email',email,'phone',phone) FROM eligible RETURNING id) SELECT count(*)::text FROM queued",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(Cart_id)),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@10 = pog:returning(_pipe@9, single_string_decoder()),
                            _pipe@11 = pog:execute(_pipe@10, Db),
                            fun(Result) ->
                                case Result of
                                    {ok, Rows} ->
                                        case gleam@list:first(erlang:element(3, Rows)) of
                                            {ok, ~"1"} ->
                                                _pipe@12 = wisp:response(202),
                                                _pipe@13 = fun gleam@http@response:set_header/3(_pipe@12, ~"content-type", ~"application/json; charset=utf-8"),
                                                wisp:string_body(_pipe@13, ~"{\"status\":\"queued\"}");

                                            _ ->
                                                _pipe@14 = wisp:response(404),
                                                wisp:json_body(_pipe@14, ~"{\"error\":\"Sepet bulunamadı veya iletişim bilgisi eksik.\"}")
                                        end;

                                    {error, _} ->
                                        _pipe@15 = wisp:response(500),
                                        wisp:json_body(_pipe@15, ~"{\"error\":\"Hatırlatma kuyruğa alınamadı.\"}")
                                end
                            end(_pipe@11)
                        end)
                    end);

                {get, [~"admin", ~"popups", ~"data"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        case begin
                            _pipe@6 = ~"select id::text,title,kind,content,button_text,delay_seconds::text,case when active then 'Aktif' else 'Pasif' end from agency.popups where tenant_id=$1::uuid order by created_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, popup_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"title", gleam@json:string(erlang:element(2, Row))}, {~"kind", gleam@json:string(erlang:element(3, Row))}, {~"content", gleam@json:string(erlang:element(4, Row))}, {~"buttonText", gleam@json:string(erlang:element(5, Row))}, {~"delaySeconds", gleam@json:string(erlang:element(6, Row))}, {~"status", gleam@json:string(erlang:element(7, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Popuplar okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"popups"]} ->
                    require_admin(Db, Token, fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.popups(tenant_id, title, kind, content, image_url, button_text, button_link, delay_seconds, active) VALUES($1::uuid, $2, $3, $4, $5, $6, $7, $8, true)",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"title"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"kind"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"content"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"image_url"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"button_text"))),
                            _pipe@14 = pog:parameter(_pipe@13, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"button_link"))),
                            _pipe@15 = pog:parameter(_pipe@14, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"delay_seconds"))),
                            _pipe@16 = pog:execute(_pipe@15, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/popups")
                            end(_pipe@16)
                        end)
                    end);

                {get, [~"admin", ~"offers", ~"data"]} ->
                    require_panel_session(Db, Token, ~"offers", fun(Session) ->
                        case begin
                            _pipe@6 = ~"select o.id::text,o.reference_code,coalesce(c.full_name,'Misafir'),coalesce(l.title,'Özel İlan'),o.total_minor::text,o.currency,o.dates_text,o.status from agency.offers o left join agency.customers c on c.id=o.customer_id left join agency.listings l on l.id=o.listing_id where o.tenant_id=$1::uuid order by o.created_at desc",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:returning(_pipe@8, offer_decoder()),
                            pog:execute(_pipe@9, Db)
                        end of
                            {ok, Result} ->
                                _pipe@10 = erlang:element(3, Result),
                                _pipe@11 = gleam@json:array(_pipe@10, fun(Row) ->
                                    gleam@json:object([{~"id", gleam@json:string(erlang:element(1, Row))}, {~"referenceCode", gleam@json:string(erlang:element(2, Row))}, {~"customer", gleam@json:string(erlang:element(3, Row))}, {~"listing", gleam@json:string(erlang:element(4, Row))}, {~"totalMinor", gleam@json:string(erlang:element(5, Row))}, {~"currency", gleam@json:string(erlang:element(6, Row))}, {~"datesText", gleam@json:string(erlang:element(7, Row))}, {~"status", gleam@json:string(erlang:element(8, Row))}])
                                end),
                                _pipe@12 = gleam@json:to_string(_pipe@11),
                                fun(Body) ->
                                    _pipe@13 = wisp:ok(),
                                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/json; charset=utf-8"),
                                    wisp:string_body(_pipe@14, Body)
                                end(_pipe@12);

                            {error, _} ->
                                _pipe@13 = wisp:response(500),
                                wisp:json_body(_pipe@13, ~"{\"error\":\"Teklifler okunamadı\"}")
                        end
                    end);

                {post, [~"admin", ~"offers"]} ->
                    require_panel_session(Db, Token, ~"offers", fun(Session) ->
                        wisp:require_form(Req, fun(Form) ->
                            _pipe@6 = ~"INSERT INTO agency.offers(tenant_id, reference_code, dates_text, total_minor, currency, notes, status) VALUES($1::uuid, $2, $3, greatest($4,0), coalesce((select cur.code from agency.currencies cur where cur.code=upper($5) limit 1),'TRY'), $6, 'sent') ON CONFLICT(reference_code) DO UPDATE SET dates_text=excluded.dates_text, total_minor=excluded.total_minor, currency=excluded.currency, notes=excluded.notes WHERE agency.offers.tenant_id=$1::uuid",
                            _pipe@7 = pog:'query'(_pipe@6),
                            _pipe@8 = pog:parameter(_pipe@7, pog_ffi:coerce(erlang:element(2, Session))),
                            _pipe@9 = pog:parameter(_pipe@8, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"reference_code"))),
                            _pipe@10 = pog:parameter(_pipe@9, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"dates_text"))),
                            _pipe@11 = pog:parameter(_pipe@10, pog_ffi:coerce(form_int(erlang:element(2, Form), ~"total_minor"))),
                            _pipe@12 = pog:parameter(_pipe@11, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"currency"))),
                            _pipe@13 = pog:parameter(_pipe@12, pog_ffi:coerce(form_value(erlang:element(2, Form), ~"notes"))),
                            _pipe@14 = pog:execute(_pipe@13, Db),
                            fun(_) ->
                                wisp:redirect(~"/admin/offers")
                            end(_pipe@14)
                        end)
                    end);

                {post, [~"admin", Section@1]} ->
                    require_session(Db, Token, fun(_) ->
                        wisp:redirect(<<"/admin/"/utf8, Section@1/binary>>)
                    end);

                {get, [~"admin", Section@2, _]} ->
                    require_panel_session(Db, Token, Section@2, fun(Session) ->
                        _pipe@6 = wisp:ok(),
                        wisp:html_body(_pipe@6, nexus_agency@panel:section(Session, Section@2, section_intro(Section@2), section_links(Section@2), Lang, Active_cat))
                    end);

                {get, [~"admin", Section@3, _, _]} ->
                    require_panel_session(Db, Token, Section@3, fun(Session) ->
                        _pipe@6 = wisp:ok(),
                        wisp:html_body(_pipe@6, nexus_agency@panel:section(Session, Section@3, section_intro(Section@3), section_links(Section@3), Lang, Active_cat))
                    end);

                {get, [~"health"]} ->
                    _pipe@6 = wisp:ok(),
                    _pipe@7 = fun gleam@http@response:set_header/3(_pipe@6, ~"cache-control", ~"no-store"),
                    wisp:json_body(_pipe@7, ~"{\"service\":\"nexus-agency\",\"database\":\"ready\",\"environment\":\"development\"}");

                {get, [~"v1", ~"health"]} ->
                    _pipe@8 = wisp:ok(),
                    _pipe@9 = fun gleam@http@response:set_header/3(_pipe@8, ~"cache-control", ~"no-store"),
                    wisp:json_body(_pipe@9, ~"{\"service\":\"nexus-agency\",\"database\":\"ready\",\"environment\":\"development\"}");

                {get, [~"v1", ~"listings", Listing_id, ~"availability"]} ->
                    public_availability(Req, Db, Listing_id);

                {get, [~"v1", ~"search", ~"intent"]} ->
                    search_intent(Req, Db);

                {get, [~"robots.txt"]} ->
                    _pipe@10 = wisp:ok(),
                    _pipe@11 = fun gleam@http@response:set_header/3(_pipe@10, ~"content-type", ~"text/plain; charset=utf-8"),
                    wisp:string_body(_pipe@11, <<<<"User-agent: *\nAllow: /\nDisallow: /admin\nSitemap: "/utf8, Origin/binary>>/binary, "/sitemap.xml\n"/utf8>>);

                {get, [~"sitemap.xml"]} ->
                    Tenant_id = begin
                        _pipe@12 = public_tenant_id(Db, Req),
                        gleam@result:unwrap(_pipe@12, ~"")
                    end,
                    _pipe@13 = wisp:ok(),
                    _pipe@14 = fun gleam@http@response:set_header/3(_pipe@13, ~"content-type", ~"application/xml; charset=utf-8"),
                    wisp:string_body(_pipe@14, <<<<<<<<<<<<<<<<<<<<"<?xml version=\"1.0\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"><url><loc>"/utf8, Origin/binary>>/binary, "/</loc></url><url><loc>"/utf8>>/binary, Origin/binary>>/binary, "/urunler</loc></url><url><loc>"/utf8>>/binary, Origin/binary>>/binary, "/iletisim</loc></url>"/utf8>>/binary, (category_sitemap_urls(Origin))/binary>>/binary, (cms_sitemap_urls(Db, Origin, Tenant_id))/binary>>/binary, (listing_sitemap_urls(Db, Origin, Tenant_id))/binary>>/binary, "</urlset>"/utf8>>);

                {get, []} ->
                    demo_home_page(Req, Db, Origin);

                {get, [~"urunler"]} ->
                    public_products_page(Req, Db, Origin);

                {get, [~"urunler", Listing_id@1]} ->
                    public_product_detail_page(Req, Db, Origin, Listing_id@1);

                {get, [~"kategori", Category_slug]} ->
                    public_category_page(Req, Db, Origin, Category_slug);

                {post, [~"api", ~"public", ~"checkout", ~"start"]} ->
                    public_checkout_start(Req, Db);

                {get, [~"rezervasyon"]} ->
                    public_checkout_page(Req, Db, Origin);

                {get, [~"odeme", ~"parampos"]} ->
                    _pipe@15 = public_parampos_page(Req, Db, Origin),
                    fun gleam@http@response:set_header/3(_pipe@15, ~"cache-control", ~"no-store");

                {post, [~"api", ~"public", ~"checkout", ~"parampos", ~"start"]} ->
                    public_parampos_start(Req, Db, Origin);

                {post, [~"api", ~"public", ~"checkout", ~"parampos", ~"return"]} ->
                    public_parampos_return(Req, Db, Origin);

                {post, [~"api", ~"public", ~"chat"]} ->
                    public_chat(Req, Db);

                {get, [~"iletisim"]} ->
                    public_contact_page(Req, Origin);

                {post, [~"iletisim"]} ->
                    public_inquiry(Req, Db);

                {get, [~"hesap"]} ->
                    public_account_page(Req, Db, Origin);

                {get, [~"konaklama-kategoriler"]} ->
                    public_category_page(Req, Db, Origin, ~"hotel");

                {get, [~"deneyimler"]} ->
                    public_category_page(Req, Db, Origin, ~"tour");

                {get, [~"emlak"]} ->
                    public_category_page(Req, Db, Origin, ~"holiday_home");

                {get, [~"yazarlar"]} ->
                    public_authors_page(Req, Db, Origin);

                {get, [~"arac"]} ->
                    public_category_page(Req, Db, Origin, ~"car");

                {get, [~"ucus"]} ->
                    public_category_page(Req, Db, Origin, ~"flight");

                {get, [~"otobus"]} ->
                    public_category_page(Req, Db, Origin, ~"bus");

                {get, [Parent, Child]} ->
                    public_cms_page(Req, Db, Origin, <<<<Parent/binary, "/"/utf8>>/binary, Child/binary>>);

                {get, [Slug]} ->
                    public_cms_page(Req, Db, Origin, Slug);

                {_, _} ->
                    _pipe@16 = wisp:response(404),
                    wisp:string_body(_pipe@16, ~"Sayfa bulunamadı")
            end
        end)
    end).

-file("src\\nexus_agency\\router.gleam", 220).
-spec exempt_from_csrf(gleam@http@request:request(wisp@internal:connection())) -> boolean().
-doc(~" CSRF muafiyetleri: oturum öncesi akışlar (giriş) ve robots.txt'in
 POST'ta beklenmedik istekleri. Diğer tüm admin POST'lar token ister.").
exempt_from_csrf(Req) ->
    case fun gleam@http@request:path_segments/1(Req) of
        [~"robots.txt"] ->
            true;

        _ ->
            false
    end.

-file("src\\nexus_agency\\router.gleam", 241).
-spec same_origin_write(gleam@http@request:request(wisp@internal:connection()), binary()) -> boolean().
same_origin_write(Req, Origin) ->
    case gleam@list:key_find(erlang:element(3, Req), ~"origin") of
        {ok, Value} ->
            Value =:= Origin;

        {error, _} ->
            case gleam@list:key_find(erlang:element(3, Req), ~"referer") of
                {ok, Value@1} ->
                    gleam_stdlib:string_starts_with(Value@1, <<Origin/binary, "/"/utf8>>);

                {error, _} ->
                    false
            end
    end.

-file("src\\nexus_agency\\router.gleam", 164).
-spec handle(gleam@http@request:request(wisp@internal:connection()), pog:connection(), binary()) -> gleam@http@response:response(wisp:body()).
handle(Req, Db, Origin) ->
    Is_admin_post = case {erlang:element(2, Req), gleam@list:first(fun gleam@http@request:path_segments/1(Req))} of
        {post, {ok, First}} ->
            First =:= ~"admin";

        {_, _} ->
            false
    end,
    case Is_admin_post andalso not same_origin_write(Req, Origin) of
        true ->
            _pipe = wisp:response(403),
            _pipe@1 = wisp:string_body(_pipe, ~"Güvenlik kaynağı doğrulanamadı."),
            security_headers(_pipe@1);

        false ->
            case Is_admin_post of
                true ->
                    case exempt_from_csrf(Req) of
                        true ->
                            _pipe@2 = dispatch(Req, Db, Origin),
                            security_headers(_pipe@2);

                        false ->
                            case nexus_agency@csrf:session_token_from(Req) of
                                {error, _} ->
                                    _pipe@3 = wisp:response(403),
                                    _pipe@4 = wisp:string_body(_pipe@3, ~"CSRF doğrulaması başarısız. Sayfayı yenileyip tekrar deneyin."),
                                    security_headers(_pipe@4);

                                {ok, Session_token} ->
                                    _pipe@5 = nexus_agency@csrf:require_csrf_form(Req, Session_token, fun(Req@1) ->
                                        dispatch(Req@1, Db, Origin)
                                    end),
                                    security_headers(_pipe@5)
                            end
                    end;

                false ->
                    case {erlang:element(2, Req), gleam@list:first(fun gleam@http@request:path_segments/1(Req))} of
                        {get, {ok, ~"admin"}} ->
                            case nexus_agency@csrf:session_token_from(Req) of
                                {ok, Session_token@1} ->
                                    _pipe@6 = dispatch(Req, Db, Origin),
                                    _pipe@7 = nexus_agency@csrf:set_js_cookie(_pipe@6, Session_token@1),
                                    security_headers(_pipe@7);

                                {error, _} ->
                                    _pipe@8 = dispatch(Req, Db, Origin),
                                    security_headers(_pipe@8)
                            end;

                        {_, _} ->
                            _pipe@9 = dispatch(Req, Db, Origin),
                            security_headers(_pipe@9)
                    end
            end
    end.
