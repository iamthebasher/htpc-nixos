# Conflux icon theme (not in nixpkgs): the app icons under Strata
# (pkgs/strata-icon-theme inherits it). Same package as Balthasar's.
# To update: change rev, set hash = lib.fakeHash, rebuild, and paste the
# hash from the error.
{ stdenvNoCC, fetchFromGitHub, hicolor-icon-theme, adwaita-icon-theme, kdePackages }:

stdenvNoCC.mkDerivation {
  pname = "conflux-icon-theme";
  version = "unstable-2026-11-14";
  src = fetchFromGitHub {
    owner = "MoshiurRahmanAdib";
    repo = "Conflux-Icon-Theme";
    rev = "f3808414e66ac8d32847c9cdcc6a657b69c6c792";
    hash = "sha256-Ppa+wnTcty93HMROizm0NOr06qUujtJsbW9chiPtryU=";
  };
  # index.theme falls back to these for icons Conflux doesn't have
  propagatedBuildInputs = [
    hicolor-icon-theme
    adwaita-icon-theme
    kdePackages.breeze-icons
  ];
  dontBuild = true;
  dontFixup = true;
  dontWrapQtApps = true; # breeze-icons drags in a Qt hook; nothing to wrap
  dontDropIconThemeCache = true;
  installPhase = ''
    runHook preInstall
    rm -rf .github Workspace images *.md preview.png update.sh .gitignore
    find . -name optimize.sh -delete   # dev-script links into Workspace/
    mkdir -p $out/share/icons/Conflux
    cp -a . $out/share/icons/Conflux/
    runHook postInstall
  '';
}
