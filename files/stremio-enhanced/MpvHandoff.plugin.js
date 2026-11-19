/**
 * @name MpvHandoff
 * @description Hands streams to host mpv; kills Stremio's internal transcode.
 * @version 3.4.0
 * @author asher
 */
(function () {
  const LISTENER = "http://127.0.0.1:7777/play";
  const STATUS = "http://127.0.0.1:7777/status";
  let current = null;
  function log(m){ console.log("[MpvHandoff]", m); }
  log("running v3.4 (cut internal transcode, leave player when mpv closes)");

  function sourceOf(u) {
    if (!u || u.indexOf(":11470/") === -1) return null;
    var m = u.match(/[?&]mediaURL=([^&]+)/);
    if (m) return decodeURIComponent(m[1]);
    if (/\/[a-f0-9]{40}\/\d+\??/i.test(u)) return u;
    return null;
  }
  function consider(u) {
    var src = sourceOf(u);
    if (!src || src === current) return;
    current = src;
    log("HANDOFF " + src);
    fetch(LISTENER + "?url=" + encodeURIComponent(src), { mode: "no-cors" })
      .then(watchPlayer, function(){});
  }

  // Once mpv closes, step back out of Stremio's player screen to the show
  // page. The listener's /status says whether mpv is still open.
  var watch = null;
  function watchPlayer() {
    clearInterval(watch);
    var failures = 0;
    watch = setInterval(function () {
      fetch(STATUS, { cache: "no-store" })
        .then(function (r) { return r.json(); })
        .then(function (s) {
          failures = 0;
          if (s.playing) return;
          clearInterval(watch);
          if (window.location.hash.indexOf("#/player") === 0) {
            log("mpv closed, leaving the player");
            history.back();
          }
        })
        .catch(function () { if (++failures >= 5) clearInterval(watch); }); // old listener without /status
    }, 1000);
  }

  var of = window.fetch;
  window.fetch = function (input) {
    try { consider(typeof input === "string" ? input : (input && input.url)); } catch (e) {}
    return of.apply(this, arguments);
  };
  var oopen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (method, url) {
    try { consider(url); } catch (e) {}
    return oopen.apply(this, arguments);
  };

  setInterval(function () {
    document.querySelectorAll("video").forEach(function (v) {
      try {
        v.muted = true;
        if (!v.paused) v.pause();
        // Cut the source so Stremio's server stops transcoding for this hidden player.
        var s = v.currentSrc || v.src || "";
        if (s.indexOf(":11470/") !== -1) {
          v.removeAttribute("src");
          v.load();
        }
      } catch (e) {}
    });
    if (!document.querySelector("video")) current = null;
  }, 500);
})();
