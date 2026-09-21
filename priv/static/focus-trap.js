// NEXUS Agency — Focus Trap
// Modal/dialog açıkken klavye odağını (özellikle Tab/Shift+Tab) container içinde tutar.
// Kullanım: FocusTrap.activate(el, { onEscape, initialFocus });  FocusTrap.deactivate();
(function () {
  'use strict';

  var FOCUSABLE = [
    'a[href]',
    'button:not([disabled])',
    'input:not([disabled]):not([type="hidden"])',
    'select:not([disabled])',
    'textarea:not([disabled])',
    '[tabindex]:not([tabindex="-1"])',
  ].join(',');

  var active = null; // { container, previouslyFocused, onEscape }

  function visible(el) {
    if (!el) return false;
    var rect = el.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return false;
    var style = window.getComputedStyle(el);
    return style.visibility !== 'hidden' && style.display !== 'none';
  }

  function focusableIn(container) {
    var list = container.querySelectorAll(FOCUSABLE);
    var out = [];
    for (var i = 0; i < list.length; i++) {
      if (visible(list[i]) && list[i].offsetParent !== null) out.push(list[i]);
    }
    return out;
  }

  function firstFocusable(container) {
    // Autofocus önceliği: data-autofocus > ilk odaklanılabilir
    var preferred = container.querySelector('[data-autofocus]');
    if (preferred && visible(preferred)) return preferred;
    var list = focusableIn(container);
    return list.length ? list[0] : null;
  }

  function onKeydown(e) {
    if (!active) return;
    var container = active.container;

    if (e.key === 'Escape' && typeof active.onEscape === 'function') {
      e.preventDefault();
      active.onEscape();
      return;
    }
    if (e.key !== 'Tab') return;

    var items = focusableIn(container);
    if (!items.length) {
      // Odaklanılabilir hiçbir şey yoksa odağı container'da tut
      e.preventDefault();
      container.focus();
      return;
    }

    var first = items[0];
    var last = items[items.length - 1];
    var current = document.activeElement;

    if (e.shiftKey) {
      // Geriye: ilk öğeden çıkış denemesi -> sona dön
      if (current === first || !container.contains(current)) {
        e.preventDefault();
        last.focus();
      }
    } else {
      // İleriye: son öğeden çıkış denemesi -> başa dön
      if (current === last || !container.contains(current)) {
        e.preventDefault();
        first.focus();
      }
    }
  }

  window.FocusTrap = {
    /** Konteyner için trap'i etkinleştir; trap aktifken element tab sırası dışına çıkamaz. */
    activate: function (container, opts) {
      opts = opts || {};
      if (active) this.deactivate(); // iç içe kullanım: öncekini kapat
      active = {
        container: container,
        previouslyFocused: document.activeElement,
        onEscape: opts.onEscape || null,
      };
      document.addEventListener('keydown', onKeydown, true); // capture: bubble'a düşmeden yakala
      var initial = opts.initialFocus || firstFocusable(container);
      if (initial) {
        // Deactivate edilmişse gecikmiş odak gizli öğeye atlamasın (race guard)
        setTimeout(function () {
          if (active && active.container === container) initial.focus();
        }, 0);
      }
      return active;
    },

    /** Trap'i kapat; odağı activate anındaki öğeye döndür (aynı tick'te). */
    deactivate: function () {
      if (!active) return;
      document.removeEventListener('keydown', onKeydown, true);
      var prev = active.previouslyFocused;
      active = null;
      if (prev && typeof prev.focus === 'function' && document.contains(prev)) {
        // Senkron restore: deactivate() döndüğünde odak zaten opener'da olmalı
        prev.focus();
      }
    },

    /** Bu container aktif trap mi? */
    isActive: function (container) {
      return !!active && active.container === container;
    },
  };
})();
