# "Strata" icon theme, built by gen.py:
#   - folders and file types: Strata's bundled Lucide + Catppuccin icons and its
#     own extension tables, so they match the file manager exactly; the full
#     Catppuccin set fills in file types Strata doesn't cover
#   - interface icons (actions, status, devices, emblems): full Lucide set,
#     names listed in ./interface.txt, each with a GTK -symbolic variant
# Colours default to Balthasar's theme.nix (accent #00a6b2 etc.). App icons fall
# through to Conflux (pkgs/conflux-icon-theme). Copied from Balthasar's
# /etc/nixos/home/strata-icons; keep the two in sync.
#
# To update Lucide/Catppuccin: change rev, set hash = lib.fakeHash, rebuild,
# copy the real hash from the error.
{ pkgs, lib, strataSrc
, accent ? "#00a6b2", fg ? "#f2f2f2"
, warning ? "#e5e500", danger ? "#e50000", success ? "#00d900"
, inherits ? "Conflux" }:

let
  lucide = pkgs.fetchFromGitHub {          # ISC licence
    owner = "lucide-icons";
    repo = "lucide";
    rev = "1.77.0";
    hash = "sha256-ApK3bmc5s8VQG3ukr8w4J6iewW85rHxOESan1L01W2M=";
  };
  catppuccin = pkgs.fetchFromGitHub {      # MIT licence
    owner = "catppuccin";
    repo = "vscode-icons";
    rev = "v1.26.0";
    hash = "sha256-xzCf3RChPKG8XClKfrKAnNF7tcT6ySdDZUxnasw3JPs=";
  };
  python = pkgs.python3.withPackages (p: [ p.picosvg ]);
in
pkgs.runCommandLocal "strata-icon-theme" { } ''
  ${python}/bin/python3 -I ${./gen.py} \
    --strata ${strataSrc} \
    --lucide ${lucide} \
    --ctp ${catppuccin} \
    --interface ${./interface.txt} \
    --mime ${pkgs.shared-mime-info}/share/mime/packages/freedesktop.org.xml \
    --out $out/share/icons/Strata \
    --accent "${accent}" --fg "${fg}" \
    --warning "${warning}" --danger "${danger}" --success "${success}" \
    --inherits "${inherits}"
  mkdir -p $out/share/licenses/strata-icon-theme
  cp ${lucide}/LICENSE $out/share/licenses/strata-icon-theme/Lucide-ISC.txt
  cp ${catppuccin}/LICENSE $out/share/licenses/strata-icon-theme/Catppuccin-MIT.txt
''
