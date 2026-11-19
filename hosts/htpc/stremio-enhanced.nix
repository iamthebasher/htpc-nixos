# stremio-enhanced 1.2.1, packaged here because the custom-packages flake is
# still on 1.2.0. Stremio Web v5.1 broke 1.2.0: the Enhanced section went
# missing from settings and themes stopped applying. 1.2.1 (2026-11-17) fixes
# that. Copied from custom-packages' packages/stremio-enhanced/default.nix
# with only the version and hash changed. Delete this file and switch
# hosts/htpc/default.nix back to inputs.custom-packages once that flake
# ships >= 1.2.1.
{ lib
, fetchurl
, appimageTools
, ffmpeg
, makeWrapper
}:

let
  pname = "stremio-enhanced";
  version = "1.2.1";
  src = fetchurl {
    url = "https://github.com/REVENGE977/stremio-enhanced/releases/download/v${version}/Stremio.Enhanced-${version}.AppImage";
    # matches the sha256 GitHub publishes for this release asset
    hash = "sha256-rkom93sV6AQVdzddrkK/gBfmN7J+gnMoP1738rpbcM8=";
  };
  appimageContents = appimageTools.extract { inherit pname version src; };
  serverJs = fetchurl {
    url = "https://raw.githubusercontent.com/Stremio/stremio-linux-shell/1021ef7ba75d740f941ff3a1c4c5a5bc5671ac64/data/server.js";
    hash = "sha256-qfj/0cT9TL4dkS9zcNuePdFgXgXqMdr/NH+bpZFF9cg=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraPkgs = pkgs: with pkgs; [
    ffmpeg
  ];

  extraInstallCommands = ''
    if [ -f ${appimageContents}/stremio-enhanced.desktop ]; then
      install -m 444 -D ${appimageContents}/stremio-enhanced.desktop \
        $out/share/applications/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace-fail 'Exec=AppRun --no-sandbox' 'Exec=${pname}' \
        --replace-fail 'Icon=stremio-enhanced' 'Icon=${pname}'
    fi

    if [ -f ${appimageContents}/stremio-enhanced.png ]; then
      install -m 444 -D ${appimageContents}/stremio-enhanced.png \
        $out/share/icons/hicolor/512x512/apps/${pname}.png
    fi

    install -m 444 -D ${serverJs} \
      $out/share/${pname}/streamingserver/server.js

    wrapProgram $out/bin/${pname} \
      --run 'mkdir -p "$HOME/.config/stremio-enhanced/streamingserver"' \
      --run 'test -f "$HOME/.config/stremio-enhanced/streamingserver/server.js" || cp '"${serverJs}"' "$HOME/.config/stremio-enhanced/streamingserver/server.js"' \
      --run 'mkdir -p "$HOME/.config/stremio-enhanced/plugins"'
  '';

  meta = with lib; {
    description = "Stremio Enhanced - Stremio with enhanced features";
    homepage = "https://github.com/REVENGE977/stremio-enhanced";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "stremio-enhanced";
  };
}
