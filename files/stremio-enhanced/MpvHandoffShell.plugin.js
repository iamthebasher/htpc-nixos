/**
 * @name MpvHandoffShell
 * @description Sends playback to the host's mpv instead of the built-in player (stremio-linux-shell enhanced).
 * @version 1.2.0
 * @author asher
 */
// For REVENGE977's Rust stremio-linux-shell (GTK/WebKit + libmpv). The
// Electron stremio-enhanced uses MpvHandoff.plugin.js instead: there Stremio
// plays in an HTML <video>, here it drives an embedded libmpv over IPC.
//
// Stremio Web sends {type: 6, args: ["mpv-command", ["loadfile", url, ...]]}
// to the shell through webkit.messageHandlers.ipc. This catches that
// loadfile, sends the URL to the handoff listener (same one as the Electron
// plugin: services.htpc.media.stremio.mpvHandoff, 127.0.0.1:7777), and
// swallows it so the embedded player never starts. Every other message
// passes through untouched.
(function () {
  const LISTENER = "http://127.0.0.1:7777/play";
  const STATUS = "http://127.0.0.1:7777/status";
  let last = { url: null, at: 0 };
  // "[Plugin]": the shell only forwards tagged console lines to its terminal log
  function log(m) { console.log("[Plugin] [MpvHandoffShell]", m); }

  // true = handled here, don't forward to the shell
  function intercept(msg) {
    let data = msg;
    if (typeof msg === "string") {
      try { data = JSON.parse(msg); } catch (e) { return false; }
    }
    if (!data || data.type !== 6 || !Array.isArray(data.args)) return false;
    const [name, cmd] = data.args;
    if (typeof name === "string" && name.startsWith("mpv-")) log("ipc " + name + " " + (Array.isArray(cmd) ? cmd[0] : cmd));
    if (name !== "mpv-command" || !Array.isArray(cmd) || cmd[0] !== "loadfile") return false;
    const url = cmd[1];
    if (typeof url !== "string" || !/^https?:\/\//.test(url)) return false;

    // the same message can pass through more than one wrapped layer below
    const now = Date.now();
    if (url === last.url && now - last.at < 5000) return true;
    // Stremio follows a direct (debrid) link with a second loadfile of the
    // same video through its streaming server (:11470, forceTranscoding), a
    // few seconds later. Keep mpv on the direct link; still swallow this one
    // so the embedded player doesn't start. A :11470 URL on its own (plain
    // torrents) is handed off as normal.
    if (url.indexOf("127.0.0.1:11470/") !== -1 && last.url && last.url.indexOf("127.0.0.1:11470/") === -1 && now - last.at < 15000) {
      log("skip streaming-server copy of the direct link");
      return true;
    }
    last = { url, at: now };

    log("HANDOFF " + url);
    fetch(LISTENER + "?url=" + encodeURIComponent(url), { mode: "no-cors" })
      .then(watchPlayer, function () {});
    return true;
  }

  // Stremio sits on its (empty) player screen while mpv plays. Once mpv
  // closes, step back to the show page, ready for another episode or source.
  // The listener's /status says whether mpv is still open.
  let watch = null;
  function watchPlayer() {
    clearInterval(watch);
    let failures = 0;
    watch = setInterval(function () {
      fetch(STATUS, { cache: "no-store" })
        .then(function (r) { return r.json(); })
        .then(function (s) {
          failures = 0;
          if (s.playing) return;
          clearInterval(watch);
          if (window.location.hash.startsWith("#/player")) {
            log("mpv closed, leaving the player");
            history.back();
          }
        })
        .catch(function () { if (++failures >= 5) clearInterval(watch); }); // old listener without /status
    }, 1000);
  }

  function wrap(obj, key, label) {
    try {
      const orig = obj && obj[key];
      if (typeof orig !== "function" || orig.__mpvHandoff) return;
      const wrapped = function (msg) {
        try { if (intercept(msg)) return; } catch (e) {}
        return orig.apply(this, arguments);
      };
      wrapped.__mpvHandoff = true;
      obj[key] = wrapped;
      log("hooked " + label);
    } catch (e) {
      log("could not hook " + label + ": " + e);
    }
  }

  // The preload looks the WebKit handler up on every call, so wrapping it
  // catches everything. The others cover references captured earlier.
  function hookAll() {
    const h = globalThis.webkit && globalThis.webkit.messageHandlers;
    wrap(h && h.ipc, "postMessage", "webkit ipc");
    wrap(window.ipc, "postMessage", "window.ipc");
    wrap(window.qt && window.qt.webChannelTransport, "send", "qt transport");
    wrap(globalThis.chrome && globalThis.chrome.webview, "postMessage", "chrome.webview");
  }
  hookAll();
  log("running v1.2");
})();
