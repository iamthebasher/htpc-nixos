# REVENGE977's Stremio Enhanced on Stremio's Rust Linux shell (GTK4 +
# WebKitGTK + libmpv), built from source. Upstream's only release artifact is
# a "Devel" flatpak bundle, and the author plans to retire the Electron
# stremio-enhanced in favour of this.
#
# Runtime layout (same directories the Electron build uses, so the two share
# plugins, themes and settings.json):
#   ~/.config/stremio-enhanced/plugins, themes, settings.json
#   ~/.config/stremio-enhanced/streamingserver/server.js (seeded by the wrapper)
# The streaming server runs under nodejs; ffmpeg/ffprobe come from PATH, which
# stops the app downloading its own ffmpeg build at first start.
#
# Updating: bump version, set src hash and cargoHash to lib.fakeHash, then
# build once per hash (`nix build .#stremio-linux-shell-enhanced`) and paste
# each "got:" value.
{ lib
, rustPlatform
, fetchFromGitHub
, fetchurl
, pkg-config
, wrapGAppsHook4
, gettext
, glib
, esbuild
, makeShellWrapper
, gtk4
, libadwaita
, webkitgtk_6_0
, mpv-unwrapped
, libepoxy
, glib-networking
, nodejs
, ffmpeg
}:

let
  # Stremio's streaming server, the same file the Electron build used
  # (upstream downloads it at build time; not in the repo).
  serverJs = fetchurl {
    url = "https://raw.githubusercontent.com/Stremio/stremio-linux-shell/1021ef7ba75d740f941ff3a1c4c5a5bc5671ac64/data/server.js";
    hash = "sha256-qfj/0cT9TL4dkS9zcNuePdFgXgXqMdr/NH+bpZFF9cg=";
  };
  appId = "io.github.revenge977.StremioLinuxShellEnhanced";
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stremio-linux-shell-enhanced";
  version = "1.2.2-enhanced.4";

  # The one submodule (flatpak-builder-tools) is only for the flatpak build.
  src = fetchFromGitHub {
    owner = "REVENGE977";
    repo = "stremio-linux-shell";
    tag = finalAttrs.version;
    hash = "sha256-CTkbzr9WGx95CAF1NKOPgYGccdflgdCND4ug0BAwszI=";
  };

  # covers the git dependency (Stremio/libmpv2-rs) pinned in Cargo.lock
  cargoHash = "sha256-c06w4utf3VYyRJSSnkc5kTexDlE1o0Z9wHvpiKv5t8I=";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
    gettext # msgfmt, called by build.rs
    glib # glib-compile-schemas, called by build.rs
    (lib.getDev glib)
    esbuild
    makeShellWrapper # wrapProgramShell, see postFixup
  ];

  buildInputs = [
    gtk4
    libadwaita
    webkitgtk_6_0
    mpv-unwrapped # libmpv
    libepoxy
    # TLS for WebKit's network process. Without it every https:// request
    # fails ("Load failed"): the UI only loads because it comes over plain
    # http from the local streaming server. wrapGAppsHook4 adds it to
    # GIO_EXTRA_MODULES.
    glib-networking
  ];

  # build.rs writes the compiled locales and gsettings schema to these
  # (.cargo/config.toml only sets them when unset). GETTEXT_DIR is also
  # baked into the binary as the runtime locale path. The schema dir is the
  # layout wrapGAppsHook4 adds to XDG_DATA_DIRS.
  env = {
    GETTEXT_DIR = "${placeholder "out"}/share/locale";
    GSETTINGS_SCHEMA_DIR = "${placeholder "out"}/share/gsettings-schemas/${finalAttrs.pname}-${finalAttrs.version}/glib-2.0/schemas";
  };

  postPatch = ''
    # The embedded player loads this file at startup, and the default is the
    # user's ~/.config/mpv/mpv.conf. An mpv.conf with force-window (like
    # files/mpv's) makes libmpv try to open its own window and the app
    # aborts before showing anything. Point it at the app's own directory;
    # a missing file is only a warning. Changeable in the app's preferences.
    substituteInPlace data/${appId}.gschema.xml \
      --replace-fail '"~/.config/mpv/mpv.conf"' '"~/.config/stremio-enhanced/mpv.conf"'

    # Plasma launches DBusActivatable entries over D-Bus, and NixOS doesn't
    # register a package's session services just because it's installed.
    substituteInPlace data/${appId}.desktop \
      --replace-fail 'Exec=stremio %u' 'Exec=${finalAttrs.meta.mainProgram} %u' \
      --replace-fail 'DBusActivatable=true' ""
  '';

  # build.rs runs `npx -y esbuild`, which needs the network. Bundle with
  # nixpkgs' esbuild instead (the TypeScript has no npm imports). With no
  # node on the build PATH, build.rs then keeps this enhanced.js.
  preBuild = ''
    (cd src/app/enhanced && esbuild src/index.ts --bundle --format=iife \
      --loader:.html=text --target=es2020 --outfile=enhanced.js)
  '';

  # the only test looks for server.js on the build machine
  doCheck = false;

  postInstall = ''
    install -Dm644 data/icons/${appId}.svg -t $out/share/icons/hicolor/scalable/apps/
    install -Dm644 data/${appId}.desktop -t $out/share/applications/
    install -Dm644 data/${appId}.metainfo.xml -t $out/share/metainfo/
    install -Dm644 data/stremio.1 $out/share/man/man1/${finalAttrs.meta.mainProgram}.1
  '';

  # wrapGAppsHook4 makes a compiled wrapper, which can't take --run. Let it
  # only collect its arguments, then write a shell wrapper with them plus ours.
  dontWrapGApps = true;

  # Our additions, in order:
  # - PATH: streaming server runtime (node); ffmpeg + ffprobe found on PATH
  # - LD_LIBRARY_PATH: libepoxy is dlopen()ed by name at startup, so it
  #   isn't in the binary's RUNPATH
  # - GSK_RENDERER: from upstream's data/stremio.sh, GSK's default renderer
  #   misbehaves on Nvidia
  # - seed the config dirs and the streaming server script
  postFixup = ''
    wrapProgramShell $out/bin/${finalAttrs.meta.mainProgram} \
      "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ nodejs ffmpeg ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libepoxy ]} \
      --run 'if [ -e /dev/nvidia0 ]; then export GSK_RENDERER="''${GSK_RENDERER:-opengl}"; fi' \
      --run 'mkdir -p "$HOME/.config/stremio-enhanced/streamingserver" "$HOME/.config/stremio-enhanced/plugins"' \
      --run 'test -f "$HOME/.config/stremio-enhanced/streamingserver/server.js" || install -m644 ${serverJs} "$HOME/.config/stremio-enhanced/streamingserver/server.js"'
  '';

  meta = {
    description = "Stremio Enhanced (plugins, themes) on Stremio's native GTK4/WebKit Linux shell";
    homepage = "https://github.com/REVENGE977/stremio-linux-shell";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "stremio-linux-shell-enhanced";
  };
})
