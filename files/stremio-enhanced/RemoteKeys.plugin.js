/**
 * @name RemoteKeys
 * @description Remote-control buttons for Stremio's UI: Back, Search, List (library), Home.
 * @version 1.2.0
 * @author asher
 */
// Works in both stremio-enhanced builds (Electron and the Rust/WebKit shell):
// it only listens to keydown in the page. Playback itself is in mpv-htpc
// (MpvHandoff plugins), whose buttons are in files/mpv/input.conf, so this
// covers browsing only.
//
// Evdev -> what the page sees. KEY_BACK/KEY_SEARCH arrive as XF86Back/
// XF86Search; browsers name those "BrowserBack"/"BrowserSearch" (Windows
// keyCodes 166/170), KEY_HOMEPAGE "BrowserHome" (172). KEY_COMPOSE (the MX3's
// List button) arrives as "ContextMenu" (93). Codes per button: modules/hardware/input.nix.
(function () {
  // Logs every keydown that isn't a plain character, to learn what a new
  // remote sends. "[Plugin]": the Rust shell only forwards tagged lines to
  // its terminal log.
  const DEBUG = true;
  function log(m) { console.log("[Plugin] [RemoteKeys]", m); }

  const BACK = { keys: ["BrowserBack", "GoBack"], codes: [166] };
  const SEARCH = { keys: ["BrowserSearch"], codes: [170] };
  // confirmed in WebKitGTK 2026-11-19: KEY_COMPOSE arrives as ContextMenu/93
  const LIST = { keys: ["ContextMenu", "Compose"], codes: [93] };
  const HOME = { keys: ["BrowserHome"], codes: [172] };
  const is = (e, k) => k.keys.includes(e.key) || k.codes.includes(e.keyCode);

  // Popups, menus and modals that Escape closes, checked before navigating
  // back. Stremio's class names are hashed CSS modules, so match on stems.
  const OVERLAY = '[class*="modal-container"], [class*="popup-menu-container"], [class*="menu-container"][class*="open"], [role="dialog"]';

  function pressEscape() {
    const target = document.activeElement || document.body;
    for (const type of ["keydown", "keyup"]) {
      target.dispatchEvent(new KeyboardEvent(type, {
        key: "Escape", code: "Escape", keyCode: 27, which: 27, bubbles: true, cancelable: true,
      }));
    }
  }

  function back() {
    const route = window.location.hash;
    // Search: straight back to the Board. Stremio rewrites the address on
    // every keystroke (#/search?search=...) and refocuses the box, so
    // stepping back through history never gets out of it.
    if (page(route) === "#/search") {
      if (document.activeElement) document.activeElement.blur();
      window.location.hash = "#/";
      return "leave search for home";
    }
    const el = document.activeElement;
    if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA")) {
      el.blur(); // leave the search box first; the next Back navigates
      return "blur input";
    }
    if (document.querySelector(OVERLAY)) {
      pressEscape();
      return "close overlay";
    }
    if (isHome(route)) return "at home, nothing to do";
    goBackFrom(page(route), 3);
    return "history.back from " + page(route);
  }

  // "#/library?sort=lastwatched" -> "#/library". Some pages (the library)
  // rewrite their own address on load, leaving a duplicate history entry,
  // so one history.back() can land on the same page. Keep stepping back
  // until the page actually changes.
  function page(route) { return route.split("?")[0]; }
  function isHome(route) { return route === "" || route === "#" || page(route) === "#/"; }
  function goBackFrom(from, tries) {
    history.back();
    setTimeout(function () {
      const now = window.location.hash;
      if (tries > 1 && page(now) === from && !isHome(now)) goBackFrom(from, tries - 1);
    }, 250);
  }

  function home() {
    window.location.hash = "#/";
    return "go home";
  }

  function searchInput() {
    return document.querySelector(
      'input[class*="search-input"], [class*="search-bar"] input, input[type="search"], input[placeholder*="earch"]'
    );
  }

  function search() {
    const input = searchInput();
    if (input) { input.focus(); input.select && input.select(); return "focus search box"; }
    window.location.hash = "#/search";
    setTimeout(function () { const i = searchInput(); if (i) i.focus(); }, 400);
    return "open search page";
  }

  function list() {
    window.location.hash = "#/library";
    return "open library";
  }

  window.addEventListener("keydown", function (e) {
    if (DEBUG && e.key && e.key.length > 1) {
      log("key=" + e.key + " code=" + e.code + " keyCode=" + e.keyCode);
    }
    let action = null;
    if (is(e, BACK)) action = back;
    else if (is(e, SEARCH)) action = search;
    else if (is(e, LIST)) action = list;
    else if (is(e, HOME)) action = home;
    if (!action) return;
    e.preventDefault();
    e.stopPropagation();
    log(action());
  }, true);

  log("running v1.2");
})();
