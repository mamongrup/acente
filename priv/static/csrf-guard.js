// csrf-guard.js — Panel geneli CSRF (synchronizer token) entegrasyonu.
//
// Sunucu, giriş anında `nexus_csrf` çerezine oturumdan türetilmiş token'ı
// yazar (HttpOnly DEĞİL — bu betik okur; değer imzasızdır, güvenlik sunucu
// tarafındaki HMAC doğrulamasındadır). Bu betik:
//   1) CSRF başlangıcında TÜM form'lara gizli `csrf` alanı enjekte eder
//      (statik + sonradan eklenen formlar MutationObserver ile),
//   2) sunucuya form-data gönderen fetch çağrılarını sarmalar,
//   3) table-bulk gibi dinamik üretici form'ların submit anında token
//      taşımasını garantiler.
// Token yoksa form gönderimi durdurulur ve kullanıcıya re-login önerilir.

(function () {
  "use strict";

  var FIELD = "csrf";

  function readCookie(name) {
    var parts = document.cookie.split(/;\s*/);
    for (var i = 0; i < parts.length; i++) {
      var eq = parts[i].indexOf("=");
      if (eq > 0 && parts[i].slice(0, eq) === name) {
        return decodeURIComponent(parts[i].slice(eq + 1));
      }
    }
    return null;
  }

  function token() {
    return readCookie("nexus_csrf");
  }

  function ensureField(form) {
    if (!form || form.tagName !== "FORM") return;
    // Giriş formu oturum oluşturur; bu aşamada CSRF çerezi henüz yoktur.
    if (form.getAttribute("action") === "/login") return;
    if (form.querySelector('input[name="' + FIELD + '"]')) return;
    var value = token();
    if (!value) return;
    var input = document.createElement("input");
    input.type = "hidden";
    input.name = FIELD;
    input.value = value;
    form.appendChild(input);
  }

  function scan(root) {
    var forms = (root || document).querySelectorAll("form");
    Array.prototype.forEach.call(forms, ensureField);
  }

  // 1) Statik + dinamik formlar
  function start() {
    scan(document);
    if (document.documentElement.hasAttribute("data-csrf-observed")) return;
    document.documentElement.setAttribute("data-csrf-observed", "true");
    var observer = new MutationObserver(function (mutations) {
      mutations.forEach(function (mutation) {
        Array.prototype.forEach.call(mutation.addedNodes, function (node) {
          if (node.nodeType !== 1) return;
          if (node.tagName === "FORM") {
            ensureField(node);
          } else if (node.querySelectorAll) {
            scan(node);
          }
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });

    // 3) Submit anında son savunma: token'sız form gönderilmesin.
    //    (table-bulk geçici formları observer'a düşmeden submit olabilir.)
    document.addEventListener(
      "submit",
      function (e) {
        var form = e.target;
        if (!form || form.tagName !== "FORM") return;
        if (form.getAttribute("action") === "/login") return;
        ensureField(form);
        if (!form.querySelector('input[name="' + FIELD + '"]')) {
          e.preventDefault();
          console.warn("CSRF token yok — sayfayı yenileyip tekrar giriş yapın.");
        }
      },
      true
    );

    // 2) fetch sarmalayıcı: FormData VE URLSearchParams gövdelerine token
    //    ekler. URLSearchParams kritik: sunucudaki require_csrf_form yalnız
    //    urlencoded gövdeleri ayrıştırır (multipart 403 olur) — theme-toggle
    //    gibi URLSearchParams ile gönderen modüller buradan token alır.
    //    FormData'lı fetch'ler de multipart yerine urlencoded'a ÇEVRİLİR
    //    (dosya içermeyenler): aksi halde tüm FormData POST'ları sunucuda
    //    CSRF 403 alır (Ayarlar kaydı dahil). Dosyalı gövdeler olduğu gibi
    //    kalır — Origin kontrolü tek savunma olarak kalır.
    var origFetch = window.fetch;
    if (origFetch) {
      window.fetch = function (input, init) {
        try {
          var method = ((init && init.method) || "GET").toUpperCase();
          var body = init && init.body;
          var isFormData =
            typeof FormData !== "undefined" && body instanceof FormData;
          var isUrlEncoded =
            typeof URLSearchParams !== "undefined" &&
            body instanceof URLSearchParams;
          if (method === "POST" && isFormData) {
            var hasFile = false;
            body.forEach(function (value) {
              if (
                (typeof File !== "undefined" && value instanceof File) ||
                (typeof Blob !== "undefined" && value instanceof Blob)
              ) {
                hasFile = true;
              }
            });
            if (!hasFile) {
              var value = token();
              if (value && !body.has(FIELD)) body.append(FIELD, value);
              var params = new URLSearchParams();
              body.forEach(function (v, k) {
                params.append(k, v);
              });
              init.body = params;
            }
          } else if (
            method === "POST" &&
            isUrlEncoded &&
            !body.has(FIELD)
          ) {
            var value2 = token();
            if (value2) body.append(FIELD, value2);
          }
        } catch (err) {
          /* sarmalayıcı hataları isteği engellemesin */
        }
        return origFetch.apply(this, arguments);
      };
    }
  }

  // table-bulk gibi dinamik form üreten modüller için global API:
  // tagForm(form) → form'a csrf alanı ekler (yoksa).
  window.__NexusCsrf = {
    token: token,
    tagForm: ensureField,
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
  } else {
    start();
  }
})();
