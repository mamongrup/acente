import gleam/list
import gleam/string
import gleam/time/calendar
import gleam/time/duration as tduration
import gleam/time/timestamp
import lustre/attribute as a
import lustre/element as dom
import nexus_agency/ai_client
import nexus_agency/auth.{type Session}
import nexus_agency/i18n

fn text(value: String) {
  dom.text(value)
}

/// Paneldeki tum arayuz ikonlari tek bir Hugeicons sozlesmesinden uretilir.
fn hugeicon(name: String, extra_class: String) {
  dom.unsafe_raw_html(
    "",
    "i",
    [
      a.class("hgi-stroke hgi-" <> name <> " " <> extra_class),
      a.attribute("aria-hidden", "true"),
    ],
    "",
  )
}

pub type CategoryNav {
  CategoryNav(code: String, key: String)
}

fn catalog_categories() -> List(CategoryNav) {
  [
    CategoryNav("hotel", "cat_hotel"),
    CategoryNav("holiday_home", "cat_holiday_home"),
    CategoryNav("yacht", "cat_yacht"),
    CategoryNav("tour", "cat_tour"),
    CategoryNav("activity", "cat_activity"),
    CategoryNav("flight", "cat_flight"),
    CategoryNav("car", "cat_car"),
    CategoryNav("cruise", "cat_cruise"),
    CategoryNav("pilgrimage", "cat_pilgrimage"),
    CategoryNav("visa", "cat_visa"),
    CategoryNav("ferry", "cat_ferry"),
    CategoryNav("transfer", "cat_transfer"),
    CategoryNav("beach", "cat_beach"),
    CategoryNav("cinema", "cat_cinema"),
    CategoryNav("event", "cat_event"),
    CategoryNav("restaurant", "cat_restaurant"),
    CategoryNav("bus", "cat_bus"),
  ]
}

fn tree_sublink(href: String, label: String) {
  dom.element("a", [a.href(href), a.class("tree-sublink")], [text(label)])
}

fn sidebar_menu_link(href: String, label: String) {
  dom.element("a", [a.href(href), a.class("sidebar-menu-link")], [text(label)])
}

fn sidebar_menu_group(
  id: String,
  title: String,
  items: List(#(String, String)),
  default_open: Bool,
) {
  let class_name = case default_open {
    True -> "sidebar-menu-group is-open"
    False -> "sidebar-menu-group"
  }
  dom.element(
    "div",
    [a.class(class_name), a.attribute("data-sidebar-group", id)],
    [
      dom.element(
        "button",
        [
          a.type_("button"),
          a.class("sidebar-menu-toggle"),
          a.attribute("aria-expanded", case default_open {
            True -> "true"
            False -> "false"
          }),
        ],
        [
          dom.element("span", [a.class("sidebar-menu-title")], [text(title)]),
          hugeicon("arrow-down-01", "sidebar-menu-chevron"),
        ],
      ),
      dom.element(
        "div",
        [a.class("sidebar-menu-items")],
        items |> list.map(fn(item) { sidebar_menu_link(item.0, item.1) }),
      ),
    ],
  )
}

fn catalog_tree(lang: String, active_cat: String) {
  dom.element(
    "div",
    [a.class("sidebar-catalog-tree")],
    catalog_categories()
      |> list.map(fn(cat) {
        let is_active = active_cat == cat.code
        dom.element(
          "div",
          [
            a.class(case is_active {
              True -> "tree-category-group open"
              False -> "tree-category-group"
            }),
          ],
          [
            dom.element(
              "button",
              [
                a.type_("button"),
                a.class("tree-category-toggle"),
                a.attribute("data-toggle-cat", cat.code),
              ],
              [
                hugeicon("arrow-right-01", "tree-arrow"),
                dom.element("span", [a.class("tree-cat-title")], [
                  text(i18n.t(lang, cat.key)),
                ]),
              ],
            ),
            dom.element(
              "div",
              [a.class("tree-subitems")],
              category_subitems(cat, lang),
            ),
          ],
        )
      }),
  )
}

fn category_subitems(cat: CategoryNav, lang: String) {
  let base = "/admin/catalog?cat=" <> cat.code

  case cat.code {
    "holiday_home" -> [
      tree_sublink(base <> "&view=overview", i18n.t(lang, "sub_overview")),
      tree_sublink(base, i18n.t(lang, "sub_listings")),
      tree_sublink(base <> "#catalog-workspace", i18n.t(lang, "sub_new")),
      tree_sublink(
        "/admin/categories?cat=" <> cat.code <> "#category-fields",
        i18n.t(lang, "sub_attributes"),
      ),
      tree_sublink(
        "/admin/holiday-home/property-types?cat=" <> cat.code,
        i18n.t(lang, "sub_holiday_home_types"),
      ),
      tree_sublink(
        "/admin/holiday-home/themes?cat=" <> cat.code,
        i18n.t(lang, "sub_holiday_home_themes"),
      ),
      tree_sublink(
        "/admin/holiday-home/faq?cat=" <> cat.code,
        i18n.t(lang, "sub_faq_template"),
      ),
      tree_sublink(
        "/admin/holiday-home/inclusions?cat=" <> cat.code,
        i18n.t(lang, "sub_includes"),
      ),
      tree_sublink(
        "/admin/holiday-home/rules?cat=" <> cat.code,
        i18n.t(lang, "sub_rules"),
      ),
      tree_sublink(
        "/admin/regions?cat=" <> cat.code <> "#seo",
        i18n.t(lang, "sub_seo"),
      ),
      tree_sublink(
        "/admin/holiday-home/availability?cat=" <> cat.code,
        i18n.t(lang, "sub_availability"),
      ),
      tree_sublink(
        "/admin/holiday-home/recovery?cat=" <> cat.code,
        i18n.t(lang, "sub_recovery"),
      ),
    ]
    _ -> [
      tree_sublink(base <> "&view=overview", i18n.t(lang, "sub_overview")),
      tree_sublink(base, i18n.t(lang, "sub_listings")),
      tree_sublink(base <> "#catalog-workspace", i18n.t(lang, "sub_new")),
      tree_sublink(
        "/admin/categories?cat=" <> cat.code <> "#category-fields",
        i18n.t(lang, "sub_attributes"),
      ),
      tree_sublink(base <> "#includes", i18n.t(lang, "sub_includes")),
      tree_sublink(base <> "#rules", i18n.t(lang, "sub_rules")),
      tree_sublink(
        "/admin/campaigns?cat=" <> cat.code,
        i18n.campaign_label(lang, cat.key),
      ),
      tree_sublink(
        "/admin/categories?cat=" <> cat.code <> "#themes",
        i18n.t(lang, "sub_themes"),
      ),
      tree_sublink(
        "/admin/categories?cat=" <> cat.code <> "#rooms",
        i18n.t(lang, "sub_rooms"),
      ),
      tree_sublink(
        "/admin/regions?cat=" <> cat.code <> "#seo",
        i18n.t(lang, "sub_seo"),
      ),
      tree_sublink(base <> "#availability", i18n.t(lang, "sub_availability")),
      tree_sublink(
        "/admin/abandoned-carts?cat=" <> cat.code,
        i18n.t(lang, "sub_recovery"),
      ),
    ]
  }
}

pub fn login_page(message: String, lang: String) -> String {
  layout(
    "Giriş",
    dom.element("main", [a.class("auth-card")], [
      dom.element("span", [a.class("eyebrow")], [text("NEXUS AGENCY")]),
      dom.element("h1", [], [text("Çalışma alanınıza giriş yapın")]),
      dom.element("p", [a.class("muted")], [
        text("Acente, ekip ve müşteri operasyonlarını tek yerden yönetin."),
      ]),
      dom.element("form", [a.method("post"), a.action("/login")], [
        dom.element("label", [], [
          text("E-posta"),
          dom.element(
            "input",
            [
              a.name("email"),
              a.type_("email"),
              a.required(True),
              a.autocomplete("username"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text(i18n.t(lang, "tenant_selector")),
          dom.element(
            "input",
            [
              a.name("tenant_slug"),
              a.type_("text"),
              a.attribute(
                "placeholder",
                i18n.t(lang, "tenant_slug_placeholder"),
              ),
              a.autocomplete("organization"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("İki aşamalı giriş kodu (etkinse)"),
          dom.element(
            "input",
            [
              a.name("mfa_code"),
              a.type_("text"),
              a.autocomplete("one-time-code"),
              a.attribute("maxlength", "16"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Parola"),
          dom.element(
            "input",
            [
              a.name("password"),
              a.type_("password"),
              a.required(True),
              a.autocomplete("current-password"),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Giriş yap"),
        ]),
      ]),
      case message {
        "" -> text("")
        value -> dom.element("p", [a.class("error")], [text(value)])
      },
      // Tema secici swatch — giris sayfasinda da tema degistirilebilsin
      dom.element("div", [a.class("login-theme-swatch")], [
        dom.element("span", [a.class("login-theme-label")], [text("Tema")]),
        dom.element("div", [a.class("login-theme-swatches")], [
          theme_swatch_button("dark", "Karanlık"),
          theme_swatch_button("light", "Aydınlık"),
        ]),
      ]),
    ]),
    lang,
    [],
    [],
  )
}

fn theme_swatch_button(value: String, label: String) -> dom.Element(Nil) {
  dom.element(
    "button",
    [
      a.type_("button"),
      a.class("login-theme-swatch-btn"),
      a.attribute("data-theme-value", value),
      a.attribute("title", label),
      a.attribute("aria-label", label),
    ],
    [dom.text("")],
  )
}

fn sidebar_element(lang: String, active_cat: String, membership: String) {
  let is_admin = membership == "admin" || membership == "owner"
  let all_operation_links = [
    #("/admin/control-center", "Süper yönetim denetimleri"),
    #("/admin/reservations", i18n.t(lang, "reservations")),
    #("/admin/offers", i18n.t(lang, "offers")),
    #("/admin/inquiries", i18n.t(lang, "inquiries")),
    #("/admin/customer-care", "Müşteri hizmetleri"),
    #("/admin/notifications", i18n.t(lang, "notification_center")),
    #("/admin/search-analytics", i18n.t(lang, "search_analytics")),
    #("/admin/abandoned-carts", i18n.t(lang, "abandoned_carts")),
    #("/admin/customers", i18n.t(lang, "customers")),
    #("/admin/reports", i18n.t(lang, "reports")),
    #("/admin/finance-overview", "Finans ve faturalar"),
    #("/admin/commerce-operations", "Satış ve kanal operasyonları"),
    #("/admin/commercial-operations", "Ticari operasyonlar"),
    #("/admin/supplier-operations", "Tedarikçi operasyonu"),
    #("/admin/review-center", "İnceleme merkezi"),
    #("/admin/role-context", "Görev alanım"),
  ]
  let operation_links = case membership {
    "admin" | "owner" -> all_operation_links
    "staff" -> [
      #("/admin/reservations", i18n.t(lang, "reservations")),
      #("/admin/offers", i18n.t(lang, "offers")),
      #("/admin/inquiries", i18n.t(lang, "inquiries")),
      #("/admin/customer-care", "Müşteri hizmetleri"),
      #("/admin/customers", i18n.t(lang, "customers")),
      #("/admin/reports", i18n.t(lang, "reports")),
      #("/admin/role-context", "Görev alanım"),
    ]
    "sub_agency" -> [
      #("/admin/reservations", i18n.t(lang, "reservations")),
      #("/admin/offers", i18n.t(lang, "offers")),
      #("/admin/customers", i18n.t(lang, "customers")),
      #("/admin/assigned-inquiries", "Atanmış talepler"),
      #("/admin/role-context", "Görev alanım"),
    ]
    "supplier" -> [
      #("/admin/supplier-bookings", "Rezervasyonlarım"),
      #("/admin/supplier-inquiries", "İlan talepleri"),
      #("/admin/supplier-operations", "Belgeler ve hakediş"),
      #("/admin/role-context", "Görev alanım"),
    ]
    _ -> []
  }
  let content_links = [
    #("/admin/campaigns", i18n.t(lang, "campaigns")),
    #("/admin/cms", i18n.t(lang, "cms")),
    #("/admin/media", i18n.t(lang, "media")),
    #("/admin/popups", i18n.t(lang, "popups")),
  ]
  let network_links = [
    #("/admin/sub-agencies", i18n.t(lang, "sub_agencies")),
    #("/admin/supplier-onboarding", "Tedarikçi başvuruları"),
    #("/admin/listing-submissions", "İlan başvuruları"),
    #("/admin/supplier-campaigns?audience=supplier", i18n.t(lang, "campaigns")),
    #("/admin/regions", i18n.t(lang, "regions")),
    #("/admin/ai", i18n.t(lang, "ai")),
    #("/admin/integrations", i18n.t(lang, "integrations")),
    #("/admin/sync", "Sync durumu"),
    #("/admin/languages", i18n.t(lang, "languages")),
    #("/admin/currencies", i18n.t(lang, "currencies")),
  ]
  let network_links_for_role = case membership {
    "admin" | "owner" -> network_links
    "supplier" -> [
      #(
        "/admin/supplier-campaigns?audience=supplier",
        i18n.t(lang, "campaigns"),
      ),
    ]
    _ -> []
  }
  let system_links = [
    #("/admin/team", i18n.t(lang, "team")),
    #("/admin/settings", i18n.t(lang, "settings")),
    #("/admin/seo", "SEO merkezi"),
    #("/admin/membership-setup", "Üyelik kurulumu ve bildirimler"),
  ]
  dom.element("aside", [a.class("sidebar")], [
    dom.element("div", [a.class("brand")], [
      hugeicon("airplane-02", "brand-icon"),
      dom.element("div", [], [
        text("NEXUS"),
        dom.element("small", [], [text(i18n.t(lang, "welcome_eyebrow"))]),
      ]),
    ]),
    dom.element("nav", [a.class("sidebar-nav")], [
      sidebar_menu_link("/admin", i18n.t(lang, "dashboard")),
      // Keep the category tree inside the same top-level accordion as the
      // other catalog links so it is closed on non-catalog screens.
      case membership {
        "sub_agency" -> dom.element("span", [], [])
        _ ->
          dom.element(
            "div",
            [
              a.class(case active_cat != "" {
                True -> "sidebar-menu-group is-open"
                False -> "sidebar-menu-group"
              }),
              a.attribute("data-sidebar-group", "catalog"),
            ],
            [
              dom.element(
                "button",
                [
                  a.type_("button"),
                  a.class("sidebar-menu-toggle"),
                  a.attribute("aria-expanded", case active_cat != "" {
                    True -> "true"
                    False -> "false"
                  }),
                ],
                [
                  dom.element("span", [a.class("sidebar-menu-title")], [
                    text(i18n.t(lang, "catalog")),
                  ]),
                  hugeicon("arrow-down-01", "sidebar-menu-chevron"),
                ],
              ),
              dom.element("div", [a.class("sidebar-menu-items")], [
                case membership {
                  "admin" -> catalog_tree(lang, active_cat)
                  "staff" -> sidebar_menu_link("/admin/catalog", "İlanlar")
                  "supplier" -> sidebar_menu_link("/admin/catalog", "İlanlarım")
                  _ -> dom.element("span", [], [])
                },
                case is_admin {
                  True ->
                    sidebar_menu_link(
                      "/admin/settings#contracts",
                      i18n.t(lang, "cat_contracts"),
                    )
                  False -> dom.element("span", [], [])
                },
                case is_admin {
                  True ->
                    sidebar_menu_link(
                      "/admin/categories#subcategories",
                      i18n.t(lang, "cat_subcategories"),
                    )
                  False -> dom.element("span", [], [])
                },
              ]),
            ],
          )
      },
      sidebar_menu_group(
        "operations",
        i18n.t(lang, "operations_header"),
        operation_links,
        False,
      ),
      sidebar_menu_group(
        "content",
        i18n.t(lang, "cms"),
        case membership {
          "admin" -> content_links
          "staff" -> [#("/admin/media", i18n.t(lang, "media"))]
          "supplier" -> [#("/admin/media", i18n.t(lang, "media"))]
          _ -> []
        },
        False,
      ),
      sidebar_menu_group(
        "network",
        i18n.t(lang, "integrations"),
        network_links_for_role,
        False,
      ),
      sidebar_menu_group(
        "system",
        i18n.t(lang, "settings"),
        case is_admin {
          True -> system_links
          False -> []
        },
        False,
      ),
    ]),
    dom.element("div", [a.class("sidebar-footer")], [
      dom.element("form", [a.method("post"), a.action("/logout")], [
        dom.element("button", [a.class("logout")], [
          text(i18n.t(lang, "logout")),
        ]),
      ]),
    ]),
  ])
}

fn panel_mobile_tab_bar(lang: String, membership: String) {
  let #(catalog_href, catalog_label, operations_href, last_href, last_label) = case
    membership
  {
    "supplier" -> #(
      "/admin/listings",
      "İlanlarım",
      "/admin/supplier-bookings",
      "/admin/supplier-campaigns?audience=supplier",
      "Kampanya",
    )
    "sub_agency" -> #(
      "/admin/offers",
      "Teklifler",
      "/admin/reservations",
      "/admin/customers",
      "Müşteriler",
    )
    "staff" -> #(
      "/admin/listings",
      i18n.t(lang, "catalog"),
      "/admin/reservations",
      "/admin/inquiries",
      "Talepler",
    )
    _ -> #(
      "/admin/listings",
      i18n.t(lang, "catalog"),
      "/admin/reservations",
      "/admin/cms",
      i18n.t(lang, "cms"),
    )
  }
  dom.element(
    "nav",
    [
      a.class("panel-tab-bar"),
      a.attribute("aria-label", i18n.t(lang, "mobile_menu")),
    ],
    [
      dom.element("a", [a.class("panel-tab-item"), a.href("/admin")], [
        hugeicon("dashboard-square-01", "panel-tab-icon"),
        dom.element("span", [a.class("panel-tab-label")], [
          text(i18n.t(lang, "dashboard")),
        ]),
      ]),
      dom.element("a", [a.class("panel-tab-item"), a.href(catalog_href)], [
        hugeicon("package", "panel-tab-icon"),
        dom.element("span", [a.class("panel-tab-label")], [
          text(catalog_label),
        ]),
      ]),
      dom.element("a", [a.class("panel-tab-item"), a.href(operations_href)], [
        hugeicon("invoice-01", "panel-tab-icon"),
        dom.element("span", [a.class("panel-tab-label")], [
          text(i18n.t(lang, "operations_header")),
        ]),
      ]),
      dom.element("a", [a.class("panel-tab-item"), a.href(last_href)], [
        hugeicon("pencil-edit-01", "panel-tab-icon"),
        dom.element("span", [a.class("panel-tab-label")], [
          text(last_label),
        ]),
      ]),
      dom.element(
        "button",
        [
          a.class("panel-tab-item"),
          a.type_("button"),
          a.attribute("data-panel-tab-more", ""),
        ],
        [
          hugeicon("more-horizontal", "panel-tab-icon"),
          dom.element("span", [a.class("panel-tab-label")], [
            text(i18n.t(lang, "settings")),
          ]),
        ],
      ),
    ],
  )
}

fn topbar_element(title: String, user_name: String, lang: String) {
  dom.element("header", [a.class("panel-topbar")], [
    dom.element(
      "button",
      [
        a.type_("button"),
        a.class("mobile-nav-toggle"),
        a.id("mobile-nav-toggle"),
        a.attribute("aria-label", i18n.t(lang, "menu_open")),
        a.attribute("aria-expanded", "false"),
      ],
      [hugeicon("menu-01", "")],
    ),
    dom.element("div", [a.class("crumb-wrap")], [
      text(i18n.t(lang, "welcome_eyebrow") <> " / "),
      dom.element("span", [a.class("highlight")], [text(title)]),
    ]),
    dom.element("div", [a.class("topbar-right")], [
      dom.element("div", [a.class("lang-picker-wrap")], [
        dom.element(
          "button",
          [
            a.type_("button"),
            a.class("lang-btn"),
            a.id("topbar-lang-btn"),
            a.attribute("aria-haspopup", "menu"),
            a.attribute("aria-expanded", "false"),
            a.attribute(
              "aria-label",
              i18n.t(lang, "lang_switch_label") <> " — " <> i18n.lang_name(lang),
            ),
          ],
          [text(i18n.flag_icon(lang) <> " " <> string.uppercase(lang) <> " ▾")],
        ),
        dom.element(
          "div",
          [
            a.class("lang-menu"),
            a.id("topbar-lang-menu"),
            a.attribute("role", "menu"),
            a.attribute("aria-label", i18n.t(lang, "languages_aria")),
          ],
          i18n.supported_languages()
            |> list.map(fn(item) {
              let code = item.0
              let flag = item.1
              let name = item.2
              let is_active = code == lang
              dom.element(
                "a",
                [
                  a.href("/set-lang/" <> code),
                  a.class(case is_active {
                    True -> "lang-option active"
                    False -> "lang-option"
                  }),
                  a.attribute("role", "menuitem"),
                  a.attribute("aria-current", case is_active {
                    True -> "true"
                    False -> "false"
                  }),
                ],
                [text(flag <> " " <> name)],
              )
            }),
        ),
      ]),
      dom.element(
        "button",
        [
          a.class("secondary"),
          a.id("topbar-search-trigger"),
          a.attribute("style", "padding:6px 14px;font-size:12px;gap:6px;"),
          a.attribute("aria-haspopup", "dialog"),
          a.attribute("aria-label", i18n.t(lang, "search_quick") <> " (Ctrl+K)"),
        ],
        [text(i18n.t(lang, "search_quick"))],
      ),
      dom.element("div", [a.class("currency-ticker")], [
        dom.element("span", [a.class("tcmb-pulse")], []),
        text(i18n.t(lang, "tcmb_live")),
      ]),
      // Tema toggle: koyu ↔ aydınlık. Varsayılan saate göre (auto).
      // Tıklama: dark ↔ light arasında geçiş yapar.
      dom.element(
        "button",
        [
          a.attribute("type", "button"),
          a.class("theme-toggle-btn"),
          a.id("theme-toggle"),
          a.attribute("aria-label", "Tema değiştir"),
          a.attribute("title", "Koyu/aydınlık tema arasında geçiş"),
        ],
        [
          dom.unsafe_raw_html(
            "",
            "i",
            [a.class("hgi-stroke hgi-moon-02 theme-icon-dark")],
            "",
          ),
          dom.unsafe_raw_html(
            "",
            "i",
            [a.class("hgi-stroke hgi-sun-01 theme-icon-light")],
            "",
          ),
        ],
      ),
      dom.element("span", [a.class("user-chip")], [
        dom.element("span", [a.class("user-avatar-dot")], []),
        text(user_name),
      ]),
    ]),
  ])
}

/// Sunucu saatiyle auto palet çözümü — theme-boot.js eşikleriyle aynı:
/// 07–19 aydınlık, diğer saatler koyu.
/// Sunucu saatiyle auto palet çözümü — varsayılan tema belirlenmezse
/// zaman dilimine göre dark veya light döndürür.
pub fn auto_theme_at(ts: timestamp.Timestamp) -> String {
  let #(_, time) = timestamp.to_calendar(ts, tduration.minutes(3 * 60))
  let calendar.TimeOfDay(hours: hour, ..) = time
  // 07–19 arası aydınlık, diğer saatler koyu
  case hour {
    h if h >= 7 && h < 19 -> "light"
    _ -> "dark"
  }
}

pub fn dashboard(s: Session, lang: String, active_cat: String) -> String {
  let nexus_status = case s.membership {
    "admin" -> "Hazır"
    _ -> "Kapalı"
  }
  let #(dashboard_intro, actions) = case s.membership {
    "supplier" -> #(
      "İlanlarınızı, müsaitliğinizi ve size gelen rezervasyonları yönetin.",
      [
        #(
          "/admin/catalog#catalog-workspace",
          "İlanlarım",
          "Kendi ilanlarınızı oluşturun ve güncelleyin",
        ),
        #(
          "/admin/catalog#rate-plans",
          "Fiyat ve müsaitlik",
          "Fiyat planlarını ve takvimi yönetin",
        ),
        #(
          "/admin/supplier-bookings",
          "Rezervasyonlarım",
          "İlanlarınıza ait rezervasyonları izleyin",
        ),
        #(
          "/admin/supplier-inquiries",
          "İlan talepleri",
          "Kendi ilanlarınıza gelen müşteri taleplerini görün",
        ),
        #(
          "/admin/supplier-operations",
          "Belgeler ve hakediş",
          "Belge yenileme, ödemeler ve performans",
        ),
        #(
          "/admin/supplier-campaigns?audience=supplier",
          "Kampanyalarım",
          "Tedarikçi kampanyalarını yönetin",
        ),
        #("/admin/media", "Medya", "İlan görsellerini düzenleyin"),
      ],
    )
    "sub_agency" -> #("Satışlarınızı ve kendi müşterilerinizi takip edin.", [
      #(
        "/admin/reservations",
        "Rezervasyonlar",
        "Satış ve seyahat durumlarını yönetin",
      ),
      #("/admin/offers", "Teklifler", "Müşterilere sunulan teklifleri izleyin"),
      #("/admin/customers", "Müşteriler", "Müşteri kayıtlarını görüntüleyin"),
      #(
        "/admin/assigned-inquiries",
        "Atanmış talepler",
        "Acente ekibinize yönlendirilen talepleri görün",
      ),
    ])
    "staff" -> #("Günlük operasyonları ve müşteri taleplerini yönetin.", [
      #(
        "/admin/reservations",
        "Rezervasyonlar",
        "Bekleyen ve yaklaşan işlemleri izleyin",
      ),
      #(
        "/admin/inquiries",
        "Gelen talepler",
        "Yeni müşteri taleplerini yanıtlayın",
      ),
      #(
        "/admin/customer-care",
        "Müşteri hizmetleri",
        "Destek ve işlem taleplerini yönetin",
      ),
      #("/admin/catalog#catalog-workspace", "İlanlar", "Kataloğu güncelleyin"),
      #("/admin/reports", "Raporlar", "Operasyon sonuçlarını inceleyin"),
    ])
    _ -> #(
      "Acente satışlarını, tedarikçileri, müşteri hizmetlerini ve siteyi tek yerden yönetin.",
      [
        #(
          "/admin/reservations",
          "Rezervasyonlar",
          "Bekleyen ve yaklaşan işlemleri izleyin",
        ),
        #(
          "/admin/customer-care",
          "Müşteri hizmetleri",
          "Destek ve işlem taleplerini yönetin",
        ),
        #(
          "/admin/catalog#catalog-workspace",
          "İlan ve envanter",
          "17 ana kategoride kendi ilanlarınızı yönetin",
        ),
        #(
          "/admin/supplier-onboarding",
          "Tedarikçi başvuruları",
          "Başvuru ve belge süreçlerini izleyin",
        ),
        #(
          "/admin/review-center",
          "İnceleme merkezi",
          "Tedarikçi yanıtları ve yayın taleplerini karara bağlayın",
        ),
        #("/admin/sub-agencies", "Acenteler", "Alt acente ağınızı yönetin"),
        #("/admin/campaigns", "Kampanyalar", "Dönemsel teklifleri yönetin"),
        #(
          "/admin/reports",
          "Raporlar",
          "Satış ve operasyon sonuçlarını inceleyin",
        ),
        #(
          "/admin/finance-overview",
          "Finans ve faturalar",
          "Sipariş, ödeme, iade ve fatura durumlarını izleyin",
        ),
        #(
          "/admin/integrations",
          "Entegrasyonlar",
          "Bağlantıları ve senkronizasyonu denetleyin",
        ),
        #("/admin/team", "Ekip ve yetkiler", "Kullanıcı erişimini yönetin"),
      ],
    )
  }
  layout_with_theme(
    s.theme_pref,
    i18n.t(lang, "dashboard"),
    dom.element(
      "div",
      [a.class("dashboard"), a.attribute("data-panel-role", s.membership)],
      [
        sidebar_element(lang, active_cat, s.membership),
        panel_mobile_tab_bar(lang, s.membership),
        dom.element("section", [a.class("panel-area")], [
          topbar_element(i18n.t(lang, "dashboard"), s.name, lang),
          dom.element("main", [a.class("panel-content")], [
            dom.element("div", [a.class("welcome")], [
              dom.element("span", [a.class("eyebrow")], [
                text(i18n.t(lang, "welcome_eyebrow")),
              ]),
              dom.element("h1", [], [
                text(s.name <> ", " <> i18n.t(lang, "dashboard")),
              ]),
              dom.element("p", [], [
                text(dashboard_intro),
              ]),
            ]),
            // Son güncelleme zaman damgası — JS tarafından canlı güncellenir
            dom.element(
              "div",
              [
                a.class("dashboard-last-updated"),
                a.id("dashboard-last-updated"),
                a.attribute("role", "status"),
                a.attribute("aria-live", "polite"),
              ],
              [text("")],
            ),
            dom.element(
              "div",
              [a.class("metric-grid"), a.id("dashboard-metrics")],
              [
                metric_id(
                  i18n.t(lang, "metric_published"),
                  "0",
                  i18n.t(lang, "metric_published_desc"),
                  "dashboard-published",
                ),
                metric_id(
                  i18n.t(lang, "metric_pending"),
                  "0",
                  i18n.t(lang, "metric_pending_desc"),
                  "dashboard-pending",
                ),
                metric_id(
                  i18n.t(lang, "metric_upcoming"),
                  "0",
                  i18n.t(lang, "metric_upcoming_desc"),
                  "dashboard-upcoming",
                ),
                metric_id(
                  i18n.t(lang, "metric_nexus"),
                  nexus_status,
                  i18n.t(lang, "metric_nexus_desc"),
                  "dashboard-nexus",
                ),
              ],
            ),
            dom.element(
              "section",
              [a.id("dashboard-work-queue"), a.class("quick")],
              [
                dom.element("h2", [], [text("İş bekleyen konular")]),
                dom.element("p", [a.class("muted")], [
                  text("Güncel operasyon kuyruğu yükleniyor…"),
                ]),
              ],
            ),
            // 14 günlük trend modalı — dashboard-admin.js kart tıklamasıyla açar;
            // serileri /admin/dashboard/series'ten çizer (sparkline'larla aynı veri).
            dom.element(
              "div",
              [
                a.class("chart-modal-overlay"),
                a.id("trend-chart-modal"),
                a.attribute("role", "dialog"),
                a.attribute("aria-modal", "true"),
                a.attribute("aria-labelledby", "trend-chart-title"),
                a.attribute("hidden", "hidden"),
              ],
              [
                dom.element("div", [a.class("chart-modal")], [
                  dom.element("header", [a.class("chart-modal-head")], [
                    dom.element("div", [], [
                      dom.element("h2", [a.id("trend-chart-title")], [
                        text("14 günlük trend"),
                      ]),
                      dom.element("p", [a.class("chart-modal-sub")], [
                        text("Acente veritabanından günlük kümeler"),
                      ]),
                    ]),
                    dom.element(
                      "button",
                      [
                        a.attribute("type", "button"),
                        a.class("chart-modal-close"),
                        a.attribute("aria-label", "Grafik modalını kapat"),
                      ],
                      [text("✕")],
                    ),
                  ]),
                  dom.element(
                    "div",
                    [
                      a.class("chart-series-tabs"),
                      a.id("chart-series-tabs"),
                      a.attribute("role", "tablist"),
                      a.attribute("aria-label", "Seri seç"),
                    ],
                    [],
                  ),
                  // Aralık seçici: 7 / 14 / 30 günlük görünüm
                  dom.element(
                    "div",
                    [
                      a.class("chart-range-picker"),
                      a.id("chart-range-picker"),
                      a.attribute("role", "group"),
                      a.attribute("aria-label", "Gün aralığı seç"),
                    ],
                    [
                      dom.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("range-btn"),
                          a.attribute("data-days", "7"),
                        ],
                        [text("7g")],
                      ),
                      dom.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("range-btn active"),
                          a.attribute("data-days", "14"),
                        ],
                        [text("14g")],
                      ),
                      dom.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("range-btn"),
                          a.attribute("data-days", "30"),
                        ],
                        [text("30g")],
                      ),
                    ],
                  ),
                  dom.element(
                    "div",
                    [a.class("chart-host"), a.id("trend-chart-host")],
                    [],
                  ),
                  dom.element("p", [a.class("chart-modal-foot")], [
                    text(
                      "Noktaların üzerine gelin veya odaklanın; sol-sağ ok tuşlarıyla günler arasında gezinin.",
                    ),
                  ]),
                ]),
              ],
            ),
            dom.element(
              "div",
              [a.class("quick-grid")],
              actions |> list.map(fn(item) { quick(item.0, item.1, item.2) }),
            ),
          ]),
        ]),
      ],
    ),
    lang,
    ["/static/dashboard-admin.js?v=20260928-service1"],
    [],
    s.wizard_prefs_json,
  )
}

/// Panel bölüm sayfası.
///
/// `section_key` sabit bir slug'dır ("regions", "cms", ...) ve yönlendirme
/// anahtarıdır: form seçimi ile script/CSS seçimi buna göre yapılır. Görünür
/// başlık seçili dilden `i18n.section_title` ile üretilir — böylece başlık
/// çevrilebilirken dispeç sabit kalır.
pub fn section(
  s: Session,
  section_key: String,
  intro: String,
  links: List(#(String, String)),
  lang: String,
  active_cat: String,
) -> String {
  let title = i18n.section_title(lang, section_key)
  let title = case section_key {
    "control-center" -> "Süper yönetim denetimleri"
    "role-context" -> "Görev alanım"
    "supplier-bookings" -> "Rezervasyonlarım"
    "supplier-inquiries" -> "İlan talepleri"
    "supplier-operations" -> "Belgeler ve hakediş"
    "assigned-inquiries" -> "Atanmış talepler"
    "review-center" -> "İnceleme merkezi"
    "finance-overview" -> "Finans ve faturalar"
    "commercial-operations" -> "Ticari operasyonlar"
    _ -> title
  }
  layout_with_theme(
    s.theme_pref,
    title,
    dom.element(
      "div",
      [a.class("dashboard"), a.attribute("data-panel-role", s.membership)],
      [
        sidebar_element(lang, active_cat, s.membership),
        panel_mobile_tab_bar(lang, s.membership),
        dom.element("section", [a.class("panel-area")], [
          topbar_element(title, s.name, lang),
          dom.element("main", [a.class("panel-content")], [
            dom.element("div", [a.class("welcome")], [
              dom.element("span", [a.class("eyebrow")], [
                text(i18n.t(lang, "welcome_eyebrow")),
              ]),
              dom.element("h1", [], [text(title)]),
              dom.element("p", [], [text(intro)]),
            ]),
            dom.element(
              "div",
              [a.class("quick-grid")],
              links
                |> list.map(fn(item) {
                  quick(item.0, item.1, "İlgili yönetim alanını açın.")
                }),
            ),
            // Dispeç SLUG üzerinden: görünen başlık artık dile göre değiştiği
            // için başlıkla eşleştirmek yanlış form/varlık seçerdi.
            case section_key {
              "control-center" -> control_center_form()
              "role-context" -> role_context_form()
              "regions" -> region_form()
              "settings" -> settings_form()
              "currencies" -> currency_form()
              "customers" -> customers_form(lang)
              "reservations" -> reservations_form()
              "supplier-bookings" -> supplier_bookings_form()
              "supplier-inquiries" -> supplier_inquiries_form()
              "supplier-operations" -> supplier_operations_form()
              "assigned-inquiries" -> assigned_inquiries_form()
              "finance-overview" -> finance_overview_form()
              "commercial-operations" -> commercial_operations_form()
              "review-center" -> review_center_form()
              "languages" -> languages_form()
              "catalog" | "listings" -> catalog_form(active_cat)
              "categories" -> categories_form()
              "integrations" -> integrations_form()
              "sync" -> sync_form()
              "supplier-onboarding" -> supplier_onboarding_form()
              "listing-submissions" -> listing_submissions_form()
              "cms" -> cms_form()
              "ai" -> ai_form()
              "campaigns" | "supplier-campaigns" -> campaigns_form()
              "team" -> team_form(lang)
              "reports" -> reports_form()
              "media" -> media_form()
              "abandoned-carts" -> abandoned_carts_form()
              "sub-agencies" -> sub_agencies_form()
              "popups" -> popups_banners_form()
              "offers" -> offers_form()
              "inquiries" -> inquiries_form()
              "notifications" -> notifications_form()
              "search-analytics" -> search_analytics_form()
              _ -> dom.element("div", [], [])
            },
          ]),
        ]),
      ],
    ),
    lang,
    section_scripts(section_key),
    section_stylesheets(section_key),
    s.wizard_prefs_json,
  )
}

fn role_context_form() {
  dom.element("section", [a.class("quick"), a.id("role-context-workspace")], [
    dom.element("h2", [], [text("Hesap rolleri")]),
    dom.element("p", [a.class("muted")], [
      text(
        "Yalnızca hesabınıza açık görev alanına geçebilirsiniz. Her görev alanı kendi kayıt sınırlarını uygular.",
      ),
    ]),
    dom.element(
      "div",
      [a.id("role-context-content"), a.attribute("aria-live", "polite")],
      [text("Yükleniyor…")],
    ),
  ])
}

fn control_center_form() {
  dom.element("section", [a.class("quick"), a.id("control-center-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Canlı operasyon denetimleri")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Sonuçlar yalnızca bu acenteye aittir. Bağımsız çalışma normal durumdur; NEXUS bağlantısı isteğe bağlıdır.",
          ),
        ]),
      ]),
      dom.element(
        "button",
        [
          a.type_("button"),
          a.class("secondary"),
          a.id("control-center-refresh"),
        ],
        [text("Kontrolleri yenile")],
      ),
    ]),
    dom.element(
      "p",
      [a.id("control-center-status"), a.attribute("role", "status")],
      [text("Denetimler yükleniyor…")],
    ),
    dom.element(
      "div",
      [a.class("metric-grid"), a.id("control-center-summary")],
      [],
    ),
    dom.element(
      "div",
      [a.class("table-card"), a.id("control-center-results")],
      [],
    ),
  ])
}

fn supplier_bookings_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("supplier-bookings-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("Rezervasyon ve hizmet işleri")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Yetkiniz olan rezervasyonları ve açık hizmet adımlarını buradan yönetin.",
            ),
          ]),
        ]),
      ]),
      dom.element(
        "div",
        [a.id("supplier-bookings-list"), a.attribute("aria-live", "polite")],
        [text("Yükleniyor…")],
      ),
    ],
  )
}

fn supplier_inquiries_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("supplier-inquiries-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("İlanlarıma gelen talepler")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Yalnızca size ait ilanlara gönderilen talepler burada görünür.",
            ),
          ]),
        ]),
      ]),
      dom.element(
        "div",
        [a.id("supplier-inquiries-list"), a.attribute("aria-live", "polite")],
        [text("Yükleniyor…")],
      ),
    ],
  )
}

fn supplier_operations_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("supplier-operations-workspace")],
    [
      dom.element("h2", [], [text("Tedarikçi operasyonu")]),
      dom.element("p", [a.class("muted")], [
        text(
          "Belge yenilemelerini, onaylı rezervasyonlardan doğan hakedişleri ve gerçek işlem sayılarını takip edin.",
        ),
      ]),
      dom.element(
        "div",
        [
          a.id("supplier-operations-content"),
          a.attribute("aria-live", "polite"),
        ],
        [text("Yükleniyor…")],
      ),
    ],
  )
}

fn assigned_inquiries_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("assigned-inquiries-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("Acente ekibine atanmış talepler")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Yalnızca kuruluşunuza yönlendirilen müşteri talepleri görünür.",
            ),
          ]),
        ]),
      ]),
      dom.element(
        "div",
        [a.id("assigned-inquiries-list"), a.attribute("aria-live", "polite")],
        [text("Yükleniyor…")],
      ),
    ],
  )
}

fn finance_overview_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("finance-overview-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("Sipariş, ödeme ve fatura takibi")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Finans kayıtlarını acente bazında inceleyin; ödeme ve iade kararlarını ilgili işlem ekranında tamamlayın.",
            ),
          ]),
        ]),
      ]),
      dom.element(
        "div",
        [a.id("finance-overview-content"), a.attribute("aria-live", "polite")],
        [text("Yükleniyor…")],
      ),
    ],
  )
}

fn commercial_operations_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("commercial-operations-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("Kategori ve satış operasyonları")]),
          dom.element("p", [a.class("muted")], [
            text(
              "17 kategorinin hizmet adımlarını, kanal eşlemelerini, alt acente sözleşmelerini ve fiyat onaylarını yönetin.",
            ),
          ]),
        ]),
      ]),
      dom.element(
        "div",
        [
          a.id("commercial-operations-content"),
          a.attribute("aria-live", "polite"),
        ],
        [text("Yükleniyor…")],
      ),
    ],
  )
}

fn review_center_form() {
  dom.element("section", [a.class("quick"), a.id("review-center-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("İnceleme ve onay kuyruğu")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Tedarikçi rezervasyon yanıtları, ilan incelemeleri ve üyelik başvuruları.",
          ),
        ]),
      ]),
    ]),
    dom.element(
      "div",
      [a.id("review-center-list"), a.attribute("aria-live", "polite")],
      [text("Yükleniyor…")],
    ),
  ])
}

fn bulk_delete_form(
  action: String,
  publish: Bool,
  unpublish: Bool,
  csv: Bool,
  csv_name: String,
) -> dom.Element(Nil) {
  dom.element(
    "form",
    list.flatten([
      [
        a.attribute("data-bulk-form", "true"),
        a.method("post"),
        a.action(action),
        a.class("bulk-delete-form"),
      ],
      case publish {
        True -> [a.attribute("data-bulk-publish", "true")]
        False -> []
      },
      case unpublish {
        True -> [a.attribute("data-bulk-unpublish", "true")]
        False -> []
      },
      case csv {
        True -> [a.attribute("data-bulk-csv", "true")]
        False -> []
      },
      [a.attribute("data-bulk-csv-name", csv_name)],
    ]),
    [],
  )
}

fn inquiries_form() {
  dom.element("section", [a.class("quick"), a.id("inquiries-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Teklif talepleri")]),
        dom.element("p", [a.class("muted")], [
          text("Vitrinden gelen müşteri taleplerini yönetin."),
        ]),
      ]),
      dom.element(
        "button",
        [
          a.type_("button"),
          a.class("secondary"),
          a.attribute("onclick", "loadInquiries()"),
        ],
        [text("Yenile")],
      ),
    ]),
    dom.element("div", [a.class("table-wrap")], [
      dom.element(
        "table",
        [
          a.class("data-table"),
          a.attribute("data-bulk-table", "true"),
          a.attribute("data-bulk-label", "talep"),
        ],
        [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Müşteri")]),
              dom.element("th", [], [text("İlan")]),
              dom.element("th", [], [text("İletişim")]),
              dom.element("th", [], [text("Durum")]),
            ]),
          ]),
          dom.element("tbody", [a.id("inquiries-table-body")], [
            dom.element("tr", [], [
              dom.element("td", [a.attribute("colspan", "5")], [
                text("Yükleniyor…"),
              ]),
            ]),
          ]),
        ],
      ),
    ]),
    bulk_delete_form(
      "/admin/inquiries/bulk-delete",
      False,
      False,
      True,
      "talepler",
    ),
    dom.element(
      "script",
      [
        a.attribute("src", "/static/inquiries-admin.js"),
        a.attribute("defer", "defer"),
      ],
      [],
    ),
  ])
}

fn notifications_form() {
  dom.element("section", [a.class("quick"), a.id("notifications-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Bildirim merkezi")]),
        dom.element("p", [a.class("muted")], [
          text("Teklif ve operasyon bildirimlerinin gönderim durumunu izleyin."),
        ]),
      ]),
      dom.element(
        "button",
        [
          a.type_("button"),
          a.class("secondary"),
          a.attribute("onclick", "loadNotifications()"),
        ],
        [text("Yenile")],
      ),
    ]),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Kanal")]),
            dom.element("th", [], [text("Şablon")]),
            dom.element("th", [], [text("Alıcı")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Deneme")]),
          ]),
        ]),
        dom.element("tbody", [a.id("notifications-table-body")], [
          dom.element("tr", [], [
            dom.element("td", [a.attribute("colspan", "4")], [
              text("Yükleniyor…"),
            ]),
          ]),
        ]),
      ]),
    ]),
    dom.element(
      "script",
      [
        a.attribute("src", "/static/notifications-admin.js"),
        a.attribute("defer", "defer"),
      ],
      [],
    ),
  ])
}

fn search_analytics_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("search-analytics-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("Arama analitiği")]),
          dom.element("p", [a.class("muted")], [
            text("Son 30 gündeki müşteri arama eğilimleri."),
          ]),
        ]),
        dom.element(
          "button",
          [
            a.type_("button"),
            a.class("secondary"),
            a.attribute("onclick", "loadSearchAnalytics()"),
          ],
          [text("Yenile")],
        ),
      ]),
      dom.element("div", [a.class("table-wrap")], [
        dom.element("table", [], [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Kategori")]),
              dom.element("th", [], [text("Konum")]),
              dom.element("th", [], [text("Arama")]),
            ]),
          ]),
          dom.element("tbody", [a.id("search-analytics-table-body")], [
            dom.element("tr", [], [
              dom.element("td", [a.attribute("colspan", "3")], [
                text("Yükleniyor…"),
              ]),
            ]),
          ]),
        ]),
      ]),
      dom.element(
        "script",
        [
          a.attribute("src", "/static/search-analytics.js"),
          a.attribute("defer", "defer"),
        ],
        [],
      ),
    ],
  )
}

fn customers_form(lang: String) {
  dom.element("section", [a.class("quick"), a.id("customers-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Müşteri kayıtları")]),
        dom.element("p", [a.class("muted")], [
          text("Müşterilerinizi kaydedin ve rezervasyon geçmişine hazırlayın."),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Canlı veri")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/customers"), a.class("customer-form")],
      [
        dom.element("label", [], [
          text("Ad soyad"),
          dom.element(
            "input",
            [
              a.name("full_name"),
              a.required(True),
              a.attribute("placeholder", "Ayşe Yılmaz"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text(i18n.t(lang, "customer_contact")),
          dom.element(
            "input",
            [
              a.name("email"),
              a.type_("email"),
              a.required(False),
              a.attribute("placeholder", "ayse@example.com"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Telefon"),
          dom.element(
            "input",
            [
              a.name("phone"),
              a.type_("tel"),
              a.attribute("placeholder", "+90 5xx xxx xx xx"),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Müşteriyi kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element(
        "table",
        [
          a.class("data-table"),
          a.attribute("data-bulk-table", "true"),
          a.attribute("data-bulk-label", "müşteri"),
        ],
        [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Müşteri")]),
              dom.element("th", [], [text("E-posta")]),
              dom.element("th", [], [text("Telefon")]),
              dom.element("th", [], [text("Kayıt tarihi")]),
            ]),
          ]),
          dom.element("tbody", [a.id("customers-table-body")], [
            dom.element("tr", [], [
              dom.element(
                "td",
                [a.attribute("colspan", "5"), a.class("empty-state")],
                [text("Müşteriler yükleniyor…")],
              ),
            ]),
          ]),
        ],
      ),
    ]),
    bulk_delete_form(
      "/admin/customers/bulk-delete",
      False,
      False,
      True,
      "musteriler",
    ),
  ])
}

fn reservations_form() {
  dom.element("section", [a.class("quick"), a.id("reservations-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Rezervasyon oluştur")]),
        dom.element("p", [a.class("muted")], [
          text("Müşteri ve ilan seçerek teklif veya rezervasyon kaydı açın."),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Canlı veri")]),
    ]),
    dom.element(
      "form",
      [
        a.method("post"),
        a.action("/admin/reservations"),
        a.class("reservation-form"),
      ],
      [
        dom.element("label", [], [
          text("Referans kodu"),
          dom.element(
            "input",
            [
              a.name("reference_code"),
              a.required(True),
              a.attribute("placeholder", "NX-2026-0001"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("İlan"),
          dom.element(
            "select",
            [a.name("listing_id"), a.id("reservation-listing")],
            [
              dom.element("option", [a.attribute("value", "")], [
                text("İlan seçin"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Müşteri"),
          dom.element(
            "select",
            [a.name("customer_id"), a.id("reservation-customer")],
            [
              dom.element("option", [a.attribute("value", "")], [
                text("Müşteri seçin"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Giriş tarihi"),
          dom.element("input", [a.name("check_in"), a.type_("date")], []),
        ]),
        dom.element("label", [], [
          text("Çıkış tarihi"),
          dom.element("input", [a.name("check_out"), a.type_("date")], []),
        ]),
        dom.element("label", [], [
          text("Misafir sayısı"),
          dom.element(
            "input",
            [
              a.name("guest_count"),
              a.type_("number"),
              a.attribute("min", "1"),
              a.attribute("value", "1"),
              a.required(True),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Toplam (kuruş)"),
          dom.element(
            "input",
            [
              a.name("total_minor"),
              a.type_("number"),
              a.attribute("min", "0"),
              a.attribute("value", "0"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Para birimi"),
          dom.element(
            "input",
            [a.name("currency"), a.attribute("value", "TRY"), a.required(True)],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Durum"),
          dom.element("select", [a.name("status")], [
            dom.element("option", [a.attribute("value", "inquiry")], [
              text("Talep"),
            ]),
            dom.element("option", [a.attribute("value", "option")], [
              text("Opsiyon"),
            ]),
            dom.element("option", [a.attribute("value", "confirmed")], [
              text("Onaylandı"),
            ]),
          ]),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Rezervasyonu kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element(
        "table",
        [
          a.class("data-table"),
          a.attribute("data-bulk-table", "true"),
          a.attribute("data-bulk-label", "rezervasyon"),
        ],
        [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Referans")]),
              dom.element("th", [], [text("Müşteri / İlan")]),
              dom.element("th", [], [text("Tarih")]),
              dom.element("th", [], [text("Tutar")]),
              dom.element("th", [], [text("Durum")]),
            ]),
          ]),
          dom.element("tbody", [a.id("reservations-table-body")], [
            dom.element("tr", [], [
              dom.element(
                "td",
                [a.attribute("colspan", "5"), a.class("empty-state")],
                [text("Rezervasyonlar yükleniyor…")],
              ),
            ]),
          ]),
        ],
      ),
    ]),
    bulk_delete_form(
      "/admin/reservations/bulk-delete",
      False,
      False,
      True,
      "rezervasyonlar",
    ),
  ])
}

fn languages_form() {
  dom.element("section", [a.class("quick"), a.id("languages-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Dil ekle veya düzenle")]),
        dom.element("p", [a.class("muted")], [
          text(
            "İçeriklerinizi farklı dillerde yayınlamak için dil kayıtlarını yönetin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Çoklu dil")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/languages"), a.class("language-form")],
      [
        dom.element("label", [], [
          text("Dil kodu"),
          dom.element(
            "input",
            [
              a.name("code"),
              a.required(True),
              a.attribute("maxlength", "10"),
              a.attribute("placeholder", "en"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Dil adı"),
          dom.element(
            "input",
            [
              a.name("name"),
              a.required(True),
              a.attribute("placeholder", "English"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Yerel ad"),
          dom.element(
            "input",
            [
              a.name("native_name"),
              a.required(True),
              a.attribute("placeholder", "English"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Durum"),
          dom.element("select", [a.name("active")], [
            dom.element("option", [a.attribute("value", "true")], [
              text("Aktif"),
            ]),
            dom.element("option", [a.attribute("value", "false")], [
              text("Pasif"),
            ]),
          ]),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Dili kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element(
        "table",
        [
          a.class("data-table"),
          a.attribute("data-bulk-table", "true"),
          a.attribute("data-bulk-label", "dil"),
        ],
        [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Kod")]),
              dom.element("th", [], [text("Dil")]),
              dom.element("th", [], [text("Yerel ad")]),
              dom.element("th", [], [text("Durum")]),
              dom.element("th", [], [text("Rol")]),
            ]),
          ]),
          dom.element("tbody", [a.id("languages-table-body")], [
            dom.element("tr", [], [
              dom.element(
                "td",
                [a.attribute("colspan", "5"), a.class("empty-state")],
                [text("Diller yükleniyor…")],
              ),
            ]),
          ]),
        ],
      ),
    ]),
    bulk_delete_form("/admin/languages/bulk-delete", True, True, True, "diller"),
  ])
}

fn category_display_name(code: String) -> String {
  case code {
    "hotel" -> "Otel"
    "holiday_home" -> "Tatil Evi"
    "yacht" -> "Yat"
    "tour" -> "Tur"
    "activity" -> "Aktivite"
    "flight" -> "Uçuş"
    "car" -> "Araç"
    "cruise" -> "Kruvaziyer"
    "pilgrimage" -> "Hac & Umre"
    "visa" -> "Vize"
    "ferry" -> "Feribot"
    "transfer" -> "Transfer"
    "beach" -> "Şezlong"
    "cinema" -> "Sinema"
    "event" -> "Etkinlik"
    "restaurant" -> "Restoran"
    "bus" -> "Otobüs"
    "villa" -> "Tatil Evi"
    "flight_bus" -> "Uçuş"
    "hajj" -> "Hac & Umre"
    "sunbed" -> "Şezlong"
    _ -> "Otel"
  }
}

fn wizard_step_tab(step: String, num: String, label: String, is_active: Bool) {
  dom.element(
    "button",
    [
      a.attribute("type", "button"),
      a.class(case is_active {
        True -> "wizard-step-tab active"
        False -> "wizard-step-tab"
      }),
      a.attribute("data-step", step),
      a.attribute("aria-label", "Adım " <> num <> ": " <> label),
      a.attribute("aria-current", case is_active {
        True -> "step"
        False -> "false"
      }),
    ],
    [
      dom.element("span", [a.class("tab-num")], [text(num)]),
      dom.element("span", [a.class("tab-label")], [text(label)]),
      dom.element(
        "span",
        [a.class("tab-completion-badge"), a.attribute("aria-hidden", "true")],
        [],
      ),
    ],
  )
}

fn step_footer_nav(prev_step: String, next_step: String, next_label: String) {
  dom.element("div", [a.class("step-footer-actions")], [
    case prev_step {
      "" -> dom.element("div", [], [])
      _ ->
        dom.element(
          "button",
          [
            a.attribute("type", "button"),
            a.class("btn-step-nav btn-step-prev"),
            a.attribute("data-target-step", prev_step),
          ],
          [text("← Geri")],
        )
    },
    dom.element(
      "button",
      [
        a.attribute("type", "button"),
        a.class("btn-step-nav btn-step-next"),
        a.attribute("data-target-step", next_step),
      ],
      [text(next_label <> " →")],
    ),
  ])
}

fn step_footer_submit(prev_step: String) {
  dom.element("div", [a.class("step-footer-actions")], [
    dom.element(
      "button",
      [
        a.attribute("type", "button"),
        a.class("btn-step-nav btn-step-prev"),
        a.attribute("data-target-step", prev_step),
      ],
      [text("← Geri")],
    ),
    dom.element(
      "button",
      [
        a.type_("submit"),
        a.class("btn-step-nav btn-step-submit"),
        a.id("btn-wizard-main-submit"),
      ],
      [text("🚀 Kataloğa Kaydet ve Yayınla")],
    ),
  ])
}

/// JS arayüzü olan sayfalarda kullanılır; ilgili script yüklenmemişse form gönderimi
/// etkisiz kalmasın diye POST devre dışı bırakılır (ör. /admin/offers tabanlı
/// teklif oluşturma yalnızca JS üzerinden çalışır).
fn no_post_without_js() {
  dom.element("script", [], [
    text(
      "document.addEventListener('submit',function(e){var f=e.target;if(f&&f.dataset.jsOnly==='true'){e.preventDefault();}});",
    ),
  ])
}

fn top_live_preview_card(
  effective_cat: String,
  _is_hotel: Bool,
  cat_name: String,
) {
  dom.element(
    "div",
    [
      a.id("top-live-preview-wrapper"),
      a.class("top-live-preview-wrapper glass-glow"),
    ],
    [
      dom.element("div", [a.class("top-preview-header-bar")], [
        dom.element("div", [a.class("preview-header-badge-group")], [
          dom.element("span", [a.class("live-badge-pulse")], [
            dom.element("span", [a.class("live-dot-pulse")], []),
            text("CANLI İLAN KARTI ÖNİZLEMESİ"),
          ]),
          dom.element("span", [a.class("live-badge-sub")], [
            text("Müşterilerin arama ve vitrinde göreceği gerçek kart"),
          ]),
        ]),
        dom.element("span", [a.class("live-sync-indicator")], [
          dom.element("span", [a.class("sync-icon")], [text("⚡")]),
          text("Aşağıda özellik eklendikçe anlık güncellenir"),
        ]),
      ]),
      dom.element(
        "div",
        [a.id("top-showcase-card"), a.class("top-showcase-card")],
        [
          dom.element("div", [a.class("showcase-media-box")], [
            dom.element(
              "img",
              [
                a.id("preview-img"),
                a.attribute("src", case effective_cat {
                  "hotel" ->
                    "https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=800&q=80"
                  "yacht" ->
                    "https://images.unsplash.com/photo-1567899378494-47b22a2ae96a?auto=format&fit=crop&w=800&q=80"
                  "tour" ->
                    "https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=800&q=80"
                  "activity" ->
                    "https://images.unsplash.com/photo-1533873984035-25970ab07461?auto=format&fit=crop&w=800&q=80"
                  "car" ->
                    "https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=800&q=80"
                  "transfer" ->
                    "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?auto=format&fit=crop&w=800&q=80"
                  "flight" ->
                    "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?auto=format&fit=crop&w=800&q=80"
                  "cruise" ->
                    "https://images.unsplash.com/photo-1548574505-5e239809ee19?auto=format&fit=crop&w=800&q=80"
                  "ferry" ->
                    "https://images.unsplash.com/photo-1506953823976-52e1fdc0149a?auto=format&fit=crop&w=800&q=80"
                  "bus" ->
                    "https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=800&q=80"
                  "beach" ->
                    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80"
                  "restaurant" ->
                    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80"
                  "pilgrimage" ->
                    "https://images.unsplash.com/photo-1565552645632-d725f8bfc19a?auto=format&fit=crop&w=800&q=80"
                  "visa" ->
                    "https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=800&q=80"
                  "event" ->
                    "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=800&q=80"
                  "cinema" ->
                    "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&q=80"
                  _ ->
                    "https://images.unsplash.com/photo-1580587771525-78b9dba3b914?auto=format&fit=crop&w=800&q=80"
                }),
                a.attribute("alt", "İlan Görseli"),
              ],
              [],
            ),
            dom.element(
              "span",
              [a.id("preview-badge"), a.class("card-cat-badge")],
              [text(cat_name)],
            ),
            dom.element(
              "span",
              [a.id("preview-photo-count"), a.class("card-photo-count")],
              [text("📸 0 Fotoğraf")],
            ),
            dom.element("span", [a.class("card-fav-btn")], [text("♡")]),
          ]),
          dom.element("div", [a.class("showcase-info-box")], [
            dom.element("div", [a.class("showcase-top-row")], [
              dom.element(
                "span",
                [a.id("preview-locality"), a.class("card-location")],
                [
                  text("📍 (Konum henüz girilmedi - Adım 2'de belirleyin)"),
                ],
              ),
              dom.element("div", [a.class("showcase-meta-right")], [
                dom.element(
                  "span",
                  [a.id("preview-rating"), a.class("card-rating")],
                  [
                    text("★ 5.0 (Yeni İlan)"),
                  ],
                ),
                dom.element(
                  "span",
                  [
                    a.id("preview-status-pill"),
                    a.class("card-status-pill published"),
                  ],
                  [text("Yayında")],
                ),
              ]),
            ]),
            dom.element(
              "h3",
              [a.id("preview-title"), a.class("showcase-title")],
              [
                text("(İlan başlığı henüz girilmedi - Adım 1'de yazın)"),
              ],
            ),
            dom.element(
              "div",
              [a.id("preview-specs"), a.class("showcase-specs-row")],
              case effective_cat {
                "hotel" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🏨 Oda Tipleri")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("🍽️ Konsept")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("🏖️ Plaj & Havuz")],
                  ),
                ]
                "yacht" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("⚓ Kabin Sayısı")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("👥 Misafir Kapasitesi")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("👨‍✈️ Mürettebat")],
                  ),
                ]
                "tour" | "activity" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("⏱️ Tur Süresi")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("👥 Kontenjan")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("🧭 Rehber")],
                  ),
                ]
                "car" | "transfer" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🚗 Segment")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("🕹️ Vites")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("🛡️ Kasko")],
                  ),
                ]
                "cruise" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🚢 Gemi / Rota")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("🛏️ Kabin")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("🍽️ Tam Pansiyon")],
                  ),
                ]
                "flight" | "bus" | "ferry" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🎫 Sefer / Rota")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("🧳 Bagaj")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("💺 Koltuk")],
                  ),
                ]
                "restaurant" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🍽️ Mutfak")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("🍷 Rezervasyon")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("👥 Masa")],
                  ),
                ]
                "beach" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🏖️ Beach Club")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("⛱️ Şezlong / Loca")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("🍹 Harcama Kredisi")],
                  ),
                ]
                "visa" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🌍 Ülke")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("📋 Evrak Desteği")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("⏱️ 15 İş Günü")],
                  ),
                ]
                "pilgrimage" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🕋 Umre / Hac")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("🏨 5★ Harem Yakını")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("✈️ Uçuş Dahil")],
                  ),
                ]
                "event" | "cinema" -> [
                  dom.element(
                    "span",
                    [a.id("preview-spec-1"), a.class("spec-pill")],
                    [text("🎟️ Bilet / Seans")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-2"), a.class("spec-pill")],
                    [text("📍 Mekân / Salon")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-spec-3"), a.class("spec-pill")],
                    [text("🔞 Yaş Sınırı")],
                  ),
                ]
                _ -> [
                  dom.element(
                    "span",
                    [a.id("preview-guests-badge"), a.class("spec-pill")],
                    [text("👥 Kapasite")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-bedrooms-badge"), a.class("spec-pill")],
                    [text("🛏️ Yatak Odaları")],
                  ),
                  dom.element(
                    "span",
                    [a.id("preview-bathrooms-badge"), a.class("spec-pill")],
                    [text("🛁 Banyolar")],
                  ),
                ]
              },
            ),
            dom.element("div", [a.class("showcase-amenities-wrap")], [
              dom.element("span", [a.class("amenities-label-small")], [
                text("İlana Eklenen Özellikler:"),
              ]),
              dom.element(
                "div",
                [
                  a.id("preview-amenities-icons"),
                  a.class("showcase-amenities-chips"),
                ],
                [
                  dom.element("span", [a.class("amenity-placeholder")], [
                    text(
                      "Henüz özellik seçilmedi (Adım 4'ten donanım ekleyebilirsiniz)",
                    ),
                  ]),
                ],
              ),
            ]),
            dom.element("div", [a.class("showcase-bottom-row")], [
              dom.element("div", [a.class("card-price-wrap")], [
                dom.element(
                  "span",
                  [a.id("preview-price"), a.class("card-price-amount")],
                  [
                    text("₺0"),
                  ],
                ),
                dom.element(
                  "span",
                  [a.id("preview-price-period"), a.class("card-price-period")],
                  [
                    text(case effective_cat {
                      "hotel" -> " / gece / oda"
                      "holiday_home" | "villa" -> " / gece"
                      "yacht" -> " / gün (tekne)"
                      "tour"
                      | "activity"
                      | "flight"
                      | "bus"
                      | "ferry"
                      | "pilgrimage" -> " / kişi"
                      "car" -> " / gün (araç)"
                      "transfer" -> " / transfer"
                      "cruise" -> " / kişi / kabin"
                      "beach" -> " / gün (ünite)"
                      "restaurant" -> " / kişi (ön ödeme)"
                      "visa" -> " / başvuru"
                      "event" | "cinema" -> " / bilet"
                      _ -> " / birim"
                    }),
                  ],
                ),
              ]),
              dom.element("div", [a.class("showcase-action-preview")], [
                dom.element("span", [a.class("preview-hint-pill")], [
                  text("Müşteri Arama & Kart Görünümü"),
                ]),
              ]),
            ]),
          ]),
        ],
      ),
    ],
  )
}

fn wizard_amenity_chip(code: String, _legacy_icon: String, label: String) {
  dom.element(
    "button",
    [
      a.attribute("type", "button"),
      a.class("amenity-toggle-chip"),
      a.attribute("data-amenity", code),
      a.attribute("aria-pressed", "false"),
    ],
    [
      hugeicon(amenity_icon(code), "chip-icon"),
      dom.element("span", [a.class("chip-text")], [text(label)]),
    ],
  )
}

fn amenity_icon(code: String) -> String {
  case code {
    "wifi" -> "wifi-01"
    "parking" -> "parking-area-square"
    "open_pool" | "indoor_pool" -> "swimming"
    "ac" -> "snow"
    "fuel" -> "gas-stove"
    "skipper" -> "user-star-01"
    "tennis_court" -> "tennis-ball"
    "restaurant" | "breakfast" | "meal" -> "restaurant-01"
    "spa" | "sauna" -> "hot-tube"
    "security" | "insurance" -> "shield-01"
    "transfer" -> "car-01"
    _ -> "tick-02"
  }
}

fn wizard_sample_prompt(prompt: String, label: String) {
  dom.element(
    "button",
    [
      a.attribute("type", "button"),
      a.class("ai-quick-chip"),
      a.attribute("data-prompt", prompt),
    ],
    [text(label)],
  )
}

fn hotel_room_type_modal() {
  dom.element(
    "div",
    [
      a.id("room-type-modal"),
      a.class("room-modal-backdrop hidden"),
      a.attribute("role", "dialog"),
      a.attribute("aria-modal", "true"),
      a.attribute("aria-labelledby", "room-modal-title"),
      a.attribute("aria-hidden", "true"),
    ],
    [
      dom.element("div", [a.class("room-modal-dialog glass-glow")], [
        dom.element("div", [a.class("modal-header")], [
          dom.element("div", [a.class("modal-title-wrap")], [
            dom.element("span", [a.class("modal-icon")], [text("🛏️")]),
            dom.element("h3", [a.id("room-modal-title")], [
              text("Yeni Oda Tipi Ekle"),
            ]),
          ]),
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("modal-close-btn"),
              a.id("btn-close-room-modal"),
              a.attribute("aria-label", "Oda tipi penceresini kapat"),
            ],
            [text("✕")],
          ),
        ]),
        dom.element("div", [a.class("modal-body")], [
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [a.class("field-wide")], [
              text("Oda Tipi Adı"),
              dom.element(
                "input",
                [
                  a.id("modal-room-title"),
                  a.attribute(
                    "placeholder",
                    "Örn: Swim-up Havuz Bağlantılı Deluxe Süit",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Oda Büyüklüğü (m²)"),
              dom.element(
                "input",
                [
                  a.id("modal-room-size"),
                  a.type_("number"),
                  a.attribute("placeholder", "38"),
                  a.attribute("value", "38"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Yetişkin Kapasitesi"),
              dom.element(
                "input",
                [
                  a.id("modal-room-adults"),
                  a.type_("number"),
                  a.attribute("min", "1"),
                  a.attribute("value", "2"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Çocuk Kapasitesi"),
              dom.element(
                "input",
                [
                  a.id("modal-room-children"),
                  a.type_("number"),
                  a.attribute("min", "0"),
                  a.attribute("value", "1"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Yatak Konfigürasyonu"),
              dom.element(
                "input",
                [
                  a.id("modal-room-bed"),
                  a.attribute("placeholder", "Örn: 1 King Çift Kişilik"),
                  a.attribute("value", "1 Çift Kişilik King Size"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Manzara Türü"),
              dom.element("select", [a.id("modal-room-view")], [
                dom.element(
                  "option",
                  [a.attribute("value", "Panoramik Deniz")],
                  [text("Panoramik Deniz")],
                ),
                dom.element("option", [a.attribute("value", "Kısmi Deniz")], [
                  text("Kısmi Deniz"),
                ]),
                dom.element(
                  "option",
                  [a.attribute("value", "Havuz Manzaralı")],
                  [text("Havuz Manzaralı")],
                ),
                dom.element("option", [a.attribute("value", "Kara / Bahçe")], [
                  text("Kara / Bahçe"),
                ]),
                dom.element("option", [a.attribute("value", "Dağ / Doğa")], [
                  text("Dağ / Doğa"),
                ]),
              ]),
            ]),
            dom.element("label", [], [
              text("Oteldeki Toplam Adet"),
              dom.element(
                "input",
                [
                  a.id("modal-room-count"),
                  a.type_("number"),
                  a.attribute("min", "1"),
                  a.attribute("value", "20"),
                ],
                [],
              ),
            ]),
          ]),
        ]),
        dom.element("div", [a.class("modal-footer")], [
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("btn-modal-cancel"),
              a.id("btn-cancel-room-modal"),
            ],
            [text("Vazgeç")],
          ),
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("btn-modal-save"),
              a.id("btn-save-room-modal"),
            ],
            [text("✓ Bu Oda Tipini Ekle")],
          ),
        ]),
      ]),
    ],
  )
}

fn hotel_room_type_card(
  id: String,
  title: String,
  size_m2: String,
  adults: String,
  children: String,
  bed: String,
  view_type: String,
  count: String,
) {
  dom.element(
    "div",
    [a.class("room-type-card"), a.attribute("data-room-id", id)],
    [
      dom.element("div", [a.class("room-type-header")], [
        dom.element("div", [a.class("room-type-title-row")], [
          dom.element("span", [a.class("room-type-icon")], [text("🛏️")]),
          dom.element("strong", [a.class("room-type-name")], [text(title)]),
        ]),
        dom.element("span", [a.class("room-type-count-badge")], [
          text(count <> " Oda"),
        ]),
      ]),
      dom.element("div", [a.class("room-type-specs")], [
        dom.element("span", [a.class("room-spec-pill")], [
          text("📐 " <> size_m2 <> " m²"),
        ]),
        dom.element("span", [a.class("room-spec-pill")], [
          text("👥 " <> adults <> " Yetişkin + " <> children <> " Çocuk"),
        ]),
        dom.element("span", [a.class("room-spec-pill")], [text("🛌 " <> bed)]),
        dom.element("span", [a.class("room-spec-pill")], [
          text("🌅 " <> view_type),
        ]),
      ]),
    ],
  )
}

fn category_general_step3(cat: String) {
  let profile = case cat {
    "flight" -> #(
      "Uçuş Sefer & Biletleme Bilgileri",
      "Havayolu firması, kalkış-varış havalimanı, bilet sınıfı ve bagaj kurallarını tanımlayın.",
      [
        #("Havayolu / Taşıyıcı", "airline_or_provider", "Türk Hava Yolları"),
        #("Kalkış Havalimanı (Şehir)", "route_from", "IST (İstanbul)"),
        #("Varış Havalimanı (Şehir)", "route_to", "AYT (Antalya)"),
        #("Uçuş Sınıfı (Fare Class)", "fare_class", "Ekonomi / Business"),
        #(
          "Bagaj Hakkı Politikası",
          "baggage_policy",
          "23 kg kayıtlı + 8 kg kabin",
        ),
        #(
          "Bilet Kuralları & İade",
          "ticket_rules",
          "Değiştirilebilir / 24 saat kala kesintisiz iade",
        ),
      ],
    )
    "cruise" -> #(
      "Kruvaziyer Gemi, Rota & Kabin Bilgileri",
      "Gemi adı, kalkış limanı, seyir rotası, kabin tipleri ve konsepti belirleyin.",
      [
        #(
          "Gemi / Kruvaziyer Şirketi",
          "ship_or_provider",
          "MSC Cruises / Celestyal",
        ),
        #(
          "Seyir Rotası & Limanlar",
          "route",
          "Kuşadası → Mikonos → Santorini → Rodos",
        ),
        #("Kalkış Limanı", "departure_port", "Kuşadası Ege Port"),
        #("Kabin Tipleri", "cabin_types", "İç Kabin, Dış Kabin, Balkonlu, Süit"),
        #("Seyir Süresi", "duration", "7 Gece 8 Gün"),
        #(
          "Pansiyon / Konsept",
          "board_type",
          "Tam Pansiyon Plus / Her Şey Dahil",
        ),
      ],
    )
    "ferry" -> #(
      "Feribot Sefer & Liman Bilgileri",
      "Feribot rotası, limanlar, sefer saatleri, araç kabulü ve bilet kurallarını girin.",
      [
        #(
          "Feribot İşletmecisi / Operatör",
          "operator",
          "Bodrum Express Lines / İDO",
        ),
        #("Kalkış Limanı", "route_from", "Bodrum Kale Limanı"),
        #("Varış Limanı", "route_to", "Kos (İstanköy) Limanı"),
        #("Sefer Tarifesi / Saatleri", "schedule", "Her Gün 09:30 & 17:30"),
        #(
          "Araç Kabulü & Sınırlamalar",
          "vehicle_allowed",
          "Yolcu + Otomobil + Motosiklet",
        ),
        #(
          "Bilet Kuralları & Pasaport Şartı",
          "ticket_rules",
          "Kapıda Vize / Min. 90 Gün Pasaport Geçerliliği",
        ),
      ],
    )
    "event" -> #(
      "Etkinlik Tarih, Mekân & Bilet Bilgileri",
      "Konser, festival veya gösteri için etkinlik türü, mekân, tarih-saat ve bilet kategorilerini tanımlayın.",
      [
        #("Etkinlik Türü", "event_type", "Konser / Festival / Tiyatro"),
        #("Mekân & Sahne", "venue", "Antalya Açıkhava Sahnesi"),
        #("Başlangıç Tarih & Saati", "start_datetime", "2026-07-15 21:00"),
        #("Bitiş Tarih & Saati", "end_datetime", "2026-07-15 23:30"),
        #(
          "Bilet / Kategori Tipi",
          "ticket_type",
          "VIP Protokol / Sahne Önü / Tribün",
        ),
        #("Yaş Sınırı", "age_limit", "18+ / Aileye Uygun"),
      ],
    )
    "restaurant" -> #(
      "Restoran Masa, Menü & Servis Bilgileri",
      "Mutfak konsepti, mekân bölümü, masa kapasitesi, servis saatleri ve rezervasyon koşullarını belirleyin.",
      [
        #(
          "Mutfak Konsepti & Türü",
          "cuisine_type",
          "Akdeniz & Ege Deniz Ürünleri",
        ),
        #(
          "Restoran Mekânı / Alan",
          "venue",
          "Deniz Manzaralı Teras / Ana Salon",
        ),
        #(
          "Rezervasyon Türü",
          "reservation_type",
          "Ön Ödemeli Masaya Rezervasyon / Fiks Menülü",
        ),
        #("Toplam Masa / Kişi Kapasitesi", "capacity", "30 Masa / 120 Kişi"),
        #(
          "Menü Seçenekleri",
          "menu_options",
          "Tadım Menüsü, Vegan/Vejetaryen, Çocuk Menüsü",
        ),
        #(
          "Servis & Mutfak Saatleri",
          "service_hours",
          "Öğle 12:00 – 15:00 / Akşam 18:30 – 23:30",
        ),
      ],
    )
    "bus" -> #(
      "Otobüs Sefer, Koltuk & Güzergâh Bilgileri",
      "Otobüs firması, güzergâh, kalkış-varış terminalleri, koltuk düzeni ve bagaj kurallarını tanımlayın.",
      [
        #("Otobüs Firması", "operator", "NEXUS Express / Kamil Koç"),
        #("Kalkış Şehri & Otogarı", "route_from", "İstanbul (Esenler Otogarı)"),
        #("Varış Şehri & Otogarı", "route_to", "Antalya Şehirlerarası Otogarı"),
        #("Koltuk Düzeni & Tipi", "seat_type", "2+1 Rahat Hat Koltuk"),
        #("Bagaj Hakkı", "baggage_policy", "30 kg bagaj hakkı"),
        #(
          "Bilet Kuralları & İptal",
          "ticket_rules",
          "Kalkışa 2 saat kalaya kadar kesintisiz iade/açığa alma",
        ),
      ],
    )
    "beach" -> #(
      "Plaj, Şezlong & Loca Hizmet Bilgileri",
      "Plaj adı, giriş türü, şezlong/loca tipleri, kapasite ve yeme-içme politikasını tanımlayın.",
      [
        #("Plaj / Beach Club Adı", "beach_name", "Lara Private Beach & Club"),
        #(
          "Giriş Türü",
          "access_type",
          "Giriş Ücretli / Özel Üyelik / Harcama Limitli",
        ),
        #(
          "Ünite / Şezlong Tipi",
          "seat_type",
          "Ön Sıra Şezlong / VIP Loca / Cabana",
        ),
        #("Toplam Ünite Kapasitesi", "capacity", "120 Şezlong, 12 VIP Loca"),
        #(
          "Yeme - İçme Politikası",
          "food_beverage_policy",
          "Dışarıdan yiyecek getirilmez, restoranda asgari harcama limiti",
        ),
        #("Kullanım Saat Aralığı", "time_slot", "08:30 – 19:00"),
      ],
    )
    "visa" -> #(
      "Vize Danışmanlığı & Başvuru Koşulları",
      "Hedef ülke, vize türü, ortalama işlem süresi, gerekli evraklar ve randevu koşullarını açıklayın.",
      [
        #("Hedef Ülke", "destination_country", "Yunanistan / Schengen"),
        #("Vize Türü", "visa_type", "Turistik C Tipi Vize"),
        #("Ortalama İşlem Süresi", "processing_time", "15 iş günü"),
        #(
          "Zorunlu Başvuru Evrakları",
          "required_documents",
          "Pasaport (min. 6 ay geçerli), SGK dökümü, banka hesap dökümü",
        ),
        #(
          "Konsolosluk Randevusu Gerekli mi?",
          "appointment_required",
          "Evet (Parmak izi randevusu dahil)",
        ),
      ],
    )
    "pilgrimage" -> #(
      "Hac / Umre Programı & Hizmet Detayları",
      "Organizasyon türü, kalkış şehri, program süresi, otel sınıfı ve dahil hizmetleri tanımlayın.",
      [
        #("Organizasyon Türü", "package_type", "Umre Turu / Hac Organizasyonu"),
        #(
          "Kalkış Şehri / Havalimanı",
          "departure_city",
          "İstanbul (IST) / Ankara (ESB)",
        ),
        #("Program Süresi", "duration", "14 Gün (7 Gün Mekke + 7 Gün Medine)"),
        #(
          "Otel Sınıfı & Konum",
          "hotel_class",
          "5 Yıldızlı Lüks (Harem'e Yürüme Mesafesi)",
        ),
        #(
          "Vize Hizmeti Dahil mi?",
          "visa_included",
          "Evet, e-vize ve grup vizesi dahil",
        ),
        #(
          "Dini Rehberlik & Ziyaretler",
          "guidance_included",
          "Deneyimli din görevlisi ve Mekke/Medine ziyaretleri dahil",
        ),
      ],
    )
    "cinema" -> #(
      "Sinema Seans, Salon & Gösterim Bilgileri",
      "Sinema salonu, film adı, seans saatleri, koltuk düzeni ve bilet kurallarını tanımlayın.",
      [
        #(
          "Sinema / Salon Adı",
          "venue",
          "Cinemaximum Mall of Antalya - Salon 4 (IMAX)",
        ),
        #("Film / Gösterim Adı", "movie_or_program", "Gladiator II"),
        #("Seans Saatleri", "session_time", "13:30, 16:45, 20:00"),
        #(
          "Koltuk Tipi & Salon Düzeni",
          "seat_type",
          "Premium VIP Recliner Koltuk",
        ),
        #(
          "Bilet Kuralları & İndirimler",
          "ticket_rules",
          "Öğrenci & Tam Bilet, seansa 30 dk kalaya kadar iade",
        ),
      ],
    )
    _ -> #(
      "Hizmet Kapasitesi & Operasyon Bilgileri",
      "Bu ürünün kapasitesini, çalışma saatlerini, teslim noktasını ve operasyon koşullarını tanımlayın.",
      [
        #("Hizmet Kapasitesi", "capacity", "Örn: 20 kişi"),
        #("Çalışma / Hizmet Saatleri", "service_hours", "09:00 – 18:00"),
        #("Teslim / Buluşma Noktası", "meeting_point", "Örn: Merkez ofis"),
        #(
          "Önemli Operasyon Notu",
          "operation_note",
          "Önceden rezervasyon gereklidir",
        ),
      ],
    )
  }
  dom.element(
    "div",
    [
      a.id("sec-3"),
      a.class("wizard-step-panel"),
      a.attribute("data-step-content", "3"),
    ],
    [
      dom.element("div", [a.class("step-heading")], [
        dom.element("span", [a.class("step-badge")], [text("Adım 3 / 7")]),
        dom.element("h3", [], [text(profile.0)]),
        dom.element("p", [a.class("muted")], [text(profile.1)]),
      ]),
      dom.element(
        "div",
        [a.class("form-grid-2")],
        list.map(profile.2, fn(field) {
          dom.element("label", [], [
            text(field.0),
            dom.element(
              "input",
              [a.name(field.1), a.attribute("placeholder", field.2)],
              [],
            ),
          ])
        }),
      ),
      step_footer_nav("2", "4", "Sonraki Adım: Olanaklar & Hizmetler"),
    ],
  )
}

fn category_code_prefix_and_hint(cat: String) -> #(String, String) {
  case cat {
    "hotel" -> #("HTL-BOD-01", "Otel / Tesis Kodu")
    "holiday_home" -> #("VIL-0001", "Tatil Evi Kodu")
    "yacht" -> #("YAT-0001", "Yat / Tekne Kodu")
    "tour" -> #("TUR-0001", "Tur Hizmet Kodu")
    "activity" -> #("ACT-0001", "Aktivite Kodu")
    "car" -> #("CAR-0001", "Araç Filo Kodu")
    "transfer" -> #("TRF-0001", "Transfer Kodu")
    "flight" -> #("FLT-0001", "Uçuş Kodu")
    "cruise" -> #("CRU-0001", "Kruvaziyer Kodu")
    "ferry" -> #("FRY-0001", "Feribot Kodu")
    "bus" -> #("BUS-0001", "Otobüs Sefer Kodu")
    "beach" -> #("BCH-0001", "Plaj / Loca Kodu")
    "restaurant" -> #("RST-0001", "Restoran Kodu")
    "visa" -> #("VIS-0001", "Vize Hizmet Kodu")
    "pilgrimage" -> #("PLG-0001", "Hac/Umre Program Kodu")
    "event" -> #("EVT-0001", "Etkinlik Kodu")
    "cinema" -> #("CIN-0001", "Sinema Seans Kodu")
    _ -> #("SRV-0001", "Hizmet / Ürün Kodu")
  }
}

fn category_title_placeholder(cat: String) -> String {
  case cat {
    "hotel" -> "Örn: Bodrum Luxury Resort & Spa (Ultra Her Şey Dahil)"
    "holiday_home" ->
      "Örn: Bodrum Yalıkavak Panoramik Deniz Manzaralı Lüks Balayı Villası"
    "yacht" -> "Örn: Göcek Koylarında 24 Metre Lüks Ahşap Gulet (Mürettebatlı)"
    "tour" -> "Örn: Kapadokya Gün Doğumu Balon & Vadi Turu (Rehberli)"
    "activity" -> "Örn: Fethiye Ölüdeniz Babadağ Tandem Yamaç Paraşütü"
    "car" -> "Örn: 2026 Mercedes-Benz Vito Tourer VIP Minivan (Otomatik)"
    "transfer" ->
      "Örn: Milas-Bodrum Havalimanı → Yalıkavak VIP Havalimanı Transferi"
    "flight" ->
      "Örn: Türk Hava Yolları İstanbul (IST) → Antalya (AYT) Direkt Uçuş"
    "cruise" ->
      "Örn: 7 Gece Ege & Adriyatik Kruvaziyer Gemi Turu (Kuşadası Çıkışlı)"
    "ferry" -> "Örn: Bodrum Kale Limanı → Kos (İstanköy) Hızlı Katamaran Seferi"
    "bus" -> "Örn: İstanbul (Esenler) → Antalya 2+1 Rahat Hat Gece Ekspresi"
    "beach" -> "Örn: Lara Beach Club Ön Sıra VIP Loca & Şezlong Paketi"
    "restaurant" -> "Örn: Sunset Grill & Seafood Alaçatı - Akdeniz Tadım Menüsü"
    "visa" ->
      "Örn: Yunanistan & Schengen Turistik Vize Danışmanlık ve Başvuru Paketi"
    "pilgrimage" ->
      "Örn: 14 Günlük 5 Yıldızlı Lüks Umre Programı (Harem Yürüme Mesafesi)"
    "event" ->
      "Örn: Antalya Açıkhava Yaz Konserleri: Fazıl Say & Serenad Bağcan"
    "cinema" ->
      "Örn: IMAX Özel Gösterim: Gladiator II (Mall of Antalya Salon 4)"
    _ -> "Örn: Hizmet / Ürün Başlığı"
  }
}

fn step1_category_classification(cat: String) {
  case cat {
    "hotel" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Otel Sınıfı & Yıldız"),
          dom.element(
            "select",
            [a.name("hotel_stars"), a.id("input-hotel-stars")],
            [
              dom.element("option", [a.attribute("value", "5_star")], [
                text("5 Yıldızlı Lüks Resort & Spa"),
              ]),
              dom.element("option", [a.attribute("value", "4_star")], [
                text("4 Yıldızlı Otel"),
              ]),
              dom.element("option", [a.attribute("value", "boutique")], [
                text("Özel Kategori / Lüks Butik Otel"),
              ]),
              dom.element("option", [a.attribute("value", "thermal")], [
                text("Termal & Sağlık Oteli"),
              ]),
              dom.element("option", [a.attribute("value", "city")], [
                text("Şehir & İş Oteli"),
              ]),
              dom.element("option", [a.attribute("value", "apart")], [
                text("Apart Otel"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Pansiyon / Konsept Türü"),
          dom.element(
            "select",
            [a.name("board_type"), a.id("input-board-type")],
            [
              dom.element("option", [a.attribute("value", "uai")], [
                text("Ultra Her Şey Dahil (UAI)"),
              ]),
              dom.element("option", [a.attribute("value", "ai")], [
                text("Her Şey Dahil (AI)"),
              ]),
              dom.element("option", [a.attribute("value", "fb_plus")], [
                text("Tam Pansiyon Plus"),
              ]),
              dom.element("option", [a.attribute("value", "hb")], [
                text("Yarım Pansiyon (HB)"),
              ]),
              dom.element("option", [a.attribute("value", "bb")], [
                text("Oda Kahvaltı (BB)"),
              ]),
              dom.element("option", [a.attribute("value", "ro")], [
                text("Sadece Oda (Room Only)"),
              ]),
            ],
          ),
        ]),
      ])
    "holiday_home" ->
      dom.element("label", [a.class("field-wide")], [
        text("Tatil Evi Tipi"),
        dom.element(
          "select",
          [
            a.name("property_type"),
            a.id("input-property-type"),
            a.attribute("data-managed-filter-category", "holiday_home"),
            a.attribute("data-managed-filter-key", "property_type"),
          ],
          [
            dom.element("option", [a.attribute("value", "Villa")], [
              text("Villa"),
            ]),
            dom.element("option", [a.attribute("value", "Apart")], [
              text("Apart"),
            ]),
            dom.element("option", [a.attribute("value", "Bungalov")], [
              text("Bungalov"),
            ]),
            dom.element("option", [a.attribute("value", "Daire")], [
              text("Daire"),
            ]),
            dom.element("option", [a.attribute("value", "Residence")], [
              text("Residence"),
            ]),
          ],
        ),
      ])
    "yacht" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Yat / Tekne Türü"),
          dom.element(
            "select",
            [
              a.name("yacht_type"),
              a.id("input-yacht-type"),
              a.attribute("data-managed-filter-category", "yacht"),
              a.attribute("data-managed-filter-key", "yacht_type"),
            ],
            [
              dom.element("option", [a.attribute("value", "Gulet")], [
                text("Gulet (Geleneksel Ahşap Yat)"),
              ]),
              dom.element("option", [a.attribute("value", "Motoryat")], [
                text("Motoryat (VIP & Hızlı)"),
              ]),
              dom.element("option", [a.attribute("value", "Yelkenli")], [
                text("Yelkenli (Monohull)"),
              ]),
              dom.element("option", [a.attribute("value", "Katamaran")], [
                text("Katamaran (Çift Gövde)"),
              ]),
              dom.element("option", [a.attribute("value", "Tekne")], [
                text("Tekne / Sürat Motoru"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Kiralama Tipi"),
          dom.element(
            "select",
            [a.name("charter_type"), a.id("input-charter-type")],
            [
              dom.element("option", [a.attribute("value", "private")], [
                text("Özel Yat Kiralama (Mürettebatlı)"),
              ]),
              dom.element("option", [a.attribute("value", "cabin")], [
                text("Kabin Kiralama (Mavi Tur)"),
              ]),
              dom.element("option", [a.attribute("value", "bareboat")], [
                text("Kaptansız Kiralama (Bareboat)"),
              ]),
            ],
          ),
        ]),
      ])
    "car" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Araç Segmenti & Kasa Tipi"),
          dom.element(
            "select",
            [a.name("vehicle_type"), a.id("input-vehicle-type")],
            [
              dom.element("option", [a.attribute("value", "suv")], [
                text("Lüks SUV & 4x4"),
              ]),
              dom.element("option", [a.attribute("value", "vip_minivan")], [
                text("VIP Mercedes-Benz Vito / Minivan"),
              ]),
              dom.element("option", [a.attribute("value", "sedan")], [
                text("Sedan (Ekonomik / Orta)"),
              ]),
              dom.element("option", [a.attribute("value", "luxury_sedan")], [
                text("Premium Lüks Sedan"),
              ]),
              dom.element("option", [a.attribute("value", "cabrio")], [
                text("Cabrio / Spor Üstü Açık"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Şanzıman / Vites"),
          dom.element("select", [a.name("transmission"), a.id("input-trans")], [
            dom.element("option", [a.attribute("value", "automatic")], [
              text("Tam Otomatik Vites"),
            ]),
            dom.element("option", [a.attribute("value", "manual")], [
              text("Manuel (Düz Vites)"),
            ]),
          ]),
        ]),
      ])
    "tour" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Tur Tipi"),
          dom.element(
            "select",
            [a.name("tour_format"), a.id("input-tour-format")],
            [
              dom.element("option", [a.attribute("value", "group")], [
                text("Grup Turu"),
              ]),
              dom.element("option", [a.attribute("value", "private")], [
                text("Kişiye Özel VIP Tur"),
              ]),
            ],
          ),
        ]),
      ])
    "activity" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Aktivite Türü"),
          dom.element(
            "select",
            [a.name("activity_type"), a.id("input-act-type")],
            [
              dom.element("option", [a.attribute("value", "paragliding")], [
                text("Yamaç Paraşütü (Tandem)"),
              ]),
              dom.element("option", [a.attribute("value", "diving")], [
                text("Tüplü Dalış (Scuba Diving)"),
              ]),
              dom.element("option", [a.attribute("value", "rafting")], [
                text("Rafting & Kanyon Geçişi"),
              ]),
              dom.element("option", [a.attribute("value", "safari")], [
                text("Jeep / ATV Safari"),
              ]),
              dom.element("option", [a.attribute("value", "watersports")], [
                text("Su Sporları & Jet Ski"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Zorluk Seviyesi"),
          dom.element("select", [a.name("difficulty"), a.id("input-diff")], [
            dom.element("option", [a.attribute("value", "easy")], [
              text("Kolay / Her Yaşa Uygun"),
            ]),
            dom.element("option", [a.attribute("value", "moderate")], [
              text("Orta Seviye"),
            ]),
            dom.element("option", [a.attribute("value", "hard")], [
              text("İleri Seviye / Adrenalin"),
            ]),
          ]),
        ]),
      ])
    "flight" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Kabin / Uçuş Sınıfı"),
          dom.element(
            "select",
            [a.name("fare_class"), a.id("input-fare-class")],
            [
              dom.element("option", [a.attribute("value", "economy")], [
                text("Ekonomi Sınıfı (Economy)"),
              ]),
              dom.element("option", [a.attribute("value", "premium_economy")], [
                text("Premium Ekonomi"),
              ]),
              dom.element("option", [a.attribute("value", "business")], [
                text("Business Class"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Uçuş Tipi"),
          dom.element(
            "select",
            [a.name("flight_type"), a.id("input-flight-type")],
            [
              dom.element("option", [a.attribute("value", "direct")], [
                text("Direkt Uçuş"),
              ]),
              dom.element("option", [a.attribute("value", "charter")], [
                text("Charter Sefer"),
              ]),
              dom.element("option", [a.attribute("value", "connecting")], [
                text("Aktarmalı Sefer"),
              ]),
            ],
          ),
        ]),
      ])
    "cruise" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Kruvaziyer Seyir Bölgesi"),
          dom.element(
            "select",
            [a.name("cruise_region"), a.id("input-cruise-region")],
            [
              dom.element("option", [a.attribute("value", "aegean")], [
                text("Ege & Yunan Adaları"),
              ]),
              dom.element("option", [a.attribute("value", "mediterranean")], [
                text("Doğu & Batı Akdeniz"),
              ]),
              dom.element("option", [a.attribute("value", "fjords")], [
                text("Norveç Fiyortları & Kuzey"),
              ]),
              dom.element("option", [a.attribute("value", "caribbean")], [
                text("Karayipler"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Pansiyon / Konsept"),
          dom.element(
            "select",
            [a.name("board_type"), a.id("input-cruise-board")],
            [
              dom.element("option", [a.attribute("value", "all_inclusive")], [
                text("Her Şey Dahil"),
              ]),
              dom.element("option", [a.attribute("value", "full_board")], [
                text("Tam Pansiyon Plus"),
              ]),
            ],
          ),
        ]),
      ])
    "transfer" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Transfer Türü"),
          dom.element(
            "select",
            [a.name("transfer_type"), a.id("input-transfer-type")],
            [
              dom.element("option", [a.attribute("value", "airport_vip")], [
                text("Havalimanı VIP Transfer"),
              ]),
              dom.element("option", [a.attribute("value", "intercity")], [
                text("Şehirlerarası Özel Transfer"),
              ]),
              dom.element("option", [a.attribute("value", "hourly_driver")], [
                text("Şoförlü Saatlik / Günlük Tahsis"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Hizmet Aracı"),
          dom.element(
            "select",
            [a.name("vehicle_type"), a.id("input-trf-veh")],
            [
              dom.element("option", [a.attribute("value", "vip_vito")], [
                text("Mercedes-Benz Vito VIP"),
              ]),
              dom.element("option", [a.attribute("value", "sedan_e")], [
                text("Mercedes E-Class VIP Sedan"),
              ]),
              dom.element("option", [a.attribute("value", "sprinter")], [
                text("Mercedes Sprinter VIP (10-16 Kişi)"),
              ]),
            ],
          ),
        ]),
      ])
    "beach" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Plaj / Tesis Türü"),
          dom.element(
            "select",
            [a.name("access_type"), a.id("input-beach-type")],
            [
              dom.element("option", [a.attribute("value", "beach_club")], [
                text("Premium Beach Club"),
              ]),
              dom.element("option", [a.attribute("value", "hotel_beach")], [
                text("Otel / Resort Plaj Alanı"),
              ]),
              dom.element("option", [a.attribute("value", "public_facility")], [
                text("Belediye / Tesis Plajı"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Rezervasyon Birimi"),
          dom.element(
            "select",
            [a.name("seat_type"), a.id("input-beach-seat")],
            [
              dom.element("option", [a.attribute("value", "sunbed")], [
                text("Şezlong & Şemsiye Seti"),
              ]),
              dom.element("option", [a.attribute("value", "vip_cabana")], [
                text("VIP Loca / Cabana"),
              ]),
              dom.element("option", [a.attribute("value", "front_row")], [
                text("Denize Sıfır Ön Sıra"),
              ]),
            ],
          ),
        ]),
      ])
    "restaurant" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Mutfak Türü & Konsept"),
          dom.element(
            "select",
            [a.name("cuisine_type"), a.id("input-rest-cuisine")],
            [
              dom.element("option", [a.attribute("value", "seafood")], [
                text("Ege & Akdeniz Deniz Ürünleri"),
              ]),
              dom.element("option", [a.attribute("value", "fine_dining")], [
                text("Fine Dining & Modern Mutfak"),
              ]),
              dom.element("option", [a.attribute("value", "steakhouse")], [
                text("Steakhouse & Ocakbaşı"),
              ]),
              dom.element("option", [a.attribute("value", "international")], [
                text("Dünya Mutfağı"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Rezervasyon Tipi"),
          dom.element(
            "select",
            [a.name("reservation_type"), a.id("input-rest-res-type")],
            [
              dom.element("option", [a.attribute("value", "standard")], [
                text("Masaya Rezervasyon"),
              ]),
              dom.element("option", [a.attribute("value", "tasting_menu")], [
                text("Fiks Tadım Menülü Rezervasyon"),
              ]),
              dom.element("option", [a.attribute("value", "special_event")], [
                text("Kutlama / Özel Grup Masası"),
              ]),
            ],
          ),
        ]),
      ])
    "pilgrimage" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Organizasyon Türü"),
          dom.element(
            "select",
            [a.name("package_type"), a.id("input-plg-type")],
            [
              dom.element("option", [a.attribute("value", "umrah_vip")], [
                text("5 Yıldızlı Lüks Umre Programı"),
              ]),
              dom.element("option", [a.attribute("value", "umrah_standard")], [
                text("Standart Umre Programı"),
              ]),
              dom.element("option", [a.attribute("value", "hajj")], [
                text("Hac Organizasyonu"),
              ]),
              dom.element("option", [a.attribute("value", "quds")], [
                text("Kudüs Ziyareti & Kültür Turu"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Otel Harem Mesafesi"),
          dom.element(
            "select",
            [a.name("hotel_class"), a.id("input-plg-hotel")],
            [
              dom.element("option", [a.attribute("value", "walking_distance")], [
                text("Harem'e Sıfır / Yürüme Mesafesi"),
              ]),
              dom.element("option", [a.attribute("value", "shuttle")], [
                text("24 Saat Ring Servisli Otel"),
              ]),
            ],
          ),
        ]),
      ])
    "visa" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Vize Türü"),
          dom.element("select", [a.name("visa_type"), a.id("input-visa-type")], [
            dom.element("option", [a.attribute("value", "tourist")], [
              text("Turistik Vize (C Tipi)"),
            ]),
            dom.element("option", [a.attribute("value", "business")], [
              text("Ticari / Fuar Vizesi"),
            ]),
            dom.element("option", [a.attribute("value", "student")], [
              text("Eğitim / Öğrenci Vizesi"),
            ]),
            dom.element("option", [a.attribute("value", "family")], [
              text("Aile / Ziyaret Vizesi"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Hizmet Paketi Kapsamı"),
          dom.element(
            "select",
            [a.name("appointment_required"), a.id("input-visa-pkg")],
            [
              dom.element("option", [a.attribute("value", "full_service")], [
                text("Tam Danışmanlık (Randevu + Dosya + Karşılama)"),
              ]),
              dom.element("option", [a.attribute("value", "file_only")], [
                text("Yalnızca Dosya & Form Hazırlığı"),
              ]),
            ],
          ),
        ]),
      ])
    "ferry" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Feribot Hat Tipi"),
          dom.element(
            "select",
            [a.name("ferry_type"), a.id("input-ferry-type")],
            [
              dom.element("option", [a.attribute("value", "catamaran")], [
                text("Hızlı Deniz Otobüsü / Katamaran"),
              ]),
              dom.element("option", [a.attribute("value", "car_ferry")], [
                text("Arabalı Vapur (Feribot)"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Araç Kabul Durumu"),
          dom.element(
            "select",
            [a.name("vehicle_allowed"), a.id("input-ferry-veh")],
            [
              dom.element("option", [a.attribute("value", "passengers_only")], [
                text("Sadece Yaya Yolcu"),
              ]),
              dom.element("option", [a.attribute("value", "cars_allowed")], [
                text("Yolcu + Araç Kabulü Var"),
              ]),
            ],
          ),
        ]),
      ])
    "bus" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Otobüs Koltuk Düzeni"),
          dom.element("select", [a.name("seat_type"), a.id("input-bus-seat")], [
            dom.element("option", [a.attribute("value", "2_plus_1")], [
              text("2+1 Rahat Hat (Geniş Koltuk)"),
            ]),
            dom.element("option", [a.attribute("value", "2_plus_2")], [
              text("2+2 Standart Hat"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Sefer Türü"),
          dom.element(
            "select",
            [a.name("bus_service_type"), a.id("input-bus-srv")],
            [
              dom.element("option", [a.attribute("value", "night_express")], [
                text("Gece Ekspres Seferi"),
              ]),
              dom.element("option", [a.attribute("value", "day_express")], [
                text("Gündüz Seferi"),
              ]),
            ],
          ),
        ]),
      ])
    "event" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Etkinlik Türü"),
          dom.element(
            "select",
            [a.name("event_type"), a.id("input-event-genre")],
            [
              dom.element("option", [a.attribute("value", "concert")], [
                text("Konser & Canlı Müzik"),
              ]),
              dom.element("option", [a.attribute("value", "festival")], [
                text("Açık Hava Festivali"),
              ]),
              dom.element("option", [a.attribute("value", "theatre")], [
                text("Tiyatro & Müzikal"),
              ]),
              dom.element("option", [a.attribute("value", "standup")], [
                text("Stand-up Gösterisi"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Bilet Kategorisi"),
          dom.element(
            "select",
            [a.name("ticket_type"), a.id("input-evt-ticket")],
            [
              dom.element("option", [a.attribute("value", "vip")], [
                text("VIP Protokol & Sahne Önü"),
              ]),
              dom.element("option", [a.attribute("value", "numbered")], [
                text("Numaralı Oturmalı Koltuk"),
              ]),
              dom.element("option", [a.attribute("value", "general")], [
                text("Genel Giriş / Ayakta"),
              ]),
            ],
          ),
        ]),
      ])
    "cinema" ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Salon Teknolojisi"),
          dom.element(
            "select",
            [a.name("venue_format"), a.id("input-cin-format")],
            [
              dom.element("option", [a.attribute("value", "imax")], [
                text("IMAX Lazer"),
              ]),
              dom.element("option", [a.attribute("value", "4dx")], [
                text("4DX Hareketli Koltuk"),
              ]),
              dom.element("option", [a.attribute("value", "vip_gold")], [
                text("VIP Gold Class / Recliner"),
              ]),
              dom.element("option", [a.attribute("value", "standard_2d")], [
                text("Standart Dijital 2D / 3D"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Koltuk Tipi"),
          dom.element("select", [a.name("seat_type"), a.id("input-cin-seat")], [
            dom.element("option", [a.attribute("value", "vip_recliner")], [
              text("VIP Recliner Yatar Koltuk"),
            ]),
            dom.element("option", [a.attribute("value", "double_seat")], [
              text("Çift Kişilik Koltuk (Love Seat)"),
            ]),
            dom.element("option", [a.attribute("value", "standard")], [
              text("Standart Salon Koltuğu"),
            ]),
          ]),
        ]),
      ])
    _ ->
      dom.element("div", [a.class("form-grid-2")], [
        dom.element("label", [], [
          text("Hizmet Paketi"),
          dom.element(
            "select",
            [a.name("service_package"), a.id("input-srv-pkg")],
            [
              dom.element("option", [a.attribute("value", "standard")], [
                text("Standart Hizmet Paketi"),
              ]),
              dom.element("option", [a.attribute("value", "premium")], [
                text("Premium / VIP Hizmet Paketi"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Hizmet Türü"),
          dom.element(
            "input",
            [
              a.name("service_kind"),
              a.attribute("placeholder", "Örn: Bireysel / Kurumsal"),
            ],
            [],
          ),
        ]),
      ])
  }
}

fn step_tab_label(step: Int, cat: String) -> String {
  case step {
    3 ->
      case cat {
        "hotel" -> "Oda Tipleri & Kapasite"
        "yacht" -> "Kabin & Mürettebat"
        "tour" | "activity" -> "Program & Rehber"
        "flight" | "ferry" | "bus" -> "Sefer & Koltuk/Bagaj"
        "car" | "transfer" -> "Araç Segmenti & Şoför"
        "cruise" -> "Kabin & Güverte"
        "restaurant" -> "Masa & Menü/Mutfak"
        "beach" -> "Şezlong & Loca Düzeni"
        "cinema" | "event" -> "Salon & Bilet Kategorisi"
        "visa" -> "Başvuru & Evrak Şartları"
        "pilgrimage" -> "Tur Programı & Otel Tipi"
        _ -> "Kapasite & Odalar"
      }
    4 ->
      case cat {
        "hotel" -> "Tesis Olanakları"
        "yacht" -> "Yat Donanımları"
        "tour" | "activity" -> "Tur Hizmetleri & Dahiller"
        "flight" | "ferry" | "bus" -> "Seyahat Hizmetleri"
        "car" | "transfer" -> "Araç Özellikleri & Kasko"
        "cruise" -> "Gemi Olanakları"
        "restaurant" -> "Restoran Olanakları"
        "beach" -> "Plaj Olanakları"
        "cinema" | "event" -> "Etkinlik Özellikleri"
        "visa" -> "Vize Danışmanlık Hizmetleri"
        "pilgrimage" -> "Hac/Umre Hizmetleri"
        _ -> "Donanım ve Olanaklar"
      }
    6 ->
      case cat {
        "hotel" -> "Fiyat & Çocuk Politikası"
        "holiday_home" -> "Fiyat, Takvim & iCal"
        "yacht" -> "Kiralama Ücreti & APA"
        "tour" | "activity" -> "Tur Fiyatı & Katılım"
        "flight" | "ferry" | "bus" -> "Bilet Fiyatı & İade"
        "car" | "transfer" -> "Kiralama & Depozito"
        "cruise" -> "Kruvaziyer & Liman Vergisi"
        "restaurant" -> "Menü/Kuver & Rezervasyon"
        "beach" -> "Şezlong & Harcama Limiti"
        "cinema" | "event" -> "Bilet & Giriş Kuralları"
        "visa" -> "Danışmanlık & Harç Bedelleri"
        "pilgrimage" -> "Paket Fiyatı & Ödeme Planı"
        _ -> "Fiyat & Satış Koşulları"
      }
    _ -> ""
  }
}

fn step6_currency_select() {
  dom.element("select", [a.name("currency"), a.id("input-currency")], [
    dom.element("option", [a.attribute("value", "TRY")], [
      text("TRY (₺ Türk Lirası)"),
    ]),
    dom.element("option", [a.attribute("value", "USD")], [text("USD ($ Dolar)")]),
    dom.element("option", [a.attribute("value", "EUR")], [text("EUR (€ Euro)")]),
    dom.element("option", [a.attribute("value", "GBP")], [
      text("GBP (£ Sterlin)"),
    ]),
    dom.element("option", [a.attribute("value", "CNY")], [
      text("CNY (¥ Çin Yuanı)"),
    ]),
  ])
}

fn step6_price_input(
  label_text: String,
  display_val: String,
  minor_val: String,
) {
  dom.element("label", [], [
    text(label_text),
    dom.element("div", [a.class("currency-input-wrap")], [
      dom.element("span", [a.class("currency-symbol-tag")], [text("₺")]),
      dom.element(
        "input",
        [
          a.id("input-price-display"),
          a.attribute("type", "text"),
          a.attribute("placeholder", display_val),
          a.attribute("value", display_val),
        ],
        [],
      ),
    ]),
    dom.element(
      "input",
      [
        a.name("price_minor"),
        a.id("input-price-minor"),
        a.type_("hidden"),
        a.attribute("value", minor_val),
      ],
      [],
    ),
  ])
}

fn step6_commission_input(default_val: String) {
  dom.element("label", [], [
    text("Acente Komisyonu (%)"),
    dom.element(
      "input",
      [
        a.name("commission_percent"),
        a.id("input-commission-percent"),
        a.attribute("placeholder", default_val),
        a.attribute("value", default_val),
      ],
      [],
    ),
  ])
}

fn step6_cancellation_input(default_val: String) {
  dom.element("label", [a.class("field-wide")], [
    text("İptal & İade Politikası"),
    dom.element(
      "input",
      [
        a.name("cancellation_policy"),
        a.id("input-cancellation"),
        a.attribute("placeholder", default_val),
        a.attribute("value", default_val),
      ],
      [],
    ),
  ])
}

fn step6_panel(
  title: String,
  subtitle: String,
  content: List(dom.Element(msg)),
) {
  dom.element(
    "div",
    [
      a.id("sec-6"),
      a.class("wizard-step-panel"),
      a.attribute("data-step-content", "6"),
    ],
    list.append(
      [
        dom.element("div", [a.class("step-heading")], [
          dom.element("span", [a.class("step-badge")], [text("Adım 6 / 7")]),
          dom.element("h3", [], [text(title)]),
          dom.element("p", [a.class("muted")], [text(subtitle)]),
        ]),
      ],
      list.append(content, [
        step_footer_nav("5", "7", "Sonraki Adım: Açıklama, SEO & Onay"),
      ]),
    ),
  )
}

fn category_pricing_step6(cat: String, is_hotel: Bool) {
  case cat {
    "hotel" ->
      step6_panel(
        "Fiyat, Çocuk Politikası & Giriş/Çıkış",
        "Gecelik oda fiyatı, para birimi, çocuk indirimleri ve check-in kurallarını belirleyin.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input("Gecelik Taban Fiyat", "18.500", "1850000"),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Fiyatlandırma Modeli"),
              dom.element(
                "select",
                [a.name("pricing_model"), a.id("input-pricing-model")],
                [
                  dom.element("option", [a.attribute("value", "per_room")], [
                    text("Oda Başı Gecelik"),
                  ]),
                  dom.element("option", [a.attribute("value", "per_person")], [
                    text("Kişi Başı Gecelik (PP)"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("1. Çocuk Politikası"),
              dom.element(
                "select",
                [a.name("child_policy_1"), a.id("input-child-policy-1")],
                [
                  dom.element("option", [a.attribute("value", "free_0_12")], [
                    text("0-12 Yaş 1. Çocuk Ücretsiz"),
                  ]),
                  dom.element("option", [a.attribute("value", "free_0_6")], [
                    text("0-6 Yaş 1. Çocuk Ücretsiz"),
                  ]),
                  dom.element("option", [a.attribute("value", "free_0_2")], [
                    text("0-2 Yaş Bebek Ücretsiz"),
                  ]),
                  dom.element("option", [a.attribute("value", "adult_only")], [
                    text("+16 Yetişkin Oteli (Çocuksuz)"),
                  ]),
                ],
              ),
            ]),
            dom.element("label", [], [
              text("2. Çocuk İndirimi"),
              dom.element(
                "input",
                [
                  a.name("child_policy_2_discount"),
                  a.id("input-child-discount"),
                  a.attribute("placeholder", "Örn: %50 İndirimli"),
                  a.attribute("value", "%50 İndirimli"),
                ],
                [],
              ),
            ]),
            step6_commission_input("15.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Giriş Saati (Check-in)"),
              dom.element(
                "input",
                [
                  a.name("check_in_time"),
                  a.id("input-check-in"),
                  a.attribute("value", "14:00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Çıkış Saati (Check-out)"),
              dom.element(
                "input",
                [
                  a.name("check_out_time"),
                  a.id("input-check-out"),
                  a.attribute("value", "12:00"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Giriş tarihinden 48 saat öncesine kadar %100 kesintisiz iade hakkı.",
          ),
        ],
      )

    "holiday_home" ->
      step6_panel(
        "Fiyat, Satış Koşulları & Takvim",
        "Gecelik birim fiyatı, temizlik ücretini ve iCal iki yönlü takvim bağlantısını ayarlayın.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input("Gecelik Taban Fiyat", "25.000", "2500000"),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Temizlik Ücreti (TL)"),
              dom.element(
                "input",
                [
                  a.name("cleaning_fee"),
                  a.id("input-cleaning-fee"),
                  a.type_("number"),
                  a.attribute("placeholder", "2500"),
                  a.attribute("value", "2500"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-4")], [
            dom.element("label", [], [
              text("Hasar Depozitosu (TL)"),
              dom.element(
                "input",
                [
                  a.name("damage_deposit"),
                  a.id("input-damage-deposit"),
                  a.type_("number"),
                  a.attribute("placeholder", "5000"),
                  a.attribute("value", "5000"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Kısa Konaklama Ücreti (TL)"),
              dom.element(
                "input",
                [
                  a.name("short_stay_fee"),
                  a.id("input-short-stay-fee"),
                  a.type_("number"),
                  a.attribute("placeholder", "2000"),
                  a.attribute("value", "2000"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Kısa Konaklama Altı (Gece)"),
              dom.element(
                "input",
                [
                  a.name("short_stay_min_nights"),
                  a.id("input-short-stay-nights"),
                  a.type_("number"),
                  a.attribute("placeholder", "5"),
                  a.attribute("value", "5"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Günlük Havuz Isıtma (TL)"),
              dom.element(
                "input",
                [
                  a.name("pool_heating_fee"),
                  a.id("input-pool-heating-fee"),
                  a.type_("number"),
                  a.attribute("placeholder", "1500"),
                  a.attribute("value", "1500"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Min. Konaklama (Gece)"),
              dom.element(
                "input",
                [
                  a.name("min_stay_days"),
                  a.id("input-min-stay"),
                  a.type_("number"),
                  a.attribute("placeholder", "3"),
                  a.attribute("value", "3"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Ön Ödeme / Depozito (%)"),
              dom.element(
                "input",
                [
                  a.name("deposit_percent"),
                  a.id("input-deposit-percent"),
                  a.attribute("placeholder", "35.00"),
                  a.attribute("value", "35.00"),
                ],
                [],
              ),
            ]),
            step6_commission_input("15.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Harici kanal iCal takvim URL'si"),
              dom.element(
                "input",
                [
                  a.name("ical_url"),
                  a.id("input-ical-url"),
                  a.attribute(
                    "placeholder",
                    "https://tesis.example.com/calendar.ics",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("iCal Tampon (+- Gün)"),
              dom.element(
                "input",
                [
                  a.name("ical_offset_days"),
                  a.id("input-ical-offset"),
                  a.attribute("placeholder", "+1"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Mülk Sahibi / Tedarikçi"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Ahmet Bey / Portföy"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Tedarikçi Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 532 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Giriş tarihinden 14 gün öncesine kadar %100 kesintisiz iade hakkı.",
          ),
        ],
      )

    "yacht" ->
      step6_panel(
        "Yat Kiralama Bedeli, APA & Mürettebat Koşulları",
        "Günlük kiralama taban fiyatı, APA kumanya depozitosu, liman giriş/çıkış ve iptal şartlarını belirleyin.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input("Günlük Kiralama Bedeli", "45.000", "4500000"),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Kiralama Tipi"),
              dom.element(
                "select",
                [a.name("charter_type"), a.id("input-charter-type")],
                [
                  dom.element("option", [a.attribute("value", "daily")], [
                    text("Günlük Seyir"),
                  ]),
                  dom.element("option", [a.attribute("value", "weekly")], [
                    text("Haftalık Kiralama (Cts-Cts)"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("APA / Kumanya & Yakıt Depozitosu (%)"),
              dom.element(
                "input",
                [
                  a.name("apa_deposit_percent"),
                  a.id("input-apa-deposit"),
                  a.attribute("placeholder", "30.00"),
                  a.attribute("value", "30.00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Mürettebat Bahşiş Oranı (%)"),
              dom.element(
                "input",
                [
                  a.name("crew_tip_percent"),
                  a.id("input-crew-tip"),
                  a.attribute("placeholder", "10.00"),
                  a.attribute("value", "10.00"),
                ],
                [],
              ),
            ]),
            step6_commission_input("15.00"),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Minimum Kiralama (Gün)"),
              dom.element(
                "input",
                [
                  a.name("min_charter_days"),
                  a.id("input-min-charter"),
                  a.type_("number"),
                  a.attribute("placeholder", "3"),
                  a.attribute("value", "3"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Marina Biniş Saati"),
              dom.element(
                "input",
                [
                  a.name("check_in_time"),
                  a.id("input-check-in"),
                  a.attribute("value", "15:00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Marina İniş Saati"),
              dom.element(
                "input",
                [
                  a.name("check_out_time"),
                  a.id("input-check-out"),
                  a.attribute("value", "10:00"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Armatör / Tekne Sahibi"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Örn: Göcek Yatçılık A.Ş."),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Yetkili Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 532 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Seyir tarihinden 30 gün öncesine kadar %100 kesintisiz iade hakkı; son 15 günde %50 kesinti uygulanır.",
          ),
        ],
      )

    "tour" | "activity" ->
      step6_panel(
        "Katılım Ücreti, İndirimler & Kontenjan",
        "Kişi başı katılım fiyatı, çocuk indirimleri, ön ödeme oranı ve iptal politikasını yapılandırın.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input("Kişi Başı Katılım Bedeli", "1.750", "175000"),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Fiyatlandırma Tipi"),
              dom.element(
                "select",
                [a.name("pricing_type"), a.id("input-pricing-type")],
                [
                  dom.element("option", [a.attribute("value", "per_person")], [
                    text("Kişi Başı Sabit"),
                  ]),
                  dom.element(
                    "option",
                    [a.attribute("value", "private_group")],
                    [text("Özel Grup / Araç Başı")],
                  ),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Çocuk İndirim Oranı (%)"),
              dom.element(
                "input",
                [
                  a.name("child_discount_percent"),
                  a.id("input-child-discount"),
                  a.attribute("placeholder", "%50 İndirimli"),
                  a.attribute("value", "%50 İndirimli"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Rezervasyon Ön Ödemesi (%)"),
              dom.element(
                "input",
                [
                  a.name("deposit_percent"),
                  a.id("input-deposit-percent"),
                  a.attribute("placeholder", "30.00"),
                  a.attribute("value", "30.00"),
                ],
                [],
              ),
            ]),
            step6_commission_input("20.00"),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Min. Katılımcı"),
              dom.element(
                "input",
                [
                  a.name("min_pax"),
                  a.id("input-min-pax"),
                  a.type_("number"),
                  a.attribute("placeholder", "2"),
                  a.attribute("value", "2"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Maks. Grup Kontenjanı"),
              dom.element(
                "input",
                [
                  a.name("group_size"),
                  a.id("input-group-size"),
                  a.type_("number"),
                  a.attribute("placeholder", "16"),
                  a.attribute("value", "16"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Son Rezervasyon Kapanışı"),
              dom.element(
                "input",
                [
                  a.name("sales_cutoff_hours"),
                  a.id("input-sales-cutoff"),
                  a.attribute("placeholder", "Tur saatinden 12 saat önce"),
                  a.attribute("value", "Tur saatinden 12 saat önce"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Tur Operatörü / Rehber"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute(
                    "placeholder",
                    "Örn: Kapadokya Balon Turizmi Ltd.",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Yetkili Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 5xx xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Tur hareket saatinden 24 saat öncesine kadar kesintisiz %100 iade garantisi.",
          ),
        ],
      )

    "flight" | "ferry" | "bus" ->
      step6_panel(
        "Bilet Fiyatı, Bagaj Ücretleri & İade/Değişiklik",
        "Tek yön taban bilet fiyatı, çocuk tarifeleri, ek bagaj bedeli ve bilet değişim kurallarını girin.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input("Tek Yön Taban Bilet Fiyatı", "2.250", "225000"),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Bilet Sınıfı"),
              dom.element(
                "select",
                [a.name("fare_class"), a.id("input-fare-class")],
                [
                  dom.element("option", [a.attribute("value", "economy")], [
                    text("Ekonomi / Standart"),
                  ]),
                  dom.element("option", [a.attribute("value", "promo")], [
                    text("Promosyon / İadesiz"),
                  ]),
                  dom.element("option", [a.attribute("value", "business")], [
                    text("Business / VIP Sınıf"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Çocuk / Öğrenci İndirimi (%)"),
              dom.element(
                "input",
                [
                  a.name("child_discount_percent"),
                  a.id("input-child-discount"),
                  a.attribute("placeholder", "%20 İndirimli"),
                  a.attribute("value", "%20 İndirimli"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Ekstra Bagaj Ücreti (TL)"),
              dom.element(
                "input",
                [
                  a.name("extra_baggage_fee"),
                  a.id("input-extra-baggage"),
                  a.attribute("placeholder", "150 TL / 5 Kg"),
                  a.attribute("value", "150 TL / 5 Kg"),
                ],
                [],
              ),
            ]),
            step6_commission_input("10.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Sefer Satış Kapanış Süresi"),
              dom.element(
                "input",
                [
                  a.name("sales_cutoff_hours"),
                  a.id("input-sales-cutoff"),
                  a.attribute("placeholder", "Kalkıştan 2 saat öncesine kadar"),
                  a.attribute("value", "Kalkıştan 2 saat öncesine kadar"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("PNR Opsiyon Süresi"),
              dom.element(
                "input",
                [
                  a.name("option_period_hours"),
                  a.id("input-option-period"),
                  a.attribute("placeholder", "24 Saat"),
                  a.attribute("value", "24 Saat"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Taşıyıcı Firma / Temsilci"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Örn: Türk Hava Yolları / Sealine"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Temsilci Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 850 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Kalkış saatinden 12 saat öncesine kadar %20 kesintili iade veya ücretsiz tarih değişikliği.",
          ),
        ],
      )

    "car" | "transfer" ->
      step6_panel(
        "Kiralama / Transfer Bedeli, Depozito & Sürüş Koşulları",
        "Günlük veya güzergah bedeli, provizyon depozitosu, ek km tarifesi ve teslimat kurallarını belirleyin.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input(
              "Günlük / Transfer Taban Ücreti",
              "3.200",
              "320000",
            ),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Fiyat Modeli"),
              dom.element(
                "select",
                [a.name("pricing_model"), a.id("input-pricing-model")],
                [
                  dom.element("option", [a.attribute("value", "daily")], [
                    text("Günlük Kiralama"),
                  ]),
                  dom.element(
                    "option",
                    [a.attribute("value", "point_to_point")],
                    [text("Noktadan Noktaya Transfer")],
                  ),
                  dom.element("option", [a.attribute("value", "hourly")], [
                    text("Şoförlü Saatlik Tahsis"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Kredi Kartı Provizyon Blokesi (TL)"),
              dom.element(
                "input",
                [
                  a.name("security_deposit"),
                  a.id("input-security-deposit"),
                  a.attribute("placeholder", "5000 TL"),
                  a.attribute("value", "5000 TL"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Ekstra KM Başına Ücret (TL)"),
              dom.element(
                "input",
                [
                  a.name("extra_km_fee"),
                  a.id("input-extra-km-fee"),
                  a.attribute("placeholder", "6 TL / Km"),
                  a.attribute("value", "6 TL / Km"),
                ],
                [],
              ),
            ]),
            step6_commission_input("15.00"),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Min. Kiralama Süresi (Gün)"),
              dom.element(
                "input",
                [
                  a.name("min_rental_days"),
                  a.id("input-min-rental"),
                  a.attribute("placeholder", "1 Gün"),
                  a.attribute("value", "1 Gün"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Havalimanı Ücretsiz Bekleme"),
              dom.element(
                "input",
                [
                  a.name("free_waiting_mins"),
                  a.id("input-free-waiting"),
                  a.attribute("placeholder", "45 Dakika"),
                  a.attribute("value", "45 Dakika"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Genç Sürücü (21-25) Farkı"),
              dom.element(
                "input",
                [
                  a.name("young_driver_fee"),
                  a.id("input-young-driver"),
                  a.attribute("placeholder", "350 TL / Gün"),
                  a.attribute("value", "350 TL / Gün"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Filo / Transfer Operasyon Sorumlusu"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Örn: Ege Filo & VIP Transfer"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Operasyon Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 532 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Teslimat saatinden 24 saat öncesine kadar kesintisiz ücretsiz iptal ve tam provizyon iadesi.",
          ),
        ],
      )

    "cruise" ->
      step6_panel(
        "Kruvaziyer Kabin Fiyatı, Liman Vergisi & Erken Rezervasyon",
        "Kişi başı kabin fiyatı, liman vergisi dahil durumu, tek kişilik oda farkı ve ön ödeme şartları.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input(
              "Kişi Başı Kabin Taban Fiyatı",
              "38.500",
              "3850000",
            ),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Kabin Kategorisi"),
              dom.element(
                "select",
                [a.name("cabin_category"), a.id("input-cabin-category")],
                [
                  dom.element("option", [a.attribute("value", "interior")], [
                    text("İç Kabin"),
                  ]),
                  dom.element("option", [a.attribute("value", "oceanview")], [
                    text("Dış / Deniz Manzaralı"),
                  ]),
                  dom.element("option", [a.attribute("value", "balcony")], [
                    text("Balkonlu Kabin"),
                  ]),
                  dom.element("option", [a.attribute("value", "suite")], [
                    text("Süit / VIP Güverte"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Liman Vergileri & Harçlar"),
              dom.element(
                "input",
                [
                  a.name("port_tax"),
                  a.id("input-port-tax"),
                  a.attribute("placeholder", "180 EUR (Fiyata Dahil)"),
                  a.attribute("value", "180 EUR (Fiyata Dahil)"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Tek Kişi Farkı (%)"),
              dom.element(
                "input",
                [
                  a.name("single_supplement_percent"),
                  a.id("input-single-supplement"),
                  a.attribute("placeholder", "%50 Single Farkı"),
                  a.attribute("value", "%50 Single Farkı"),
                ],
                [],
              ),
            ]),
            step6_commission_input("12.00"),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Kesin Kayıt Ön Ödemesi (%)"),
              dom.element(
                "input",
                [
                  a.name("deposit_percent"),
                  a.id("input-deposit-percent"),
                  a.attribute("placeholder", "30.00"),
                  a.attribute("value", "30.00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Erken Rezervasyon İndirimi"),
              dom.element(
                "input",
                [
                  a.name("early_booking_discount"),
                  a.id("input-early-booking"),
                  a.attribute("placeholder", "%15 İndirim"),
                  a.attribute("value", "%15 İndirim"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Bakiye Kapanış Süresi"),
              dom.element(
                "input",
                [
                  a.name("final_payment_days"),
                  a.id("input-final-payment"),
                  a.attribute("placeholder", "Kalkıştan 30 gün önce"),
                  a.attribute("value", "Kalkıştan 30 gün önce"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Gemi Donatanı / Acente Temsilcisi"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute(
                    "placeholder",
                    "Örn: Celestyal Cruises / Ege Hatları",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Temsilci Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 212 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Kalkışa 60 gün kalaya kadar kesintisiz iade; 30 gün kalaya kadar %50 kesintili iade hakkı.",
          ),
        ],
      )

    "restaurant" ->
      step6_panel(
        "Kuver / Menü Bedeli, Masa Depozitosu & Rezervasyon Kuralları",
        "Ortalama kişi başı kuver bedeli, masa garanti depozitosu, opsiyon tutma süresi ve iptal politikası.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input(
              "Kişi Başı Ortalama Menü / Kuver Bedeli",
              "1.250",
              "125000",
            ),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Hizmet Türü"),
              dom.element(
                "select",
                [a.name("service_type"), a.id("input-service-type")],
                [
                  dom.element("option", [a.attribute("value", "a_la_carte")], [
                    text("Alakart Menü"),
                  ]),
                  dom.element("option", [a.attribute("value", "set_menu")], [
                    text("Fix / Set Menü"),
                  ]),
                  dom.element("option", [a.attribute("value", "tasting")], [
                    text("Şefin Tadım Menüsü"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Masa Rezervasyon Depozitosu (TL)"),
              dom.element(
                "input",
                [
                  a.name("reservation_deposit"),
                  a.id("input-reservation-deposit"),
                  a.attribute("placeholder", "500 TL"),
                  a.attribute("value", "500 TL"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Masa Tutma Süresi (Gecikme)"),
              dom.element(
                "input",
                [
                  a.name("table_hold_mins"),
                  a.id("input-table-hold"),
                  a.attribute("placeholder", "15 Dakika"),
                  a.attribute("value", "15 Dakika"),
                ],
                [],
              ),
            ]),
            step6_commission_input("10.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Garsoniye / Servis Oranı (%)"),
              dom.element(
                "input",
                [
                  a.name("service_charge_percent"),
                  a.id("input-service-charge"),
                  a.attribute("placeholder", "%10 Servis Bedeli"),
                  a.attribute("value", "%10 Servis Bedeli"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Çocuk Politikası & Menüsü"),
              dom.element(
                "input",
                [
                  a.name("child_policy"),
                  a.id("input-child-policy"),
                  a.attribute(
                    "placeholder",
                    "0-6 Yaş Ücretsiz / Çocuk Sandalyesi Mevcut",
                  ),
                  a.attribute(
                    "value",
                    "0-6 Yaş Ücretsiz / Çocuk Sandalyesi Mevcut",
                  ),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Restoran Müdürü / Rezervasyon Yetkilisi"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Örn: Sunset Bistro Alaçatı"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Rezervasyon Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 252 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Rezervasyon saatinden 2 saat öncesine kadar iptal durumunda masa depozitosu eksiksiz iade edilir.",
          ),
        ],
      )

    "beach" ->
      step6_panel(
        "Şezlong / Loca Giriş Fiyatı & Harcama Limitleri",
        "Günlük giriş ve şezlong bedeli, asgari harcama tutarı ve havlu depozito kurallarını belirleyin.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input(
              "Günlük Şezlong / Loca Taban Ücreti",
              "950",
              "95000",
            ),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Düzen / Rezervasyon Tipi"),
              dom.element(
                "select",
                [a.name("beach_pricing_type"), a.id("input-beach-pricing-type")],
                [
                  dom.element("option", [a.attribute("value", "sunbed")], [
                    text("Standart Tek Şezlong & Şemsiye"),
                  ]),
                  dom.element("option", [a.attribute("value", "front_row")], [
                    text("Ön Sıra / VIP Şezlong"),
                  ]),
                  dom.element("option", [a.attribute("value", "cabana")], [
                    text("Özel Loca / Cabana Gazebo"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Minimum Harcama Limiti (TL)"),
              dom.element(
                "input",
                [
                  a.name("minimum_spend"),
                  a.id("input-minimum-spend"),
                  a.attribute("placeholder", "1500 TL"),
                  a.attribute("value", "1500 TL"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Plaj Havlusu Depozitosu (TL)"),
              dom.element(
                "input",
                [
                  a.name("towel_deposit"),
                  a.id("input-towel-deposit"),
                  a.attribute("placeholder", "200 TL"),
                  a.attribute("value", "200 TL"),
                ],
                [],
              ),
            ]),
            step6_commission_input("15.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Plaj Açılış Saati"),
              dom.element(
                "input",
                [
                  a.name("check_in_time"),
                  a.id("input-check-in"),
                  a.attribute("value", "09:00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Kapanış & Tahliye Saati"),
              dom.element(
                "input",
                [
                  a.name("check_out_time"),
                  a.id("input-check-out"),
                  a.attribute("value", "19:00"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Beach Club İşletme Yetkilisi"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Örn: Lara Beach Club İşletmesi"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Rezervasyon Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 533 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Rezervasyon gününden 24 saat öncesine kadar yapılan iptallerde ödeme tam iade edilir.",
          ),
        ],
      )

    "cinema" | "event" ->
      step6_panel(
        "Bilet Fiyatı, İndirimli Kategoriler & Giriş Kuralları",
        "Koltuk veya ayakta taban bilet fiyatı, öğrenci indirimi, hizmet bedeli ve iade politikasını belirleyin.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input("Standart Bilet Taban Fiyatı", "650", "65000"),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Oturma Düzeni"),
              dom.element(
                "select",
                [a.name("seating_type"), a.id("input-seating-type")],
                [
                  dom.element("option", [a.attribute("value", "numbered")], [
                    text("Numaralı Koltuk Düzeni"),
                  ]),
                  dom.element("option", [a.attribute("value", "general")], [
                    text("Genel Giriş / Ayakta"),
                  ]),
                  dom.element("option", [a.attribute("value", "vip")], [
                    text("VIP / Sahne Önü Protokol"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Öğrenci / İndirimli Bilet Oranı (%)"),
              dom.element(
                "input",
                [
                  a.name("discount_percent"),
                  a.id("input-discount-percent"),
                  a.attribute("placeholder", "%25 İndirimli"),
                  a.attribute("value", "%25 İndirimli"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Biletleme Hizmet Bedeli (TL)"),
              dom.element(
                "input",
                [
                  a.name("service_fee"),
                  a.id("input-service-fee"),
                  a.attribute("placeholder", "35 TL"),
                  a.attribute("value", "35 TL"),
                ],
                [],
              ),
            ]),
            step6_commission_input("10.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Kapı Açılış Saati"),
              dom.element(
                "input",
                [
                  a.name("doors_open_time"),
                  a.id("input-doors-open"),
                  a.attribute("placeholder", "Etkinlikten 1 saat önce"),
                  a.attribute("value", "Etkinlikten 1 saat önce"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Bilet Satış Kapanış Saati"),
              dom.element(
                "input",
                [
                  a.name("sales_cutoff"),
                  a.id("input-sales-cutoff"),
                  a.attribute("placeholder", "Etkinlik başlangıcında"),
                  a.attribute("value", "Etkinlik başlangıcında"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Organizatör / Gişe Sorumlusu"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute(
                    "placeholder",
                    "Örn: Kültür Sanat Organizasyon A.Ş.",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Gişe Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 850 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Etkinliğin iptali veya ertelenmesi haricinde satılan biletlerde cayma veya iade hakkı bulunmaz.",
          ),
        ],
      )

    "visa" ->
      step6_panel(
        "Danışmanlık Hizmet Bedeli, Konsolosluk Harçları & İade Şartı",
        "Dosya hazırlık ücreti, resmi konsolosluk harçları, randevu takibi ve red halinde iade şartları.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input(
              "Vize Danışmanlık Hizmet Bedeli",
              "3.500",
              "350000",
            ),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Başvuru Hızı / Türü"),
              dom.element(
                "select",
                [a.name("application_speed"), a.id("input-application-speed")],
                [
                  dom.element("option", [a.attribute("value", "standard")], [
                    text("Standart Başvuru Süreci"),
                  ]),
                  dom.element("option", [a.attribute("value", "express")], [
                    text("Ekspres / VIP Başvuru Hizmeti"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("Konsolosluk & Harç Bedeli"),
              dom.element(
                "input",
                [
                  a.name("consular_fee"),
                  a.id("input-consular-fee"),
                  a.attribute(
                    "placeholder",
                    "90 EUR (Başvuru Merkezine Ödenir)",
                  ),
                  a.attribute("value", "90 EUR (Başvuru Merkezine Ödenir)"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Tercüme & Noter Hizmeti"),
              dom.element(
                "input",
                [
                  a.name("translation_fee"),
                  a.id("input-translation-fee"),
                  a.attribute("placeholder", "Ek Ücrete Tabidir"),
                  a.attribute("value", "Ek Ücrete Tabidir"),
                ],
                [],
              ),
            ]),
            step6_commission_input("20.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Dosya Açılış Ön Ödemesi (%)"),
              dom.element(
                "input",
                [
                  a.name("deposit_percent"),
                  a.id("input-deposit-percent"),
                  a.attribute("placeholder", "50.00"),
                  a.attribute("value", "50.00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Ortalama Sonuçlanma Süresi"),
              dom.element(
                "input",
                [
                  a.name("processing_time"),
                  a.id("input-processing-time"),
                  a.attribute("placeholder", "15 - 25 İş Günü"),
                  a.attribute("value", "15 - 25 İş Günü"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Vize Departman Sorumlusu"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute("placeholder", "Örn: Vize Operasyon Birimi"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("İletişim Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 212 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Resmi makamlara ödenen harçlar iade edilmez; randevu oluşturulmadan önce danışmanlık %100 iade edilir.",
          ),
        ],
      )

    "pilgrimage" ->
      step6_panel(
        "Hac / Umre Paket Fiyatı, Oda Farkları & Ödeme Planı",
        "Kişi başı oda paylaşımlı paket fiyatı, 2 kişilik oda farkı, taksit vadeleri ve cayma şartları.",
        [
          dom.element("div", [a.class("form-grid-3")], [
            step6_price_input(
              "Kişi Başı Paket Taban Fiyatı",
              "48.000",
              "4800000",
            ),
            dom.element("label", [], [
              text("Para Birimi"),
              step6_currency_select(),
            ]),
            dom.element("label", [], [
              text("Oda Paylaşım Tipi"),
              dom.element(
                "select",
                [a.name("room_occupancy"), a.id("input-room-occupancy")],
                [
                  dom.element("option", [a.attribute("value", "quad")], [
                    text("4 Kişilik Standart Oda"),
                  ]),
                  dom.element("option", [a.attribute("value", "triple")], [
                    text("3 Kişilik Aile Odası"),
                  ]),
                  dom.element("option", [a.attribute("value", "double")], [
                    text("2 Kişilik Özel Oda"),
                  ]),
                ],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-3")], [
            dom.element("label", [], [
              text("2 Kişilik Oda Farkı (USD)"),
              dom.element(
                "input",
                [
                  a.name("double_room_diff"),
                  a.id("input-double-diff"),
                  a.attribute("placeholder", "450 USD"),
                  a.attribute("value", "450 USD"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Çocuk Katılım İndirimi (%)"),
              dom.element(
                "input",
                [
                  a.name("child_discount_percent"),
                  a.id("input-child-discount"),
                  a.attribute("placeholder", "%35 İndirimli"),
                  a.attribute("value", "%35 İndirimli"),
                ],
                [],
              ),
            ]),
            step6_commission_input("10.00"),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Kesin Kayıt Ön Ödemesi (%)"),
              dom.element(
                "input",
                [
                  a.name("deposit_percent"),
                  a.id("input-deposit-percent"),
                  a.attribute("placeholder", "40.00"),
                  a.attribute("value", "40.00"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Kalan Bakiye Kapanış Vadesi"),
              dom.element(
                "input",
                [
                  a.name("final_payment_deadline"),
                  a.id("input-final-deadline"),
                  a.attribute("placeholder", "Gidişten 20 gün önce"),
                  a.attribute("value", "Gidişten 20 gün önce"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              text("Hac & Umre Operasyon Sorumlusu"),
              dom.element(
                "input",
                [
                  a.name("owner_name"),
                  a.id("input-owner-name"),
                  a.attribute(
                    "placeholder",
                    "Örn: Diyanet Onaylı A Grubu Acente",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Operasyon Telefon"),
              dom.element(
                "input",
                [
                  a.name("owner_phone"),
                  a.id("input-owner-phone"),
                  a.attribute("placeholder", "+90 312 xxx xx xx"),
                ],
                [],
              ),
            ]),
          ]),
          step6_cancellation_input(
            "Uçak ve vize kesintileri düşüldükten sonra kalan tutar seyahatten 15 gün öncesine kadar iade edilir.",
          ),
        ],
      )

    _ ->
      case is_hotel {
        True -> category_pricing_step6("hotel", True)
        False ->
          step6_panel(
            "Fiyatlandırma, Satış Koşulları & İptal Politikası",
            "Hizmet birim bedelini, acente komisyon oranını ve iptal/iade kurallarını belirleyin.",
            [
              dom.element("div", [a.class("form-grid-3")], [
                step6_price_input("Birim Hizmet Bedeli", "5.000", "500000"),
                dom.element("label", [], [
                  text("Para Birimi"),
                  step6_currency_select(),
                ]),
                step6_commission_input("15.00"),
              ]),
              dom.element("div", [a.class("form-grid-2")], [
                dom.element("label", [], [
                  text("Ön Ödeme / Güvence Oranı (%)"),
                  dom.element(
                    "input",
                    [
                      a.name("deposit_percent"),
                      a.id("input-deposit-percent"),
                      a.attribute("placeholder", "25.00"),
                      a.attribute("value", "25.00"),
                    ],
                    [],
                  ),
                ]),
                dom.element("label", [], [
                  text("Son Rezervasyon Kabul Süresi"),
                  dom.element(
                    "input",
                    [
                      a.name("sales_cutoff_hours"),
                      a.id("input-sales-cutoff"),
                      a.attribute(
                        "placeholder",
                        "Hizmet başlangıcından 24 saat önce",
                      ),
                      a.attribute("value", "Hizmet başlangıcından 24 saat önce"),
                    ],
                    [],
                  ),
                ]),
              ]),
              dom.element("div", [a.class("form-grid-2")], [
                dom.element("label", [], [
                  text("Tedarikçi / Hizmet Sağlayıcı"),
                  dom.element(
                    "input",
                    [
                      a.name("owner_name"),
                      a.id("input-owner-name"),
                      a.attribute("placeholder", "Hizmet Yetkilisi"),
                    ],
                    [],
                  ),
                ]),
                dom.element("label", [], [
                  text("Tedarikçi Telefon"),
                  dom.element(
                    "input",
                    [
                      a.name("owner_phone"),
                      a.id("input-owner-phone"),
                      a.attribute("placeholder", "+90 5xx xxx xx xx"),
                    ],
                    [],
                  ),
                ]),
              ]),
              step6_cancellation_input(
                "Hizmet başlama tarihinden 48 saat öncesine kadar kesintisiz %100 iade hakkı.",
              ),
            ],
          )
      }
  }
}

fn catalog_form(active_cat: String) {
  let effective_cat = case active_cat {
    "" -> "hotel"
    cat -> cat
  }
  let cat_name = category_display_name(effective_cat)
  let is_hotel = effective_cat == "hotel"

  dom.element(
    "section",
    [a.class("quick airbnb-wizard-section"), a.id("catalog-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [
            text(case active_cat {
              "" -> "Katalog ve Hizmet Envanteri"
              _ -> cat_name <> " Kataloğu"
            }),
          ]),
          dom.element("p", [a.class("muted")], [
            text(case is_hotel {
              True ->
                "Otel ve resort tesisleri için oda tipleri, konsept ve tesis imkanlarıyla akıllı ilan oluşturun."
              False ->
                "Kiralık yazlık standartlarında oda, banyo, özel havuz ve donanım adımlarıyla ilan oluşturun."
            }),
          ]),
        ]),
        dom.element("span", [a.class("status-pill")], [
          text(cat_name),
        ]),
      ]),

      // Top Control Bar: Form Reset, AI Assistant, Sample Populate
      dom.element("div", [a.class("catalog-top-controls")], [
        dom.element("div", [a.class("stepper-badge-intro")], [
          dom.element("span", [a.class("stepper-icon-pin")], [text("🧭")]),
          dom.element("strong", [], [text("Adım Adım İlan Sihirbazı")]),
          dom.element("span", [a.class("muted")], [
            text("— 7 odaklı adımda eksiksiz ve hatasız ilan oluşturun"),
          ]),
        ]),
        dom.element("div", [a.class("quick-action-group")], [
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("btn-quick-util"),
              a.id("btn-toggle-ai-card"),
            ],
            [
              dom.element("span", [], [text("✨")]),
              text("AI Asistanı (Gizle/Aç)"),
            ],
          ),
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("btn-quick-util"),
              a.id("btn-fill-sample"),
            ],
            [
              dom.element("span", [], [text("📋")]),
              text("Örnek Şablonu Doldur"),
            ],
          ),
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("btn-quick-util btn-danger-soft"),
              a.id("btn-reset-form"),
            ],
            [
              dom.element("span", [], [text("🗑️")]),
              text("Formu Temizle"),
            ],
          ),
          dom.element(
            "a",
            [
              a.href("/admin/ai#social-compose-form"),
              a.class("btn-quick-util"),
              a.attribute(
                "title",
                "Yapay Zeka ve Sosyal Medya Paylaşım Stüdyosu",
              ),
            ],
            [
              dom.element("span", [], [text("📱")]),
              text("Sosyal Medya & AI"),
            ],
          ),
          dom.element(
            "button",
            [
              a.attribute("type", "button"),
              a.class("btn-quick-util"),
              a.id("btn-reset-view"),
              a.attribute(
                "title",
                "Mod tercihi ve açık bölüm düzenini sıfırlar",
              ),
            ],
            [
              dom.element("span", [], [text("🔄")]),
              text("Görünümü Sıfırla"),
            ],
          ),
        ]),
      ]),

      // 1. AI Reference Link & Prompt Importer Card (Collapsible)
      dom.element(
        "div",
        [a.id("ai-import-card"), a.class("ai-import-card glass-glow")],
        [
          dom.element("div", [a.class("ai-import-top")], [
            dom.element("div", [a.class("ai-title-wrap")], [
              dom.element("span", [a.class("ai-badge-pulse")], [
                text("✦ AI POWERED"),
              ]),
              dom.element("h3", [], [
                text("Yapay Zeka ile Tek Tıkla İlanı Çıkar & Doldur"),
              ]),
            ]),
            dom.element("p", [a.class("ai-subtitle")], [
              text(case is_hotel {
                True ->
                  "Otel web sitesi bağlantısını yapıştırın; Yapay Zeka oda tiplerini, konsepti ve tesis imkanlarını saniyeler içinde hazırlasın."
                False ->
                  "Villa web sitesi bağlantısını yapıştırın; Yapay Zeka kapasiteyi, havuz niteliklerini ve fiyatı saniyeler içinde hazırlasın."
              }),
            ]),
          ]),
          dom.element("div", [a.class("ai-import-row")], [
            dom.element("div", [a.class("ai-input-wrapper")], [
              dom.element("span", [a.class("ai-input-icon")], [text("🔗")]),
              dom.element(
                "input",
                [
                  a.id("ai-import-input"),
                  a.attribute("type", "text"),
                  a.attribute(
                    "aria-label",
                    "AI içe aktarma kaynağı: bağlantı veya serbest açıklama",
                  ),
                  a.attribute("placeholder", case is_hotel {
                    True ->
                      "Örn: https://tesis.example.com veya 'Bodrum Torba'da denize sıfır, 5 yıldızlı ultra her şey dahil lüks resort otel, gecelik 18.500 TL...'"
                    False ->
                      "Örn: https://villa.example.com/ilan veya 'Bodrum Yalıkavak'ta 4 yatak odalı, 4 banyolu, sonsuzluk havuzlu lüks villa, gecelik 25.000 TL...'"
                  }),
                ],
                [],
              ),
            ]),
            dom.element(
              "button",
              [
                a.id("ai-import-btn"),
                a.attribute("type", "button"),
                a.class("ai-magic-button"),
              ],
              [
                dom.element("span", [a.class("sparkle-icon")], [text("✨")]),
                text("AI ile Analiz Et & Doldur"),
              ],
            ),
          ]),
          dom.element("div", [a.class("ai-quick-samples")], case is_hotel {
            True -> [
              dom.element("span", [a.class("ai-sample-label")], [
                text("Örnek Promptlar:"),
              ]),
              wizard_sample_prompt(
                "Bodrum Torba'da denize sıfır, 5 yıldızlı ultra her şey dahil lüks resort otel, aquapark, özel plaj, 4 farklı oda tipi, gecelik 18.500 TL",
                "🏨 Bodrum 5★ Lüks Resort",
              ),
              wizard_sample_prompt(
                "Antalya Belek'te golf sahalarına yakın, her şey dahil aile resort oteli, mini club, açık/kapalı havuz, gecelik 14.200 TL",
                "🏖️ Antalya Her Şey Dahil",
              ),
              wizard_sample_prompt(
                "Çeşme Alaçatı'da otantik taş mimarili lüks butik otel, termal spa havuzu, oda kahvaltı konsept, gecelik 8.900 TL",
                "🧖 Çeşme Butik Termal",
              ),
              wizard_sample_prompt(
                "Kapadokya Göreme'de balon manzaralı teraslı otantik mağara süit otel, jakuzili, kahvaltı dahil, gecelik 9.500 TL",
                "🎈 Kapadokya Cave Hotel",
              ),
            ]
            False -> [
              dom.element("span", [a.class("ai-sample-label")], [
                text("Örnek Promptlar:"),
              ]),
              wizard_sample_prompt(
                "Bodrum Yalıkavak'ta panoramik deniz manzaralı, 4 yatak odalı, 4 banyolu, sonsuzluk havuzlu, jakuzili lüks balayı villası, gecelik 25.000 TL",
                "🏡 Bodrum Lüks Villa",
              ),
              wizard_sample_prompt(
                "Kalkan Kaş'ta doğa içinde, jakuzili, %100 korunaklı havuzlu, deniz manzaralı balayı villası, gecelik 14.500 TL",
                "🌅 Kalkan Korunaklı Villa",
              ),
              wizard_sample_prompt(
                "Fethiye Kayaköy'de şömineli, geniş bahçeli, korunaklı havuzlu müstakil taş villa, gecelik 16.000 TL",
                "🌲 Fethiye Doğa Taş Ev",
              ),
              wizard_sample_prompt(
                "Göcek koylarında 24 metre lüks ahşap gulet, 4 kabin, aşçı ve mürettebat dahil, günlük 45.000 TL",
                "⚓ Göcek Mavi Tur Yatı",
              ),
            ]
          }),
          dom.element(
            "div",
            [a.id("ai-import-status"), a.class("ai-status-bar hidden")],
            [
              dom.element("div", [a.class("ai-status-spinner")], []),
              dom.element("span", [a.id("ai-status-text")], [
                text("Yapay Zeka içeriği inceliyor ve 7 adımı hazırlıyor..."),
              ]),
            ],
          ),
        ],
      ),

      // Top Live Preview Card (Prominently placed above stepper)
      top_live_preview_card(effective_cat, is_hotel, cat_name),

      // 2. Stepper Progress Track & Tabs
      dom.element(
        "div",
        [a.id("wizard-stepper-wrap"), a.class("wizard-stepper-wrap")],
        [
          dom.element(
            "div",
            [
              a.class("wizard-progress-track"),
              a.attribute("role", "progressbar"),
              a.attribute("aria-label", "Sihirbaz ilerlemesi"),
              a.attribute("aria-valuemin", "1"),
              a.attribute("aria-valuemax", "7"),
              a.attribute("aria-valuenow", "1"),
            ],
            [
              dom.element(
                "div",
                [a.id("wizard-progress-fill"), a.class("wizard-progress-fill")],
                [],
              ),
            ],
          ),
          dom.element(
            "span",
            [a.id("wizard-progress-label"), a.class("wizard-progress-label")],
            [text("0% tamamlandı")],
          ),
          dom.element("div", [a.class("wizard-step-tabs")], [
            wizard_step_tab("1", "01", "Temel Bilgiler", True),
            wizard_step_tab("2", "02", "Konum & Harita", False),
            wizard_step_tab("3", "03", step_tab_label(3, effective_cat), False),
            wizard_step_tab("4", "04", step_tab_label(4, effective_cat), False),
            wizard_step_tab("5", "05", "Fotoğraflar", False),
            wizard_step_tab("6", "06", step_tab_label(6, effective_cat), False),
            wizard_step_tab("7", "07", "Önizleme & Onay", False),
          ]),
        ],
      ),

      // 3. Wizard Form & Focused Step Layout
      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/catalog"),
          a.id("airbnb-listing-form"),
          a.class("wizard-stepper-layout"),
          a.attribute("novalidate", "novalidate"),
        ],
        [
          dom.element(
            "input",
            [
              a.type_("hidden"),
              a.name("category"),
              a.id("catalog-category-input"),
              a.attribute("value", effective_cat),
            ],
            [],
          ),
          dom.element(
            "input",
            [
              a.type_("hidden"),
              a.name("amenities"),
              a.id("wizard-amenities-input"),
              a.attribute("value", "[]"),
            ],
            [],
          ),
          dom.element(
            "input",
            [
              a.type_("hidden"),
              a.name("images"),
              a.id("wizard-images-input"),
              a.attribute("value", "[]"),
            ],
            [],
          ),
          dom.element(
            "input",
            [
              a.type_("hidden"),
              a.name("room_types"),
              a.id("wizard-room-types-input"),
              a.attribute("value", "[]"),
            ],
            [],
          ),
          dom.element(
            "input",
            [
              a.type_("hidden"),
              a.name("extra_metadata"),
              a.id("wizard-extra-metadata-input"),
              a.attribute("value", "{}"),
            ],
            [],
          ),

          // LEFT COLUMN: Wizard Step Cards
          dom.element("div", [a.class("wizard-steps-container")], [
            // Form Top Sticky Actions: Quick Save Draft & Publish
            dom.element("div", [a.class("form-sticky-top-actions")], [
              dom.element("div", [a.class("actions-left")], [
                // Stepper / Tam Form modu geçişi — listing-wizard.js setMode()
                // bu iki düğmeyi bekler; CSS: .mode-switcher-group/.btn-mode-tab
                dom.element(
                  "div",
                  [
                    a.class("mode-switcher-group"),
                    a.attribute("role", "group"),
                    a.attribute("aria-label", "Form modu seçimi"),
                  ],
                  [
                    dom.element(
                      "button",
                      [
                        a.attribute("type", "button"),
                        a.class("btn-mode-tab active"),
                        a.id("btn-mode-stepper"),
                        a.attribute("aria-pressed", "true"),
                      ],
                      [text("🧭 Sihirbaz")],
                    ),
                    dom.element(
                      "button",
                      [
                        a.attribute("type", "button"),
                        a.class("btn-mode-tab"),
                        a.id("btn-mode-full"),
                        a.attribute("aria-pressed", "false"),
                      ],
                      [text("⚡ Hızlı Form")],
                    ),
                  ],
                ),
                dom.element("span", [a.class("form-mode-indicator")], [
                  dom.element("span", [a.class("indicator-dot")], []),
                  dom.element("span", [a.id("form-mode-text")], [
                    text("Sihirbaz Modu"),
                  ]),
                ]),
              ]),
              dom.element("div", [a.class("actions-right")], [
                dom.element(
                  "button",
                  [
                    a.attribute("type", "button"),
                    a.class("btn-top-draft"),
                    a.id("btn-quick-draft"),
                    a.attribute("aria-label", "Taslak olarak kaydet"),
                  ],
                  [text("💾 Taslak Kaydet")],
                ),
                dom.element(
                  "button",
                  [
                    a.attribute("type", "button"),
                    a.class("btn-top-publish"),
                    a.id("btn-quick-publish"),
                    a.attribute("aria-label", "Kataloğa kaydet ve yayınla"),
                  ],
                  [text("🚀 Kataloğa Kaydet ve Yayınla")],
                ),
              ]),
            ]),

            // Tam Form (Hızlı) modunda bölüm atlama çubuğu — setMode('full')
            // çağrısı .hidden sınıfını kaldırır; hedefler sec-1..sec-7 panelleri.
            dom.element(
              "div",
              [
                a.id("full-form-quick-nav"),
                a.class("full-form-quick-nav hidden"),
                a.attribute("role", "navigation"),
                a.attribute("aria-label", "Form bölümleri arasında hızlı geçiş"),
              ],
              [
                dom.element("span", [a.class("nav-label")], [
                  text("Hızlı Geçiş"),
                ]),
                dom.element(
                  "a",
                  [
                    a.class("nav-pill"),
                    a.href("#sec-1"),
                    a.attribute("aria-current", "true"),
                  ],
                  [text("Temel Bilgiler")],
                ),
                dom.element("a", [a.class("nav-pill"), a.href("#sec-2")], [
                  text("Konum"),
                ]),
                dom.element("a", [a.class("nav-pill"), a.href("#sec-3")], [
                  text("Kapasite"),
                ]),
                dom.element("a", [a.class("nav-pill"), a.href("#sec-4")], [
                  text("Donanımlar"),
                ]),
                dom.element("a", [a.class("nav-pill"), a.href("#sec-5")], [
                  text("Fotoğraflar"),
                ]),
                dom.element("a", [a.class("nav-pill"), a.href("#sec-6")], [
                  text("Fiyat"),
                ]),
                dom.element("a", [a.class("nav-pill"), a.href("#sec-7")], [
                  text("Önizleme"),
                ]),
              ],
            ),

            // Active Edit Mode Banner
            dom.element(
              "div",
              [
                a.id("wizard-edit-mode-banner"),
                a.class("wizard-edit-mode-banner hidden"),
              ],
              [
                dom.element("div", [a.class("banner-left")], [
                  dom.element("span", [a.class("banner-icon")], [text("✏️")]),
                  dom.element("span", [a.class("banner-text")], [
                    text("İlan Düzenleme Modu: "),
                    dom.element("strong", [a.id("banner-listing-code")], []),
                    text(" — "),
                    dom.element("span", [a.id("banner-listing-title")], []),
                  ]),
                ]),
                dom.element("div", [a.class("banner-right")], [
                  dom.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.id("btn-cancel-edit-mode"),
                      a.class("btn-banner-new"),
                    ],
                    [text("➕ Yeni İlan Moduna Dön")],
                  ),
                ]),
              ],
            ),

            // STEP 1: Temel Bilgiler
            dom.element(
              "div",
              [
                a.id("sec-1"),
                a.class("wizard-step-panel active"),
                a.attribute("data-step-content", "1"),
              ],
              [
                dom.element("div", [a.class("step-heading")], [
                  dom.element("span", [a.class("step-badge")], [
                    text("Adım 1 / 7"),
                  ]),
                  dom.element("h3", [], [
                    text(case is_hotel {
                      True -> "Otel & Tesis Temel Bilgileri"
                      False -> "Temel İlan Bilgileri"
                    }),
                  ]),
                  dom.element("p", [a.class("muted")], [
                    text(case is_hotel {
                      True ->
                        "Otelinizin adını, acente tesis kodunu, yıldız sınıfını ve konaklama konseptini belirleyin."
                      False ->
                        "İlanınızın başlığını, acente hizmet kodunu ve yayın durumunu belirleyin."
                    }),
                  ]),
                ]),
                dom.element("div", [a.class("form-grid-2")], [
                  dom.element("label", [], [
                    text(category_code_prefix_and_hint(effective_cat).1),
                    dom.element("div", [a.class("input-inline-action-wrap")], [
                      dom.element(
                        "input",
                        [
                          a.name("code"),
                          a.id("input-code"),
                          a.required(True),
                          a.attribute(
                            "placeholder",
                            category_code_prefix_and_hint(effective_cat).0,
                          ),
                        ],
                        [],
                      ),
                      dom.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("btn-inline-action"),
                          a.id("btn-gen-code"),
                          a.attribute("title", "Otomatik benzersiz kod üret"),
                        ],
                        [text("⚡ Kod Üret")],
                      ),
                    ]),
                  ]),
                  dom.element("label", [], [
                    text("Yayın Durumu"),
                    dom.element(
                      "select",
                      [a.name("status"), a.id("input-status")],
                      [
                        dom.element(
                          "option",
                          [a.attribute("value", "published")],
                          [text("Yayında (Aktif)")],
                        ),
                        dom.element("option", [a.attribute("value", "draft")], [
                          text("Taslak"),
                        ]),
                        dom.element("option", [a.attribute("value", "review")], [
                          text("İncelemede"),
                        ]),
                        dom.element("option", [a.attribute("value", "paused")], [
                          text("Duraklatıldı"),
                        ]),
                      ],
                    ),
                  ]),
                ]),
                step1_category_classification(effective_cat),
                dom.element("label", [a.class("field-wide")], [
                  text(case is_hotel {
                    True -> "Otel Adı / Tesis Ticari Ünvanı"
                    False -> "Başlık / İlan Adı"
                  }),
                  dom.element("div", [a.class("input-inline-action-wrap")], [
                    dom.element(
                      "input",
                      [
                        a.name("title"),
                        a.id("input-title"),
                        a.required(True),
                        a.attribute(
                          "placeholder",
                          category_title_placeholder(effective_cat),
                        ),
                      ],
                      [],
                    ),
                    dom.element(
                      "button",
                      [
                        a.attribute("type", "button"),
                        a.class("btn-ai-pill"),
                        a.id("btn-ai-title"),
                        a.attribute("title", "Yapay zeka ile başlık üret"),
                      ],
                      [text("✨ AI Başlık")],
                    ),
                  ]),
                ]),
                step_footer_nav("", "2", "Sonraki Adım: Konum & Harita"),
              ],
            ),

            // STEP 2: Konum & Harita
            dom.element(
              "div",
              [
                a.id("sec-2"),
                a.class("wizard-step-panel"),
                a.attribute("data-step-content", "2"),
              ],
              [
                dom.element("div", [a.class("step-heading")], [
                  dom.element("span", [a.class("step-badge")], [
                    text("Adım 2 / 7"),
                  ]),
                  dom.element("h3", [], [text("Konum & Lokasyon Detayları")]),
                  dom.element("p", [a.class("muted")], [
                    text(
                      "Misafirlerin aramalarda mülkünüzü kolayca bulabilmesi için lokasyonu belirtin.",
                    ),
                  ]),
                ]),
                case is_hotel {
                  True ->
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Şehir / Bölge"),
                        dom.element(
                          "input",
                          [
                            a.name("locality"),
                            a.id("input-locality"),
                            a.required(True),
                            a.attribute(
                              "placeholder",
                              "Örn: Torba, Bodrum, Muğla",
                            ),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Plaj / Sahil Durumu"),
                        dom.element(
                          "select",
                          [
                            a.name("beach_distance"),
                            a.id("input-beach-distance"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "zero")],
                              [text("Denize Sıfır (Mavi Bayraklı Özel Plaj)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "50m")],
                              [text("50 Metre (Yürüme Mesafesi)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "200m")],
                              [text("200 Metre")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "shuttle")],
                              [text("Özel Plaj Shuttle Servisi Var")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "city")],
                              [text("Şehir İçi / Plaja Uzak")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Havalimanı Mesafesi (km)"),
                        dom.element(
                          "input",
                          [
                            a.name("airport_distance"),
                            a.id("input-airport-distance"),
                            a.attribute("placeholder", "Örn: 32 km (BJV)"),
                            a.attribute("value", "32 km"),
                          ],
                          [],
                        ),
                      ]),
                    ])
                  False ->
                    dom.element("div", [a.class("form-grid-2")], [
                      dom.element("label", [], [
                        text("Bölge / İlçe / Şehir"),
                        dom.element(
                          "input",
                          [
                            a.name("locality"),
                            a.id("input-locality"),
                            a.required(True),
                            a.attribute(
                              "placeholder",
                              "Örn: Yalıkavak, Bodrum, Muğla",
                            ),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Mevkii / Koyu / Semt"),
                        dom.element(
                          "input",
                          [
                            a.name("neighborhood"),
                            a.id("input-neighborhood"),
                            a.attribute(
                              "placeholder",
                              "Örn: Tilkicik Koyu / Marina Yakını",
                            ),
                          ],
                          [],
                        ),
                      ]),
                    ])
                },
                dom.element("label", [a.class("field-wide")], [
                  text("Harita Koordinatları veya Google Maps Linki"),
                  dom.element(
                    "input",
                    [
                      a.name("map_coords"),
                      a.id("input-map-coords"),
                      a.attribute(
                        "placeholder",
                        "37.1084, 27.2912 veya https://maps.google.com/...",
                      ),
                    ],
                    [],
                  ),
                ]),
                step_footer_nav("1", "3", case is_hotel {
                  True -> "Sonraki Adım: Oda Tipleri & Kapasite"
                  False -> "Sonraki Adım: Kapasite & Odalar"
                }),
              ],
            ),

            // STEP 3: Kapasite, Envanter & Sektörel Özellikler (16 Kategori Ayrımı)
            case effective_cat {
              "hotel" ->
                dom.element(
                  "div",
                  [
                    a.id("sec-3"),
                    a.class("wizard-step-panel"),
                    a.attribute("data-step-content", "3"),
                  ],
                  [
                    dom.element("div", [a.class("step-heading")], [
                      dom.element("span", [a.class("step-badge")], [
                        text("Adım 3 / 7"),
                      ]),
                      dom.element("h3", [], [
                        text("Oda Tipleri, Envanter & Tesis Kapasitesi"),
                      ]),
                      dom.element("p", [a.class("muted")], [
                        text(
                          "Oteller oda ve süit kategorileriyle yönetilir. Tesisinizdeki oda tiplerini, m² ölçülerini ve kapasitelerini belirleyin.",
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Toplam Tesis Oda Sayısı"),
                        dom.element(
                          "input",
                          [
                            a.name("hotel_total_rooms"),
                            a.id("input-hotel-rooms"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("placeholder", "Örn: 180"),
                            a.attribute("value", "180"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Toplam Yatak Kapasitesi"),
                        dom.element(
                          "input",
                          [
                            a.name("hotel_total_beds"),
                            a.id("input-hotel-beds"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("placeholder", "Örn: 420"),
                            a.attribute("value", "420"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Ana Havuz & Aquapark Sayısı"),
                        dom.element(
                          "input",
                          [
                            a.name("hotel_pools_count"),
                            a.id("input-hotel-pools"),
                            a.attribute(
                              "placeholder",
                              "Örn: 3 Açık Havuz + 1 Aquapark + 1 Kapalı",
                            ),
                            a.attribute(
                              "value",
                              "3 Açık Havuz, 1 Aquapark, 1 Kapalı Termal",
                            ),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("room-types-manager-header")], [
                      dom.element("h4", [a.class("room-types-title")], [
                        text("Tesis Oda Tipleri (Envanter Listesi)"),
                      ]),
                      dom.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("btn-add-room-type"),
                          a.id("btn-add-room-type"),
                        ],
                        [text("+ Yeni Oda Tipi Ekle")],
                      ),
                    ]),
                    dom.element(
                      "div",
                      [a.id("room-types-container"), a.class("room-types-list")],
                      [
                        hotel_room_type_card(
                          "1",
                          "Standart Kara / Bahçe Manzaralı Oda",
                          "28",
                          "2",
                          "1",
                          "1 Çift Kişilik",
                          "Kara / Bahçe",
                          "80",
                        ),
                        hotel_room_type_card(
                          "2",
                          "Deluxe Panoramik Deniz Manzaralı Oda",
                          "38",
                          "3",
                          "1",
                          "1 Çift + 1 Tek Kişilik",
                          "Deniz Manzaralı",
                          "60",
                        ),
                        hotel_room_type_card(
                          "3",
                          "Aile Süiti (Family Suite - 2 Odalı)",
                          "54",
                          "4",
                          "2",
                          "1 Çift + 2 Tek Kişilik",
                          "Deniz & Havuz",
                          "30",
                        ),
                        hotel_room_type_card(
                          "4",
                          "Balayı & King Suite (Jakuzili)",
                          "46",
                          "2",
                          "0",
                          "1 King Bed + Jakuzi",
                          "Panoramik Deniz",
                          "10",
                        ),
                      ],
                    ),
                    step_footer_nav("2", "4", "Sonraki Adım: Tesis İmkânları"),
                  ],
                )
              "yacht" ->
                dom.element(
                  "div",
                  [
                    a.id("sec-3"),
                    a.class("wizard-step-panel"),
                    a.attribute("data-step-content", "3"),
                  ],
                  [
                    dom.element("div", [a.class("step-heading")], [
                      dom.element("span", [a.class("step-badge")], [
                        text("Adım 3 / 7"),
                      ]),
                      dom.element("h3", [], [
                        text("Tekne, Kabin & Seyir Donanımı"),
                      ]),
                      dom.element("p", [a.class("muted")], [
                        text(
                          "Yat, gulet veya katamaranınızın kabin sayısı, yatak kapasitesi, mürettebat ve bağlama limanını belirleyin.",
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Tekne Türü"),
                        dom.element(
                          "select",
                          [
                            a.name("boat_type"),
                            a.id("input-boat-type"),
                            a.attribute("data-managed-filter-category", "yacht"),
                            a.attribute("data-managed-filter-key", "yacht_type"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "gulet")],
                              [text("Lüks Gulet (Ahşap Yat)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "motoryacht")],
                              [text("Motoryat (VIP)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "catamaran")],
                              [text("Katamaran")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "sailboat")],
                              [text("Yelkenli Yat")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "speedboat")],
                              [text("Sürat Teknesi / Günlük Tur")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Toplam Kabin Sayısı"),
                        dom.element(
                          "input",
                          [
                            a.name("cabin_count"),
                            a.id("input-cabin-count"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("value", "4"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Misafir Yatak Kapasitesi"),
                        dom.element(
                          "input",
                          [
                            a.name("berth_count"),
                            a.id("input-berth-count"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("value", "8"),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Kaptan & Mürettebat"),
                        dom.element(
                          "select",
                          [a.name("crew_status"), a.id("input-crew-status")],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "captain_and_chef")],
                              [text("Kaptan + Aşçı + Gemici Dahil")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "captain_only")],
                              [text("Sadece Kaptan Dahil")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "bareboat")],
                              [text("Kaptansız (Bareboat)")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Seyir Yakıtı Durumu"),
                        dom.element(
                          "select",
                          [a.name("fuel_policy"), a.id("input-fuel-policy")],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "included")],
                              [text("Seyir Yakıtı Fiyata Dahil")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "excluded")],
                              [text("Yakıt Misafire Ait (Kullanım Kadar)")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Tekne Boyu (Metre)"),
                        dom.element(
                          "input",
                          [
                            a.name("boat_length"),
                            a.id("input-boat-length"),
                            a.attribute("placeholder", "Örn: 24 Metre"),
                            a.attribute("value", "24 Metre"),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-2")], [
                      dom.element("label", [], [
                        text("Bağlama Limanı / Marina"),
                        dom.element(
                          "input",
                          [
                            a.name("port_name"),
                            a.id("input-port-name"),
                            a.attribute(
                              "placeholder",
                              "Örn: Göcek Belediye Marina / D-Marin",
                            ),
                            a.attribute("value", "Göcek Belediye Marina"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Tur Giriş & Çıkış Saatleri"),
                        dom.element(
                          "input",
                          [
                            a.name("check_times"),
                            a.id("input-boat-times"),
                            a.attribute(
                              "placeholder",
                              "Cumartesi 15:00 Giriş / Cumartesi 10:00 Çıkış",
                            ),
                            a.attribute(
                              "value",
                              "Cumartesi 15:00 Giriş / Cumartesi 10:00 Çıkış",
                            ),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    step_footer_nav("2", "4", "Sonraki Adım: Tekne Donanımları"),
                  ],
                )
              "tour" | "activity" ->
                dom.element(
                  "div",
                  [
                    a.id("sec-3"),
                    a.class("wizard-step-panel"),
                    a.attribute("data-step-content", "3"),
                  ],
                  [
                    dom.element("div", [a.class("step-heading")], [
                      dom.element("span", [a.class("step-badge")], [
                        text("Adım 3 / 7"),
                      ]),
                      dom.element("h3", [], [
                        text("Tur Süresi, Rota & Hizmet Kapsamı"),
                      ]),
                      dom.element("p", [a.class("muted")], [
                        text(
                          "Düzenlediğiniz turun süresini, kalkış noktasını, rehber dillerini ve fiyata dahil hizmetleri belirleyin.",
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Tur / Aktivite Süresi"),
                        dom.element(
                          "select",
                          [
                            a.name("duration_hours"),
                            a.id("input-duration-hours"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "full_day")],
                              [text("Tam Gün (09:00 - 18:00)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "half_day")],
                              [text("Yarım Gün (4-5 Saat)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "multi_day")],
                              [text("Konaklamalı (2+ Gün)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "hourly")],
                              [text("Saatlik (1-3 Saat)")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Zorluk Derecesi"),
                        dom.element(
                          "select",
                          [
                            a.name("difficulty_level"),
                            a.id("input-difficulty-level"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "easy")],
                              [text("Kolay / Her Yaşa & Aileye Uygun")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "medium")],
                              [text("Orta Seviye")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "hard")],
                              [text("Zor / Macera & Adrenalin")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Rehber Dilleri"),
                        dom.element(
                          "input",
                          [
                            a.name("guide_languages"),
                            a.id("input-guide-languages"),
                            a.attribute(
                              "placeholder",
                              "Türkçe, İngilizce, Rusça",
                            ),
                            a.attribute("value", "Türkçe, İngilizce, Rusça"),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-2")], [
                      dom.element("label", [], [
                        text("Kalkış & Buluşma Noktası"),
                        dom.element(
                          "input",
                          [
                            a.name("meeting_point"),
                            a.id("input-meeting-point"),
                            a.attribute(
                              "placeholder",
                              "Örn: Otel Lobisinden Alış veya Marina İskelesi",
                            ),
                            a.attribute(
                              "value",
                              "Otel Lobisinden Alış veya Marina İskelesi",
                            ),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Maks. Grup Kontenjanı"),
                        dom.element(
                          "input",
                          [
                            a.name("group_size"),
                            a.id("input-group-size"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("value", "16"),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    step_footer_nav("2", "4", "Sonraki Adım: Tur Hizmetleri"),
                  ],
                )
              "car" | "transfer" ->
                dom.element(
                  "div",
                  [
                    a.id("sec-3"),
                    a.class("wizard-step-panel"),
                    a.attribute("data-step-content", "3"),
                  ],
                  [
                    dom.element("div", [a.class("step-heading")], [
                      dom.element("span", [a.class("step-badge")], [
                        text("Adım 3 / 7"),
                      ]),
                      dom.element("h3", [], [
                        text("Araç Sınıfı, Şanzıman & Kiralama Koşulları"),
                      ]),
                      dom.element("p", [a.class("muted")], [
                        text(
                          "Kiralık aracın veya transfer aracının sınıfını, vites, yakıt ve asgari sürücü şartlarını belirleyin.",
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Araç Segmenti"),
                        dom.element(
                          "select",
                          [
                            a.name("vehicle_segment"),
                            a.id("input-vehicle-segment"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "suv")],
                              [text("Lüks SUV & 4x4")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "vip_minivan")],
                              [text("VIP Mercedes Vito / Transporter")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "economy")],
                              [text("Ekonomik Hatchback / Sedan")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "luxury_sedan")],
                              [text("Premium / Lüks Sedan")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "cabrio")],
                              [text("Cabrio / Üstü Açık")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Vites Türü"),
                        dom.element(
                          "select",
                          [a.name("transmission"), a.id("input-transmission")],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "automatic")],
                              [text("Tam Otomatik")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "manual")],
                              [text("Manuel (Düz Vites)")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Yakıt Türü"),
                        dom.element(
                          "select",
                          [a.name("fuel_type"), a.id("input-fuel-type")],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "diesel")],
                              [text("Dizel")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "gasoline")],
                              [text("Benzin")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "hybrid")],
                              [text("Hibrit")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "electric")],
                              [text("Tam Elektrikli")],
                            ),
                          ],
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Yolcu & Bagaj Kapasitesi"),
                        dom.element(
                          "input",
                          [
                            a.name("car_capacity"),
                            a.id("input-car-capacity"),
                            a.attribute(
                              "placeholder",
                              "5 Yolcu + 3 Büyük Valiz",
                            ),
                            a.attribute("value", "5 Yolcu + 3 Büyük Valiz"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Kredi Kartı Provizyon (Depozito)"),
                        dom.element(
                          "input",
                          [
                            a.name("car_deposit"),
                            a.id("input-car-deposit"),
                            a.attribute("placeholder", "Örn: 5.000 TL"),
                            a.attribute("value", "5.000 TL"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Asgari Yaş & Ehliyet Şartı"),
                        dom.element(
                          "input",
                          [
                            a.name("driver_requirement"),
                            a.id("input-driver-req"),
                            a.attribute(
                              "placeholder",
                              "Min. 23 Yaş & 2 Yıllık Ehliyet",
                            ),
                            a.attribute(
                              "value",
                              "Min. 23 Yaş & 2 Yıllık Ehliyet",
                            ),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    step_footer_nav("2", "4", "Sonraki Adım: Araç Donanımları"),
                  ],
                )
              "holiday_home" ->
                dom.element(
                  "div",
                  [
                    a.id("sec-3"),
                    a.class("wizard-step-panel"),
                    a.attribute("data-step-content", "3"),
                  ],
                  [
                    dom.element("div", [a.class("step-heading")], [
                      dom.element("span", [a.class("step-badge")], [
                        text("Adım 3 / 7"),
                      ]),
                      dom.element("h3", [], [
                        text("Kapasite, Odalar & Özel Havuz Detayları"),
                      ]),
                      dom.element("p", [a.class("muted")], [
                        text(
                          "Müstakil villanın misafir kapasitesini, yatak odası/banyo sayısını ve özel havuz ölçülerini girin.",
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-4")], [
                      dom.element("label", [], [
                        text("Maks. Misafir"),
                        dom.element(
                          "input",
                          [
                            a.name("guests"),
                            a.id("input-guests"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("value", "8"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Yatak Odası"),
                        dom.element(
                          "input",
                          [
                            a.name("bedrooms"),
                            a.id("input-bedrooms"),
                            a.type_("number"),
                            a.attribute("min", "0"),
                            a.attribute("value", "4"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Yatak Sayısı"),
                        dom.element(
                          "input",
                          [
                            a.name("beds"),
                            a.id("input-beds"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("value", "5"),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Banyo Sayısı"),
                        dom.element(
                          "input",
                          [
                            a.name("bathrooms"),
                            a.id("input-bathrooms"),
                            a.type_("number"),
                            a.attribute("min", "1"),
                            a.attribute("value", "4"),
                          ],
                          [],
                        ),
                      ]),
                    ]),
                    dom.element("div", [a.class("form-grid-3")], [
                      dom.element("label", [], [
                        text("Özel Havuz Ölçüleri (En x Boy x Derinlik)"),
                        dom.element(
                          "input",
                          [
                            a.name("pool_dimensions"),
                            a.id("input-pool-dimensions"),
                            a.attribute(
                              "placeholder",
                              "Örn: 4x10m Derinlik 1.55m (Sonsuzluk Havuzu)",
                            ),
                            a.attribute(
                              "value",
                              "4x10m Derinlik 1.55m (Sonsuzluk Havuzu)",
                            ),
                          ],
                          [],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Korunaklı / Muhafazakar Durumu"),
                        dom.element(
                          "select",
                          [
                            a.name("sheltered_pool"),
                            a.id("input-sheltered-pool"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "true")],
                              [
                                text(
                                  "Evet (%100 Korunaklı - Dışarıdan Görünmez)",
                                ),
                              ],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "false")],
                              [text("Hayır (Standart / Yarı Korunaklı)")],
                            ),
                          ],
                        ),
                      ]),
                      dom.element("label", [], [
                        text("Havuz Isıtma Durumu"),
                        dom.element(
                          "select",
                          [
                            a.name("pool_heating_status"),
                            a.id("input-pool-heating-status"),
                          ],
                          [
                            dom.element(
                              "option",
                              [a.attribute("value", "heated")],
                              [text("Isıtmalı Havuz (Aktif)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "optional")],
                              [text("Opsiyonel (Ücretli Isıtma)")],
                            ),
                            dom.element(
                              "option",
                              [a.attribute("value", "none")],
                              [text("Isıtma Yok (Standart Havuz)")],
                            ),
                          ],
                        ),
                      ]),
                    ]),
                    dom.element("label", [a.class("field-wide")], [
                      text("Bakanlık Turizm İzin Belge / Ruhsat No"),
                      dom.element(
                        "input",
                        [
                          a.name("ministry_license_no"),
                          a.id("input-license-no"),
                          a.attribute("placeholder", "Örn: 48-1234"),
                          a.attribute("value", "48-1234"),
                        ],
                        [],
                      ),
                    ]),
                    step_footer_nav(
                      "2",
                      "4",
                      "Sonraki Adım: Donanım & Olanaklar",
                    ),
                  ],
                )
              _ -> category_general_step3(effective_cat)
            },

            // STEP 4: Olanaklar & Donanımlar (16 Sektöre Göre Özel Donanımlar)
            dom.element(
              "div",
              [
                a.id("sec-4"),
                a.class("wizard-step-panel"),
                a.attribute("data-step-content", "4"),
              ],
              [
                dom.element("div", [a.class("step-heading")], [
                  dom.element("span", [a.class("step-badge")], [
                    text("Adım 4 / 7"),
                  ]),
                  dom.element("h3", [], [
                    text(case effective_cat {
                      "hotel" -> "Otel & Tesis İmkânları"
                      "yacht" -> "Tekne & Seyir Donanımları"
                      "tour" | "activity" ->
                        "Dahil Olan Ayrıcalıklar & Güvenlik"
                      "car" | "transfer" -> "Araç Donanımı & Kasko Hizmetleri"
                      "holiday_home" -> "Tatil Evi Donanımları & İmkânları"
                      _ -> "Ürün Olanakları & Hizmet Kapsamı"
                    }),
                  ]),
                  dom.element("p", [a.class("muted")], [
                    text(
                      "Misafirlerin filtreleme yaparken göreceği olanakları tıklayarak seçin.",
                    ),
                  ]),
                ]),
                dom.element(
                  "div",
                  [a.class("amenities-chips-grid")],
                  case effective_cat {
                    "hotel" -> [
                      wizard_amenity_chip(
                        "private_beach",
                        "🏖️",
                        "Özel Plaj & İskele (Mavi Bayrak)",
                      ),
                      wizard_amenity_chip("open_pool", "🏊", "Açık Yüzme Havuzu"),
                      wizard_amenity_chip(
                        "aquapark",
                        "🌊",
                        "Aquapark & Su Kaydırakları",
                      ),
                      wizard_amenity_chip(
                        "heated_indoor_pool",
                        "♨️",
                        "Isıtmalı Kapalı Havuz",
                      ),
                      wizard_amenity_chip(
                        "spa_hamam",
                        "🧖",
                        "Spa, Masaj & Türk Hamamı",
                      ),
                      wizard_amenity_chip(
                        "alacarte",
                        "🍽️",
                        "Alakart Restoranlar",
                      ),
                      wizard_amenity_chip(
                        "kids_club",
                        "🧒",
                        "Mini Club & Çocuk Kulübü",
                      ),
                      wizard_amenity_chip(
                        "all_inclusive_bar",
                        "🍸",
                        "Havuz & Sahil Bar (All-Inclusive)",
                      ),
                      wizard_amenity_chip(
                        "reception_24h",
                        "🛎️",
                        "24 Saat Resepsiyon",
                      ),
                      wizard_amenity_chip(
                        "fitness",
                        "🏋️",
                        "Fitness & Spor Salonu",
                      ),
                      wizard_amenity_chip(
                        "valet_parking",
                        "🚗",
                        "Ücretsiz Vale & Otopark",
                      ),
                      wizard_amenity_chip(
                        "room_service",
                        "🛎️",
                        "24 Saat Oda Servisi",
                      ),
                      wizard_amenity_chip(
                        "wifi",
                        "📶",
                        "Yüksek Hızlı Wi-Fi (Tüm Tesis)",
                      ),
                      wizard_amenity_chip(
                        "airport_shuttle",
                        "🚐",
                        "Havalimanı VIP Transfer",
                      ),
                      wizard_amenity_chip(
                        "conference_room",
                        "💼",
                        "Toplantı & Kongre Salonu",
                      ),
                      wizard_amenity_chip(
                        "live_music",
                        "🎭",
                        "Canlı Müzik & Gece Şovları",
                      ),
                      wizard_amenity_chip("tennis_court", "🎾", "Tenis Kortu"),
                      wizard_amenity_chip(
                        "wheelchair_access",
                        "♿",
                        "Engelsiz / Engelli Dostu",
                      ),
                    ]
                    "yacht" -> [
                      wizard_amenity_chip("skipper", "👨‍✈️", "Kaptan & Mürettebat"),
                      wizard_amenity_chip("fuel", "⛽", "Seyir Yakıtı Dahil"),
                      wizard_amenity_chip("ac", "❄️", "Tüm Kabinlerde Klima"),
                      wizard_amenity_chip("wifi", "📶", "Uydu İnterneti / Wi-Fi"),
                      wizard_amenity_chip(
                        "water_sports",
                        "🏄",
                        "Su Sporları & Kano / SUP",
                      ),
                      wizard_amenity_chip(
                        "snorkel",
                        "🤿",
                        "Şnorkel & Balıkçılık Takımı",
                      ),
                      wizard_amenity_chip(
                        "sound_system",
                        "🔊",
                        "Bluetooth Müzik Sistemi",
                      ),
                      wizard_amenity_chip(
                        "dinghy",
                        "🚤",
                        "Servis Botu (Zodyak & Motor)",
                      ),
                      wizard_amenity_chip(
                        "ice_maker",
                        "🧊",
                        "Buz Makinesi & Derin Dondurucu",
                      ),
                      wizard_amenity_chip(
                        "generator",
                        "⚡",
                        "Jeneratör & 220V Elektrik",
                      ),
                      wizard_amenity_chip(
                        "sunbeds",
                        "☀️",
                        "Güneşlenme Minderleri & Tente",
                      ),
                      wizard_amenity_chip(
                        "sea_ladder",
                        "🪜",
                        "Yüzme Merdiveni & Platform",
                      ),
                    ]
                    "tour" | "activity" -> [
                      wizard_amenity_chip(
                        "licensed_guide",
                        "🧭",
                        "Profesyonel Lisanslı Rehber",
                      ),
                      wizard_amenity_chip(
                        "hotel_transfer",
                        "🚐",
                        "Otelden / Otele VIP Transfer",
                      ),
                      wizard_amenity_chip(
                        "lunch_included",
                        "🍽️",
                        "Öğle Yemeği Dahil",
                      ),
                      wizard_amenity_chip(
                        "entrance_tickets",
                        "🎟️",
                        "Müze & Örenyeri Giriş Biletleri",
                      ),
                      wizard_amenity_chip(
                        "travel_insurance",
                        "🛡️",
                        "Kişisel Seyahat Sigortası",
                      ),
                      wizard_amenity_chip(
                        "equipment",
                        "🦺",
                        "Tüm Güvenlik ve Spor Ekipmanları",
                      ),
                      wizard_amenity_chip(
                        "photo_video",
                        "📸",
                        "Aksiyon Kamera / Drone Çekimi",
                      ),
                      wizard_amenity_chip(
                        "drink_included",
                        "🥤",
                        "İçecek ve Aperitif İkramı",
                      ),
                    ]
                    "car" | "transfer" -> [
                      wizard_amenity_chip(
                        "full_insurance",
                        "🛡️",
                        "Tam Kaza ve Hırsızlık Sigortası (CDW)",
                      ),
                      wizard_amenity_chip(
                        "unlimited_km",
                        "🛣️",
                        "Sınırsız Kilometre",
                      ),
                      wizard_amenity_chip("auto_trans", "🕹️", "Otomatik Vites"),
                      wizard_amenity_chip(
                        "extra_driver",
                        "👤",
                        "Ücretsiz 2. Sürücü",
                      ),
                      wizard_amenity_chip(
                        "baby_seat",
                        "👶",
                        "Bebek / Çocuk Koltuğu",
                      ),
                      wizard_amenity_chip(
                        "airport_delivery",
                        "✈️",
                        "Havalimanında Ücretsiz Teslimat",
                      ),
                      wizard_amenity_chip(
                        "road_assist",
                        "🔧",
                        "7/24 Kesintisiz Yol Yardımı",
                      ),
                      wizard_amenity_chip(
                        "no_deposit",
                        "💳",
                        "Düşük / Kart Blokesiz Depozito",
                      ),
                    ]
                    "cruise" -> [
                      wizard_amenity_chip(
                        "balcony_cabin",
                        "🌊",
                        "Balkonlu Kabin İmkanı",
                      ),
                      wizard_amenity_chip(
                        "all_inclusive_dining",
                        "🍽️",
                        "Her Şey Dahil Alakart & Büfe",
                      ),
                      wizard_amenity_chip(
                        "pool_deck",
                        "🏊",
                        "Açık Güverte Yüzme Havuzu",
                      ),
                      wizard_amenity_chip(
                        "spa_wellness",
                        "🧖",
                        "Lüks Spa, Masaj & Termal Alan",
                      ),
                      wizard_amenity_chip(
                        "casino_theater",
                        "🎭",
                        "Casino, Broadway Şovları & Tiyatro",
                      ),
                      wizard_amenity_chip(
                        "duty_free",
                        "🛍️",
                        "Duty-Free Alışveriş Alanları",
                      ),
                      wizard_amenity_chip(
                        "kids_club",
                        "🧒",
                        "Çocuk & Genç Kulübü (Mini Club)",
                      ),
                      wizard_amenity_chip(
                        "shore_excursions",
                        "🧭",
                        "Rehberli Liman & Şehir Turları",
                      ),
                      wizard_amenity_chip(
                        "satellite_wifi",
                        "📶",
                        "Uydu İnterneti & Wi-Fi",
                      ),
                      wizard_amenity_chip(
                        "room_service",
                        "🛎️",
                        "24 Saat Kabin Servisi",
                      ),
                    ]
                    "flight" | "bus" | "ferry" -> [
                      wizard_amenity_chip("wifi", "📶", "Yüksek Hızlı Wi-Fi"),
                      wizard_amenity_chip(
                        "power_socket",
                        "🔌",
                        "USB & 220V Priz Bağlantısı",
                      ),
                      wizard_amenity_chip(
                        "seat_selection",
                        "💺",
                        "Ücretsiz Koltuk Seçimi",
                      ),
                      wizard_amenity_chip(
                        "catering",
                        "☕",
                        "Sıcak/Soğuk İkram & Yemek Servisi",
                      ),
                      wizard_amenity_chip(
                        "extra_baggage",
                        "🧳",
                        "Ekstra Bagaj Satın Alma",
                      ),
                      wizard_amenity_chip(
                        "tv_screen",
                        "📺",
                        "Kişisel Multimedya Ekranı",
                      ),
                      wizard_amenity_chip(
                        "priority_boarding",
                        "⚡",
                        "Öncelikli Biniş (Priority)",
                      ),
                      wizard_amenity_chip(
                        "air_conditioning",
                        "❄️",
                        "Gelişmiş İklimlendirme",
                      ),
                    ]
                    "restaurant" -> [
                      wizard_amenity_chip(
                        "sea_view",
                        "🌊",
                        "Deniz Manzaralı Teras",
                      ),
                      wizard_amenity_chip(
                        "valet",
                        "🚗",
                        "Ücretsiz Vale & Otopark",
                      ),
                      wizard_amenity_chip(
                        "sommelier",
                        "🍷",
                        "Sommelier & Zengin Şarap Kavı",
                      ),
                      wizard_amenity_chip(
                        "live_music",
                        "🎶",
                        "Canlı Akustik / Caz Performansı",
                      ),
                      wizard_amenity_chip(
                        "private_room",
                        "🚪",
                        "Özel VIP Yemek Odası",
                      ),
                      wizard_amenity_chip(
                        "vegan_menu",
                        "🥗",
                        "Vegan & Vejetaryen Seçenekler",
                      ),
                      wizard_amenity_chip(
                        "kids_friendly",
                        "👶",
                        "Çocuk Alanı & Mama Sandalyesi",
                      ),
                      wizard_amenity_chip(
                        "outdoor_seating",
                        "🌿",
                        "Bahçe & Açık Hava Masaları",
                      ),
                    ]
                    "beach" -> [
                      wizard_amenity_chip(
                        "vip_cabana",
                        "🛖",
                        "Özel VIP Loca / Cabana",
                      ),
                      wizard_amenity_chip(
                        "pier",
                        "⛵",
                        "Güneşlenme İskelesi & Merdiven",
                      ),
                      wizard_amenity_chip(
                        "towel_service",
                        "🧺",
                        "Ücretsiz Plaj Havlusu",
                      ),
                      wizard_amenity_chip(
                        "cocktail_bar",
                        "🍹",
                        "Sahil Kokteyl & Sushi Bar",
                      ),
                      wizard_amenity_chip(
                        "water_sports",
                        "🏄",
                        "Su Sporları & Jet Ski",
                      ),
                      wizard_amenity_chip(
                        "dj_music",
                        "🎧",
                        "Canlı DJ & Gün Batımı Partileri",
                      ),
                      wizard_amenity_chip(
                        "shower_cabin",
                        "🚿",
                        "Lüks Duş & Giyinme Kabinleri",
                      ),
                      wizard_amenity_chip(
                        "valet",
                        "🚗",
                        "Vale & Güvenli Otopark",
                      ),
                    ]
                    "visa" -> [
                      wizard_amenity_chip(
                        "document_review",
                        "📋",
                        "Uzman Evrak İnceleme & Kontrol",
                      ),
                      wizard_amenity_chip(
                        "form_filling",
                        "✍️",
                        "Resmi Başvuru Formu Doldurma",
                      ),
                      wizard_amenity_chip(
                        "early_appointment",
                        "📅",
                        "Erken Randevu Takibi",
                      ),
                      wizard_amenity_chip(
                        "translation",
                        "🗣️",
                        "Yeminli Tercüme & Noter Desteği",
                      ),
                      wizard_amenity_chip(
                        "travel_insurance",
                        "🛡️",
                        "30.000€ Teminatlı Seyahat Sigortası",
                      ),
                      wizard_amenity_chip(
                        "vip_escort",
                        "🤝",
                        "Başvuru Merkezinde Birebir Karşılama",
                      ),
                      wizard_amenity_chip(
                        "courier_delivery",
                        "📦",
                        "Pasaportun Adrese Kurye ile Teslimi",
                      ),
                    ]
                    "pilgrimage" -> [
                      wizard_amenity_chip(
                        "near_haram",
                        "🕋",
                        "Harem-i Şerif'e Yürüme Mesafesi",
                      ),
                      wizard_amenity_chip(
                        "buffet_dining",
                        "🍽️",
                        "Açık Büfe Türk Mutfağı Yemek",
                      ),
                      wizard_amenity_chip(
                        "religious_guide",
                        "📖",
                        "Deneyimli Din Görevlisi & Rehberlik",
                      ),
                      wizard_amenity_chip(
                        "vip_bus",
                        "🚌",
                        "Lüks Klimalı Transfer Araçları",
                      ),
                      wizard_amenity_chip(
                        "ihram_gift",
                        "🎁",
                        "İhram, Çanta & Rehber Kitap Seti",
                      ),
                      wizard_amenity_chip(
                        "medical_team",
                        "🩺",
                        "Türk Sağlık Ekibi & Doktor Desteği",
                      ),
                      wizard_amenity_chip(
                        "zamzam",
                        "💧",
                        "Dönüşte 5 Litre Zemzem İkramı",
                      ),
                      wizard_amenity_chip(
                        "ziyarat",
                        "🕌",
                        "Mekke & Medine Kutsal Ziyaret Turları",
                      ),
                    ]
                    "event" | "cinema" -> [
                      wizard_amenity_chip(
                        "vip_lounge",
                        "🥂",
                        "VIP Lounge & Ayrıcalıklı Giriş",
                      ),
                      wizard_amenity_chip(
                        "valet_parking",
                        "🚗",
                        "Ücretsiz Otopark & Vale",
                      ),
                      wizard_amenity_chip(
                        "catering_included",
                        "🍿",
                        "İkram, Aperitif & İçecek",
                      ),
                      wizard_amenity_chip(
                        "cloakroom",
                        "🧥",
                        "Ücretsiz Vestiyer Hizmeti",
                      ),
                      wizard_amenity_chip(
                        "disabled_access",
                        "♿",
                        "Engelsiz Erişim & Özel Koltuk",
                      ),
                      wizard_amenity_chip(
                        "premium_audio",
                        "🔊",
                        "Dolby Atmos & Yüksek Akustik",
                      ),
                    ]
                    _ -> [
                      wizard_amenity_chip("pool", "🏊", "Özel Müstakil Havuz"),
                      wizard_amenity_chip(
                        "sheltered",
                        "🛡️",
                        "%100 Korunaklı Havuz",
                      ),
                      wizard_amenity_chip(
                        "jacuzzi",
                        "♨️",
                        "Jakuzi & Sıcak Küvet",
                      ),
                      wizard_amenity_chip("bbq", "🥩", "Barbekü & Taş Fırın"),
                      wizard_amenity_chip(
                        "fireplace",
                        "🔥",
                        "Şömine & Odun Ateşi",
                      ),
                      wizard_amenity_chip(
                        "sea_view",
                        "🌊",
                        "Panoramik Deniz Manzarası",
                      ),
                      wizard_amenity_chip(
                        "sauna",
                        "🧖",
                        "Sauna & Dinlenme Odası",
                      ),
                      wizard_amenity_chip(
                        "ac",
                        "❄️",
                        "Tüm Odalarda Bağımsız Klima",
                      ),
                      wizard_amenity_chip(
                        "parking",
                        "🚗",
                        "Müstakil Özel Otopark",
                      ),
                      wizard_amenity_chip(
                        "wifi",
                        "📶",
                        "Yüksek Hızlı Fiber Wi-Fi",
                      ),
                      wizard_amenity_chip(
                        "pet_friendly",
                        "🐾",
                        "Evcil Hayvan Dostu",
                      ),
                      wizard_amenity_chip(
                        "baby_friendly",
                        "👶",
                        "Bebek Yatağı & Mama Sandalyesi",
                      ),
                      wizard_amenity_chip(
                        "ev_charge",
                        "⚡",
                        "Araç Şarj İstasyonu",
                      ),
                      wizard_amenity_chip(
                        "generator",
                        "⚡",
                        "Kesintisiz Jeneratör",
                      ),
                      wizard_amenity_chip(
                        "sunset_terrace",
                        "🌅",
                        "Gün Batımı Terası",
                      ),
                      wizard_amenity_chip(
                        "breakfast",
                        "🍳",
                        "Özel Kahvaltı Servisi",
                      ),
                      wizard_amenity_chip(
                        "boat_pier",
                        "⛵",
                        "Özel İskele / Bağlama",
                      ),
                      wizard_amenity_chip("smart_tv", "📺", "Smart TV & Netflix"),
                    ]
                  },
                ),
                step_footer_nav("3", "5", "Sonraki Adım: Fotoğraflar & Galeri"),
              ],
            ),

            // STEP 5: Fotoğraflar & Galeri
            dom.element(
              "div",
              [
                a.id("sec-5"),
                a.class("wizard-step-panel"),
                a.attribute("data-step-content", "5"),
              ],
              [
                dom.element("div", [a.class("step-heading")], [
                  dom.element("span", [a.class("step-badge")], [
                    text("Adım 5 / 7"),
                  ]),
                  dom.element("h3", [], [
                    text(case is_hotel {
                      True -> "Otel & Tesis Fotoğrafları"
                      False -> "Fotoğraflar & Medya Galerisi"
                    }),
                  ]),
                  dom.element("p", [a.class("muted")], [
                    text(case is_hotel {
                      True ->
                        "Tesis genel görünümü, plaj, havuz, restoran ve oda fotoğraflarını ekleyin."
                      False ->
                        "İlanınızın vitrinini oluşturacak yüksek kaliteli görselleri ekleyin. İlk görsel kapak fotoğrafı olur."
                    }),
                  ]),
                ]),
                dom.element(
                  "div",
                  [a.id("photo-dropzone"), a.class("photo-dropzone")],
                  [
                    dom.element(
                      "input",
                      [
                        a.id("photo-file-input"),
                        a.type_("file"),
                        a.attribute("multiple", "multiple"),
                        a.attribute("accept", "image/*"),
                        a.attribute("aria-label", "Fotoğraf dosyaları seç"),
                        a.attribute("style", "display:none;"),
                      ],
                      [],
                    ),
                    dom.element("span", [a.class("dropzone-icon")], [text("📸")]),
                    dom.element("div", [a.class("dropzone-texts")], [
                      dom.element("strong", [], [
                        text(
                          "Bilgisayarınızdan Fotoğrafları Seçin veya Sürükleyin",
                        ),
                      ]),
                      dom.element("span", [a.class("muted")], [
                        text(
                          "JPG, PNG, WebP formatları desteklenir. İlk fotoğraf vitrin kapağı olur.",
                        ),
                      ]),
                    ]),
                    dom.element(
                      "button",
                      [
                        a.attribute("type", "button"),
                        a.class("btn-browse-photos"),
                        a.id("btn-browse-photos"),
                      ],
                      [text("📁 Dosya Seç")],
                    ),
                  ],
                ),
                dom.element("div", [a.class("media-url-adder")], [
                  dom.element("span", [a.class("muted-label")], [
                    text("veya Web Görsel URL'si ile ekle:"),
                  ]),
                  dom.element(
                    "input",
                    [
                      a.id("media-new-url-input"),
                      a.attribute("type", "url"),
                      a.attribute(
                        "aria-label",
                        "Web görsel URL'si ile fotoğraf ekle",
                      ),
                      a.attribute(
                        "placeholder",
                        "Fotoğraf URL'si yapıştırın (https://...)",
                      ),
                    ],
                    [],
                  ),
                  dom.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("btn-add-photo"),
                      a.id("btn-add-photo"),
                    ],
                    [
                      text("+ Ekle"),
                    ],
                  ),
                ]),
                dom.element(
                  "div",
                  [
                    a.class("photos-preview-gallery"),
                    a.id("wizard-photos-gallery"),
                  ],
                  [
                    dom.element("div", [a.class("gallery-empty-note")], [
                      text(
                        "Henüz görsel eklenmedi. Yukarıdan fotoğraf seçebilir veya URL yapıştırabilirsiniz.",
                      ),
                    ]),
                  ],
                ),
                step_footer_nav(
                  "4",
                  "6",
                  "Sonraki Adım: Fiyat & Satış Koşulları",
                ),
              ],
            ),
            // STEP 6: Fiyatlandırma, Satış Koşulları & Takvim (17 Kategoriye Özel)
            category_pricing_step6(effective_cat, is_hotel),

            // STEP 7: Önizleme, Açıklama, SEO & Onay
            dom.element(
              "div",
              [
                a.id("sec-7"),
                a.class("wizard-step-panel"),
                a.attribute("data-step-content", "7"),
              ],
              [
                dom.element("div", [a.class("step-heading")], [
                  dom.element("span", [a.class("step-badge")], [
                    text("Adım 7 / 7"),
                  ]),
                  dom.element("h3", [], [
                    text("Tanıtım Açıklaması, SEO & Yayınlama"),
                  ]),
                  dom.element("p", [a.class("muted")], [
                    text(
                      "İlanınızın zengin açıklamasını, arama motoru (Google) SEO başlıklarını ve slug yapısını belirleyin.",
                    ),
                  ]),
                ]),
                dom.element("label", [a.class("field-wide")], [
                  text("Detaylı Tanıtım Açıklaması"),
                  dom.element(
                    "textarea",
                    [
                      a.name("description"),
                      a.id("input-description"),
                      a.class("rich-textarea"),
                      a.attribute("data-rich-editor", "true"),
                      a.attribute("rows", "5"),
                      a.attribute(
                        "placeholder",
                        "Mülkün mimarisi, manzarası, oda detayları ve çevresi hakkında açıklama...",
                      ),
                    ],
                    [],
                  ),
                ]),
                dom.element("div", [a.class("step-quick-action")], [
                  dom.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("btn-ai-enhance"),
                      a.id("btn-ai-desc"),
                    ],
                    [
                      text("✨ AI ile Açıklamayı Zenginleştir"),
                    ],
                  ),
                  dom.element(
                    "button",
                    [
                      a.attribute("type", "button"),
                      a.class("btn-ai-enhance btn-ai-translate-glow"),
                      a.id("btn-ai-translate-6"),
                    ],
                    [
                      text("🌍 AI ile 6 Dile Çevir (EN, DE, RU, ZH, FR)"),
                    ],
                  ),
                ]),
                dom.element(
                  "div",
                  [
                    a.id("ai-translations-card"),
                    a.class("ai-translations-card hidden"),
                  ],
                  [
                    dom.element("div", [a.class("translations-card-header")], [
                      dom.element("div", [a.class("trans-title-wrap")], [
                        dom.element("span", [a.class("badge-polyglot")], [
                          text("🌐 6 DİL OTOMATİK ÇEVİRİ MERKEZİ (AI)"),
                        ]),
                        dom.element("p", [a.class("muted-polyglot")], [
                          text(
                            "Başlık ve açıklama çok dilli misafirler için hazırlandı. İnceleyip dilediğiniz gibi düzenleyebilirsiniz.",
                          ),
                        ]),
                      ]),
                      dom.element(
                        "button",
                        [
                          a.attribute("type", "button"),
                          a.class("btn-close-trans-card"),
                          a.id("btn-close-trans-card"),
                        ],
                        [text("✕ Kapat")],
                      ),
                    ]),
                    dom.element(
                      "div",
                      [
                        a.id("translations-tabs-bar"),
                        a.class("translations-tabs-bar"),
                      ],
                      [
                        dom.element(
                          "button",
                          [
                            a.attribute("type", "button"),
                            a.class("trans-tab-btn active"),
                            a.attribute("data-lang", "en"),
                          ],
                          [text("🇬🇧 English")],
                        ),
                        dom.element(
                          "button",
                          [
                            a.attribute("type", "button"),
                            a.class("trans-tab-btn"),
                            a.attribute("data-lang", "de"),
                          ],
                          [text("🇩🇪 Deutsch")],
                        ),
                        dom.element(
                          "button",
                          [
                            a.attribute("type", "button"),
                            a.class("trans-tab-btn"),
                            a.attribute("data-lang", "ru"),
                          ],
                          [text("🇷🇺 Русский")],
                        ),
                        dom.element(
                          "button",
                          [
                            a.attribute("type", "button"),
                            a.class("trans-tab-btn"),
                            a.attribute("data-lang", "zh"),
                          ],
                          [text("🇨🇳 中文")],
                        ),
                        dom.element(
                          "button",
                          [
                            a.attribute("type", "button"),
                            a.class("trans-tab-btn"),
                            a.attribute("data-lang", "fr"),
                          ],
                          [text("🇫🇷 Français")],
                        ),
                      ],
                    ),
                    dom.element(
                      "div",
                      [
                        a.id("trans-content-panel"),
                        a.class("trans-content-panel"),
                      ],
                      [],
                    ),
                  ],
                ),

                // AI SEO MODULE
                dom.element("div", [a.class("ai-seo-module-card")], [
                  dom.element("div", [a.class("seo-card-header")], [
                    dom.element("div", [a.class("seo-header-title")], [
                      dom.element("span", [a.class("seo-icon")], [text("🔍")]),
                      dom.element("h4", [], [
                        text("Yapay Zeka Destekli SEO & Meta Modülü"),
                      ]),
                    ]),
                    dom.element(
                      "button",
                      [
                        a.attribute("type", "button"),
                        a.class("btn-ai-pill"),
                        a.id("btn-ai-seo"),
                      ],
                      [text("✨ AI ile SEO ve Snippet Üret")],
                    ),
                  ]),
                  dom.element("div", [a.class("form-grid-2")], [
                    dom.element("label", [], [
                      text("Google SEO Başlığı (Meta Title)"),
                      dom.element(
                        "input",
                        [
                          a.name("seo_title"),
                          a.id("input-seo-title"),
                          a.attribute("maxlength", "70"),
                          a.attribute("placeholder", case is_hotel {
                            True ->
                              "Bodrum Luxury Resort & Spa | 5 Yıldızlı Ultra Her Şey Dahil Otel"
                            False ->
                              "Bodrum Yalıkavak Lüks Kiralık Havuzlu Villa | Acente Adı"
                          }),
                        ],
                        [],
                      ),
                      dom.element(
                        "span",
                        [a.class("field-hint"), a.id("seo-title-count")],
                        [text("0 / 60 karakter")],
                      ),
                    ]),
                    dom.element("label", [], [
                      text("URL Kalıcı Bağlantı (Slug)"),
                      dom.element(
                        "input",
                        [
                          a.name("seo_slug"),
                          a.id("input-seo-slug"),
                          a.attribute("placeholder", case is_hotel {
                            True ->
                              "bodrum-luxury-resort-spa-ultra-all-inclusive"
                            False ->
                              "bodrum-yalikavak-luks-kiralik-havuzlu-villa"
                          }),
                        ],
                        [],
                      ),
                      dom.element("span", [a.class("field-hint")], [
                        text("Örn: bodrum-kiralik-villa"),
                      ]),
                    ]),
                  ]),
                  dom.element("label", [a.class("field-wide")], [
                    text("Google Arama Açıklaması (Meta Description)"),
                    dom.element(
                      "textarea",
                      [
                        a.name("seo_description"),
                        a.id("input-seo-desc"),
                        a.attribute("rows", "2"),
                        a.attribute("maxlength", "170"),
                        a.attribute("placeholder", case is_hotel {
                          True ->
                            "Bodrum Torba mevkiinde denize sıfır, özel plajlı, spa ve aquapark olanaklarına sahip 5 yıldızlı ultra her şey dahil resort otel. Hemen rezervasyon yapın."
                          False ->
                            "Bodrum Yalıkavak'ta özel havuzlu, panoramik deniz manzaralı ve 4 yatak odalı lüks kiralık tatil villası. En iyi fiyat garantisiyle doğrudan acente rezervasyonu."
                        }),
                      ],
                      [],
                    ),
                    dom.element(
                      "span",
                      [a.class("field-hint"), a.id("seo-desc-count")],
                      [text("0 / 160 karakter")],
                    ),
                  ]),
                  dom.element("div", [a.class("seo-serp-preview")], [
                    dom.element("div", [a.class("serp-header")], [
                      dom.element("span", [a.class("serp-badge")], [
                        text("Google Arama Sonucu Görünümü"),
                      ]),
                    ]),
                    dom.element("div", [a.class("serp-url-row")], [
                      dom.element("span", [a.class("serp-site")], [
                        text("https://acente.com"),
                      ]),
                      dom.element(
                        "span",
                        [a.class("serp-path"), a.id("serp-preview-slug")],
                        [
                          text(case is_hotel {
                            True -> " › otel › bodrum-luxury-resort"
                            False -> " › villa › bodrum-yalikavak-villa"
                          }),
                        ],
                      ),
                    ]),
                    dom.element(
                      "div",
                      [a.class("serp-title"), a.id("serp-preview-title")],
                      [
                        text(case is_hotel {
                          True ->
                            "Bodrum Luxury Resort & Spa | 5 Yıldızlı Ultra Her Şey Dahil Otel"
                          False -> "Bodrum Yalıkavak Lüks Kiralık Havuzlu Villa"
                        }),
                      ],
                    ),
                    dom.element(
                      "div",
                      [a.class("serp-snippet"), a.id("serp-preview-desc")],
                      [
                        text(case is_hotel {
                          True ->
                            "Bodrum Torba mevkiinde denize sıfır, özel plajlı, spa ve aquapark olanaklarına sahip 5 yıldızlı ultra her şey dahil resort otel. Hemen rezervasyon yapın."
                          False ->
                            "Bodrum Yalıkavak'ta özel havuzlu, panoramik deniz manzaralı ve 4 yatak odalı lüks kiralık tatil villası. En iyi fiyat garantisiyle doğrudan acente rezervasyonu."
                        }),
                      ],
                    ),
                  ]),
                ]),

                dom.element("div", [a.class("wizard-summary-box")], [
                  dom.element("h4", [], [text("✓ İlan Özeti")]),
                  dom.element("p", [a.id("summary-text")], [
                    text(
                      "Tüm adımlardaki zorunlu bilgiler doldurulduğunda ilanınız doğrudan acente kataloğuna ve rezervasyon motoruna bağlanacaktır.",
                    ),
                  ]),
                ]),
                step_footer_submit("6"),
              ],
            ),

            // WIZARD CONTROLS (Prev / Next / Publish)
            dom.element("div", [a.class("wizard-nav-bar")], [
              dom.element(
                "button",
                [
                  a.attribute("type", "button"),
                  a.class("wizard-nav-btn btn-prev"),
                  a.id("btn-wizard-prev"),
                ],
                [text("← Önceki Adım")],
              ),
              dom.element("div", [a.class("wizard-step-counter")], [
                dom.element(
                  "span",
                  [
                    a.id("wizard-step-text"),
                    a.attribute("aria-live", "polite"),
                  ],
                  [text("Adım 1 / 7")],
                ),
              ]),
              dom.element(
                "button",
                [
                  a.attribute("type", "button"),
                  a.class("wizard-nav-btn btn-next"),
                  a.id("btn-wizard-next"),
                ],
                [text("Sonraki Adım: Konum →")],
              ),
              dom.element(
                "button",
                [
                  a.type_("submit"),
                  a.class("wizard-submit-btn hidden"),
                  a.id("btn-wizard-submit"),
                ],
                [text("🚀 Kataloğa Kaydet ve Yayınla")],
              ),
            ]),
          ]),
        ],
      ),
      dom.element("div", [a.class("table-wrap catalog-listings-table")], [
        dom.element("div", [a.class("table-header-bar")], [
          dom.element("div", [a.class("table-title-area")], [
            dom.element("h3", [a.class("table-section-title")], [
              text("Kayıtlı İlanlar & Hizmet Envanteri"),
            ]),
            dom.element(
              "span",
              [a.id("listings-count-badge"), a.class("count-badge")],
              [text("0 İlan")],
            ),
          ]),
          dom.element("div", [a.class("table-actions-area")], [
            dom.element(
              "button",
              [
                a.attribute("type", "button"),
                a.id("btn-table-new-listing"),
                a.class("btn-table-new"),
              ],
              [text("➕ Yeni İlan Ekle")],
            ),
          ]),
        ]),
        dom.element(
          "table",
          [
            a.class("data-table"),
            a.attribute("data-bulk-table", "true"),
            a.attribute("data-bulk-label", "ilan"),
          ],
          [
            dom.element("thead", [], [
              dom.element("tr", [], [
                dom.element("th", [], [text("Kod")]),
                dom.element("th", [], [text("Başlık")]),
                dom.element("th", [], [text("Kategori")]),
                dom.element("th", [], [text("Konum")]),
                dom.element("th", [], [text("Fiyat")]),
                dom.element("th", [], [text("Durum")]),
                dom.element("th", [], [text("Hazırlık")]),
                dom.element("th", [a.class("text-right")], [text("İşlem")]),
              ]),
            ]),
            dom.element("tbody", [a.id("listings-table-body")], [
              dom.element("tr", [], [
                dom.element(
                  "td",
                  [a.attribute("colspan", "7"), a.class("empty-state")],
                  [text("Katalog yükleniyor…")],
                ),
              ]),
            ]),
          ],
        ),
      ]),
      listing_operations_form(),
      hotel_room_type_modal(),
      dom.element(
        "div",
        [
          a.id("wizard-toast-container"),
          a.class("wizard-toast-container"),
          a.attribute("aria-live", "polite"),
          a.attribute("aria-atomic", "false"),
          a.attribute("role", "status"),
        ],
        [],
      ),
    ],
  )
}

fn listing_selector(id: String) {
  dom.element("select", [a.name("listing_id"), a.id(id), a.required(True)], [
    dom.element("option", [a.attribute("value", "")], [text("İlan seçin")]),
  ])
}

fn listing_operations_form() {
  dom.element(
    "form",
    [
      a.id("bulk-form"),
      a.attribute("data-bulk-form", "true"),
      a.attribute("data-bulk-publish", "true"),
      a.attribute("data-bulk-unpublish", "true"),
      a.attribute("data-bulk-csv", "true"),
      a.attribute("data-bulk-csv-name", "katalog"),
      a.method("post"),
      a.action("/admin/catalog/bulk-delete"),
    ],
    [
      dom.element("div", [a.class("sub-workspace-wrapper")], [
        // PRICING & RATE PLANS CARD
        dom.element("div", [a.id("pricing"), a.class("glass-subcard")], [
          dom.element("div", [a.class("subcard-header")], [
            dom.element("div", [a.class("subcard-title-group")], [
              dom.element("span", [a.class("subcard-icon")], [text("💳")]),
              dom.element("div", [], [
                dom.element("h3", [], [
                  text("Fiyat, Komisyon & Satış Koşulları"),
                ]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "İlana özel taban satış fiyatı, acente komisyonu, ön ödeme ve iptal kurallarını tanımlayın.",
                  ),
                ]),
              ]),
            ]),
            dom.element("span", [a.class("status-pill")], [
              text("Fiyatlandırma Motoru"),
            ]),
          ]),
          dom.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/listings/rates"),
              a.class("rate-form-grid"),
            ],
            [
              dom.element("label", [a.class("col-span-2")], [
                text("İlan"),
                listing_selector("rate-listing-id"),
              ]),
              dom.element("label", [], [
                text("Plan adı"),
                dom.element(
                  "input",
                  [
                    a.name("name"),
                    a.required(True),
                    a.attribute("placeholder", "Standart fiyat"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Para birimi"),
                dom.element(
                  "input",
                  [
                    a.name("currency"),
                    a.required(True),
                    a.attribute("value", "TRY"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Taban fiyat (kuruş)"),
                dom.element(
                  "input",
                  [
                    a.name("base_minor"),
                    a.type_("number"),
                    a.attribute("min", "0"),
                    a.required(True),
                    a.attribute("placeholder", "Örn: 2500000"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Komisyon (%)"),
                dom.element(
                  "input",
                  [
                    a.name("commission_percent"),
                    a.type_("number"),
                    a.attribute("min", "0"),
                    a.attribute("max", "100"),
                    a.attribute("step", "0.01"),
                    a.attribute("value", "15"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Ön ödeme (%)"),
                dom.element(
                  "input",
                  [
                    a.name("deposit_percent"),
                    a.type_("number"),
                    a.attribute("min", "0"),
                    a.attribute("max", "100"),
                    a.attribute("step", "0.01"),
                    a.attribute("value", "35"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Minimum gece"),
                dom.element(
                  "input",
                  [
                    a.name("min_nights"),
                    a.type_("number"),
                    a.attribute("min", "1"),
                    a.attribute("value", "2"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Durum"),
                dom.element("select", [a.name("active")], [
                  dom.element("option", [a.attribute("value", "true")], [
                    text("Aktif"),
                  ]),
                  dom.element("option", [a.attribute("value", "false")], [
                    text("Pasif"),
                  ]),
                ]),
              ]),
              dom.element("label", [a.class("col-span-3")], [
                text("İptal politikası"),
                dom.element(
                  "input",
                  [
                    a.name("cancellation_policy"),
                    a.attribute("placeholder", "İptal ve iade şartlarını yazın"),
                    a.attribute(
                      "value",
                      "Giriş tarihinden 14 gün öncesine kadar %100 kesintisiz iade hakkı.",
                    ),
                  ],
                  [],
                ),
              ]),
              dom.element("div", [a.class("form-actions-bar")], [
                dom.element(
                  "button",
                  [a.type_("submit"), a.class("primary btn-compact")],
                  [
                    dom.element("span", [a.class("btn-icon")], [text("✓")]),
                    text("Fiyat Planını Kaydet"),
                  ],
                ),
              ]),
            ],
          ),
          dom.element("div", [a.class("table-wrap subcard-table")], [
            dom.element("table", [a.class("data-table")], [
              dom.element("thead", [], [
                dom.element("tr", [], [
                  dom.element("th", [], [text("İlan")]),
                  dom.element("th", [], [text("Plan")]),
                  dom.element("th", [], [text("Fiyat")]),
                  dom.element("th", [], [text("Komisyon")]),
                  dom.element("th", [], [text("Ön ödeme")]),
                  dom.element("th", [], [text("Min. gece")]),
                  dom.element("th", [], [text("Durum")]),
                ]),
              ]),
              dom.element("tbody", [a.id("rates-table-body")], [
                dom.element("tr", [], [
                  dom.element(
                    "td",
                    [a.attribute("colspan", "7"), a.class("empty-state")],
                    [text("Fiyat planları yükleniyor…")],
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),

        // AVAILABILITY & INVENTORY CARD
        dom.element("div", [a.id("availability"), a.class("glass-subcard")], [
          dom.element("div", [a.class("subcard-header")], [
            dom.element("div", [a.class("subcard-title-group")], [
              dom.element("span", [a.class("subcard-icon")], [text("📅")]),
              dom.element("div", [], [
                dom.element("h3", [], [
                  text("Günlük Müsaitlik & Kontenjan Kontrolü"),
                ]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Belirli tarihlerdeki müsait birim sayısını ve satışa açıklık durumunu yönetin.",
                  ),
                ]),
              ]),
            ]),
            dom.element("span", [a.class("status-pill")], [text("Takvim Sync")]),
          ]),
          dom.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/listings/availability"),
              a.class("rate-form-grid"),
            ],
            [
              dom.element("label", [a.class("col-span-2")], [
                text("İlan"),
                listing_selector("availability-listing-id"),
              ]),
              dom.element("label", [a.class("col-span-2")], [
                text("Tarih"),
                dom.element(
                  "input",
                  [a.name("day"), a.type_("date"), a.required(True)],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Toplam birim"),
                dom.element(
                  "input",
                  [
                    a.name("units_total"),
                    a.type_("number"),
                    a.attribute("min", "0"),
                    a.attribute("value", "1"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [], [
                text("Müsait birim"),
                dom.element(
                  "input",
                  [
                    a.name("units_available"),
                    a.type_("number"),
                    a.attribute("min", "0"),
                    a.attribute("value", "1"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [a.class("col-span-2")], [
                text("Satış durumu"),
                dom.element("select", [a.name("closed")], [
                  dom.element("option", [a.attribute("value", "false")], [
                    text("Satışta (Açık)"),
                  ]),
                  dom.element("option", [a.attribute("value", "true")], [
                    text("Kapalı (Bloke)"),
                  ]),
                ]),
              ]),
              dom.element("div", [a.class("form-actions-bar")], [
                dom.element(
                  "button",
                  [a.type_("submit"), a.class("primary btn-compact")],
                  [
                    dom.element("span", [a.class("btn-icon")], [text("✓")]),
                    text("Müsaitliği Kaydet"),
                  ],
                ),
              ]),
            ],
          ),
          dom.element("div", [a.class("table-wrap subcard-table")], [
            dom.element("table", [a.class("data-table")], [
              dom.element("thead", [], [
                dom.element("tr", [], [
                  dom.element("th", [], [text("İlan")]),
                  dom.element("th", [], [text("Tarih")]),
                  dom.element("th", [], [text("Toplam")]),
                  dom.element("th", [], [text("Müsait")]),
                  dom.element("th", [], [text("Durum")]),
                ]),
              ]),
              dom.element("tbody", [a.id("availability-table-body")], [
                dom.element("tr", [], [
                  dom.element(
                    "td",
                    [a.attribute("colspan", "5"), a.class("empty-state")],
                    [text("Müsaitlik yükleniyor…")],
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ],
  )
}

fn categories_form() {
  dom.element("section", [a.class("quick"), a.id("categories-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Kategori ve alan yönetimi")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Kategori ağacınızı oluşturun; ilan formlarında kullanılacak kod, SEO slug ve görünürlük ayarlarını yönetin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Canlı veri")]),
    ]),
    dom.element(
      "form",
      [
        a.method("post"),
        a.action("/admin/categories"),
        a.class("category-form"),
      ],
      [
        dom.element("label", [], [
          text("Üst kategori ID (opsiyonel)"),
          dom.element(
            "select",
            [a.name("parent_id"), a.id("category-parent-id")],
            [
              dom.element("option", [a.attribute("value", "")], [
                text("Üst kategori yok"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Kategori kodu"),
          dom.element(
            "input",
            [
              a.name("code"),
              a.required(True),
              a.attribute("placeholder", "VILLA"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Kategori adı"),
          dom.element(
            "input",
            [
              a.name("name"),
              a.required(True),
              a.attribute("placeholder", "Tatil evi kiralama"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Slug"),
          dom.element(
            "input",
            [
              a.name("slug"),
              a.required(True),
              a.attribute("placeholder", "tatil-evi-kiralama"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Sıra"),
          dom.element(
            "input",
            [
              a.name("sort_order"),
              a.type_("number"),
              a.attribute("value", "0"),
              a.attribute("min", "0"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Durum"),
          dom.element("select", [a.name("active")], [
            dom.element("option", [a.attribute("value", "true")], [
              text("Aktif"),
            ]),
            dom.element("option", [a.attribute("value", "false")], [
              text("Pasif"),
            ]),
          ]),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Açıklama"),
          dom.element(
            "textarea",
            [
              a.name("description"),
              a.class("rich-textarea"),
              a.attribute("data-rich-editor", "true"),
              a.attribute("rows", "3"),
              a.attribute("placeholder", "Kategori açıklaması"),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Kategoriyi kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Üst kategori")]),
            dom.element("th", [], [text("Kod")]),
            dom.element("th", [], [text("Kategori")]),
            dom.element("th", [], [text("Slug")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Sıra")]),
          ]),
        ]),
        dom.element("tbody", [a.id("categories-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "6"), a.class("empty-state")],
              [text("Kategoriler yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
    category_fields_form(),
    category_filters_form(),
  ])
}

fn category_fields_form() {
  dom.element("div", [a.id("category-fields"), a.class("sub-workspace")], [
    dom.element("h2", [], [text("İlan formu alanları")]),
    dom.element("p", [a.class("muted")], [
      text(
        "Her kategori için farklı ve zorunlu alanlar tanımlayın. Örneğin tatil evi için havuz ölçüsü, otel için yatak tipi.",
      ),
    ]),
    dom.element(
      "form",
      [
        a.method("post"),
        a.action("/admin/categories/fields"),
        a.class("category-field-form"),
      ],
      [
        dom.element("label", [], [
          text("Kategori"),
          dom.element(
            "select",
            [a.name("category_id"), a.id("field-category-id"), a.required(True)],
            [
              dom.element("option", [a.attribute("value", "")], [
                text("Kategori seçin"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Alan anahtarı"),
          dom.element(
            "input",
            [
              a.name("field_key"),
              a.required(True),
              a.attribute("placeholder", "pool_size"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Alan etiketi"),
          dom.element(
            "input",
            [
              a.name("label"),
              a.required(True),
              a.attribute("placeholder", "Havuz ölçüsü"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Alan türü"),
          dom.element("select", [a.name("field_type")], [
            dom.element("option", [a.attribute("value", "text")], [
              text("Metin"),
            ]),
            dom.element("option", [a.attribute("value", "textarea")], [
              text("Uzun metin"),
            ]),
            dom.element("option", [a.attribute("value", "number")], [
              text("Sayı"),
            ]),
            dom.element("option", [a.attribute("value", "money")], [
              text("Tutar"),
            ]),
            dom.element("option", [a.attribute("value", "date")], [
              text("Tarih"),
            ]),
            dom.element("option", [a.attribute("value", "boolean")], [
              text("Evet / Hayır"),
            ]),
            dom.element("option", [a.attribute("value", "select")], [
              text("Tek seçim"),
            ]),
            dom.element("option", [a.attribute("value", "multiselect")], [
              text("Çoklu seçim"),
            ]),
            dom.element("option", [a.attribute("value", "media")], [
              text("Medya"),
            ]),
            dom.element("option", [a.attribute("value", "location")], [
              text("Konum"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Seçenekler"),
          dom.element(
            "input",
            [
              a.name("options"),
              a.attribute("placeholder", "Deniz, Havuz, Şehir"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Zorunluluk"),
          dom.element("select", [a.name("required")], [
            dom.element("option", [a.attribute("value", "false")], [
              text("Opsiyonel"),
            ]),
            dom.element("option", [a.attribute("value", "true")], [
              text("Zorunlu"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Sıra"),
          dom.element(
            "input",
            [
              a.name("sort_order"),
              a.type_("number"),
              a.attribute("value", "0"),
              a.attribute("min", "0"),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Alanı kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Kategori")]),
            dom.element("th", [], [text("Anahtar")]),
            dom.element("th", [], [text("Etiket")]),
            dom.element("th", [], [text("Tür")]),
            dom.element("th", [], [text("Zorunluluk")]),
            dom.element("th", [], [text("Sıra")]),
          ]),
        ]),
        dom.element("tbody", [a.id("category-fields-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "6"), a.class("empty-state")],
              [text("Alanlar yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn category_filters_form() {
  dom.element("div", [a.id("category-filters"), a.class("sub-workspace")], [
    dom.element("h2", [], [text("Filtre grupları ve alt tipler")]),
    dom.element("p", [a.class("muted")], [
      text(
        "Alt kategori, tip ve vitrin filtrelerini burada yönetin. Türkçe girilen başlıklar aktif diğer diller için otomatik çeviri kuyruğuna alınır.",
      ),
    ]),
    dom.element(
      "form",
      [
        a.method("post"),
        a.action("/admin/categories/filter-groups"),
        a.class("category-field-form"),
      ],
      [
        dom.element("label", [], [
          text("Kategori"),
          dom.element(
            "select",
            [
              a.name("category_code"),
              a.id("filter-category-code"),
              a.required(True),
            ],
            [
              dom.element("option", [a.attribute("value", "")], [
                text("Kategori seçin"),
              ]),
              dom.element("option", [a.attribute("value", "hotel")], [
                text("Otel (hotel)"),
              ]),
              dom.element("option", [a.attribute("value", "holiday_home")], [
                text("Tatil Evi (holiday_home)"),
              ]),
              dom.element("option", [a.attribute("value", "yacht")], [
                text("Yat (yacht)"),
              ]),
              dom.element("option", [a.attribute("value", "tour")], [
                text("Tur (tour)"),
              ]),
              dom.element("option", [a.attribute("value", "activity")], [
                text("Aktivite (activity)"),
              ]),
              dom.element("option", [a.attribute("value", "flight")], [
                text("Uçuş (flight)"),
              ]),
              dom.element("option", [a.attribute("value", "car")], [
                text("Araç (car)"),
              ]),
              dom.element("option", [a.attribute("value", "cruise")], [
                text("Kruvaziyer (cruise)"),
              ]),
              dom.element("option", [a.attribute("value", "pilgrimage")], [
                text("Hac & Umre (pilgrimage)"),
              ]),
              dom.element("option", [a.attribute("value", "visa")], [
                text("Vize (visa)"),
              ]),
              dom.element("option", [a.attribute("value", "ferry")], [
                text("Feribot (ferry)"),
              ]),
              dom.element("option", [a.attribute("value", "transfer")], [
                text("Transfer (transfer)"),
              ]),
              dom.element("option", [a.attribute("value", "beach")], [
                text("Şezlong (beach)"),
              ]),
              dom.element("option", [a.attribute("value", "cinema")], [
                text("Sinema (cinema)"),
              ]),
              dom.element("option", [a.attribute("value", "event")], [
                text("Etkinlik (event)"),
              ]),
              dom.element("option", [a.attribute("value", "restaurant")], [
                text("Restoran (restaurant)"),
              ]),
              dom.element("option", [a.attribute("value", "bus")], [
                text("Otobüs (bus)"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Grup anahtarı"),
          dom.element(
            "input",
            [
              a.name("group_key"),
              a.required(True),
              a.attribute("placeholder", "property_type"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Grup başlığı"),
          dom.element(
            "input",
            [
              a.name("title"),
              a.required(True),
              a.attribute("placeholder", "Tatil evi tipi"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Görünüm"),
          dom.element("select", [a.name("display_type")], [
            dom.element("option", [a.attribute("value", "chips")], [
              text("Rozet / chip"),
            ]),
            dom.element("option", [a.attribute("value", "select")], [
              text("Seçim listesi"),
            ]),
            dom.element("option", [a.attribute("value", "checkboxes")], [
              text("Çoklu kutu"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Çoklu seçim"),
          dom.element("select", [a.name("multiple")], [
            dom.element("option", [a.attribute("value", "false")], [
              text("Hayır"),
            ]),
            dom.element("option", [a.attribute("value", "true")], [
              text("Evet"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Sıra"),
          dom.element(
            "input",
            [
              a.name("sort_order"),
              a.type_("number"),
              a.attribute("value", "0"),
              a.attribute("min", "0"),
            ],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Yardım metni"),
          dom.element(
            "input",
            [
              a.name("help_text"),
              a.attribute(
                "placeholder",
                "Kullanıcıya gösterilecek kısa açıklama",
              ),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Filtre grubunu kaydet"),
        ]),
      ],
    ),
    dom.element(
      "form",
      [
        a.method("post"),
        a.action("/admin/categories/filter-items"),
        a.class("category-field-form"),
      ],
      [
        dom.element("label", [], [
          text("Filtre grubu"),
          dom.element(
            "select",
            [a.name("group_id"), a.id("filter-item-group-id"), a.required(True)],
            [
              dom.element("option", [a.attribute("value", "")], [
                text("Grup seçin"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("Madde anahtarı"),
          dom.element(
            "input",
            [
              a.name("item_key"),
              a.required(True),
              a.attribute("placeholder", "villa"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Madde başlığı"),
          dom.element(
            "input",
            [
              a.name("title"),
              a.required(True),
              a.attribute("placeholder", "Villa"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Sözleşme alanı"),
          dom.element(
            "input",
            [
              a.name("contract_field_key"),
              a.attribute("placeholder", "property_type"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Sözleşme değeri"),
          dom.element(
            "input",
            [
              a.name("contract_value"),
              a.attribute("placeholder", "villa"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Sıra"),
          dom.element(
            "input",
            [
              a.name("sort_order"),
              a.type_("number"),
              a.attribute("value", "0"),
              a.attribute("min", "0"),
            ],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Yardım metni"),
          dom.element("input", [a.name("help_text")], []),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Filtre maddesini kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Kategori")]),
            dom.element("th", [], [text("Grup")]),
            dom.element("th", [], [text("Anahtar")]),
            dom.element("th", [], [text("Maddeler")]),
            dom.element("th", [], [text("Çeviri")]),
            dom.element("th", [], [text("İşlem")]),
          ]),
        ]),
        dom.element("tbody", [a.id("category-filter-groups-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "6"), a.class("empty-state")],
              [text("Filtre grupları yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn cms_form() {
  dom.element("section", [a.class("quick"), a.id("cms-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Sayfa ve SEO içerikleri")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Sayfa slug'ı, şablonu, yayın durumu ve her dilde kullanılacak SEO alanlarını tek kayıtta yönetin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Canlı veri")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/cms"), a.class("cms-form")],
      [
        dom.element("label", [], [
          text("Sayfa slug"),
          dom.element(
            "input",
            [
              a.name("slug"),
              a.required(True),
              a.id("cms-slug"),
              a.attribute("placeholder", "hakkimizda"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Şablon"),
          dom.element("select", [a.name("template")], [
            dom.element("option", [a.attribute("value", "standard")], [
              text("Standart sayfa"),
            ]),
            dom.element("option", [a.attribute("value", "landing")], [
              text("Tanıtım sayfası"),
            ]),
            dom.element("option", [a.attribute("value", "blog")], [
              text("Blog yazısı"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Sayfa kapsamı"),
          dom.element("select", [a.name("category_scope")], [
            dom.element("option", [a.value("global")], [
              text("Genel / tüm kategoriler"),
            ]),
            dom.element("option", [a.value("hotel")], [text("Otel")]),
            dom.element("option", [a.value("holiday_home")], [text("Tatil Evi")]),
            dom.element("option", [a.value("yacht")], [text("Yat")]),
            dom.element("option", [a.value("tour")], [text("Tur")]),
            dom.element("option", [a.value("activity")], [text("Aktivite")]),
            dom.element("option", [a.value("car")], [text("Araç")]),
            dom.element("option", [a.value("transfer")], [text("Transfer")]),
            dom.element("option", [a.value("flight")], [text("Uçuş")]),
            dom.element("option", [a.value("bus")], [text("Otobüs")]),
            dom.element("option", [a.value("ferry")], [text("Feribot")]),
            dom.element("option", [a.value("cruise")], [text("Kruvaziyer")]),
            dom.element("option", [a.value("event")], [text("Etkinlik")]),
            dom.element("option", [a.value("restaurant")], [text("Restoran")]),
            dom.element("option", [a.value("beach")], [text("Plaj / Şezlong")]),
            dom.element("option", [a.value("cinema")], [text("Sinema")]),
            dom.element("option", [a.value("visa")], [text("Vize")]),
            dom.element("option", [a.value("pilgrimage")], [text("Hac / Umre")]),
          ]),
        ]),
        dom.element("label", [], [
          text("Blog kategorisi (blog yazıları için)"),
          dom.element("select", [a.name("blog_category")], [
            dom.element("option", [a.value("")], [text("Kategori seçin")]),
            dom.element("option", [a.value("gezilesi-yerler")], [
              text("Gezilesi Yerler"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Blog bölgesi (slug)"),
          dom.element(
            "input",
            [a.name("region_slug"), a.attribute("placeholder", "mugla")],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Blog kapak görseli URL'si"),
          dom.element(
            "input",
            [
              a.name("cover_image"),
              a.attribute("placeholder", "https://... veya /static/..."),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Yayın durumu"),
          dom.element("select", [a.name("status")], [
            dom.element("option", [a.attribute("value", "draft")], [
              text("Taslak"),
            ]),
            dom.element("option", [a.attribute("value", "published")], [
              text("Yayında"),
            ]),
            dom.element("option", [a.attribute("value", "archived")], [
              text("Arşiv"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("SEO başlığı"),
          dom.element(
            "input",
            [
              a.name("seo_title"),
              a.attribute("placeholder", "NEXUS Agency | ..."),
            ],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("SEO açıklaması"),
          dom.element(
            "textarea",
            [
              a.name("seo_description"),
              a.attribute("rows", "3"),
              a.attribute(
                "placeholder",
                "Arama sonuçlarında görünecek açıklama",
              ),
            ],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("SEO etiketleri"),
          dom.element(
            "input",
            [
              a.name("seo_keywords"),
              a.attribute("placeholder", "seyahat, villa, otel"),
            ],
            [],
          ),
        ]),
        dom.element(
          "section",
          [a.class("page-builder-card"), a.id("page-builder")],
          [
            dom.element("div", [a.class("page-builder-heading")], [
              dom.element("h3", [], [text("Sayfa modülleri")]),
              dom.element("span", [a.class("status-pill")], [
                text("Sürükle & sırala"),
              ]),
            ]),
            dom.element("div", [a.class("page-builder-toolbar")], [
              dom.element("select", [a.id("page-builder-type")], [
                dom.element("option", [a.value("hero")], [text("Hero / Arama")]),
                dom.element("option", [a.value("source_section")], [
                  text("Sayfa bölümü"),
                ]),
                dom.element("option", [a.value("region_places")], [
                  text("Gezilesi Yerler / Bölge tanıtımı"),
                ]),
                dom.element("option", [a.value("featured_listings")], [
                  text("Öne çıkan ilanlar"),
                ]),
                dom.element("option", [a.value("category_grid")], [
                  text("Kategori kartları"),
                ]),
                dom.element("option", [a.value("trust_strip")], [
                  text("Güven şeridi"),
                ]),
                dom.element("option", [a.value("benefit_cards")], [
                  text("Neden bizi seçin kartları"),
                ]),
                dom.element("option", [a.value("video_gallery")], [
                  text("Video galerisi"),
                ]),
                dom.element("option", [a.value("destination_grid")], [
                  text("Destinasyon kartları"),
                ]),
                dom.element("option", [a.value("how_it_works")], [
                  text("Nasıl çalışır adımları"),
                ]),
                dom.element("option", [a.value("stay_types")], [
                  text("Konaklama tipleri"),
                ]),
                dom.element("option", [a.value("blog_cards")], [
                  text("Blog kartları"),
                ]),
                dom.element("option", [a.value("divider")], [
                  text("Bölüm ayırıcı"),
                ]),
                dom.element("option", [a.value("rich_text")], [
                  text("Zengin metin"),
                ]),
                dom.element("option", [a.value("newsletter")], [
                  text("Bülten kayıt"),
                ]),
                dom.element("option", [a.value("filter_bar")], [
                  text("Filtre çubuğu"),
                ]),
                dom.element("option", [a.value("listing_grid")], [
                  text("İlan ızgarası"),
                ]),
                dom.element("option", [a.value("listing_collection")], [
                  text("Seçilebilir ilan listeleme"),
                ]),
                dom.element("option", [a.value("image_gallery")], [
                  text("Görsel galeri"),
                ]),
                dom.element("option", [a.value("faq")], [text("SSS / Sorular")]),
                dom.element("option", [a.value("cta")], [
                  text("Harekete geçirici alan"),
                ]),
                dom.element("option", [a.value("testimonials")], [
                  text("Müşteri yorumları"),
                ]),
              ]),
              dom.element(
                "button",
                [
                  a.type_("button"),
                  a.class("secondary"),
                  a.id("page-builder-add"),
                ],
                [text("+ Modül ekle")],
              ),
            ]),
            dom.element(
              "div",
              [a.id("page-builder-list"), a.class("page-builder-list")],
              [],
            ),
            dom.element(
              "textarea",
              [
                a.name("blocks_json"),
                a.id("page-builder-json"),
                a.attribute("hidden", "hidden"),
              ],
              [text("[]")],
            ),
            dom.element(
              "div",
              [a.id("page-builder-preview"), a.class("page-builder-preview")],
              [text("Modül önizlemesi burada görünecek.")],
            ),
          ],
        ),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Sayfayı kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Slug")]),
            dom.element("th", [], [text("Şablon")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("SEO başlığı")]),
            dom.element("th", [], [text("Yayın tarihi")]),
            dom.element("th", [], [text("İşlem")]),
          ]),
        ]),
        dom.element("tbody", [a.id("cms-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "6"), a.class("empty-state")],
              [text("Sayfalar yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn ai_form() {
  dom.element("section", [a.class("quick"), a.id("ai-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Yapay zeka sağlayıcıları")]),
        dom.element("p", [a.class("muted")], [
          text(
            "İçerik, çeviri, SEO ve destek görevlerinde kullanılacak sağlayıcı ve modeli seçin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Seçilebilir model")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/ai"), a.class("ai-form")],
      [
        dom.element("label", [], [
          text("Sağlayıcı"),
          // Built from ai_client.supported_providers() so the selector can
          // never offer a provider that call_llm/4 refuses at the next call.
          dom.element(
            "select",
            [a.name("provider")],
            ai_client.supported_providers()
              |> list.map(fn(entry) {
                dom.element("option", [a.attribute("value", entry.0)], [
                  text(entry.1),
                ])
              }),
          ),
        ]),
        dom.element("label", [], [
          text("Model"),
          dom.element(
            "input",
            [
              a.name("model"),
              a.required(True),
              a.attribute("placeholder", "gpt-4.1-mini"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("API anahtarı"),
          dom.element(
            "input",
            [
              a.name("api_key"),
              a.type_("password"),
              a.attribute(
                "placeholder",
                "Anahtarı girin veya mevcut anahtarı korumak için boş bırakın",
              ),
              a.autocomplete("off"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Durum"),
          dom.element("select", [a.name("active")], [
            dom.element("option", [a.attribute("value", "true")], [
              text("Aktif"),
            ]),
            dom.element("option", [a.attribute("value", "false")], [
              text("Pasif"),
            ]),
          ]),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("AI sağlayıcısını kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Sağlayıcı")]),
            dom.element("th", [], [text("Model")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Anahtar")]),
          ]),
        ]),
        dom.element("tbody", [a.id("ai-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "4"), a.class("empty-state")],
              [text("AI sağlayıcıları yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
    dom.element("section", [a.class("ai-growth-suite")], [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [text("AI Satış ve İçerik Otomasyonu")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Müşteri sohbeti, takip teklifleri, çapraz satış ve sosyal medya taslaklarını tek merkezden yönetin.",
            ),
          ]),
        ]),
        dom.element("span", [a.class("status-pill")], [
          text("Otomasyon merkezi"),
        ]),
      ]),
      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/settings"),
          a.class("ai-growth-form"),
        ],
        [
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_chat_enabled")],
              [],
            ),
            text("AI karşılama sohbetini etkinleştir"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_followup_enabled")],
              [],
            ),
            text("5 saat / 10 saat / 2 gün / 5 gün takip teklifleri"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_cross_sell_enabled")],
              [],
            ),
            text("Rezervasyon sonrası marj bazlı çapraz satış"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_region_content_enabled")],
              [],
            ),
            text("Bölge rehberi ve yakın mekan içerikleri"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_campaigns_enabled")],
              [],
            ),
            text("AI kampanya taslağı ve hedef kitle önerileri"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_sales_assist_enabled")],
              [],
            ),
            text("AI satış fırsatı, upsell ve çapraz satış önerileri"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_after_sales_enabled")],
              [],
            ),
            text("AI satış sonrası destek ve vaka sınıflandırması"),
          ]),
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [a.type_("checkbox"), a.name("ai_financial_approval_required")],
              [],
            ),
            text("İade, iptal ve finansal işlemlerde insan onayı zorunlu"),
          ]),
          dom.element("label", [], [
            text("Instagram / Facebook hesabı"),
            dom.element(
              "input",
              [
                a.name("social_meta_account"),
                a.attribute("placeholder", "rezervasyonyap"),
              ],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Threads / Pinterest hesabı"),
            dom.element(
              "input",
              [
                a.name("social_global_account"),
                a.attribute("placeholder", "reservationinturkey"),
              ],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Sosyal medya dili yönlendirmesi"),
            dom.element("select", [a.name("social_language_routing")], [
              dom.element("option", [a.value("tr_meta_en_global")], [
                text("TR → rezervasyonyap · EN → reservationinturkey"),
              ]),
              dom.element("option", [a.value("manual")], [
                text("Manuel onay kuyruğu"),
              ]),
            ]),
          ]),
          dom.element("button", [a.type_("submit"), a.class("primary")], [
            text("AI otomasyonlarını kaydet"),
          ]),
        ],
      ),
    ]),
    dom.element(
      "section",
      [a.class("social-compose-card social-studio-container")],
      [
        dom.element("div", [a.class("social-studio-header")], [
          dom.element("h3", [], [text("✨ Sosyal Medya & Yapay Zeka Stüdyosu")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Instagram, Facebook, Threads ve Pinterest için ilanınızdan gönderi metni hazırlayın, görsel adresini gözden geçirin ve yayını planlayın.",
            ),
          ]),
        ]),
        dom.element("div", [a.class("social-studio-grid")], [
          dom.element(
            "form",
            [
              a.method("post"),
              a.action("/admin/social"),
              a.class("social-compose-form"),
              a.id("social-compose-form"),
            ],
            [
              dom.element(
                "input",
                [
                  a.type_("hidden"),
                  a.name("ai_generated"),
                  a.id("input-ai-generated"),
                  a.value("false"),
                ],
                [],
              ),
              dom.element("div", [a.class("ai-generator-box glass-subcard")], [
                dom.element("div", [a.class("ai-box-title")], [
                  dom.element("span", [a.class("sparkle-icon")], [text("🤖")]),
                  dom.element("strong", [], [text("İçerik Asistanı")]),
                ]),
                dom.element("div", [a.class("ai-box-row")], [
                  dom.element(
                    "input",
                    [
                      a.name("listing_id"),
                      a.id("input-social-listing-id"),
                      a.attribute(
                        "placeholder",
                        "İlan ID (UUID) veya İlan Başlığı girin",
                      ),
                    ],
                    [],
                  ),
                  dom.element(
                    "select",
                    [a.name("tone"), a.id("select-social-tone")],
                    [
                      dom.element("option", [a.value("luxury")], [
                        text("💎 Lüks & Prestijli"),
                      ]),
                      dom.element("option", [a.value("catchy")], [
                        text("⚡ Çekici & Fırsat Odaklı"),
                      ]),
                      dom.element("option", [a.value("romantic")], [
                        text("🌹 Romantik & Balayı"),
                      ]),
                      dom.element("option", [a.value("adventurous")], [
                        text("🧗 Maceracı & Dinamik"),
                      ]),
                    ],
                  ),
                ]),
                dom.element(
                  "button",
                  [
                    a.type_("button"),
                    a.class("btn-ai-pill full-width"),
                    a.id("btn-generate-social-ai"),
                  ],
                  [
                    text("✨ Gönderi Metni Hazırla"),
                  ],
                ),
              ]),
              dom.element("div", [a.class("form-row-duo")], [
                dom.element(
                  "select",
                  [a.name("network"), a.id("select-social-network")],
                  [
                    dom.element("option", [a.value("instagram")], [
                      text("📸 Instagram"),
                    ]),
                    dom.element("option", [a.value("facebook")], [
                      text("📘 Facebook"),
                    ]),
                    dom.element("option", [a.value("threads")], [
                      text("🧵 Threads"),
                    ]),
                    dom.element("option", [a.value("pinterest")], [
                      text("📌 Pinterest"),
                    ]),
                  ],
                ),
                dom.element(
                  "select",
                  [a.name("language_code"), a.id("select-social-lang")],
                  [
                    dom.element("option", [a.value("tr")], [
                      text("🇹🇷 Türkçe · rezervasyonyap"),
                    ]),
                    dom.element("option", [a.value("en")], [
                      text("🇬🇧 English · reservationinturkey"),
                    ]),
                    dom.element("option", [a.value("de")], [text("🇩🇪 Deutsch")]),
                    dom.element("option", [a.value("ru")], [text("🇷🇺 Русский")]),
                    dom.element("option", [a.value("fr")], [text("🇫🇷 Français")]),
                    dom.element("option", [a.value("zh")], [text("🇨🇳 简体中文")]),
                  ],
                ),
              ]),
              dom.element(
                "input",
                [
                  a.name("scheduled_at"),
                  a.type_("datetime-local"),
                  a.attribute("placeholder", "Planlama zamanı"),
                ],
                [],
              ),
              dom.element(
                "textarea",
                [
                  a.name("content"),
                  a.id("textarea-social-content"),
                  a.required(True),
                  a.attribute("rows", "5"),
                  a.attribute(
                    "placeholder",
                    "Gönderi metni veya AI ile üretilen içerik…",
                  ),
                ],
                [],
              ),
              dom.element(
                "input",
                [
                  a.name("media_url"),
                  a.id("input-social-media-url"),
                  a.type_("url"),
                  a.attribute(
                    "placeholder",
                    "Medya / Görsel URL'si (Instagram/Pinterest için zorunlu)",
                  ),
                ],
                [],
              ),
              dom.element("div", [a.class("form-row-duo")], [
                dom.element("select", [a.name("automation_mode")], [
                  dom.element("option", [a.value("manual")], [
                    text("Manuel onaylı paylaşım"),
                  ]),
                  dom.element("option", [a.value("automatic")], [
                    text("Otomatik zamanlı paylaşım"),
                  ]),
                ]),
                dom.element(
                  "input",
                  [
                    a.name("daily_limit"),
                    a.type_("number"),
                    a.value("5"),
                    a.attribute("min", "0"),
                    a.attribute("max", "1000"),
                    a.attribute("placeholder", "Günlük limit"),
                  ],
                  [],
                ),
              ]),
              dom.element("label", [a.class("check-row")], [
                dom.element(
                  "input",
                  [
                    a.type_("checkbox"),
                    a.name("approval_required"),
                    a.value("true"),
                    a.attribute("checked", "checked"),
                  ],
                  [],
                ),
                text("Yayınlamadan önce yönetici onayı iste"),
              ]),
              dom.element(
                "button",
                [a.type_("submit"), a.class("primary full-width")],
                [
                  text("🚀 Taslağı Sosyal Medya Kuyruğuna Al"),
                ],
              ),
            ],
          ),
          dom.element("div", [a.class("social-preview-wrapper glass-subcard")], [
            dom.element("div", [a.class("preview-header")], [
              dom.element(
                "span",
                [a.id("preview-network-badge"), a.class("badge-network")],
                [text("Instagram Önizlemesi")],
              ),
              dom.element("div", [a.class("preview-header-actions")], [
                dom.element(
                  "button",
                  [
                    a.type_("button"),
                    a.id("btn-copy-social-text"),
                    a.class("btn-preview-copy"),
                  ],
                  [text("📋 Kopyala")],
                ),
                dom.element("span", [a.class("preview-live-tag")], [
                  text("Canlı"),
                ]),
              ]),
            ]),
            dom.element(
              "div",
              [a.class("social-mockup-card"), a.id("social-mockup-card")],
              [
                dom.element("div", [a.class("mockup-author")], [
                  dom.element("div", [a.class("mockup-avatar")], [text("🏝️")]),
                  dom.element("div", [a.class("mockup-author-info")], [
                    dom.element("strong", [a.id("mockup-author-name")], [
                      text("rezervasyonyap"),
                    ]),
                    dom.element("small", [a.class("muted")], [
                      text("Sponsorlu · Türkiye"),
                    ]),
                  ]),
                ]),
                dom.element(
                  "div",
                  [a.class("mockup-image-box"), a.id("mockup-image-box")],
                  [
                    dom.element(
                      "img",
                      [
                        a.id("mockup-img"),
                        a.attribute("alt", "Önizleme Görseli"),
                      ],
                      [],
                    ),
                  ],
                ),
                dom.element("div", [a.class("mockup-body")], [
                  dom.element("div", [a.class("mockup-actions")], [
                    text("❤️ 💬 ↗️"),
                  ]),
                  dom.element(
                    "p",
                    [a.class("mockup-text"), a.id("mockup-text-display")],
                    [
                      text(
                        "✨ Tatil hayallerinizi gerçeğe dönüştürün! Yapay zeka ile oluşturulan benzersiz rotalar, villalar ve oteller sizleri bekliyor. #tatil #turizm",
                      ),
                    ],
                  ),
                ]),
              ],
            ),
          ]),
        ]),
      ],
    ),
    dom.element(
      "section",
      [a.class("social-compose-card"), a.id("social-review")],
      [
        dom.element("h3", [], [text("Sosyal gönderi denetimi")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Onay bekleyen ve sonucu doğrulanamayan gönderileri burada inceleyin. Yeniden denemeden önce sosyal ağdaki yayını kontrol edin.",
          ),
        ]),
        dom.element("div", [a.id("social-review-list")], [
          text("Gönderiler yükleniyor…"),
        ]),
      ],
    ),
    dom.element(
      "section",
      [a.class("social-compose-card"), a.id("ai-worker-review")],
      [
        dom.element("h3", [], [text("AI işçi durumu")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Bekleyen kalite testlerini, kampanya teslimatlarını ve işçi sağlık durumunu buradan izleyin.",
          ),
        ]),
        dom.element("div", [a.id("ai-worker-health-list")], [
          text("Durum yükleniyor…"),
        ]),
      ],
    ),
    dom.element(
      "section",
      [a.class("social-compose-card"), a.id("ai-campaign-review")],
      [
        dom.element("h3", [], [text("AI kampanya teslimatları")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Gönderime alınan, bekleyen ve müdahale isteyen kampanyaların SMTP kabul sonuçları.",
          ),
        ]),
        dom.element("div", [a.id("ai-campaign-runs-list")], [
          text("Kampanyalar yükleniyor…"),
        ]),
      ],
    ),
    dom.element(
      "section",
      [a.class("social-compose-card"), a.id("ai-quality-review")],
      [
        dom.element("h3", [], [text("AI kalite testleri")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Sonuçları ve bekleyen testlerin nedenlerini inceleyin. Model çıktısı olmayan testler başarılı sayılmaz.",
          ),
        ]),
        dom.element("div", [a.id("ai-quality-cases-list")], [
          text("Kalite testleri yükleniyor…"),
        ]),
      ],
    ),
    dom.element("section", [a.class("ai-supervisor-card")], [
      dom.element("h3", [], [text("AI Müdür · Sürekli Denetim")]),
      dom.element("p", [a.class("muted")], [
        text(
          "Tüm AI sağlayıcılarını, içerik kalitesini, çeviri/SEO kuyruklarını ve sosyal gönderileri düzenli aralıklarla kontrol eder.",
        ),
      ]),
      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/ai/supervisor"),
          a.class("ai-supervisor-form"),
        ],
        [
          dom.element("label", [a.class("check-row")], [
            dom.element(
              "input",
              [
                a.type_("checkbox"),
                a.name("enabled"),
                a.attribute("value", "true"),
              ],
              [],
            ),
            text("AI Müdürünü etkinleştir"),
          ]),
          dom.element("select", [a.name("interval")], [
            dom.element("option", [a.value("15m")], [text("15 dakikada bir")]),
            dom.element("option", [a.value("1h")], [text("Saatlik")]),
            dom.element("option", [a.value("6h")], [text("6 saatte bir")]),
          ]),
          dom.element("button", [a.type_("submit"), a.class("primary")], [
            text("Denetimi başlat / kuyruğa al"),
          ]),
        ],
      ),
      dom.element("small", [a.class("muted")], [
        text(
          "Her çalışmada başarısız görevleri yeniden dener, düşük kaliteli içerikleri işaretler ve yeni görevler üretir.",
        ),
      ]),
      dom.element(
        "div",
        [a.id("ai-supervisor-status"), a.class("ai-supervisor-status")],
        [text("AI Müdür durumu yükleniyor…")],
      ),
    ]),
    ai_key_pool_card(),
    ai_listing_fastfill_card(),
    ai_blog_engine_card(),
    ai_pricing_optimizer_card(),
    ai_review_sentiment_card(),
    ai_bundle_cross_sell_card(),
    ai_support_copilot_card(),
    module_control_card(),
  ])
}

fn ai_listing_fastfill_card() {
  dom.element(
    "section",
    [a.class("social-compose-card"), a.id("ai-listing-fastfill")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [
            text("⚡ AI İlan Hızlı Doldur (Notlardan Ayrıştır)"),
          ]),
          dom.element("p", [a.class("muted")], [
            text(
              "Broşür notlarını veya serbest metin açıklamalarını yapıştırın; yapay zeka otomatik olarak ilan alanlarını (başlık, kategori, fiyat, kapasite vb.) JSON olarak çıkarsın.",
            ),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("ai-generator-box glass-subcard")], [
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "select",
            [a.id("ai-fastfill-category"), a.class("form-control")],
            [
              dom.element("option", [a.value("holiday_home")], [
                text("🏡 Tatil Evi"),
              ]),
              dom.element("option", [a.value("hotel")], [text("🏨 Otel")]),
              dom.element("option", [a.value("yacht")], [text("⛵ Yat")]),
              dom.element("option", [a.value("tour")], [text("🗺️ Tur")]),
              dom.element("option", [a.value("activity")], [text("🧗 Aktivite")]),
              dom.element("option", [a.value("car")], [text("🚙 Araç")]),
              dom.element("option", [a.value("transfer")], [text("🚐 Transfer")]),
              dom.element("option", [a.value("cruise")], [text("🛳️ Kruvaziyer")]),
            ],
          ),
          dom.element(
            "button",
            [a.type_("button"), a.id("btn-ai-fastfill"), a.class("btn-ai-pill")],
            [
              text("✨ Notlardan Alanları Ayrıştır"),
            ],
          ),
        ]),
        dom.element(
          "textarea",
          [
            a.id("ai-fastfill-raw"),
            a.class("form-control"),
            a.attribute("rows", "6"),
            a.attribute(
              "placeholder",
              "Örn: Kaş manzaralı villa, 3 yatak odası, havuz, 6 misafir kapasiteli. Fiyat 8.500 TL/gece. Check-in 15:00...",
            ),
          ],
          [],
        ),
        dom.element(
          "div",
          [a.id("ai-fastfill-result"), a.class("ai-fastfill-result-box")],
          [],
        ),
      ]),
    ],
  )
}

fn ai_blog_engine_card() {
  dom.element(
    "section",
    [a.class("social-compose-card"), a.id("ai-blog-engine")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [
            text("📝 AI SEO Blog & Destinasyon Rehberi Üretici"),
          ]),
          dom.element("p", [a.class("muted")], [
            text(
              "Destinasyon ve kategori girerek arama motorlarında üst sıralarda çıkacak, dahili bağlantılı zengin HTML gezi rehberleri üretin.",
            ),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("ai-generator-box glass-subcard")], [
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-blog-destination"),
              a.class("form-control"),
              a.attribute(
                "placeholder",
                "Destinasyon (ör: Kaş, Bodrum, Fethiye)",
              ),
            ],
            [],
          ),
          dom.element(
            "select",
            [a.id("ai-blog-category"), a.class("form-control")],
            [
              dom.element("option", [a.value("holiday_home")], [
                text("🏡 Tatil Evi"),
              ]),
              dom.element("option", [a.value("hotel")], [text("🏨 Otel")]),
              dom.element("option", [a.value("yacht")], [text("⛵ Yat")]),
              dom.element("option", [a.value("tour")], [text("🗺️ Tur")]),
              dom.element("option", [a.value("activity")], [text("🧗 Aktivite")]),
            ],
          ),
        ]),
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "select",
            [a.id("ai-blog-lang"), a.class("form-control")],
            [
              dom.element("option", [a.value("tr")], [text("🇹🇷 Türkçe")]),
              dom.element("option", [a.value("en")], [text("🇬🇧 English")]),
              dom.element("option", [a.value("de")], [text("🇩🇪 Deutsch")]),
              dom.element("option", [a.value("ru")], [text("🇷🇺 Русский")]),
            ],
          ),
          dom.element(
            "button",
            [a.type_("button"), a.id("btn-ai-blog"), a.class("btn-ai-pill")],
            [
              text("✨ Gezi Rehberi & Blog Üret"),
            ],
          ),
        ]),
        dom.element(
          "div",
          [a.id("ai-blog-result"), a.class("ai-blog-result-box")],
          [],
        ),
      ]),
    ],
  )
}

fn ai_pricing_optimizer_card() {
  dom.element(
    "section",
    [a.class("social-compose-card"), a.id("ai-pricing-optimizer")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [
            text("📈 AI Akıllı Fiyatlandırma & Dinamik Gelir Stratejisi"),
          ]),
          dom.element("p", [a.class("muted")], [
            text(
              "Sezonluk talep, doluluk oranı ve hafta sonu katsayılarını analiz ederek kâr marjını maksimize eden dinamik fiyatlandırma hesaplayın.",
            ),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("ai-generator-box glass-subcard")], [
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-pricing-locality"),
              a.class("form-control"),
              a.attribute(
                "placeholder",
                "Destinasyon / Bölge (ör: Bodrum, Kaş, Fethiye)",
              ),
            ],
            [],
          ),
          dom.element(
            "select",
            [a.id("ai-pricing-category"), a.class("form-control")],
            [
              dom.element("option", [a.value("holiday_home")], [
                text("🏡 Tatil Evi / Villa"),
              ]),
              dom.element("option", [a.value("hotel")], [text("🏨 Otel")]),
              dom.element("option", [a.value("yacht")], [text("⛵ Yat")]),
              dom.element("option", [a.value("tour")], [text("🗺️ Tur")]),
              dom.element("option", [a.value("car")], [text("🚙 Araç")]),
              dom.element("option", [a.value("transfer")], [text("🚐 Transfer")]),
            ],
          ),
        ]),
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-pricing-price"),
              a.type_("number"),
              a.class("form-control"),
              a.attribute("placeholder", "Mevcut Taban Fiyat (ör: 5000)"),
            ],
            [],
          ),
          dom.element(
            "select",
            [a.id("ai-pricing-currency"), a.class("form-control")],
            [
              dom.element("option", [a.value("TRY")], [text("₺ TRY")]),
              dom.element("option", [a.value("EUR")], [text("€ EUR")]),
              dom.element("option", [a.value("USD")], [text("$ USD")]),
              dom.element("option", [a.value("GBP")], [text("£ GBP")]),
            ],
          ),
        ]),
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "select",
            [a.id("ai-pricing-season"), a.class("form-control")],
            [
              dom.element("option", [a.value("high")], [
                text("☀️ Yüksek Sezon (Yoğun Talep)"),
              ]),
              dom.element("option", [a.value("medium")], [
                text("🍂 Orta Sezon (Bahar / Dengeli)"),
              ]),
              dom.element("option", [a.value("low")], [
                text("❄️ Düşük Sezon (Fırsat Dönemi)"),
              ]),
            ],
          ),
          dom.element(
            "select",
            [a.id("ai-pricing-occupancy"), a.class("form-control")],
            [
              dom.element("option", [a.value("85")], [
                text("Doluluk: %85 (Yüksek Doluluk)"),
              ]),
              dom.element("option", [a.value("60")], [
                text("Doluluk: %60 (Dengeli)"),
              ]),
              dom.element("option", [a.value("25")], [
                text("Doluluk: %25 (Düşük - Kampanya Gerekli)"),
              ]),
            ],
          ),
        ]),
        dom.element("div", [a.class("form-actions-right")], [
          dom.element(
            "button",
            [a.type_("button"), a.id("btn-ai-pricing"), a.class("btn-ai-pill")],
            [
              text("📊 Dinamik Fiyat Stratejisini Hesapla"),
            ],
          ),
        ]),
        dom.element(
          "div",
          [a.id("ai-pricing-result"), a.class("ai-pricing-result-box")],
          [],
        ),
      ]),
    ],
  )
}

fn ai_review_sentiment_card() {
  dom.element(
    "section",
    [a.class("social-compose-card"), a.id("ai-review-sentiment")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [
            text("⭐ AI Misafir Yorumu & İtibar Asistanı (Auto-Responder)"),
          ]),
          dom.element("p", [a.class("muted")], [
            text(
              "Gelen misafir değerlendirmesini duygu analizinden geçirin, güçlü ve eksik noktaları ayrıştırarak 2 profesyonel yanıt taslağı alın.",
            ),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("ai-generator-box glass-subcard")], [
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-review-listing"),
              a.class("form-control"),
              a.attribute(
                "placeholder",
                "İlan / Tesis Adı (ör: Villa Panoramik Kaş)",
              ),
            ],
            [],
          ),
          dom.element(
            "select",
            [a.id("ai-review-rating"), a.class("form-control")],
            [
              dom.element("option", [a.value("5")], [
                text("⭐⭐⭐⭐⭐ 5 Puan (Mükemmel)"),
              ]),
              dom.element("option", [a.value("4")], [
                text("⭐⭐⭐⭐ 4 Puan (Çok İyi)"),
              ]),
              dom.element("option", [a.value("3")], [
                text("⭐⭐⭐ 3 Puan (Orta / Nötr)"),
              ]),
              dom.element("option", [a.value("2")], [
                text("⭐⭐ 2 Puan (Geliştirilmeli)"),
              ]),
              dom.element("option", [a.value("1")], [
                text("⭐ 1 Puan (Şikayet / Kriz)"),
              ]),
            ],
          ),
        ]),
        dom.element(
          "textarea",
          [
            a.id("ai-review-text"),
            a.class("form-control"),
            a.attribute("rows", "4"),
            a.attribute(
              "placeholder",
              "Misafirin bıraktığı yorumu buraya yapıştırın...",
            ),
          ],
          [],
        ),
        dom.element("div", [a.class("form-actions-right")], [
          dom.element(
            "button",
            [a.type_("button"), a.id("btn-ai-review"), a.class("btn-ai-pill")],
            [
              text("🔍 Duygu Durumunu Analiz Et & Yanıt Tasla"),
            ],
          ),
        ]),
        dom.element(
          "div",
          [a.id("ai-review-result"), a.class("ai-review-result-box")],
          [],
        ),
      ]),
    ],
  )
}

fn ai_bundle_cross_sell_card() {
  dom.element(
    "section",
    [a.class("social-compose-card"), a.id("ai-bundle-cross-sell")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [
            text("🎁 AI Çapraz Satış & Rota Paketleyici (Cross-Sell Engine)"),
          ]),
          dom.element("p", [a.class("muted")], [
            text(
              "Konaklama rezervasyonuna ek olarak transfer, tekne turu ve yerel macera deneyimlerini akıllı çapraz satış paketi olarak müşteriye sunun.",
            ),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("ai-generator-box glass-subcard")], [
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-bundle-locality"),
              a.class("form-control"),
              a.attribute(
                "placeholder",
                "Destinasyon (ör: Fethiye, Bodrum, Kaş)",
              ),
            ],
            [],
          ),
          dom.element(
            "select",
            [a.id("ai-bundle-category"), a.class("form-control")],
            [
              dom.element("option", [a.value("holiday_home")], [
                text("🏡 Tatil Evi / Villa Konaklaması"),
              ]),
              dom.element("option", [a.value("hotel")], [
                text("🏨 Otel Konaklaması"),
              ]),
              dom.element("option", [a.value("yacht")], [
                text("⛵ Mavi Tur / Yat"),
              ]),
            ],
          ),
        ]),
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "select",
            [a.id("ai-bundle-style"), a.class("form-control")],
            [
              dom.element("option", [a.value("Romantik Balayı")], [
                text("💑 Romantik Balayı"),
              ]),
              dom.element("option", [a.value("Aile Tatili")], [
                text("👨‍👩‍👧‍👦 Aile Tatili & Çocuk Dostu"),
              ]),
              dom.element("option", [a.value("Lüks & Konfor")], [
                text("💎 VIP Lüks & Konfor"),
              ]),
              dom.element("option", [a.value("Macera & Doğa")], [
                text("🧗 Macera, Doğa & Spor"),
              ]),
            ],
          ),
          dom.element(
            "input",
            [
              a.id("ai-bundle-guests"),
              a.type_("number"),
              a.class("form-control"),
              a.attribute("value", "2"),
              a.attribute("placeholder", "Misafir Sayısı"),
            ],
            [],
          ),
        ]),
        dom.element("div", [a.class("form-actions-right")], [
          dom.element(
            "button",
            [a.type_("button"), a.id("btn-ai-bundle"), a.class("btn-ai-pill")],
            [
              text("✨ Akıllı Çapraz Satış Paketi Oluştur"),
            ],
          ),
        ]),
        dom.element(
          "div",
          [a.id("ai-bundle-result"), a.class("ai-bundle-result-box")],
          [],
        ),
      ]),
    ],
  )
}

fn ai_support_copilot_card() {
  dom.element(
    "section",
    [a.class("social-compose-card"), a.id("ai-support-copilot")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [
            text("💬 AI Acente İletişim & WhatsApp / Destek Co-Pilot"),
          ]),
          dom.element("p", [a.class("muted")], [
            text(
              "Misafirlerin rezervasyon, evcil hayvan, giriş saatleri ve özel taleplerine tek tıkla kurum kültürüne uygun WhatsApp yanıt taslağı hazırlayın.",
            ),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("ai-generator-box glass-subcard")], [
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-support-name"),
              a.class("form-control"),
              a.attribute("placeholder", "Misafir Adı (ör: Ahmet Bey)"),
            ],
            [],
          ),
          dom.element(
            "select",
            [a.id("ai-support-channel"), a.class("form-control")],
            [
              dom.element("option", [a.value("whatsapp")], [text("📱 WhatsApp")]),
              dom.element("option", [a.value("email")], [text("✉️ E-Posta")]),
            ],
          ),
        ]),
        dom.element("div", [a.class("form-row-duo")], [
          dom.element(
            "input",
            [
              a.id("ai-support-listing"),
              a.class("form-control"),
              a.attribute("placeholder", "Tesis / İlan (ör: Kaş Sunset Villa)"),
            ],
            [],
          ),
          dom.element(
            "input",
            [
              a.id("ai-support-locality"),
              a.class("form-control"),
              a.attribute("placeholder", "Bölge (ör: Kaş)"),
            ],
            [],
          ),
        ]),
        dom.element(
          "textarea",
          [
            a.id("ai-support-question"),
            a.class("form-control"),
            a.attribute("rows", "4"),
            a.attribute(
              "placeholder",
              "Misafirin sorusunu buraya yapıştırın (ör: 'Erken giriş yapabilir miyiz? Evcil hayvan kabul ediyor musunuz?')",
            ),
          ],
          [],
        ),
        dom.element("div", [a.class("form-actions-right")], [
          dom.element(
            "button",
            [a.type_("button"), a.id("btn-ai-support"), a.class("btn-ai-pill")],
            [
              text("🚀 WhatsApp Yanıt Taslağı Oluştur"),
            ],
          ),
        ]),
        dom.element(
          "div",
          [a.id("ai-support-result"), a.class("ai-support-result-box")],
          [],
        ),
      ]),
    ],
  )
}

fn module_control_card() {
  dom.element("section", [a.class("quick"), a.id("module-controls")], [
    dom.element("h3", [], [text("Modül otomasyon merkezi")]),
    dom.element("p", [a.class("muted")], [
      text(
        "Her modülü manuel veya otomatik çalıştırın; günlük, haftalık ve aylık limitleri belirleyin.",
      ),
    ]),
    dom.element(
      "form",
      [
        a.method("post"),
        a.action("/admin/module-controls"),
        a.class("workspace-form"),
      ],
      [
        dom.element("select", [a.name("module_key")], [
          dom.element("option", [a.value("social")], [text("Sosyal medya")]),
          dom.element("option", [a.value("seo")], [text("SEO")]),
          dom.element("option", [a.value("translation")], [text("Çeviri")]),
          dom.element("option", [a.value("campaigns")], [text("Kampanyalar")]),
          dom.element("option", [a.value("commerce")], [text("E-ticaret")]),
          dom.element("option", [a.value("support")], [text("Destek")]),
        ]),
        dom.element("select", [a.name("mode")], [
          dom.element("option", [a.value("manual")], [text("Manuel")]),
          dom.element("option", [a.value("automatic")], [text("Otomatik")]),
        ]),
        dom.element(
          "input",
          [
            a.name("daily_limit"),
            a.type_("number"),
            a.value("0"),
            a.attribute("min", "0"),
          ],
          [],
        ),
        dom.element(
          "input",
          [
            a.name("weekly_limit"),
            a.type_("number"),
            a.value("0"),
            a.attribute("min", "0"),
          ],
          [],
        ),
        dom.element(
          "input",
          [
            a.name("monthly_limit"),
            a.type_("number"),
            a.value("0"),
            a.attribute("min", "0"),
          ],
          [],
        ),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Modül politikasını kaydet"),
        ]),
      ],
    ),
  ])
}

fn campaigns_form() {
  dom.element("section", [a.class("quick"), a.id("campaigns-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Kampanya merkezi")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Erken rezervasyon, son dakika ve dönem kampanyalarını tarih ve indirim kurallarıyla yönetin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Satış kuralları")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/campaigns"), a.class("campaign-form")],
      [
        dom.element("label", [], [
          text("Kampanya adı"),
          dom.element(
            "input",
            [
              a.name("name"),
              a.required(True),
              a.attribute("placeholder", "2027 Erken Rezervasyon"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Kampanya türü"),
          dom.element("select", [a.name("kind")], [
            dom.element("option", [a.attribute("value", "early_booking")], [
              text("Erken rezervasyon"),
            ]),
            dom.element("option", [a.attribute("value", "last_minute")], [
              text("Son dakika"),
            ]),
            dom.element("option", [a.attribute("value", "period")], [
              text("Dönem kampanyası"),
            ]),
            dom.element("option", [a.attribute("value", "coupon")], [
              text("Kupon kampanyası"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Kampanya kapsamı"),
          dom.element(
            "select",
            [a.name("campaign_audience"), a.id("campaign-audience")],
            [
              dom.element("option", [a.attribute("value", "all")], [
                text("Acente + tedarikçi (ortak yayın)"),
              ]),
              dom.element("option", [a.attribute("value", "agency")], [
                text("Yalnız acente"),
              ]),
              dom.element("option", [a.attribute("value", "supplier")], [
                text("Yalnız tedarikçi"),
              ]),
            ],
          ),
        ]),
        dom.element("label", [], [
          text("İndirim (%)"),
          dom.element(
            "input",
            [
              a.name("discount_percent"),
              a.type_("number"),
              a.attribute("min", "0"),
              a.attribute("max", "100"),
              a.attribute("step", "0.01"),
              a.required(True),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Başlangıç"),
          dom.element(
            "input",
            [a.name("starts_at"), a.type_("datetime-local")],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Bitiş"),
          dom.element(
            "input",
            [a.name("ends_at"), a.type_("datetime-local")],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Durum"),
          dom.element("select", [a.name("active")], [
            dom.element("option", [a.attribute("value", "true")], [
              text("Aktif"),
            ]),
            dom.element("option", [a.attribute("value", "false")], [
              text("Pasif"),
            ]),
          ]),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Kural notu"),
          dom.element(
            "textarea",
            [
              a.name("note"),
              a.attribute("rows", "2"),
              a.attribute(
                "placeholder",
                "Hangi ürünlerde ve hangi koşullarda uygulanacağını yazın",
              ),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Kampanyayı kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("h3", [], [text("Kampanyalar")]),
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Ad")]),
            dom.element("th", [], [text("Tür")]),
            dom.element("th", [], [text("Kapsam")]),
            dom.element("th", [], [text("Dönem")]),
            dom.element("th", [], [text("İndirim")]),
            dom.element("th", [], [text("Durum")]),
          ]),
        ]),
        dom.element("tbody", [a.id("campaigns-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "6"), a.class("empty-state")],
              [text("Kampanyalar yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
    dom.element("div", [a.id("coupons")], [
      dom.element("h2", [], [text("Kupon yönetimi")]),
      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/campaigns/coupons"),
          a.class("coupon-form"),
        ],
        [
          dom.element("label", [], [
            text("Kupon kodu"),
            dom.element(
              "input",
              [
                a.name("code"),
                a.required(True),
                a.attribute("placeholder", "YAZ2027"),
              ],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Kupon kapsamı"),
            dom.element(
              "select",
              [a.name("coupon_audience"), a.id("coupon-audience")],
              [
                dom.element("option", [a.attribute("value", "all")], [
                  text("Acente + tedarikçi"),
                ]),
                dom.element("option", [a.attribute("value", "agency")], [
                  text("Yalnız acente"),
                ]),
                dom.element("option", [a.attribute("value", "supplier")], [
                  text("Yalnız tedarikçi"),
                ]),
              ],
            ),
          ]),
          dom.element("label", [], [
            text("İndirim (%)"),
            dom.element(
              "input",
              [
                a.name("discount_percent"),
                a.type_("number"),
                a.attribute("min", "0"),
                a.attribute("max", "100"),
                a.attribute("step", "0.01"),
              ],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Kullanım sınırı"),
            dom.element(
              "input",
              [
                a.name("usage_limit"),
                a.type_("number"),
                a.attribute("min", "1"),
                a.attribute("placeholder", "Sınırsız"),
              ],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Başlangıç"),
            dom.element(
              "input",
              [a.name("starts_at"), a.type_("datetime-local")],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Bitiş"),
            dom.element(
              "input",
              [a.name("ends_at"), a.type_("datetime-local")],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Durum"),
            dom.element("select", [a.name("active")], [
              dom.element("option", [a.attribute("value", "true")], [
                text("Aktif"),
              ]),
              dom.element("option", [a.attribute("value", "false")], [
                text("Pasif"),
              ]),
            ]),
          ]),
          dom.element("button", [a.type_("submit"), a.class("primary")], [
            text("Kuponu kaydet"),
          ]),
        ],
      ),
      dom.element("div", [a.class("table-wrap")], [
        dom.element("table", [a.class("data-table")], [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Kod")]),
              dom.element("th", [], [text("Kapsam")]),
              dom.element("th", [], [text("İndirim")]),
              dom.element("th", [], [text("Kullanım")]),
              dom.element("th", [], [text("Bitiş")]),
              dom.element("th", [], [text("Durum")]),
            ]),
          ]),
          dom.element("tbody", [a.id("coupons-table-body")], [
            dom.element("tr", [], [
              dom.element(
                "td",
                [a.attribute("colspan", "6"), a.class("empty-state")],
                [text("Kuponlar yükleniyor…")],
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn team_form(lang: String) {
  dom.element("section", [a.class("quick"), a.id("team-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Üyelik ve ekip yönetimi")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Yönetici, alt acente, tedarikçi, personel ve müşteri hesaplarını oluşturun; aynı e-posta ile bilgileri ve parolayı güncelleyin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("5 üyelik tipi")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/team"), a.class("team-form")],
      [
        dom.element("label", [], [
          text("Ad soyad / unvan"),
          dom.element(
            "input",
            [
              a.name("display_name"),
              a.required(True),
              a.attribute("placeholder", "Operasyon Sorumlusu"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("E-posta"),
          dom.element(
            "input",
            [
              a.name("email"),
              a.type_("email"),
              a.required(True),
              a.attribute("placeholder", "kullanici@example.com"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Üyelik tipi"),
          dom.element("select", [a.name("membership_type")], [
            dom.element("option", [a.attribute("value", "admin")], [
              text("Yönetici"),
            ]),
            dom.element("option", [a.attribute("value", "sub_agency")], [
              text("Alt acente"),
            ]),
            dom.element("option", [a.attribute("value", "supplier")], [
              text("Tedarikçi"),
            ]),
            dom.element("option", [a.attribute("value", "staff")], [
              text("Personel"),
            ]),
            dom.element("option", [a.attribute("value", "customer")], [
              text("Müşteri"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Geçici / yeni parola"),
          dom.element(
            "input",
            [
              a.name("password"),
              a.type_("password"),
              a.attribute("minlength", "8"),
              a.attribute("placeholder", "Güncellemede boş bırakılabilir"),
              a.autocomplete("new-password"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Durum"),
          dom.element("select", [a.name("active")], [
            dom.element("option", [a.attribute("value", "true")], [
              text("Aktif"),
            ]),
            dom.element("option", [a.attribute("value", "false")], [
              text("Pasif"),
            ]),
          ]),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Üyeyi kaydet"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Üye")]),
            dom.element("th", [], [text("E-posta")]),
            dom.element("th", [], [text("Tip")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Giriş")]),
            dom.element("th", [], [text("Kayıt")]),
            dom.element("th", [], [text(i18n.t(lang, "permissions"))]),
          ]),
        ]),
        dom.element("tbody", [a.id("team-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "7"), a.class("empty-state")],
              [text("Üyeler yükleniyor…")],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn reports_form() {
  dom.element("section", [a.class("quick"), a.id("reports-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Operasyon raporu")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Satış envanteri, rezervasyonlar, müşteri talepleri ve arka plan görevlerini tek ekrandan izleyin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Canlı PostgreSQL")]),
    ]),
    dom.element("div", [a.class("metric-grid")], [
      metric_id(
        "Yayındaki ilan",
        "0",
        "Aktif satış envanteri",
        "report-published",
      ),
      metric_id("Rezervasyon", "0", "Toplam rezervasyon", "report-reservations"),
      metric_id("Müşteri", "0", "Kayıtlı müşteri", "report-customers"),
      metric_id("Yeni talep", "0", "Yanıt bekleyen iletişim", "report-contacts"),
    ]),
    // Haftalık özet: contacts + conversion dahil 7 günlük derleme; email
    // kuyruğa yazılır (agency.notifications), PDF yazdırma sayfası ayrı GET.
    dom.element("div", [a.class("weekly-digest-card")], [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [text("📧 Haftalık özet")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Son 7 günün yayın, talep, giriş, müşteri talebi ve dönüşüm serisinin derlemesi. E-posta Bildirim Merkezi kuyruğuna yazılır; PDF tarayıcının yazdırma penceresinden kaydedilir.",
            ),
          ]),
        ]),
        dom.element("div", [a.class("digest-actions")], [
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("btn-secondary-glow"),
              a.id("digest-pdf-btn"),
            ],
            [text("🖨 PDF olarak aç")],
          ),
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("btn-primary-glow"),
              a.id("digest-email-btn"),
            ],
            [text("✉️ E-posta ile gönder")],
          ),
        ]),
      ]),
      dom.element("div", [a.class("digest-summary"), a.id("digest-summary")], [
        dom.element("span", [a.class("muted")], [text("Özet yükleniyor…")]),
      ]),
      // Haftalık mini grafikler — JS tarafından 7 günlük seri verisiyle doldurulur
      dom.element(
        "div",
        [a.class("digest-sparklines"), a.id("digest-sparklines")],
        [],
      ),
      dom.element(
        "form",
        [
          a.id("digest-email-form"),
          a.class("digest-email-form"),
          a.attribute("hidden", "hidden"),
        ],
        [
          dom.element("label", [], [
            text("Alıcı e-posta"),
            dom.element(
              "input",
              [
                a.type_("email"),
                a.name("to"),
                a.required(True),
                a.placeholder("ornek@acente.com"),
              ],
              [],
            ),
          ]),
          dom.element("label", [], [
            text("Konu (isteğe bağlı)"),
            dom.element(
              "input",
              [
                a.type_("text"),
                a.name("subject"),
                a.placeholder("Haftalık özet"),
              ],
              [],
            ),
          ]),
          dom.element("div", [a.class("digest-form-actions")], [
            dom.element("button", [a.type_("submit"), a.class("primary")], [
              text("Kuyruğa al"),
            ]),
            dom.element(
              "button",
              [
                a.type_("button"),
                a.class("secondary"),
                a.id("digest-email-cancel"),
              ],
              [text("Vazgeç")],
            ),
          ]),
          dom.element(
            "span",
            [a.id("digest-email-feedback"), a.class("muted")],
            [],
          ),
        ],
      ),
    ]),
    dom.element("div", [a.class("report-grid")], [
      dom.element("div", [a.class("table-wrap")], [
        dom.element("h3", [], [text("Arka plan görevleri")]),
        dom.element("table", [a.class("data-table")], [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Görev")]),
              dom.element("th", [], [text("Durum")]),
              dom.element("th", [], [text("Deneme")]),
              dom.element("th", [], [text("Tamamlanma")]),
            ]),
          ]),
          dom.element("tbody", [a.id("report-tasks-body")], [
            dom.element("tr", [], [
              dom.element(
                "td",
                [a.attribute("colspan", "4"), a.class("empty-state")],
                [text("Görevler yükleniyor…")],
              ),
            ]),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("table-wrap")], [
        dom.element("h3", [], [text("Denetim kayıtları")]),
        dom.element("div", [a.class("report-filter-bar")], [
          dom.element(
            "input",
            [
              a.type_("search"),
              a.id("audit-search"),
              a.placeholder("İşlem, varlık veya metadata ara"),
            ],
            [],
          ),
          dom.element("select", [a.id("audit-entity")], [
            dom.element("option", [a.attribute("value", "")], [
              text("Tüm varlıklar"),
            ]),
            dom.element("option", [a.attribute("value", "listings")], [
              text("İlanlar"),
            ]),
            dom.element(
              "option",
              [a.attribute("value", "category_filter_groups")],
              [text("Filtre grupları")],
            ),
            dom.element(
              "option",
              [a.attribute("value", "category_filter_items")],
              [text("Filtre maddeleri")],
            ),
            dom.element("option", [a.attribute("value", "category_fields")], [
              text("Kategori alanları"),
            ]),
            dom.element("option", [a.attribute("value", "contract_versions")], [
              text("Sözleşmeler"),
            ]),
            dom.element("option", [a.attribute("value", "integration")], [
              text("Entegrasyon"),
            ]),
            dom.element("option", [a.attribute("value", "sync_job")], [
              text("Sync işleri"),
            ]),
          ]),
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("secondary"),
              a.id("audit-export-csv"),
            ],
            [text("CSV indir")],
          ),
        ]),
        dom.element("table", [a.class("data-table")], [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("İşlem")]),
              dom.element("th", [], [text("Varlık")]),
              dom.element("th", [], [text("Kullanıcı")]),
              dom.element("th", [], [text("Tarih")]),
              dom.element("th", [], [text("Detay")]),
            ]),
          ]),
          dom.element("tbody", [a.id("report-audits-body")], [
            dom.element("tr", [], [
              dom.element(
                "td",
                [a.attribute("colspan", "5"), a.class("empty-state")],
                [text("Kayıtlar yükleniyor…")],
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn media_form() {
  dom.element("section", [a.class("quick"), a.id("media-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Medya kütüphanesi & Fotoğraf editörü")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Fotoğrafları kırpın, boyutlandırın, renk filtreleri uygulayın ve kalite kaybı olmadan WebP/AVIF formatına dönüştürün.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("WebP / AVIF")]),
    ]),
    dom.element("div", [a.class("photo-editor-box")], [
      dom.element("div", [], [
        dom.element("label", [], [
          text("Fotoğraf yükleyin veya seçin"),
          dom.element(
            "input",
            [
              a.type_("file"),
              a.id("media-upload-input"),
              a.attribute("accept", "image/*"),
            ],
            [],
          ),
        ]),
        dom.element(
          "div",
          [a.id("photo-preview-stage"), a.class("photo-preview-stage")],
          [dom.element("canvas", [a.id("photo-canvas")], [])],
        ),
        dom.element(
          "div",
          [
            a.attribute(
              "style",
              "margin-top:12px;font-size:12.5px;color:#94a3b8;",
            ),
            a.id("photo-size-estimate"),
          ],
          [
            text(
              "Henüz fotoğraf seçilmedi. Yükleyerek hemen düzenlemeye başlayabilirsiniz.",
            ),
          ],
        ),
      ]),
      dom.element("div", [a.class("editor-controls")], [
        dom.element(
          "strong",
          [a.attribute("style", "color:#f8fafc;font-size:14px;")],
          [text("Kırpma Oranları")],
        ),
        dom.element("div", [a.class("ratio-btn-group")], [
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("ratio-btn active"),
              a.attribute("data-ratio", "free"),
            ],
            [text("Serbest")],
          ),
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("ratio-btn"),
              a.attribute("data-ratio", "16:9"),
            ],
            [text("16:9 Banner")],
          ),
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("ratio-btn"),
              a.attribute("data-ratio", "4:3"),
            ],
            [text("4:3 Galeri")],
          ),
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("ratio-btn"),
              a.attribute("data-ratio", "1:1"),
            ],
            [text("1:1 Kare")],
          ),
        ]),
        dom.element("div", [a.class("range-group")], [
          dom.element("span", [], [text("Parlaklık")]),
          dom.element(
            "input",
            [
              a.type_("range"),
              a.id("slider-brightness"),
              a.attribute("min", "50"),
              a.attribute("max", "150"),
              a.attribute("value", "100"),
            ],
            [],
          ),
        ]),
        dom.element("div", [a.class("range-group")], [
          dom.element("span", [], [text("Kontrast")]),
          dom.element(
            "input",
            [
              a.type_("range"),
              a.id("slider-contrast"),
              a.attribute("min", "50"),
              a.attribute("max", "150"),
              a.attribute("value", "100"),
            ],
            [],
          ),
        ]),
        dom.element("div", [a.class("range-group")], [
          dom.element("span", [], [text("Doygunluk")]),
          dom.element(
            "input",
            [
              a.type_("range"),
              a.id("slider-saturation"),
              a.attribute("min", "0"),
              a.attribute("max", "200"),
              a.attribute("value", "100"),
            ],
            [],
          ),
        ]),
        dom.element(
          "button",
          [
            a.type_("button"),
            a.id("photo-export-btn"),
            a.class("primary"),
            a.attribute("style", "margin-top:14px;"),
          ],
          [text("💾 WebP Olarak İndir / Kaydet")],
        ),
      ]),
    ]),
  ])
}

fn abandoned_carts_form() {
  dom.element("section", [a.class("quick"), a.id("abandoned-carts-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Terk edilmiş sepetler")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Rezervasyon veya sipariş sürecini tamamlamayan müşterileri tespit edin, otomatik/manuel hatırlatma gönderin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill warning")], [
        text("Geri Kazanım"),
      ]),
    ]),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Müşteri / Ziyaretçi")]),
            dom.element("th", [], [text("İletişim")]),
            dom.element("th", [], [text("Sepetteki Ürünler")]),
            dom.element("th", [], [text("Tutar")]),
            dom.element("th", [], [text("Son Hareket")]),
            dom.element("th", [], [text("İşlem")]),
          ]),
        ]),
        dom.element("tbody", [a.id("abandoned-carts-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "6"), a.class("empty-state")],
              [
                text("Terk edilmiş sepetler yükleniyor…"),
              ],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn sub_agencies_form() {
  dom.element("section", [a.class("quick"), a.id("sub-agencies-workspace")], [
    dom.element(
      "div",
      [a.id("partner-network-workspace"), a.attribute("aria-live", "polite")],
      [text("Acente ağı yükleniyor…")],
    ),
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("B2B Acente ve Tedarikçi Yönetimi")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Alt acentelerin üyeliklerini onaylayın, TÜRSAB ve vergi belgelerini denetleyin, ilan ekleyebilecekleri kategorileri yetkilendirin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("B2B Ağı")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/team"), a.class("team-form")],
      [
        hidden_field("membership_type", "sub_agency"),
        dom.element("label", [], [
          text("Acente / Firma adı"),
          dom.element(
            "input",
            [
              a.name("name"),
              a.required(True),
              a.attribute("placeholder", "Akdeniz Turizm Ltd."),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Yetkili e-posta"),
          dom.element(
            "input",
            [
              a.name("email"),
              a.type_("email"),
              a.required(True),
              a.attribute("placeholder", "acente@akdeniz.com"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Başlangıç parolası"),
          dom.element(
            "input",
            [
              a.name("password"),
              a.type_("password"),
              a.required(True),
              a.attribute("placeholder", "••••••••"),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Yeni acente kaydı oluştur"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element(
        "h3",
        [
          a.attribute(
            "style",
            "padding:16px 18px 0;margin:0;font-size:15px;color:#fff;",
          ),
        ],
        [text("Kayıtlı Acenteler ve Tedarikçiler")],
      ),
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Acente")]),
            dom.element("th", [], [text("E-posta")]),
            dom.element("th", [], [text("Yetki Türü")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Kayıt")]),
          ]),
        ]),
        dom.element("tbody", [a.id("team-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "5"), a.class("empty-state")],
              [
                text("Acenteler yükleniyor…"),
              ],
            ),
          ]),
        ]),
      ]),
    ]),
    supplier_campaigns_panel(),
  ])
}

fn supplier_campaigns_panel() {
  dom.element("section", [a.class("supplier-campaigns-panel")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h3", [], [text("Tedarikçi kampanyaları")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Tedarikçilerin kendi ürünlerine uyguladığı kampanyaları aynı kampanya motorundan yönetin; acente satışında otomatik olarak dikkate alınır.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [
        text("Ortak kampanya motoru"),
      ]),
    ]),
    dom.element("div", [a.class("supplier-campaign-actions")], [
      dom.element(
        "a",
        [
          a.href(
            "/admin/supplier-campaigns?audience=supplier#campaigns-workspace",
          ),
          a.class("primary"),
        ],
        [text("Tedarikçi kampanyası oluştur")],
      ),
      dom.element(
        "a",
        [
          a.href("/admin/campaigns?audience=all#campaigns-workspace"),
          a.class("secondary"),
        ],
        [text("Tüm kampanyaları yönet")],
      ),
    ]),
    dom.element("section", [a.class("ai-workforce-suite")], [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [text("AI Çalışanlar Holding Merkezi")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Her çalışan ayrı yetki, görev kuyruğu ve insan onayı politikasıyla çalışır.",
            ),
          ]),
        ]),
        dom.element("span", [a.class("status-pill")], [
          text("Denetimli otonomi"),
        ]),
      ]),
      dom.element("div", [a.class("ai-workforce-grid")], [
        ai_workforce_card(
          "Gelir yöneticisi",
          "Talep, fiyat, stok ve kampanya önerileri",
          "revenue_manager",
        ),
        ai_workforce_card(
          "Satış asistanı",
          "Upsell, sepet kurtarma ve rezervasyon fırsatları",
          "sales_assistant",
        ),
        ai_workforce_card(
          "Kampanya yöneticisi",
          "Hedef kitle, kanal ve içerik taslakları",
          "campaign_manager",
        ),
        ai_workforce_card(
          "Müşteri destek çalışanı",
          "Soruları sınıflandırır ve yanıt taslağı oluşturur",
          "support_agent",
        ),
        ai_workforce_card(
          "Risk ve güvenlik",
          "Sahtekarlık, şikayet ve işlem risklerini izler",
          "risk_guardian",
        ),
        ai_workforce_card(
          "Yönetim analisti",
          "Satış ve operasyon özetleri üretir",
          "executive_analyst",
        ),
        ai_workforce_card(
          "Katalog kalite çalışanı",
          "Eksik alanları ve duplicate ilanları bulur",
          "product_quality",
        ),
        ai_workforce_card(
          "Stok ve kapasite çalışanı",
          "Talep, kapasite ve overbooking sinyallerini izler",
          "inventory_manager",
        ),
        ai_workforce_card(
          "Kişiselleştirme çalışanı",
          "Kullanıcı niyetine göre ürün ve kategori önerir",
          "personalization",
        ),
        ai_workforce_card(
          "Rezervasyon kurtarma",
          "Terk edilen arama ve rezervasyonları takip eder",
          "recovery_manager",
        ),
        ai_workforce_card(
          "Sadakat yöneticisi",
          "Puan, seviye ve müşteri yaşam boyu değerini izler",
          "loyalty_manager",
        ),
        ai_workforce_card(
          "Finans mutabakatı",
          "Ödeme, iade ve tedarikçi farklarını bulur",
          "finance_reconciliation",
        ),
        ai_workforce_card(
          "Reklam yöneticisi",
          "Google, Meta, Yandex, Baidu ve Çin kanalları için taslak üretir",
          "ad_campaign_manager",
        ),
      ]),
    ]),
    dom.element("section", [a.class("ai-governance-suite")], [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [text("AI Orkestrasyon ve Güvenlik")]),
          dom.element("p", [a.class("muted")], [
            text(
              "İş akışları, politikalar, bilgi, model maliyetleri ve güvenlik olayları.",
            ),
          ]),
        ]),
        dom.element("span", [a.class("status-pill")], [text("Merkezi denetim")]),
      ]),
      dom.element("div", [a.class("ai-governance-grid")], [
        ai_governance_card(
          "İş akışı kuyruğu",
          "Çalışanlar arası görev aktarımı",
          "workflow_runs",
        ),
        ai_governance_card(
          "Politika merkezi",
          "AI karar kuralları ve sınırlar",
          "policies",
        ),
        ai_governance_card(
          "Bilgi merkezi",
          "İlan, sözleşme ve içerik bilgisi",
          "knowledge_documents",
        ),
        ai_governance_card(
          "Model yönlendirme",
          "Göreve göre sağlayıcı ve model",
          "model_routes",
        ),
        ai_governance_card(
          "Maliyet merkezi",
          "Token, model ve görev maliyetleri",
          "usage_costs",
        ),
        ai_governance_card(
          "Deney laboratuvarı",
          "A/B test ve dönüşüm ölçümü",
          "experiments",
        ),
        ai_governance_card(
          "Geri bildirim",
          "İnsan onaylarından öğrenme",
          "feedback_events",
        ),
        ai_governance_card(
          "Güvenlik olayları",
          "PII, injection ve politika ihlalleri",
          "security_events",
        ),
        ai_governance_card(
          "Worker sağlık paneli",
          "Heartbeat, kuyruk ve hata durumları",
          "worker_health",
        ),
        ai_governance_card(
          "Prompt sürümleri",
          "Prompt ve model geçmişi",
          "prompt_versions",
        ),
        ai_governance_card(
          "AI bütçeleri",
          "Tenant ve modül bazlı maliyet limitleri",
          "budget_limits",
        ),
        ai_governance_card(
          "Gizlilik merkezi",
          "Maskeleme, rıza ve veri silme talepleri",
          "privacy_events",
        ),
        ai_governance_card(
          "Canary yayınlar",
          "AI modüllerini kontrollü yayınlama ve rollback",
          "release_channels",
        ),
        ai_governance_card(
          "Karar auditleri",
          "Gerekçe, model, prompt ve güven skorları",
          "decision_audits",
        ),
      ]),
    ]),
    dom.element("section", [a.class("ai-commerce-suite")], [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h3", [], [text("AI Turizm ve E-Ticaret Merkezi")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Paket, stok, komisyon, müşteri ve çok kanallı satış yönetimi.",
            ),
          ]),
        ]),
        dom.element("span", [a.class("status-pill")], [text("Ticaret zekâsı")]),
      ]),
      dom.element("div", [a.class("ai-commerce-grid")], [
        ai_governance_card(
          "Dinamik paketler",
          "Otel, transfer, tur, araç ve aktivite paketleri",
          "travel_packages",
        ),
        ai_governance_card(
          "Müsaitlik merkezi",
          "Kapasite, rezervasyon ve overbooking takibi",
          "availability",
        ),
        ai_governance_card(
          "Tedarikçi skorları",
          "Kalite, yanıt, iptal ve kârlılık puanları",
          "supplier_scores",
        ),
        ai_governance_card(
          "Komisyon motoru",
          "Kategori, kanal ve tedarikçi bazlı kurallar",
          "commission_rules",
        ),
        ai_governance_card(
          "Tekil müşteri profili",
          "Tercihler, izinler, LTV ve sadakat",
          "customer_profiles",
        ),
        ai_governance_card(
          "Öneri motoru",
          "Kişiselleştirilmiş ürün ve paket önerileri",
          "recommendations",
        ),
        ai_governance_card(
          "Kanal merkezi",
          "Web, B2B, mesajlaşma ve reklam kanalları",
          "channel_connections",
        ),
      ]),
    ]),
  ])
}

fn ai_workforce_card(title: String, description: String, key: String) {
  dom.element("article", [a.class("ai-workforce-card")], [
    dom.element("div", [a.class("ai-workforce-card__head")], [
      dom.element("h4", [], [text(title)]),
      dom.element("span", [a.class("status-pill")], [text("Onaylı")]),
    ]),
    dom.element("p", [a.class("muted")], [text(description)]),
    dom.element("code", [], [text(key)]),
    dom.element("label", [a.class("check-row")], [
      dom.element(
        "input",
        [a.type_("checkbox"), a.name("ai_module_" <> key <> "_enabled")],
        [],
      ),
      text("Çalışanı etkinleştir"),
    ]),
    dom.element("label", [], [
      text("Otonomi"),
      dom.element("select", [a.name("ai_module_" <> key <> "_autonomy")], [
        dom.element("option", [a.attribute("value", "suggest")], [
          text("Öneri üret"),
        ]),
        dom.element("option", [a.attribute("value", "draft")], [
          text("Taslak oluştur"),
        ]),
        dom.element("option", [a.attribute("value", "approval_required")], [
          text("Onay gerektirir"),
        ]),
      ]),
    ]),
  ])
}

fn ai_governance_card(title: String, description: String, key: String) {
  dom.element("article", [a.class("ai-governance-card")], [
    dom.element("h4", [], [text(title)]),
    dom.element("p", [a.class("muted")], [text(description)]),
    dom.element("code", [], [text("ai." <> key)]),
    dom.element(
      "button",
      [
        a.type_("button"),
        a.class("secondary"),
        a.attribute("data-ai-governance", key),
      ],
      [text("Yönet")],
    ),
  ])
}

fn popups_banners_form() {
  dom.element("section", [a.class("quick"), a.id("popups-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Popuplar ve reklam bannerları")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Duyuru, erken rezervasyon kampanyaları, çerez politikası pencereleri ve reklam banner yerleşimlerini yönetin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Etkileşim")]),
    ]),
    dom.element(
      "form",
      [a.method("post"), a.action("/admin/popups"), a.class("campaign-form")],
      [
        dom.element("label", [], [
          text("Popup başlığı"),
          dom.element(
            "input",
            [
              a.name("title"),
              a.required(True),
              a.attribute("placeholder", "Erken Rezervasyon Fırsatları"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Popup türü"),
          dom.element("select", [a.name("kind")], [
            dom.element("option", [a.attribute("value", "campaign")], [
              text("Kampanya İndirimi"),
            ]),
            dom.element("option", [a.attribute("value", "announcement")], [
              text("Duyuru"),
            ]),
            dom.element("option", [a.attribute("value", "cookie")], [
              text("Çerez Politikası (Cookie Consent)"),
            ]),
            dom.element("option", [a.attribute("value", "lead")], [
              text("Bülten / İletişim"),
            ]),
          ]),
        ]),
        dom.element("label", [], [
          text("Gecikme süresi (saniye)"),
          dom.element(
            "input",
            [
              a.name("delay_seconds"),
              a.type_("number"),
              a.attribute("value", "3"),
              a.attribute("min", "0"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Buton metni"),
          dom.element(
            "input",
            [a.name("button_text"), a.attribute("placeholder", "Hemen İncele")],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Buton yönlendirme linki"),
          dom.element(
            "input",
            [
              a.name("button_link"),
              a.attribute("placeholder", "/kampanyalar"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Görsel URL"),
          dom.element(
            "input",
            [
              a.name("image_url"),
              a.attribute("placeholder", "https://.../banner.webp"),
            ],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Popup metni / Açıklama"),
          dom.element(
            "textarea",
            [
              a.name("content"),
              a.attribute("rows", "2"),
              a.attribute(
                "placeholder",
                "Seçili villalarda %20'ye varan erken rezervasyon fırsatları başladı.",
              ),
            ],
            [],
          ),
        ]),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Popup oluştur"),
        ]),
      ],
    ),
    dom.element("div", [a.class("table-wrap")], [
      dom.element(
        "h3",
        [
          a.attribute(
            "style",
            "padding:16px 18px 0;margin:0;font-size:15px;color:#fff;",
          ),
        ],
        [text("Tanımlı Popuplar")],
      ),
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Başlık")]),
            dom.element("th", [], [text("Tür")]),
            dom.element("th", [], [text("Gecikme")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("İşlem")]),
          ]),
        ]),
        dom.element("tbody", [a.id("popups-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "5"), a.class("empty-state")],
              [
                text("Popuplar yükleniyor…"),
              ],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn offers_form() {
  dom.element("section", [a.class("quick"), a.id("offers-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Teklif ve Onay Formu (PDF / WhatsApp)")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Rezervasyon öncesi müşteriye özel teklif, rezervasyon sonrası resmi onay formu oluşturun; tek tıkla WhatsApp ve e-posta ile iletin.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Anında İletim")]),
    ]),
    dom.element(
      "form",
      [
        a.id("offer-builder-form"),
        a.class("listing-form"),
        a.attribute("data-js-only", "true"),
      ],
      [
        dom.element("label", [], [
          text("Teklif referans kodu"),
          dom.element(
            "input",
            [
              a.id("offer-ref"),
              a.name("reference_code"),
              a.attribute("value", "TKF-2026-001"),
              a.required(True),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Müşteri adı soyadı"),
          dom.element(
            "input",
            [
              a.id("offer-customer"),
              a.name("customer_name"),
              a.attribute("placeholder", "Ahmet Yılmaz"),
              a.required(True),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Telefon (WhatsApp için 90... formatında)"),
          dom.element(
            "input",
            [
              a.id("offer-phone"),
              a.name("phone"),
              a.attribute("placeholder", "905321234567"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("E-posta adresi"),
          dom.element(
            "input",
            [
              a.id("offer-email"),
              a.name("email"),
              a.attribute("placeholder", "ahmet@example.com"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("İlan adı / Hizmet"),
          dom.element(
            "input",
            [
              a.id("offer-listing"),
              a.name("listing_title"),
              a.attribute("value", "Bodrum Sunset Deluxe Villa"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Tarihler / Kiralama Dönemi"),
          dom.element(
            "input",
            [
              a.id("offer-dates"),
              a.name("dates"),
              a.attribute("value", "10 - 17 Ağustos 2026 (7 Gece)"),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Toplam teklif tutarı"),
          dom.element(
            "input",
            [
              a.id("offer-price"),
              a.name("price_text"),
              a.attribute("value", "75.000 TL"),
            ],
            [],
          ),
        ]),
        dom.element("label", [a.class("field-wide")], [
          text("Teklif şartları, ödeme koşulları ve notlar"),
          dom.element(
            "textarea",
            [
              a.id("offer-notes"),
              a.name("notes"),
              a.attribute("rows", "2"),
              a.attribute(
                "placeholder",
                "Girişte %35 peşinat, kalan tutar varışta ödenecektir. Elektrik ve su dahildir.",
              ),
            ],
            [],
          ),
        ]),
      ],
    ),
    dom.element("div", [a.class("offer-preview-card")], [
      dom.element("div", [a.class("offer-header")], [
        dom.element(
          "strong",
          [a.attribute("style", "color:#06b6d4;font-size:15px;")],
          [text("Canlı Teklif / Form Mesajı Önizlemesi")],
        ),
        dom.element("span", [a.class("status-pill")], [text("Gönderime Hazır")]),
      ]),
      dom.element(
        "pre",
        [
          a.id("offer-preview-content"),
          a.attribute(
            "style",
            "white-space:pre-wrap;font-family:inherit;font-size:13.5px;color:#e2e8f0;background:rgba(0,0,0,0.3);padding:16px;border-radius:12px;border:1px solid rgba(255,255,255,0.06);",
          ),
        ],
        [
          text("Teklif bilgileri doldurulduğunda mesaj burada biçimlenecektir…"),
        ],
      ),
      dom.element("div", [a.class("offer-actions")], [
        dom.element(
          "button",
          [
            a.type_("button"),
            a.id("offer-whatsapp-btn"),
            a.class("whatsapp-btn"),
          ],
          [text("📱 WhatsApp ile Gönder")],
        ),
        dom.element(
          "button",
          [a.type_("button"), a.id("offer-mail-btn"), a.class("secondary")],
          [text("✉️ E-posta ile Gönder")],
        ),
        dom.element(
          "button",
          [
            a.type_("button"),
            a.class("secondary"),
            a.attribute("onclick", "window.print()"),
          ],
          [text("🖨️ PDF / Yazdır")],
        ),
      ]),
    ]),
    no_post_without_js(),
  ])
}

fn integration_yolcu360_form() {
  integration_card("Araç Kiralama · API", "yolcu360", "car_api", [
    setting_input("API adresi", "endpoint", "https://api.example.com/v1"),
    setting_input("API Key / Client ID", "api_key", "y360_..."),
    setting_input("Secret Key", "secret", "••••••••"),
  ])
}

fn integration_transfer_form() {
  integration_card("Transfer · API bağlantısı", "transfer_api", "transfer_api", [
    setting_input("Servis sağlayıcı kodu", "provider_name", "sağlayıcı-kodu"),
    setting_input("API Anahtarı", "api_key", "rt_..."),
    setting_input("Varsayılan Kar Marjı (%)", "margin_percent", "10.00"),
  ])
}

fn integration_hotel_apis_form() {
  integration_card(
    "Otel ve Uçak · API bağlantısı",
    "paximum_tatilbudur",
    "hotel_flight_api",
    [
      setting_input("Sağlayıcı kodu", "provider_name", "sağlayıcı-kodu"),
      setting_input("Acente Kodu", "agency_code", "AGY_1001"),
      setting_input("API Token", "token", "••••••••"),
    ],
  )
}

fn integration_whatsapp_form() {
  integration_card(
    "WhatsApp ve SMS mesajlaşma",
    "sms_whatsapp",
    "notification",
    [
      setting_input("SMS kullanıcı adı", "netgsm_user", "kullanıcı adı"),
      setting_input("SMS parolası", "netgsm_pass", "••••••••"),
      setting_input(
        "WhatsApp Telefon No ID",
        "whatsapp_phone_id",
        "10987654321",
      ),
      setting_input(
        "WhatsApp Kalıcı Erişim Belirteci",
        "whatsapp_token",
        "EAAB...",
      ),
      setting_input(
        "Onaylı öneri şablonu",
        "whatsapp_recommendation_template",
        "travel_recommendation",
      ),
      setting_input("Şablon dil kodu", "whatsapp_recommendation_language", "tr"),
    ],
  )
}

fn hidden_field(name: String, value: String) {
  dom.element(
    "input",
    [a.type_("hidden"), a.name(name), a.attribute("value", value)],
    [],
  )
}

fn integration_active() {
  dom.element("label", [], [
    text("Durum"),
    dom.element("select", [a.name("active")], [
      dom.element("option", [a.attribute("value", "true")], [text("Aktif")]),
      dom.element("option", [a.attribute("value", "false")], [text("Pasif")]),
    ]),
  ])
}

fn integrations_form() {
  dom.element("section", [a.class("quick"), a.id("integrations-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("h2", [], [text("Bağlantı ayarları")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Her servis kendi kartından kaydedilir. Parolalar ve anahtarlar yalnızca bu acentenin alanında tutulur.",
          ),
        ]),
      ]),
      dom.element("span", [a.class("status-pill")], [text("Ayrı bağlantılar")]),
    ]),
    dom.element("div", [a.class("integration-grid")], [
      integration_parampos_form(),
      integration_qnb_esolutions_form(),
      integration_yolcu360_form(),
      integration_transfer_form(),
      integration_hotel_apis_form(),
      integration_whatsapp_form(),
      integration_smtp_form(),
      integration_social_form(),
      integration_nexus_form(),
      integration_ota_form(),
      integration_search_engines_form(),
    ]),
    dom.element("div", [a.class("table-wrap")], [
      dom.element("h3", [], [text("Kayıtlı bağlantılar")]),
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Sağlayıcı")]),
            dom.element("th", [], [text("Tür")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Bilgi")]),
          ]),
        ]),
        dom.element("tbody", [a.id("integrations-table-body")], [
          dom.element("tr", [], [
            dom.element(
              "td",
              [a.attribute("colspan", "4"), a.class("empty-state")],
              [
                text("Bağlantılar yükleniyor…"),
              ],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn integration_search_engines_form() {
  dom.element("div", [a.class("integration-grid integration-search-engines")], [
    integration_card("Google Search Console", "google_search_console", "seo", [
      setting_input("Site adresi", "site_url", "https://ornek.com"),
      setting_input(
        "HTML doğrulama kodu",
        "verification_code",
        "google-site-verification=...",
      ),
    ]),
    integration_card("Google Merchant Center", "google_merchant", "commerce", [
      setting_input("Merchant hesap ID", "account_id", "123456789"),
      setting_input("Ülke kodu", "merchant_country", "TR"),
      setting_input(
        "Ürün feed URL",
        "feed_url",
        "https://ornek.com/feeds/google.xml",
      ),
    ]),
    integration_card("Google Analytics 4", "google_analytics", "analytics", [
      setting_input("Ölçüm ID", "measurement_id", "G-XXXXXXX"),
    ]),
    integration_card("Google Tag Manager", "google_tag_manager", "analytics", [
      setting_input("Konteyner ID", "container_id", "GTM-XXXXXXX"),
    ]),
    integration_card("Yandex Webmaster", "yandex_webmaster", "seo", [
      setting_input("Site adresi", "site_url", "https://ornek.com"),
      setting_input(
        "Doğrulama kodu",
        "verification_code",
        "yandex_verification",
      ),
    ]),
    integration_card("Baidu Search", "baidu_search", "seo", [
      setting_input("Site adresi", "site_url", "https://ornek.com"),
      setting_input("Doğrulama kodu", "verification_code", "baidu_verification"),
    ]),
  ])
}

fn integration_card(
  title: String,
  provider: String,
  kind: String,
  fields: List(dom.Element(Nil)),
) {
  dom.element(
    "form",
    [
      a.method("post"),
      a.action("/admin/integrations"),
      a.class("integration-card"),
    ],
    list.flatten([
      [
        hidden_field("provider", provider),
        hidden_field("kind", kind),
        dom.element("h3", [], [text(title)]),
        dom.element("p", [a.class("muted")], [
          text("Bilgileri girin ve bağlantıyı ayrı olarak kaydedin."),
        ]),
      ],
      fields,
      [
        integration_active(),
        dom.element(
          "button",
          [
            a.type_("button"),
            a.class("secondary integration-test-btn"),
            a.attribute("data-provider", provider),
            a.attribute("data-kind", kind),
          ],
          [
            text("Kayıt durumunu kontrol et"),
          ],
        ),
        case provider {
          "nexus" ->
            dom.element(
              "button",
              [
                a.type_("button"),
                a.class("primary nexus-request-btn"),
                a.id("nexus-connection-request"),
              ],
              [text("NEXUS'a bağlantı isteği gönder")],
            )
          _ -> dom.element("span", [], [])
        },
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Bağlantıyı kaydet"),
        ]),
      ],
    ]),
  )
}

fn integration_parampos_form() {
  integration_card(
    "Alternatif Kartlı Ödeme · Sanal POS",
    "parampos",
    "payment",
    [
      setting_input("Üye işyeri kodu", "client_code", "CLIENT_CODE"),
      setting_input("Kullanıcı adı", "username", "Kullanıcı adı"),
      setting_input("Parola", "password", "••••••••"),
      setting_input("GUID", "guid", "GUID"),
      setting_input(
        "Servis adresi (opsiyonel)",
        "endpoint",
        "ParamPOS servis URL'si",
      ),
    ],
  )
}

fn integration_qnb_esolutions_form() {
  integration_card(
    "QNB eSolutions · E-fatura ve E-arşiv",
    "qnb_esolutions",
    "document",
    [
      setting_input("Hesap / kullanıcı adı", "username", "QNB kullanıcı adı"),
      setting_input("Parola", "password", "••••••••"),
      setting_input("API anahtarı (varsa)", "api_key", "API anahtarı"),
      setting_input("Servis adresi (varsa)", "endpoint", "https://..."),
    ],
  )
}

fn integration_smtp_form() {
  integration_card("SMTP · E-posta", "smtp", "notification", [
    setting_input("SMTP sunucusu", "host", "smtp.example.com"),
    setting_input("Kullanıcı", "username", "info@example.com"),
    setting_input("Parola", "password", "••••••••"),
  ])
}

fn integration_nexus_form() {
  integration_card("NEXUS · Envanter", "nexus", "connectivity", [
    setting_input("Bağlantı adresi", "endpoint", "https://nexus.example.com"),
    setting_input("API anahtarı", "api_key", "nx_..."),
    setting_input(
      "NEXUS acente kodu (opsiyonel)",
      "agency_code",
      "Boş bırakılırsa bu tenant UUID'si kullanılır",
    ),
  ])
}

fn integration_social_form() {
  integration_card(
    "Sosyal Medya · Meta / Threads / Pinterest",
    "social",
    "social",
    [
      setting_input("Meta erişim belirteci", "access_token", "EAAB..."),
      setting_input("Facebook Sayfa ID", "page_id", "123456789"),
      setting_input("Instagram Hesap ID", "instagram_id", "1784..."),
      setting_input(
        "Threads Hesap ID",
        "threads_user_id",
        "threads kullanıcı ID",
      ),
      setting_input(
        "Threads / Pinterest belirteci",
        "pinterest_token",
        "token_...",
      ),
      setting_input("Pinterest pano ID", "pinterest_board_id", "board-id"),
      setting_input("Meta OAuth uygulama ID", "app_id", "123456789"),
      setting_input("Meta OAuth uygulama sırrı", "app_secret", "••••••••"),
      setting_input(
        "TikTok Business hesap ID",
        "tiktok_business_id",
        "business-id",
      ),
      setting_input("YouTube kanal ID", "youtube_channel_id", "UC..."),
      setting_input(
        "Meta OAuth callback adresi",
        "meta_redirect_uri",
        "https://site.tld/auth/social/meta/callback",
      ),
      setting_input(
        "TikTok OAuth callback adresi",
        "tiktok_redirect_uri",
        "https://site.tld/auth/social/tiktok/callback",
      ),
      setting_input(
        "YouTube OAuth callback adresi",
        "youtube_redirect_uri",
        "https://site.tld/auth/social/youtube/callback",
      ),
    ],
  )
}

fn integration_ota_form() {
  integration_card("OTA · Kanal yöneticisi", "ota", "channel", [
    setting_input("Bağlantı adresi", "endpoint", "https://ota.example.com"),
    setting_input("API anahtarı", "api_key", "ota_..."),
  ])
}

fn region_form() {
  dom.element(
    "section",
    [
      a.class("quick workspace-card full-width-workspace"),
      a.id("regions-workspace"),
    ],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("h2", [], [text("Bölge ve Destinasyon Yönetimi")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Ülke, şehir veya alt bölge oluşturun. Slug ve SEO alanları ilan filtrelerinde ve arama motorlarında kullanılır.",
            ),
          ]),
        ]),
        dom.element("span", [a.class("status-pill")], [text("Harita & SEO")]),
      ]),
      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/regions"),
          a.class("region-form workspace-form"),
        ],
        [
          dom.element("div", [a.class("form-grid-2")], [
            dom.element("label", [], [
              dom.element("div", [a.class("field-label-bar")], [
                dom.element("span", [], [text("Bölge adı")]),
              ]),
              dom.element(
                "input",
                [
                  a.name("name"),
                  a.id("region-input-name"),
                  a.required(True),
                  a.attribute("placeholder", "Örn: Kaş"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              dom.element("div", [a.class("field-label-bar")], [
                dom.element("span", [], [text("Kalıcı Bağlantı (Slug)")]),
                dom.element("span", [a.class("field-helper-pill")], [
                  text("Otomatik oluşturulur"),
                ]),
              ]),
              dom.element(
                "input",
                [
                  a.name("slug"),
                  a.id("region-input-slug"),
                  a.required(True),
                  a.attribute("placeholder", "antalya-kas"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              dom.element("div", [a.class("field-label-bar")], [
                dom.element("span", [], [text("Ülke kodu")]),
                dom.element("span", [a.class("field-helper-pill")], [
                  text("Varsayılan: TR"),
                ]),
              ]),
              dom.element(
                "input",
                [
                  a.name("country_code"),
                  a.attribute("value", "TR"),
                  a.required(True),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              dom.element("div", [a.class("field-label-bar")], [
                dom.element("span", [], [text("Üst bölge ID (opsiyonel)")]),
                dom.element("span", [a.class("field-helper-pill")], [
                  text("İsteğe bağlı"),
                ]),
              ]),
              dom.element(
                "input",
                [
                  a.name("parent_id"),
                  a.attribute(
                    "placeholder",
                    "Bağlı olduğu üst bölge ID veya boş bırakın",
                  ),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Enlem"),
              dom.element(
                "input",
                [
                  a.name("latitude"),
                  a.id("region-input-latitude"),
                  a.attribute("placeholder", "36.2000"),
                ],
                [],
              ),
            ]),
            dom.element("label", [], [
              text("Boylam"),
              dom.element(
                "input",
                [
                  a.name("longitude"),
                  a.id("region-input-longitude"),
                  a.attribute("placeholder", "29.6500"),
                ],
                [],
              ),
            ]),
          ]),
          dom.element("div", [a.class("ai-region-tools")], [
            dom.element(
              "button",
              [a.type_("button"), a.class("secondary"), a.id("btn-ai-geocode")],
              [text("🧭 Ülke/şehirden koordinat bul")],
            ),
            dom.element(
              "button",
              [
                a.type_("button"),
                a.class("secondary"),
                a.id("btn-ai-region-enrich"),
              ],
              [text("✨ Bölgeyi ve çevre mekanlarını oluştur")],
            ),
            dom.element("span", [a.class("muted"), a.id("region-ai-status")], [
              text("AI araçları: koordinat, bölge ve yakın mekan önerileri"),
            ]),
          ]),
          dom.element("div", [a.class("form-group-full")], [
            dom.element("div", [a.class("field-label-bar")], [
              dom.element("span", [], [text("Bölge Tanıtım Açıklaması")]),
              dom.element("span", [a.class("field-helper-pill active")], [
                text("Zengin Metin Editörü"),
              ]),
            ]),
            dom.element(
              "textarea",
              [
                a.name("description"),
                a.id("region-input-description"),
                a.class("rich-textarea"),
                a.attribute("data-rich-editor", "true"),
                a.attribute("rows", "5"),
                a.attribute(
                  "placeholder",
                  "Bölgenin tarihi, doğası, koyları ve konaklama ayrıcalıkları hakkında detaylı tanıtım...",
                ),
              ],
              [],
            ),
          ]),
          dom.element("label", [a.class("field-wide seo-source-label")], [
            dom.element("div", [a.class("field-label-bar")], [
              dom.element("span", [], [text("SEO başlığı")]),
            ]),
            dom.element(
              "input",
              [
                a.name("seo_title"),
                a.id("region-input-seo-title"),
                a.attribute(
                  "placeholder",
                  "Örn: Kaş Tatil Rehberi, Kiralık Villa & Oteller | NEXUS",
                ),
              ],
              [],
            ),
          ]),
          dom.element("label", [a.class("field-wide seo-source-label")], [
            dom.element("div", [a.class("field-label-bar")], [
              dom.element("span", [], [text("SEO açıklaması")]),
            ]),
            dom.element(
              "textarea",
              [
                a.name("seo_description"),
                a.id("region-input-seo-desc"),
                a.attribute("rows", "3"),
                a.attribute(
                  "placeholder",
                  "Google arama sonuçlarında görünecek 150 karakterlik meta açıklama...",
                ),
              ],
              [],
            ),
          ]),
          dom.element("div", [a.class("form-actions-bar")], [
            dom.element("div", [a.class("actions-left-note")], [
              dom.element("span", [a.class("autosave-indicator-dot")], []),
              dom.element("span", [a.class("muted")], [
                text(
                  "Tüm alanlar Google SERP ve meta standartlarına göre optimize edilir",
                ),
              ]),
            ]),
            dom.element("div", [a.class("actions-right-buttons")], [
              dom.element(
                "button",
                [
                  a.type_("submit"),
                  a.class("secondary btn-translate"),
                  a.formaction("/admin/translate"),
                ],
                [
                  dom.element("span", [a.class("btn-icon")], [text("🌍")]),
                  text("Diğer Dillere AI ile Çevir"),
                ],
              ),
              dom.element(
                "button",
                [a.type_("submit"), a.class("primary btn-save-glow")],
                [
                  dom.element("span", [a.class("btn-icon")], [text("✓")]),
                  text("Bölgeyi Kaydet"),
                ],
              ),
            ]),
          ]),
        ],
      ),
      dom.element(
        "div",
        [
          a.class("table-wrap full-width-table"),
          a.id("regions-table-container"),
        ],
        [
          dom.element("div", [a.class("table-header-bar")], [
            dom.element("div", [a.class("table-title-area")], [
              dom.element("h3", [a.class("table-section-title")], [
                text("Kayıtlı Bölgeler ve Destinasyonlar"),
              ]),
              dom.element(
                "span",
                [a.class("count-badge"), a.id("regions-count-badge")],
                [text("Canlı Liste")],
              ),
            ]),
          ]),
          dom.element("table", [a.class("data-table")], [
            dom.element("thead", [], [
              dom.element("tr", [], [
                dom.element("th", [], [text("Bölge")]),
                dom.element("th", [], [text("Slug")]),
                dom.element("th", [], [text("Ülke")]),
                dom.element("th", [], [text("Durum")]),
                dom.element("th", [], [text("Oluşturulma")]),
              ]),
            ]),
            dom.element("tbody", [a.id("regions-table-body")], [
              dom.element("tr", [], [
                dom.element(
                  "td",
                  [a.attribute("colspan", "5"), a.class("empty-state")],
                  [text("Bölgeler yükleniyor…")],
                ),
              ]),
            ]),
          ]),
        ],
      ),
    ],
  )
}

fn setting_tab_btn(
  tab_id: String,
  icon: String,
  label: String,
  is_active: Bool,
) {
  dom.element(
    "button",
    [
      a.type_("button"),
      a.class(case is_active {
        True -> "settings-tab-btn active"
        False -> "settings-tab-btn"
      }),
      a.attribute("data-settings-tab", tab_id),
    ],
    [
      hugeicon(icon, "tab-icon"),
      dom.element("span", [a.class("tab-label")], [text(label)]),
    ],
  )
}

fn setting_textarea(
  label: String,
  name: String,
  placeholder: String,
  rows: String,
) {
  dom.element("label", [a.class("form-group-full")], [
    text(label),
    dom.element(
      "textarea",
      [
        a.name(name),
        a.attribute("placeholder", placeholder),
        a.attribute("rows", rows),
        a.class("glass-textarea"),
      ],
      [],
    ),
  ])
}

fn setting_select(
  label: String,
  name: String,
  options: List(#(String, String)),
) {
  dom.element("label", [], [
    text(label),
    dom.element(
      "select",
      [a.name(name), a.class("glass-select")],
      options
        |> list.map(fn(opt) {
          dom.element("option", [a.attribute("value", opt.0)], [text(opt.1)])
        }),
    ),
  ])
}

fn settings_form() {
  dom.element(
    "section",
    [a.class("settings-glass-workspace"), a.id("settings-workspace")],
    [
      dom.element("div", [a.class("settings-header-banner")], [
        dom.element("div", [], [
          dom.element("span", [a.class("badge-glass-cyan")], [
            text("✦ KONTROL MERKEZİ"),
          ]),
          dom.element("h2", [], [text("Acente & Platform Ayarları")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Kurumsal marka, ödeme geçitleri, yapay zeka motoru, SMS/WhatsApp ve hukuki sözleşmelerinizi tek yerden yönetin.",
            ),
          ]),
        ]),
        dom.element("div", [a.class("header-actions")], [
          dom.element(
            "button",
            [
              a.type_("button"),
              a.class("btn-glass-save"),
              a.id("btn-save-settings-top"),
            ],
            [text("💾 Değişiklikleri Kaydet")],
          ),
        ]),
      ]),

      // Tab Navigation Bar
      dom.element("div", [a.class("settings-nav-tabs")], [
        setting_tab_btn("brand", "building-03", "Kurumsal & Marka", True),
        setting_tab_btn("pos", "credit-card", "Ödeme & Sanal POS", False),
        setting_tab_btn(
          "ai",
          "ai-beautify",
          "AI Motoru (Gemini / DeepSeek)",
          False,
        ),
        setting_tab_btn("sms", "smart-phone-01", "SMS ve bildirimler", False),
        setting_tab_btn("currency", "money-exchange-01", "Kurlar & TCMB", False),
        setting_tab_btn("analytics", "analytics-01", "Analitik & Harita", False),
        setting_tab_btn(
          "legal",
          "legal-document-01",
          "Sözleşmeler & KVKK",
          False,
        ),
        setting_tab_btn("appearance", "paint-brush-01", "Görünüm & Tema", False),
      ]),

      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/settings"),
          a.id("settings-main-form"),
          a.class("settings-tab-panels"),
        ],
        [
          // 1. KURUMSAL & MARKA
          dom.element(
            "div",
            [a.class("settings-tab-panel active"), a.id("tab-brand")],
            [
              dom.element("div", [a.class("panel-section-title")], [
                dom.element("h3", [], [
                  text("🏢 Kurumsal Kimlik, Logo ve İletişim"),
                ]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Vitrin ve belgelerde görünecek acente unvanı, TURSAB ruhsatı ve iletişim kanalları.",
                  ),
                ]),
              ]),
              dom.element("div", [a.class("form-grid-2")], [
                setting_input(
                  "Acente / Marka Adı",
                  "brand_name",
                  "NEXUS Seyahat Acentesi",
                ),
                setting_input(
                  "İletişim E-postası",
                  "contact_email",
                  "destek@acente.com",
                ),
                setting_input(
                  "Müşteri Hizmetleri Telefonu",
                  "contact_phone",
                  "+90 (242) 555 01 23",
                ),
                setting_input(
                  "WhatsApp Destek Hattı",
                  "whatsapp",
                  "+90 532 000 00 00",
                ),
                setting_input(
                  "TÜRSAB Belge Numarası",
                  "tursab_no",
                  "12345 (A Grubu)",
                ),
                setting_input(
                  "TÜRSAB Doğrulama Linki",
                  "tursab_verify_url",
                  "https://tursab.org.tr/dogrulama/...",
                ),
                setting_input(
                  "Açık Tema Logo URL",
                  "logo_url",
                  "https://.../logo-light.svg",
                ),
                setting_input(
                  "Koyu Tema Logo URL",
                  "logo_dark_url",
                  "https://.../logo-dark.svg",
                ),
                setting_input(
                  "Favicon URL",
                  "favicon_url",
                  "https://.../favicon.ico",
                ),
                setting_select("Varsayılan Dil", "default_language", [
                  #("tr", "Türkçe (Varsayılan)"),
                  #("en", "English"),
                  #("de", "Deutsch"),
                  #("ru", "Русский"),
                  #("zh", "简体中文"),
                  #("fr", "Français"),
                ]),
                setting_select("Varsayılan Para Birimi", "default_currency", [
                  #("TRY", "TRY — Türk Lirası (₺)"),
                  #("EUR", "EUR — Euro (€)"),
                  #("USD", "USD — Amerikan Doları ($)"),
                  #("GBP", "GBP — İngiliz Sterlini (£)"),
                  #("CNY", "CNY — Çin Yuanı (¥)"),
                ]),
                setting_input(
                  "Vergi Dairesi & No",
                  "tax_office",
                  "Muratpaşa V.D. / 1234567890",
                ),
              ]),
              setting_textarea(
                "Acente Resmi Adresi",
                "address",
                "Şirinyalı Mah. İsmet Gökşen Cad. No:45/A Muratpaşa / Antalya",
                "2",
              ),
              dom.element("div", [a.class("panel-section-title")], [
                dom.element("h3", [], [text("🎧 Müşteri Destek Kanalları")]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Yukarıdaki müşteri hizmetleri telefonu ve WhatsApp hattı mobil destek menüsünde kullanılır. Canlı sohbet için tawk.to widget kodunu aşağıya yapıştırın.",
                  ),
                ]),
              ]),
              setting_textarea(
                "tawk.to canlı destek kodu",
                "tawk_embed_code",
                "https://embed.tawk.to/PROPERTY_ID/WIDGET_ID veya tawk.to tarafından verilen kod",
                "4",
              ),
            ],
          ),

          // 2. ÖDEME & SANAL POS
          dom.element("div", [a.class("settings-tab-panel"), a.id("tab-pos")], [
            dom.element("div", [a.class("panel-section-title")], [
              dom.element("h3", [], [
                text("💳 Sanal POS, Havale / EFT ve Kapıda Ödeme"),
              ]),
              dom.element("p", [a.class("muted")], [
                text(
                  "Kartlı ödeme, banka havalesi ve kapıda ödeme seçeneklerini yapılandırın.",
                ),
              ]),
            ]),
            dom.element("div", [a.class("form-grid-2")], [
              setting_select(
                "Aktif ödeme sağlayıcısı",
                "active_payment_gateway",
                [
                  #("parampos", "ParamPOS"),
                  #("bank_transfer", "Yalnızca banka havalesi / EFT"),
                  #("all", "Tüm aktif yöntemler"),
                ],
              ),
              setting_input(
                "ParamPOS terminal kodu",
                "parampos_client_code",
                "CLIENT_CODE",
              ),
              setting_input(
                "ParamPOS kullanıcı adı",
                "parampos_username",
                "Kullanıcı adı",
              ),
              setting_input(
                "ParamPOS parolası",
                "parampos_password",
                "••••••••",
              ),
              setting_input(
                "ParamPOS güvenlik anahtarı",
                "parampos_guid",
                "GUID_TOKEN",
              ),
            ]),
            dom.element("h4", [a.class("sub-panel-title")], [
              text("Banka Havalesi / EFT Hesapları (Çoklu Para Birimi)"),
            ]),
            dom.element("div", [a.class("form-grid-2")], [
              setting_input(
                "TRY IBAN (Türk Lirası)",
                "bank_iban_try",
                "TR00 0000 0000 0000 0000 0000 00",
              ),
              setting_input(
                "EUR IBAN (Euro)",
                "bank_iban_eur",
                "TR00 0000 0000 0000 0000 0000 00",
              ),
              setting_input(
                "USD IBAN (Dolar)",
                "bank_iban_usd",
                "TR00 0000 0000 0000 0000 0000 00",
              ),
              setting_input(
                "GBP IBAN (Sterlin)",
                "bank_iban_gbp",
                "TR00 0000 0000 0000 0000 0000 00",
              ),
              setting_input(
                "CNY IBAN (Çin Yuanı)",
                "bank_iban_cny",
                "TR00 0000 0000 0000 0000 0000 00",
              ),
            ]),
            setting_textarea(
              "Havale Açıklama & Talimatları",
              "bank_instructions",
              "Lütfen havale/EFT yaparken açıklama kısmına Rezervasyon Kodunuzu yazınız. Dekontu WhatsApp hattımıza iletebilirsiniz.",
              "2",
            ),
          ]),

          // 3. AI MOTORU
          dom.element("div", [a.class("settings-tab-panel"), a.id("tab-ai")], [
            dom.element("div", [a.class("panel-section-title")], [
              dom.element("h3", [], [
                text("🤖 Yapay Zeka Motoru (Gemini 2.5 Flash & DeepSeek)"),
              ]),
              dom.element("p", [a.class("muted")], [
                text(
                  "İlan açıklaması üretimi, SEO optimizasyonu ve 6 dilde çevirileri gerçekleştiren LLM yapılandırması.",
                ),
              ]),
            ]),
            dom.element("div", [a.class("form-grid-2")], [
              setting_select("Varsayılan AI Sağlayıcısı", "ai_provider", [
                #(
                  "google",
                  "Google Gemini 2.5 Flash (Önerilen — Ücretsiz, Ultra Hızlı)",
                ),
                #("deepseek", "DeepSeek Chat (V3 / R1)"),
                #("glm", "GLM"),
                #("openai", "OpenAI (GPT-4o / GPT-4o-mini)"),
              ]),
              setting_input("AI Model Kodu", "ai_model", "gemini-2.5-flash"),
              setting_input(
                "AI API Anahtarı",
                "ai_api_key",
                "Google AI Studio veya DeepSeek API anahtarınız (sk-...)",
              ),
              setting_select(
                "Otomatik SEO Optimizasyonu",
                "ai_auto_seo_enabled",
                [
                  #(
                    "true",
                    "Açık — İlan oluşturulurken otomatik SEO başlığı ve açıklaması üret",
                  ),
                  #("false", "Kapalı — Yalnızca butona basıldığında üret"),
                ],
              ),
            ]),
            dom.element("div", [a.class("ai-test-box")], [
              dom.element("div", [], [
                dom.element("strong", [], [text("AI Bağlantı Durumu: ")]),
                dom.element(
                  "span",
                  [a.id("ai-status-indicator"), a.class("status-pill-neutral")],
                  [text("Test Edilmedi")],
                ),
              ]),
              dom.element(
                "button",
                [
                  a.type_("button"),
                  a.class("btn-test-ai"),
                  a.id("btn-test-ai-connection"),
                ],
                [text("⚡ AI Bağlantısını Test Et")],
              ),
            ]),
            ai_key_pool_card(),
          ]),

          // 4. SMS & MESAJLAŞMA
          dom.element("div", [a.class("settings-tab-panel"), a.id("tab-sms")], [
            dom.element("div", [a.class("glass-subcard")], [
              dom.element("h3", [], [text("Üye kimlik doğrulaması")]),
              dom.element("a", [a.href("/admin/security")], [
                text("Yönetici iki aşamalı giriş ayarları"),
              ]),
              dom.element("a", [a.href("/admin/membership-setup")], [
                text(
                  "Üyelik kurulum kontrolü, bağlantı testleri ve bildirim merkezi",
                ),
              ]),
              setting_input(
                "WhatsApp doğrulama şablonu (Authentication)",
                "whatsapp_auth_template",
                "Onaylı şablon adı",
              ),
              setting_input(
                "WhatsApp doğrulama dili",
                "whatsapp_auth_language",
                "tr",
              ),
              setting_input(
                "WhatsApp Graph API sürümü",
                "whatsapp_api_version",
                "Meta hesabınızda desteklenen sürüm",
              ),
              dom.element("p", [a.class("muted")], [
                text(
                  "Telefon No ID ve erişim belirtecini Entegrasyonlar > WhatsApp bağlantısında yönetin. Doğrulama için onaylı Authentication şablonu gerekir. Gönderim bağlantısı tamamlanana kadar telefon doğrulaması etkin değildir.",
                ),
              ]),
              setting_textarea(
                "Üyelik sözleşmesi",
                "contract_membership",
                "Üyelik koşullarınızı burada yayınlayın.",
                "6",
              ),
              dom.element("a", [a.href("/admin/customer-verification")], [
                text("Bekleyen üye kimlik başvurularını incele"),
              ]),
              dom.element("p", [a.class("muted")], [
                text(
                  "Varsayılan yöntem yönetici incelemesidir. Manuel onay, NVİ doğrulaması olarak gösterilmez. E-posta ve telefon doğrulaması ayrı takip edilir.",
                ),
              ]),
              setting_select(
                "Kimlik doğrulama yöntemi",
                "customer_identity_mode",
                [
                  #("manual", "Manuel — yönetici incelemesi"),
                ],
              ),
              dom.element(
                "button",
                [
                  a.type_("button"),
                  a.attribute("disabled", "disabled"),
                  a.attribute(
                    "title",
                    "Yetkili KPS erişimi ve servis bağlantısı tamamlandığında etkinleştirilecek",
                  ),
                ],
                [text("KPS doğrulamasını aç — bağlantı bekleniyor")],
              ),
              dom.element("p", [a.class("muted")], [
                text(
                  "KPS başvurusunun reddedilmesi üyelik işlemlerini durdurmaz. Otomatik doğrulama, servis erişimi yapılandırılıp test edilmeden açılmaz.",
                ),
              ]),
              dom.element(
                "a",
                [
                  a.href("https://kpsbasvuru.nvi.gov.tr/Acik/Anasayfa"),
                  a.attribute("target", "_blank"),
                  a.attribute("rel", "noopener noreferrer"),
                ],
                [text("Resmi KPS başvuru portalını aç")],
              ),
            ]),
            dom.element("div", [a.class("panel-section-title")], [
              dom.element("h3", [], [
                text("📱 SMS ve otomasyon bildirimleri"),
              ]),
              dom.element("p", [a.class("muted")], [
                text(
                  "Rezervasyon teyidi, kalan ödeme hatırlatması ve SMS şablonları.",
                ),
              ]),
            ]),
            dom.element("div", [a.class("form-grid-2")], [
              setting_input(
                "SMS servis kullanıcı adı",
                "netgsm_usercode",
                "Örn: 8503000000",
              ),
              setting_input(
                "SMS servis API parolası",
                "netgsm_password",
                "••••••••",
              ),
              setting_input(
                "Gönderici Başlığı (Header)",
                "netgsm_header",
                "ACENTENIZ",
              ),
              setting_select("SMS Bildirimleri Durumu", "sms_enabled", [
                #("true", "Aktif — Rezervasyon onayında müşteriye SMS gönder"),
                #("false", "Pasif — SMS gönderimi kapalı"),
              ]),
            ]),
            setting_textarea(
              "Rezervasyon Onay SMS Şablonu",
              "sms_template_booking",
              "Sayın [MUSTERI], [ILAN] için [REZERVASYON_NO] kodlu rezervasyonunuz onaylanmıştır. İyi tatiller dileriz.",
              "2",
            ),
            setting_textarea(
              "Bakiye / Giriş Hatırlatma SMS Şablonu",
              "sms_template_reminder",
              "Sayın [MUSTERI], [REZERVASYON_NO] kodlu konaklamanız [TARIH] tarihinde başlamaktadır. Kalan bakiye: [TUTAR].",
              "2",
            ),
          ]),

          // 5. KURLAR & TCMB
          dom.element(
            "div",
            [a.class("settings-tab-panel"), a.id("tab-currency")],
            [
              dom.element("div", [a.class("panel-section-title")], [
                dom.element("h3", [], [
                  text("💱 Çoklu Para Birimi & TCMB Döviz Kurları"),
                ]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Türkiye Cumhuriyet Merkez Bankası (TCMB) kurlarını canlı çekme ve kur sabitleme kuralları.",
                  ),
                ]),
              ]),
              dom.element("div", [a.class("form-grid-2")], [
                setting_select("TCMB Otomatik Güncelleme", "tcmb_auto_sync", [
                  #(
                    "true",
                    "Açık — Kurları günde 2 kez (10:00 ve 15:30) otomatik senkronize et",
                  ),
                  #("false", "Kapalı — Yalnızca elle güncelle"),
                ]),
                setting_input(
                  "Kur Marjı / Makas Yüzdesi (%)",
                  "currency_spread_percent",
                  "1.5 (TCMB kuruna %1.5 güvenlik marjı ekler)",
                ),
              ]),
              dom.element("div", [a.class("currency-quick-refresh-card")], [
                dom.element("div", [], [
                  dom.element("strong", [], [text("Anlık Kur Yenileme")]),
                  dom.element("p", [a.class("muted")], [
                    text(
                      "TCMB sunucularından güncel USD, EUR ve GBP alış/satış kurlarını anında veritabanına aktarır.",
                    ),
                  ]),
                ]),
                dom.element(
                  "button",
                  [
                    a.type_("button"),
                    a.class("btn-refresh-tcmb"),
                    a.id("btn-refresh-tcmb-now"),
                  ],
                  [text("🔄 TCMB Kurlarını Şimdi Yenile")],
                ),
              ]),
            ],
          ),

          // 6. ANALİTİK & HARİTA
          dom.element(
            "div",
            [a.class("settings-tab-panel"), a.id("tab-analytics")],
            [
              dom.element("div", [a.class("panel-section-title")], [
                dom.element("h3", [], [
                  text("📊 Ziyaretçi Analitiği, Piksel Kodları ve Harita"),
                ]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Dönüşüm takip pikselleri ve interaktif harita sağlayıcı parametreleri.",
                  ),
                ]),
              ]),
              dom.element("div", [a.class("form-grid-2")], [
                setting_input(
                  "Google Analytics 4 (GA4)",
                  "ga4_measurement_id",
                  "G-XXXXXXXXXX",
                ),
                setting_input(
                  "Google Tag Manager (GTM)",
                  "gtm_id",
                  "GTM-XXXXXXX",
                ),
                setting_input(
                  "Meta (Facebook) Pixel ID",
                  "meta_pixel_id",
                  "Örn: 123456789012345",
                ),
                setting_input(
                  "TikTok Pixel ID",
                  "tiktok_pixel_id",
                  "Örn: C123456789",
                ),
                setting_input(
                  "Google Maps API Key",
                  "google_maps_api_key",
                  "AIzaSy...",
                ),
                setting_input(
                  "Harita Varsayılan Enlem (Lat)",
                  "map_default_lat",
                  "36.8841",
                ),
                setting_input(
                  "Harita Varsayılan Boylam (Lng)",
                  "map_default_lng",
                  "30.7056",
                ),
                setting_input(
                  "Harita Varsayılan Zoom",
                  "map_default_zoom",
                  "13",
                ),
              ]),
            ],
          ),

          // 7. SÖZLEŞMELER & HUKUK
          dom.element(
            "div",
            [a.class("settings-tab-panel"), a.id("tab-legal")],
            [
              dom.element(
                "span",
                [a.id("contracts"), a.class("anchor-target")],
                [],
              ),
              dom.element("div", [a.class("panel-section-title")], [
                dom.element("h3", [], [
                  text("⚖️ Hukuki Metinler, Sözleşmeler ve KVKK"),
                ]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Rezervasyon sırasında müşteriye onaylatılan yasal sözleşmeler ve aydınlatma metinleri.",
                  ),
                ]),
              ]),
              dom.element(
                "div",
                [a.class("contract-builder"), a.id("contract-builder")],
                [
                  dom.element("div", [a.class("panel-section-title")], [
                    dom.element("h4", [], [
                      text("Kategori ve Dil Bazlı Sözleşme Şablonları"),
                    ]),
                    dom.element("p", [a.class("muted")], [
                      text(
                        "Her kategori ve aktif vitrin dili için ayrı metin hazırlayın. Genel sözleşmeler tüm ürünlerde kullanılabilir.",
                      ),
                    ]),
                  ]),
                  dom.element("div", [a.class("form-grid-3")], [
                    setting_select("Kapsam", "contract_scope_selector", [
                      #("general", "Genel sözleşme"),
                      #("hotel", "Otel"),
                      #("holiday_home", "Tatil Evi"),
                      #("yacht", "Yat"),
                      #("tour", "Tur"),
                      #("activity", "Aktivite"),
                      #("flight", "Uçuş"),
                      #("bus", "Otobüs"),
                      #("transfer", "Transfer"),
                      #("car", "Araç"),
                      #("ferry", "Feribot"),
                      #("cruise", "Kruvaziyer"),
                      #("event", "Etkinlik"),
                      #("restaurant", "Restoran"),
                      #("cinema", "Sinema"),
                      #("visa", "Vize"),
                      #("pilgrimage", "Hac & Umre"),
                      #("beach", "Plaj / Şezlong"),
                    ]),
                    setting_select("Dil", "contract_language_selector", [
                      #("tr", "Türkçe"),
                      #("en", "English"),
                      #("de", "Deutsch"),
                      #("ru", "Русский"),
                      #("zh", "中文"),
                      #("fr", "Français"),
                    ]),
                    dom.element(
                      "button",
                      [
                        a.type_("button"),
                        a.class("btn-secondary-glow"),
                        a.id("contract-template-add"),
                      ],
                      [text("+ Şablon alanı ekle")],
                    ),
                  ]),
                  dom.element(
                    "textarea",
                    [
                      a.name("contract_templates_json"),
                      a.id("contract-templates-json"),
                      a.class("sr-only"),
                      a.attribute("aria-hidden", "true"),
                    ],
                    [],
                  ),
                  dom.element(
                    "div",
                    [
                      a.id("contract-template-list"),
                      a.class("contract-template-list"),
                    ],
                    [],
                  ),
                  dom.element(
                    "textarea",
                    [
                      a.name("contract_general_json"),
                      a.id("contract-general-json"),
                      a.class("sr-only"),
                      a.attribute("aria-hidden", "true"),
                    ],
                    [],
                  ),
                ],
              ),
              setting_textarea(
                "Mesafeli Satış Sözleşmesi (HTML / Metin)",
                "contract_distance_selling",
                "İşbu sözleşme 6502 sayılı Tüketicinin Korunması Hakkında Kanun gereğince düzenlenmiştir...",
                "4",
              ),
              setting_textarea(
                "İptal, İade ve Değişiklik Koşulları",
                "contract_cancellation_refund",
                "Giriş tarihine 30 gün kalaya kadar yapılan iptallerde ön ödeme tutarı kesintisiz iade edilir...",
                "4",
              ),
              setting_textarea(
                "KVKK Aydınlatma Metni",
                "contract_privacy_policy",
                "6698 sayılı Kişisel Verilerin Korunması Kanunu uyarınca verileriniz acentemiz güvencesindedir...",
                "4",
              ),
              setting_textarea(
                "Çerez Politikası",
                "contract_cookie_policy",
                "Web sitemizde kullanıcı deneyimini iyileştirmek amacıyla çerezler kullanılmaktadır...",
                "3",
              ),
            ],
          ),

          // 8. GÖRÜNÜM & TEMA — palet kartları settings-main-form'un dışında
          // (button type=button, submit tetiklemez). Seçim theme-toggle.js
          // üzerinden POST /admin/preferences/theme ile hesaba yazılır.
          dom.element(
            "div",
            [a.class("settings-tab-panel"), a.id("tab-appearance")],
            [
              dom.element("div", [a.class("panel-section-title")], [
                dom.element("h3", [], [text("🎨 Arayüz Paleti")]),
                dom.element("p", [a.class("muted")], [
                  text(
                    "Panel ekranlarının paletini seçin. Tercih hesabınıza kaydedilir ve topbar'daki hızlı seçiciyle aynı alanı günceller; bir sonraki girişte otomatik uygulanır.",
                  ),
                ]),
              ]),
              theme_appearance_section(),
              // Dil tercihi — hesaba kaydedilir; mağaza sayfaları
              // nexus_lang çerezi üzerinden bu dilde açılır.
              dom.element(
                "div",
                [
                  a.class("panel-section-title"),
                  a.attribute("style", "margin-top: var(--space-6)"),
                ],
                [
                  dom.element("h3", [], [text("🌐 Arayüz Dili")]),
                  dom.element("p", [a.class("muted")], [
                    text(
                      "Mağaza arayüzünün dilini seçin. Tercih hesabınıza kaydedilir; tüm halka açık sayfalar bir sonraki açılışta bu dilde başlar.",
                    ),
                  ]),
                ],
              ),
              language_appearance_section(),
              // Yenileme aralığı seçici
              dom.element(
                "div",
                [
                  a.class("panel-section-title"),
                  a.attribute("style", "margin-top: var(--space-6)"),
                ],
                [
                  dom.element("h3", [], [text("⏱ Yenileme Aralığı")]),
                  dom.element("p", [a.class("muted")], [
                    text(
                      "Dashboard ve katalog sayfalarındaki canlı veri yenileme sıklığını ayarlayın.",
                    ),
                  ]),
                ],
              ),
              dom.element(
                "div",
                [
                  a.class("refresh-interval-picker"),
                  a.id("refresh-interval-picker"),
                  a.attribute("role", "radiogroup"),
                  a.attribute("aria-label", "Yenileme aralığı"),
                ],
                [
                  refresh_interval_option(
                    "15",
                    "15 sn",
                    "Hızlı — sık güncelleme",
                  ),
                  refresh_interval_option("30", "30 sn", "Varsayılan — dengeli"),
                  refresh_interval_option(
                    "60",
                    "60 sn",
                    "Yavaş — düşük trafiğe duyarlı",
                  ),
                ],
              ),
            ],
          ),

          // BOTTOM SAVE BAR
          dom.element("div", [a.class("settings-bottom-bar")], [
            dom.element(
              "button",
              [a.type_("submit"), a.class("btn-primary-glow")],
              [
                text("✓ Tüm Ayarları Kaydet"),
              ],
            ),
            dom.element(
              "span",
              [a.id("settings-save-feedback"), a.class("save-feedback-text")],
              [],
            ),
          ]),
        ],
      ),
    ],
  )
}

/// Ayarlar > Görünüm & Tema: 4 palet + auto kartı. Her kart .theme-swatch
/// Yenileme aralığı seçeneği (radio butonu + açıklama)
fn refresh_interval_option(value: String, label: String, desc: String) {
  dom.element("label", [a.class("refresh-interval-option")], [
    dom.element(
      "input",
      [
        a.type_("radio"),
        a.name("refresh_interval"),
        a.attribute("value", value),
        a.attribute("data-refresh-interval", value),
      ],
      [],
    ),
    dom.element("span", [a.class("refresh-interval-label")], [text(label)]),
    dom.element("span", [a.class("refresh-interval-desc")], [text(desc)]),
  ])
}

/// Ayarlar > Görünüm & Tema altında dil seçici. theme-toggle.js tıklama
/// delegasyonu .language-choice elemanlarını yakalar ve seçimi
/// POST /admin/preferences/language ile hesaba yazar.
fn language_appearance_section() {
  let langs = [
    #("tr", "🇹🇷 Türkçe", "Varsayılan — mağaza Türkçe"),
    #("en", "🇬🇧 English", "Store UI in English"),
    #("de", "🇩🇪 Deutsch", "Shop-Oberfläche auf Deutsch"),
    #("ru", "🇷🇺 Русский", "Интерфейс магазина на русском"),
  ]
  dom.element(
    "div",
    [
      a.class("language-picker"),
      a.attribute("role", "radiogroup"),
      a.attribute("aria-label", "Arayüz dili"),
    ],
    langs
      |> list.map(fn(lang) {
        let #(code, name, desc) = lang
        dom.element(
          "button",
          [
            a.attribute("type", "button"),
            a.class("language-choice theme-swatch theme-card"),
            a.attribute("data-language-choice", code),
            a.attribute("aria-label", name <> " — " <> desc),
            a.attribute("title", name <> " — " <> desc),
          ],
          [
            dom.element("span", [a.class("theme-card-icon")], [text(name)]),
            dom.element("span", [a.class("theme-card-desc")], [text(desc)]),
          ],
        )
      }),
  )
}

/// sınıfını taşır — theme-toggle.js'in paintUI aktif işaretlemesi ve swatch
/// tıklama delegasyonu tüm .theme-swatch elemanlarında çalıştığından buradaki
/// kartlar ekstra bağlamaya ihtiyaç duymaz. POST /admin/preferences/theme
/// aynı theme_preference alanına yazar.
fn theme_appearance_section() {
  let cards = [
    #(
      "dark",
      "Karanlık",
      "Derin karanlık tema",
      "--swatch-bg:#060a13;--swatch-accent:#22d3ee",
    ),
    #(
      "light",
      "Aydınlık",
      "Beyaz tonlu aydınlık tema",
      "--swatch-bg:#eef2f8;--swatch-accent:#0891b2",
    ),
  ]
  dom.element(
    "div",
    [
      a.class("theme-settings-grid"),
      // theme-toggle.js tıklama delegasyonu .theme-swatches veya
      // [data-theme-picker] kabına bağlanır — kart ızgarası ikincisiyle bağlanır.
      a.attribute("data-theme-picker", "true"),
    ],
    [
      dom.element(
        "button",
        [
          a.attribute("type", "button"),
          a.class("theme-swatch theme-card theme-card-auto"),
          a.attribute("data-theme-choice", "auto"),
          a.attribute(
            "aria-label",
            "Otomatik — saate göre tema (07-19 aydınlık, diğer saatler koyu)",
          ),
          a.attribute("title", "Otomatik: 07–19 aydınlık · diğer saatler koyu"),
          a.attribute("style", "--swatch-bg:#0f172a;--swatch-accent:#94a3b8"),
        ],
        [
          dom.element("span", [a.class("theme-card-icon")], [text("🕒")]),
          dom.element("span", [a.class("theme-card-name")], [text("Otomatik")]),
          dom.element("span", [a.class("theme-card-desc")], [
            text("Saate göre palet seçer"),
          ]),
        ],
      ),
      ..cards
      |> list.map(fn(card) {
        let #(choice, name, desc, style) = card
        dom.element(
          "button",
          [
            a.attribute("type", "button"),
            a.class("theme-swatch theme-card"),
            a.attribute("data-theme-choice", choice),
            a.attribute("aria-label", name <> " — " <> desc),
            a.attribute("title", name <> " — " <> desc),
            a.attribute("style", style),
          ],
          [
            dom.element("span", [a.class("theme-card-swatch")], []),
            dom.element("span", [a.class("theme-card-name")], [text(name)]),
            dom.element("span", [a.class("theme-card-desc")], [text(desc)]),
          ],
        )
      })
    ],
  )
}

fn currency_form() {
  dom.element("section", [a.class("quick"), a.id("currency-settings")], [
    dom.element("h2", [], [text("Para birimi yönetimi")]),
    dom.element("p", [a.class("muted")], [
      text(
        "Kur oranlarını ve merkez bankası güncellemesine uygulanacak yüzde düzeltmeyi yönetin.",
      ),
    ]),
    dom.element("div", [a.class("metric")], [
      dom.element("strong", [], [text("Otomatik kur güncelleme")]),
      dom.element("small", [], [
        text("Her gün iki kez çalışır veya aşağıdaki butonla hemen yenilenir."),
      ]),
      dom.element(
        "form",
        [
          a.method("post"),
          a.action("/admin/currencies/refresh"),
          a.id("currency-refresh-form"),
        ],
        [
          dom.element(
            "button",
            [
              a.type_("submit"),
              a.class("secondary"),
              a.id("currency-refresh-button"),
            ],
            [text("Tüm kurları şimdi güncelle")],
          ),
          dom.element("small", [a.id("currency-refresh-status")], [
            text(""),
          ]),
        ],
      ),
    ]),
    dom.element("form", [a.method("post"), a.action("/admin/currencies")], [
      setting_input("Para birimi kodu", "code", "TRY"),
      setting_input("Para birimi adı", "name", "Türk Lirası"),
      setting_input("Sembol", "symbol", "₺"),
      setting_input("Kur oranı", "rate", "1.00000000"),
      setting_input("Düzeltme (%)", "adjustment_percent", "0.00"),
      setting_input("1. güncelleme saati", "first_run_at", "09:00"),
      setting_input("2. güncelleme saati", "second_run_at", "16:00"),
      setting_input("Kur sağlayıcısı", "rate_provider", "tcmb"),
      dom.element("label", [], [
        text("Durum"),
        dom.element("select", [a.name("active")], [
          dom.element("option", [a.attribute("value", "true")], [text("Aktif")]),
          dom.element("option", [a.attribute("value", "false")], [text("Pasif")]),
        ]),
      ]),
      dom.element("button", [a.type_("submit"), a.class("primary")], [
        text("Para birimini kaydet"),
      ]),
    ]),
    dom.element("div", [a.class("metric-grid")], [
      metric(
        "Aktif para birimleri",
        "7",
        "TRY · EUR · USD · GBP · CNY · RUB · AED",
      ),
      dom.element("article", [a.class("metric")], [
        dom.element("span", [], [text("SON KUR GÜNCELLEMESİ")]),
        dom.element("strong", [a.id("currency-last-updated")], [
          text("Yükleniyor…"),
        ]),
        dom.element("small", [], [text("TCMB döviz satış kurları")]),
      ]),
    ]),
    dom.element("div", [a.class("metric-grid")], [
      currency_card("TRY", "Türk Lirası", "₺", "1.00000000"),
      currency_card("EUR", "Euro", "€", "0.00000000"),
      currency_card("USD", "US Dollar", "$", "0.00000000"),
      currency_card("GBP", "Pound Sterling", "£", "0.00000000"),
      currency_card("CNY", "Chinese Yuan", "¥", "0.00000000"),
      currency_card("RUB", "Russian Ruble", "₽", "0.00000000"),
      currency_card("AED", "UAE Dirham", "د.إ", "0.00000000"),
    ]),
  ])
}

fn currency_card(code: String, name: String, symbol: String, rate: String) {
  dom.element(
    "article",
    [a.class("metric"), a.attribute("data-currency-code", code)],
    [
      dom.element("span", [], [text(code <> " · " <> symbol)]),
      dom.element("strong", [], [text(name)]),
      dom.element("form", [a.method("post"), a.action("/admin/currencies")], [
        dom.element(
          "input",
          [a.type_("hidden"), a.name("code"), a.attribute("value", code)],
          [],
        ),
        dom.element(
          "input",
          [a.type_("hidden"), a.name("name"), a.attribute("value", name)],
          [],
        ),
        dom.element(
          "input",
          [a.type_("hidden"), a.name("symbol"), a.attribute("value", symbol)],
          [],
        ),
        dom.element("label", [], [
          text("Kur"),
          dom.element(
            "input",
            [
              a.name("rate"),
              a.attribute("value", rate),
              a.attribute("data-currency-rate", code),
            ],
            [],
          ),
        ]),
        dom.element("label", [], [
          text("Düzeltme (%)"),
          dom.element(
            "input",
            [a.name("adjustment_percent"), a.attribute("value", "0.00")],
            [],
          ),
        ]),
        dom.element(
          "input",
          [a.type_("hidden"), a.name("active"), a.attribute("value", "true")],
          [],
        ),
        dom.element(
          "input",
          [
            a.type_("hidden"),
            a.name("first_run_at"),
            a.attribute("value", "09:00"),
          ],
          [],
        ),
        dom.element(
          "input",
          [
            a.type_("hidden"),
            a.name("second_run_at"),
            a.attribute("value", "16:00"),
          ],
          [],
        ),
        dom.element(
          "input",
          [
            a.type_("hidden"),
            a.name("rate_provider"),
            a.attribute("value", "tcmb"),
          ],
          [],
        ),
        dom.element("button", [a.type_("submit"), a.class("primary")], [
          text("Güncelle"),
        ]),
        case code {
          "TRY" ->
            dom.element("small", [], [text("Temel para birimi silinemez")])
          _ ->
            dom.element(
              "button",
              [
                a.type_("submit"),
                a.class("secondary"),
                a.formaction("/admin/currencies/delete"),
              ],
              [text("Sil")],
            )
        },
      ]),
    ],
  )
}

fn setting_input(label: String, name: String, placeholder: String) {
  dom.element("label", [], [
    text(label),
    dom.element(
      "input",
      [
        a.name(name),
        a.attribute("placeholder", placeholder),
        a.autocomplete("off"),
      ],
      [],
    ),
  ])
}

// AI anahtar havuzu ayarları, ana ayar formunun içinde görsel olarak yer alır
// ancak ayrı JS isteğiyle /admin/ai/key-pool adresine kaydedilir. Böylece
// anahtarlar genel ayar JSON'una hiç yazılmaz ve maskeli durum bilgisiyle
// yönetilebilir.
fn ai_pool_input(
  label: String,
  name: String,
  placeholder: String,
  input_type: String,
) {
  dom.element("label", [a.class("ai-pool-field")], [
    text(label),
    dom.element(
      "input",
      [
        a.name(name),
        a.type_(input_type),
        a.attribute("placeholder", placeholder),
        a.attribute("autocomplete", "new-password"),
      ],
      [],
    ),
  ])
}

fn ai_pool_fixed_input(label: String, name: String, value: String) {
  dom.element("label", [a.class("ai-pool-field")], [
    text(label),
    dom.element(
      "input",
      [
        a.name(name),
        a.type_("text"),
        a.attribute("value", value),
        a.attribute("readonly", "readonly"),
      ],
      [],
    ),
  ])
}

fn ai_pool_row(index: String) {
  let prefix = "gemini_" <> index
  dom.element(
    "article",
    [a.class("ai-key-row"), a.attribute("data-ai-key-row", index)],
    [
      dom.element("div", [a.class("ai-key-row-title")], [
        dom.element("strong", [], [text("Gemini hesap " <> index)]),
        dom.element(
          "span",
          [a.class("ai-key-row-status"), a.attribute("data-ai-status", index)],
          [text("Yapılandırılmadı")],
        ),
      ]),
      dom.element("div", [a.class("ai-key-row-fields")], [
        ai_pool_fixed_input("Etiket", prefix <> "_label", "Gemini " <> index),
        ai_pool_input("API anahtarı", prefix <> "_key", "AIza…", "password"),
        ai_pool_input("Model", prefix <> "_model", "gemini-2.5-flash", "text"),
        ai_pool_input(
          "Günlük kota (0=sınırsız)",
          prefix <> "_limit",
          "0",
          "number",
        ),
        setting_select("Durum", prefix <> "_active", [
          #("true", "Aktif"),
          #("false", "Pasif"),
        ]),
      ]),
    ],
  )
}

fn ai_key_pool_card() {
  let gemini_indexes = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
  dom.element("section", [a.class("ai-key-pool-card"), a.id("ai-key-pool")], [
    dom.element("div", [a.class("panel-section-title")], [
      dom.element("h3", [], [text("🔑 Gemini anahtar havuzu ve DeepSeek yedeği")]),
      dom.element("p", [a.class("muted")], [
        text(
          "En fazla 10 Gemini hesabını sıraya alın. Günlük kota dolduğunda sistem otomatik olarak sonraki hesaba, Gemini havuzu tükendiğinde DeepSeek'e geçer. API anahtarları maskeli saklanır.",
        ),
      ]),
    ]),
    dom.element("div", [a.class("ai-key-pool-toolbar")], [
      dom.element("span", [a.class("badge-glass-cyan")], [
        text("10 Gemini hesabı"),
      ]),
      dom.element("span", [a.class("muted")], [text("Öncelik sırası: 1 → 10")]),
      dom.element(
        "button",
        [
          a.type_("button"),
          a.class("btn-primary-glow"),
          a.id("btn-save-ai-key-pool"),
        ],
        [text("💾 Havuzu Kaydet")],
      ),
    ]),
    dom.element(
      "div",
      [a.class("ai-key-pool-grid")],
      gemini_indexes |> list.map(ai_pool_row),
    ),
    dom.element("article", [a.class("ai-fallback-row")], [
      dom.element("div", [a.class("ai-key-row-title")], [
        dom.element("strong", [], [text("DeepSeek yedek sağlayıcı")]),
        dom.element(
          "span",
          [a.class("ai-key-row-status"), a.id("deepseek-ai-status")],
          [text("Kota dolunca devreye girer")],
        ),
      ]),
      dom.element("div", [a.class("ai-key-row-fields")], [
        ai_pool_input("API anahtarı", "deepseek_key", "sk-…", "password"),
        ai_pool_input("Model", "deepseek_model", "deepseek-chat", "text"),
        ai_pool_input(
          "Günlük kota (0=sınırsız)",
          "deepseek_limit",
          "0",
          "number",
        ),
        setting_select("Durum", "deepseek_active", [
          #("true", "Aktif"),
          #("false", "Pasif"),
        ]),
      ]),
    ]),
    dom.element(
      "div",
      [a.class("ai-key-pool-status"), a.id("ai-key-pool-status")],
      [text("Kullanım durumu yükleniyor…")],
    ),
  ])
}

fn metric(title: String, value: String, desc: String) {
  dom.element("article", [a.class("metric")], [
    dom.element("span", [], [text(title)]),
    dom.element("strong", [], [text(value)]),
    dom.element("small", [], [text(desc)]),
  ])
}

fn metric_id(title: String, value: String, desc: String, id: String) {
  let #(series_key, unit) = case id {
    "dashboard-published" -> #("published", "yayın")
    "dashboard-pending" -> #("pending", "talep")
    "dashboard-upcoming" -> #("upcoming", "rezervasyon")
    _ -> #("", "")
  }
  // Nexus bağlantı kartının serisi yok — öznitelikleri hiç basma.
  // Serili kartlar tıklanabilir: dashboard-admin.js modal grafik açar.
  // article > button (role=dialog tetikleyicisi) — kart kendisi article kalır.
  let series_attrs = case series_key {
    "" -> []
    _ -> [
      a.class("metric metric-clickable"),
      a.attribute("data-series", series_key),
      a.attribute("data-unit", unit),
      a.attribute("role", "button"),
      a.attribute("tabindex", "0"),
      a.attribute("aria-haspopup", "dialog"),
      a.attribute("aria-label", title <> " — 14 günlük trend grafiğini aç"),
      a.attribute("title", "14 günlük trendi gör"),
    ]
  }
  dom.element("article", [a.class("metric"), ..series_attrs], [
    dom.element("span", [], [text(title)]),
    dom.element("div", [a.class("metric-value-row")], [
      dom.element("strong", [a.id(id)], [text(value)]),
      dom.element(
        "span",
        [a.class("metric-trend"), a.attribute("aria-live", "polite")],
        [],
      ),
    ]),
    dom.element(
      "div",
      [a.class("metric-spark"), a.attribute("aria-hidden", "true")],
      [],
    ),
    // Haftalık toplam etiketi — JS tarafından son 7 gün toplamıyla doldurulur
    dom.element("small", [a.class("metric-weekly")], [text("")]),
    dom.element(
      "div",
      [a.class("metric-announce"), a.attribute("aria-live", "polite")],
      [text("")],
    ),
    dom.element("small", [], [text(desc)]),
  ])
}

fn quick(href: String, title: String, desc: String) {
  dom.element("a", [a.href(href), a.class("quick")], [
    dom.element("strong", [], [text(title)]),
    dom.element("span", [], [text(desc)]),
    text("→"),
  ])
}

pub fn holiday_home_manager_page(
  s: Session,
  module: String,
  lang: String,
) -> String {
  layout_with_theme(
    s.theme_pref,
    "Tatil Evi",
    dom.element("div", [a.class("dashboard")], [
      sidebar_element(lang, "holiday_home", s.membership),
      panel_mobile_tab_bar(lang, s.membership),
      dom.element("section", [a.class("panel-area")], [
        topbar_element("Tatil Evi", s.name, lang),
        dom.element("main", [a.class("panel-content")], [
          dom.element(
            "section",
            [
              a.class("quick hh-manager"),
              a.id("holiday-home-manager"),
              a.attribute("data-module", module),
            ],
            [
              dom.element("div", [a.class("section-heading")], [
                dom.element("div", [], [
                  dom.element("span", [a.class("eyebrow")], [text("TATİL EVİ")]),
                  dom.element("h2", [a.id("hh-page-title")], [
                    text("Tatil Evi yönetimi"),
                  ]),
                  dom.element("p", [a.class("muted"), a.id("hh-page-intro")], [
                    text("Yönetim ekranı yükleniyor…"),
                  ]),
                ]),
                dom.element("span", [a.class("status-pill")], [
                  text("Canlı yönetim"),
                ]),
              ]),
              dom.element("div", [a.id("hh-manager-content")], []),
              dom.element("div", [a.class("hh-savebar")], [
                dom.element("span", [a.class("muted"), a.id("hh-save-status")], [
                  text("Değişiklikler bu tarayıcıda otomatik saklanır."),
                ]),
                dom.element(
                  "button",
                  [a.type_("button"), a.class("primary"), a.id("hh-save")],
                  [text("Kaydet")],
                ),
              ]),
            ],
          ),
        ]),
      ]),
    ]),
    lang,
    [
      "/static/holiday-home-admin.js?v=20260914-full",
      "/static/holiday-home-wizard-upgrade.js?v=20260914-full",
    ],
    [
      "/static/css/08-editor-rooms-seo.css",
      "/static/css/09-catalog-mode.css?v=20260926-benefitcards1",
    ],
    s.wizard_prefs_json,
  )
}

/// Sayfaların ihtiyaç duyduğu ek betikler. Temel set (sidebar-tree, sidebar-nav,
/// quick-search) her panel sayfasında yüklenir; bölüm bazlı betikler bu listeyle
/// eklenir. Böylece her sayfa yalnızca kendi JS'ini indirir.
/// Bölüm SLUG'ına göre gerekli betik dosyaları. Katalog sihirbazı ve
/// tablo betikleri yalnızca ilgili çalışma alanında yüklenir.
///
/// Anahtar slug'dır (başlık değil): başlık artık dile göre çevrildiği için
/// onunla eşleştirmek, örneğin `?lang=en` sayfasında hiçbir modülü yüklemezdi.
fn section_scripts(section_key: String) -> List(String) {
  case section_key {
    "catalog" | "listings" -> [
      "/static/listing-admin.js",
      "/static/listing-wizard.js?v=20260918-kbd3",
      "/static/holiday-home-admin.js?v=20260914-full",
      "/static/holiday-home-wizard-upgrade.js?v=20260914-full",
      "/static/rich-editor.js?v=20260914-seo",
      "/static/ai-seo-suite.js?v=20260914-seo",
    ]
    "regions" -> [
      "/static/region-admin.js",
      "/static/rich-editor.js?v=20260914-seo",
      "/static/ai-seo-suite.js?v=20260914-seo",
    ]
    "settings" -> [
      "/static/settings-admin.js",
      "/static/ai-key-pool.js?v=20260916",
    ]
    "currencies" -> ["/static/currency-admin.js"]
    "customers" -> ["/static/customer-admin.js?v=20260927-3"]
    "reservations" -> ["/static/reservation-admin.js"]
    "role-context" -> ["/static/role-context.js?v=20260927-1"]
    "supplier-bookings" -> ["/static/supplier-bookings.js?v=20260928-1"]
    "supplier-operations" -> [
      "/static/supplier-operations.js?v=20260928-application1",
    ]
    "supplier-inquiries" -> ["/static/supplier-inquiries.js?v=20260927-1"]
    "assigned-inquiries" -> ["/static/assigned-inquiries.js?v=20260927-1"]
    "sub-agencies" -> [
      "/static/team-admin.js",
      "/static/partner-network.js?v=20260927-1",
    ]
    "finance-overview" -> ["/static/finance-overview.js?v=20260927-1"]
    "commercial-operations" -> ["/static/commercial-operations.js?v=20260927-2"]
    "review-center" -> ["/static/review-center.js?v=20260927-1"]
    "languages" -> ["/static/language-admin.js"]
    "categories" -> ["/static/category-admin.js?v=20260924-tour-tree"]
    "integrations" -> ["/static/integration-admin.js"]
    "ai" -> [
      "/static/ai-admin.js?v=20260929-ai",
      "/static/ai-key-pool.js?v=20260916",
      "/static/module-controls.js",
      "/static/social-studio.js?v=20260929",
    ]
    "sync" -> ["/static/sync-admin.js?v=20260928-2"]
    "control-center" -> ["/static/control-center.js?v=20260928-1"]
    "supplier-onboarding" -> [
      "/static/supplier-onboarding-admin.js?v=20260928-review3",
    ]
    "listing-submissions" -> [
      "/static/listing-submissions-admin.js?v=20260929-1",
    ]
    "cms" -> [
      "/static/cms-admin.js?v=20260926-hero-all1",
      "/static/rich-editor.js?v=20260914-seo",
      "/static/ai-seo-suite.js?v=20260914-seo",
    ]
    "campaigns" | "supplier-campaigns" -> ["/static/campaign-admin.js"]
    "team" -> ["/static/team-admin.js"]
    "reports" -> ["/static/report-admin.js?v=20260918-digest1"]
    "media" -> ["/static/photo-editor.js"]
    "abandoned-carts" -> ["/static/abandoned-carts.js"]
    "popups" -> ["/static/popups-admin.js"]
    "offers" -> ["/static/offer-whatsapp.js"]
    _ -> []
  }
}

fn sync_form() {
  dom.element("section", [a.class("quick"), a.id("sync-workspace")], [
    dom.element("div", [a.class("section-heading")], [
      dom.element("div", [], [
        dom.element("span", [a.class("eyebrow")], [text("NEXUS SYNC")]),
        dom.element("h2", [], [text("Senkronizasyon durumu")]),
        dom.element("p", [a.class("muted")], [
          text(
            "Nexus ile acente arasındaki sözleşme uyumu, son import işleri ve hata durumları burada izlenir.",
          ),
        ]),
      ]),
      dom.element(
        "button",
        [
          a.type_("button"),
          a.class("primary"),
          a.id("sync-refresh"),
        ],
        [text("Yenile")],
      ),
    ]),
    dom.element("div", [a.class("metric-grid"), a.id("sync-contract-cards")], [
      metric("Katalog sözleşmesi", "Yükleniyor", "Kategori sözlüğü"),
      metric("İlan sözleşmesi", "Yükleniyor", "Alan ve durum kuralları"),
      metric("Kategoriler", "Yükleniyor", "Aktif ana kategori sayısı"),
      metric("Filtreler", "Yükleniyor", "Aktif yönetilebilir filtre maddeleri"),
      metric("Panel modülleri", "Yükleniyor", "Ortak tedarikçi panel modülleri"),
    ]),
    dom.element("div", [a.class("metric-grid"), a.id("sync-health-cards")], [
      metric("NEXUS bağlantısı", "Yükleniyor", "Endpoint ve API anahtarı"),
      metric("Onay durumu", "Yükleniyor", "Acentenin bağlantı başvurusu"),
      metric("Son senkronizasyon", "Yükleniyor", "Son iş ve hata durumu"),
      metric("Son başarılı sync", "Yükleniyor", "Başarılı import zamanı"),
      metric("NEXUS ilanları", "Yükleniyor", "Merkezden gelen ilan sayısı"),
      metric("Başarısız sync işleri", "Yükleniyor", "Son hata ile birlikte"),
      metric(
        "Rezervasyon kuyruğu",
        "Yükleniyor",
        "Bekleyen / başarısız olaylar",
      ),
    ]),
    dom.element("div", [a.class("table-card")], [
      dom.element("div", [a.class("table-toolbar")], [
        dom.element("h3", [], [text("Son sync işleri")]),
        dom.element("form", [a.method("post"), a.action("/admin/sync/retry")], [
          dom.element("button", [a.type_("submit"), a.class("secondary")], [
            text("Manuel import denemesi sıraya al"),
          ]),
        ]),
      ]),
      dom.element("table", [a.class("data-table")], [
        dom.element("thead", [], [
          dom.element("tr", [], [
            dom.element("th", [], [text("Tip")]),
            dom.element("th", [], [text("Durum")]),
            dom.element("th", [], [text("Başlangıç")]),
            dom.element("th", [], [text("Bitiş")]),
            dom.element("th", [], [text("Adet")]),
            dom.element("th", [], [text("Hata")]),
          ]),
        ]),
        dom.element("tbody", [a.id("sync-jobs-body")], [
          dom.element("tr", [], [
            dom.element("td", [a.attribute("colspan", "6")], [
              text("Sync işleri yükleniyor…"),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn supplier_onboarding_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("supplier-onboarding-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("span", [a.class("eyebrow")], [
            text("TEDARİKÇİ ONBOARDING"),
          ]),
          dom.element("h2", [], [text("Tedarikçi başvuruları")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Başvuru durumu, kategori talebi, kimlik kontrolü ve belge sayıları ortak onboarding sözleşmesine göre izlenir.",
            ),
          ]),
        ]),
        dom.element(
          "button",
          [
            a.type_("button"),
            a.class("primary"),
            a.id("supplier-onboarding-refresh"),
          ],
          [text("Yenile")],
        ),
      ]),
      dom.element(
        "div",
        [a.class("metric-grid"), a.id("supplier-onboarding-status-cards")],
        [
          metric("Taslak", "0", "Tamamlanmamış başvuru"),
          metric("Gönderildi", "0", "İnceleme bekliyor"),
          metric("İncelemede", "0", "Operasyon kontrolünde"),
          metric("Onaylandı", "0", "Tedarikçi aktif"),
          metric("Askıda/Ret", "0", "Aksiyon gerekiyor"),
        ],
      ),
      dom.element("div", [a.class("table-card")], [
        dom.element("div", [a.class("table-toolbar")], [
          dom.element("h3", [], [text("Başvuru kuyruğu")]),
          dom.element("span", [a.class("muted")], [
            text("Kararlar yetki ve durum kontrolünden sonra kaydedilir."),
          ]),
        ]),
        dom.element("table", [a.class("data-table")], [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Tedarikçi")]),
              dom.element("th", [], [text("Kategori")]),
              dom.element("th", [], [text("Durum")]),
              dom.element("th", [], [text("Kimlik")]),
              dom.element("th", [], [text("Belge")]),
              dom.element("th", [], [text("Başvuru tarihi")]),
              dom.element("th", [], [text("Not")]),
              dom.element("th", [], [text("Aksiyon")]),
            ]),
          ]),
          dom.element("tbody", [a.id("supplier-onboarding-body")], [
            dom.element("tr", [], [
              dom.element("td", [a.attribute("colspan", "8")], [
                text("Başvurular yükleniyor…"),
              ]),
            ]),
          ]),
        ]),
      ]),
      dom.element("div", [a.class("table-card")], [
        dom.element("div", [a.class("table-toolbar")], [
          dom.element("h3", [], [text("Belge inceleme")]),
          dom.element("span", [a.class("muted")], [
            text(
              "Eksik, bekleyen, onaylanan ve reddedilen evraklar başvuru bazında izlenir.",
            ),
          ]),
        ]),
        dom.element("div", [a.id("supplier-document-review")], [
          dom.element("p", [a.class("muted")], [text("Belgeler yükleniyor…")]),
        ]),
      ]),
    ],
  )
}

/// Bölüm SLUG'ına göre gerekli CSS modülleri. Çekirdek set (tokens, base,
/// layout, forms/tables, media-catalog'daki ortak çubuklar, utilities, compact)
/// her sayfada yüklenir; özellik modülleri yalnızca ilgili bölümde.
fn section_stylesheets(section_key: String) -> List(String) {
  case section_key {
    "catalog" | "listings" -> [
      "/static/css/06-wizard.css",
      "/static/css/08-editor-rooms-seo.css",
      "/static/css/09-catalog-mode.css?v=20260926-benefitcards1",
      "/static/css/10-translations.css",
    ]
    "regions" -> [
      "/static/css/08-editor-rooms-seo.css",
      "/static/css/11-regions.css",
    ]
    "settings" | "ai" -> [
      "/static/css/09-catalog-mode.css?v=20260926-benefitcards1",
      "/static/css/11-regions.css",
    ]
    "cms" -> ["/static/css/08-editor-rooms-seo.css"]
    "commercial-operations" -> [
      "/static/commercial-operations.css?v=20260927-1",
    ]
    "control-center" -> ["/static/control-center.css?v=20260928-1"]
    _ -> []
  }
}

fn layout(
  title: String,
  body: dom.Element(Nil),
  lang: String,
  extra_scripts: List(String),
  extra_stylesheets: List(String),
) -> String {
  layout_with_theme("", title, body, lang, extra_scripts, extra_stylesheets, "")
}

/// layout'un tema duyarlı varyantı: theme_pref sunucu tarafı tercihtir
/// (kullanıcı hesabından gelir; boşsa "dark" varsayılanı kullanılır).
/// Tercih <html data-theme> olarak basılır — FOUC yok, boot script yalnızca
/// suncudan gelen değeri doğrular.
fn layout_with_theme(
  theme_pref: String,
  title: String,
  body: dom.Element(Nil),
  lang: String,
  extra_scripts: List(String),
  extra_stylesheets: List(String),
  wizard_prefs_json: String,
) -> String {
  layout_with_theme_and_prefs(
    theme_pref,
    title,
    body,
    lang,
    extra_scripts,
    extra_stylesheets,
    wizard_prefs_json,
  )
}

fn layout_with_theme_and_prefs(
  theme_pref: String,
  title: String,
  body: dom.Element(Nil),
  lang: String,
  extra_scripts: List(String),
  extra_stylesheets: List(String),
  wizard_prefs_json: String,
) -> String {
  let dir = case i18n.is_rtl(lang) {
    True -> "rtl"
    False -> "ltr"
  }
  let theme = case theme_pref {
    "light" -> theme_pref
    // "auto": gerçek paleti sunucu saatinden cozulur (07-19 light, diger dark)
    // çözer — tarayıcı boot'ta kendi saatiyle aynı eşiklerle doğrular.
    "auto" -> auto_theme_at(timestamp.system_time())
    _ -> "dark"
  }
  // Tüm stil sayfaları: çekirdek set + bölüm modülleri (cascade sırası korunur).
  let stylesheet_tags =
    list.append(
      core_stylesheet_links(),
      extra_stylesheets |> list.map(stylesheet_link),
    )
  let script_tags =
    list.append(
      [
        // CSRF guard en erken sırada: sonraki betiklerin ürettiği formlara
        // token enjeksiyonu submit anında hazır olsun.
        script_tag("/static/csrf-guard.js?v=20260924-login"),
        script_tag("/static/theme-toggle.js?v=20260924-locale-sync"),
        script_tag("/static/focus-trap.js"),
        script_tag("/static/table-bulk.js?v=20260918-bulk6"),
        script_tag("/static/table-expand.js?v=20260918-expand1"),
        script_tag("/static/table-cards.js?v=20260917-mobile-cards"),
        script_tag("/static/sidebar-tree.js?v=20260916-catalog-groups"),
        script_tag("/static/sidebar-nav.js?v=20260917-mobile-active"),
        script_tag("/static/quick-search.js"),
        script_tag("/static/form-enhancements.js?v=20260924-login-submit"),
        script_tag("/static/panel-tab-bar.js"),
        script_tag("/static/login-theme.js"),
        script_tag("/static/hugeicons-normalizer.js?v=20260924-hgi1"),
      ],
      extra_scripts |> list.map(script_tag),
    )
  "<!doctype html>"
  <> dom.to_string(
    dom.element(
      "html",
      [
        a.attribute("lang", lang),
        a.attribute("dir", dir),
        a.attribute("data-theme", theme),
        a.attribute("data-wizard-prefs", wizard_prefs_json),
      ],
      [
        dom.element("head", [], [
          dom.element("meta", [a.attribute("charset", "utf-8")], []),
          dom.element(
            "meta",
            [
              a.name("viewport"),
              // viewport-fit=cover: çentikli telefonlarda safe-area dolgusu (topbar) etkin olur
              a.attribute(
                "content",
                "width=device-width, initial-scale=1, viewport-fit=cover",
              ),
            ],
            [],
          ),
          // FOUC önleme: kayıtlı tema tercihini ilk boyamadan ÖNCE uygula.
          // (Inline script kullanılamaz — lustre tek tırnakları &#39; yapar.)
          dom.element(
            "script",
            [a.attribute("src", "/static/theme-boot.js?v=20260918-auto2")],
            [],
          ),
          // Modüler glass tema — çekirdek set her sayfada, bölüm modülleri sonra.
          ..list.append(stylesheet_tags, [
            dom.element(
              "link",
              [
                a.attribute("rel", "stylesheet"),
                a.href("https://use.hugeicons.com/font/icons.css"),
              ],
              [],
            ),
            dom.element("title", [], [text(title <> " · NEXUS Agency")]),
          ])
        ]),
        dom.element("body", [], list.append([body], script_tags)),
      ],
    ),
  )
}

fn script_tag(src: String) -> dom.Element(Nil) {
  let cache_busted = case string.contains(src, "?") {
    True -> src
    False -> src <> "?v=20260918-sw"
  }
  dom.element(
    "script",
    [a.attribute("src", cache_busted), a.attribute("defer", "defer")],
    [],
  )
}

fn stylesheet_link(href: String) -> dom.Element(Nil) {
  let cache_busted = case string.contains(href, "?") {
    True -> href
    False -> href <> "?v=20260918-sw"
  }
  dom.element(
    "link",
    [a.attribute("rel", "stylesheet"), a.href(cache_busted)],
    [],
  )
}

/// Her panel sayfasında yüklenen CSS modülleri (cascade sırasıyla).
fn core_stylesheet_links() -> List(dom.Element(Nil)) {
  [
    "/static/css/01-tokens.css",
    "/static/css/02-base.css",
    "/static/css/03-layout.css?v=20260927-panel2",
    "/static/css/04-forms-tables.css",
    "/static/css/05-media-catalog.css",
    "/static/css/07-utilities.css",
    "/static/css/12-compact-responsive.css",
  ]
  |> list.map(stylesheet_link)
}

fn listing_submissions_form() {
  dom.element(
    "section",
    [a.class("quick"), a.id("listing-submissions-workspace")],
    [
      dom.element("div", [a.class("section-heading")], [
        dom.element("div", [], [
          dom.element("span", [a.class("eyebrow")], [
            text("PAZARYERİ VE PORTAL İLANLARI"),
          ]),
          dom.element("h2", [], [text("İlan Başvuruları")]),
          dom.element("p", [a.class("muted")], [
            text(
              "Vitrin üzerinden (rezervasyonyap.com.tr / reservationinturkey.com) gelen tedarikçi ilan başvurularını denetleyin, onaylayın veya reddedin.",
            ),
          ]),
        ]),
        dom.element(
          "button",
          [
            a.type_("button"),
            a.class("primary"),
            a.id("listing-submissions-refresh"),
          ],
          [text("Yenile")],
        ),
      ]),
      dom.element(
        "div",
        [a.class("metric-grid"), a.id("listing-submissions-status-cards")],
        [
          metric("Bekleyen", "0", "İnceleme bekleyen ilanlar"),
          metric("Onaylanan", "0", "Kataloğa aktarılan ilanlar"),
          metric("Reddedilen", "0", "Gerekçeyle reddedilenler"),
          metric("Toplam Başvuru", "0", "Tüm vitrin kayıtları"),
        ],
      ),
      dom.element("div", [a.class("table-card")], [
        dom.element("div", [a.class("table-toolbar")], [
          dom.element("h3", [], [text("Gelen İlan Kuyruğu")]),
          dom.element("div", [a.class("filter-controls")], [
            dom.element("select", [a.id("listing-submission-status-filter")], [
              dom.element("option", [a.value("")], [text("Tüm Durumlar")]),
              dom.element("option", [a.value("pending")], [
                text("Beklemede (pending)"),
              ]),
              dom.element("option", [a.value("approved")], [
                text("Onaylanan (approved)"),
              ]),
              dom.element("option", [a.value("rejected")], [
                text("Reddedilen (rejected)"),
              ]),
            ]),
          ]),
        ]),
        dom.element("table", [a.class("data-table")], [
          dom.element("thead", [], [
            dom.element("tr", [], [
              dom.element("th", [], [text("Firma / İletişim")]),
              dom.element("th", [], [text("Kategori")]),
              dom.element("th", [], [text("İlan Başlığı & Konum")]),
              dom.element("th", [], [text("Hedef Portal")]),
              dom.element("th", [], [text("Fiyat & Kapasite")]),
              dom.element("th", [], [text("Tarih")]),
              dom.element("th", [], [text("Durum")]),
              dom.element("th", [], [text("Aksiyon")]),
            ]),
          ]),
          dom.element("tbody", [a.id("listing-submissions-body")], [
            dom.element("tr", [], [
              dom.element("td", [a.attribute("colspan", "8")], [
                text("İlan başvuruları yükleniyor…"),
              ]),
            ]),
          ]),
        ]),
      ]),
    ],
  )
}

pub fn ilan_ver_page(lang: String, domain_target: String) -> String {
  let title = case lang {
    "en" -> "List Your Property & Experiences · Partner Onboarding"
    _ -> "İlanınızı Ekleyin · Turizm Pazaryeri İlan Başvurusu"
  }
  let body =
    dom.element("main", [a.class("ilan-ver-container")], [
      dom.element(
        "div",
        [
          a.id("ilan-ver-root"),
          a.attribute("data-lang", lang),
          a.attribute("data-domain-target", domain_target),
        ],
        [
          dom.element("div", [a.class("ilan-ver-loading")], [
            dom.element("div", [a.class("spinner")], []),
            dom.element("p", [], [
              text(case lang {
                "en" -> "Loading Partner Onboarding Wizard…"
                _ -> "İlan Verme Sihirbazı Yükleniyor…"
              }),
            ]),
          ]),
        ],
      ),
    ])
  layout(title, body, lang, ["/static/ilan-ver.js?v=20260929-1"], [
    "/static/css/ilan-ver.css?v=20260929-1",
  ])
}
