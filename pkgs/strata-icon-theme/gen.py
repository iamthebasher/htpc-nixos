#!/usr/bin/env python3
"""Build the "Strata" freedesktop icon theme.

Sources, in priority order:
  1. Strata's bundled Lucide + Catppuccin SVGs and its own extension tables,
     recoloured the way Strata draws them (file_icon_colors = "theme"), so files
     and folders look the same in Strata and everywhere else.
  2. The full Catppuccin vscode-icons set, for file types Strata doesn't cover.
  3. The full Lucide set, for interface icons (actions, status, devices,
     emblems) listed in interface.txt.
Every Lucide-based name also gets a <name>-symbolic variant: strokes outlined
to filled paths (picosvg), because GTK recolours symbolic icons by fill.

usage: gen.py --strata SRC --lucide DIR --ctp DIR --interface FILE
              --mime freedesktop.org.xml --out DIR --accent HEX
              [--fg HEX --warning HEX --danger HEX --success HEX] [--inherits X]
"""
import argparse, glob, json, os, re, xml.etree.ElementTree as ET
from picosvg.svg import SVG

ap = argparse.ArgumentParser()
for a in ("strata", "lucide", "ctp", "interface", "mime", "out", "accent"):
    ap.add_argument("--" + a, required=True)
ap.add_argument("--fg", default="#f2f2f2")
ap.add_argument("--warning", default="#e5e500")
ap.add_argument("--danger", default="#e50000")
ap.add_argument("--success", default="#00d900")
ap.add_argument("--inherits", default="Conflux,hicolor")
args = ap.parse_args()
src, out, accent = args.strata, args.out, args.accent
COLOURS = dict(accent=accent, fg=args.fg, warning=args.warning,
               danger=args.danger, success=args.success)

S_LUCIDE = os.path.join(src, "data/icons/scalable/actions")
S_CTP = os.path.join(src, "data/icons/catppuccin")
RS = os.path.join(src, "src/ui/browser/entry/catppuccin.rs")
LUCIDE = os.path.join(args.lucide, "icons")
CTP = os.path.join(args.ctp, "icons/css-variables")

# Two weights, mirroring Strata's src/assets.rs:
#   small = IconContext::Interface (factor 1.0)     -> sidebars, lists, menus
#   large = IconContext::Grid at 64px (factor 0.5)  -> icon views
# Catppuccin draws 1 unit on a 16 grid; Strata multiplies it by factor * 4/3 on grids.
SIZES = {
    "small": dict(lucide=1.0, ctp=1.0, dirspec="Size=16\nMinSize=8\nMaxSize=32"),
    "large": dict(lucide=0.5, ctp=0.5 * 4 / 3, dirspec="Size=64\nMinSize=33\nMaxSize=512"),
}
SYMBOLIC_SPEC = "Size=16\nMinSize=8\nMaxSize=512"

# --- Lucide: names + deprecated aliases (Lucide 1.x renamed many icons) --------
LUCIDE_ALIAS = {}
for j in glob.glob(os.path.join(LUCIDE, "*.json")):
    name = os.path.basename(j)[:-5]
    for a in json.load(open(j)).get("aliases", []):
        LUCIDE_ALIAS.setdefault(a["name"] if isinstance(a, dict) else a, name)

def lucide_path(name):
    p = os.path.join(LUCIDE, f"{name}.svg")
    if not os.path.exists(p) and name in LUCIDE_ALIAS:
        p = os.path.join(LUCIDE, f"{LUCIDE_ALIAS[name]}.svg")
    if not os.path.exists(p):
        raise SystemExit(f"interface.txt: no Lucide icon named {name!r}")
    return p

def weighted(s, factor):
    s = s.replace('stroke-width="2"', f'stroke-width="{2 * factor:g}"')
    return s.replace('stroke-width="2.7"', f'stroke-width="{2.7 * factor:g}"')

def lucide_full(name, factor, colour):
    """A full-set Lucide icon, stroked in a theme colour."""
    return weighted(open(lucide_path(name)).read().replace("currentColor", colour), factor)

def symbolic(name):
    """Lucide icon outlined to filled paths. Fill is the text colour; GTK
    recolours it anyway, other toolkits show it as-is on a dark theme."""
    s = open(lucide_path(name)).read().replace("currentColor", args.fg)
    return SVG.fromstring(s).topicosvg().tostring(pretty_print=True)

# --- Strata's curated icons (unchanged from the original theme) ---------------
def lucide(name, factor, folder_fill=False):
    s = open(os.path.join(S_LUCIDE, f"strata-{name}.svg")).read()
    for ph in ("#8bc9eb", "#22d3ee", "#2e3436"):
        s = s.replace(ph, accent)
    if folder_fill:
        s = s.replace('fill="none"', f'fill="{accent}" fill-opacity="0.15"', 1)
    return weighted(s, factor)

def catppuccin_svg(s, factor):
    s = re.sub(r"var\(--vscode-ctp-[a-z0-9]+\)", accent, s)
    s = s.replace('fill="none"', f'fill="{accent}" fill-opacity="0.15"')
    if factor != 1.0:
        s = re.sub(r'stroke-width="([0-9.]+)"',
                   lambda m: f'stroke-width="{float(m.group(1)) * factor:g}"', s)
        s = s.replace("<svg ", f'<svg stroke-width="{factor:g}" ', 1)
    return s

# --- Strata's extension / filename tables -----------------------------------
rs = open(RS).read()
consts = dict(re.findall(r'pub const ([A-Z0-9_]+): &str = "([^"]+)";', rs))
def table(name):
    body = rs.split(f"static {name}: &[(&str, &str)] = &[", 1)[1].split("];", 1)[0]
    return {k: consts[v] for k, v in re.findall(r'\("([^"]+)",\s*([A-Z0-9_]+)\)', body)}
EXT, NAMES = table("EXTENSIONS"), table("NAMES")

# Strata's own fallback rules (src/ui/browser/entry.rs icon_for_name), applied
# after the Catppuccin table: images/video/audio/archives/etc. -> Lucide icons.
assets = open(os.path.join(src, "src/assets.rs")).read()
icon_consts = dict(re.findall(r'pub const ([A-Z0-9_]+): &str = "(strata-[^"]+)";', assets))
entry = open(os.path.join(src, "src/ui/browser/entry.rs")).read()
match_body = entry.split("let extension = lowered.rsplit_once", 1)[1].split("_ => icons::", 1)[0]
FALLBACK = {}
for exts, kind, const in re.findall(
        r'Some\(\s*((?:"[^"]+"\s*\|?\s*)+),?\s*\)\s*=>\s*\{?\s*(?:crate::assets::)?(icons|catppuccin)::([A-Z0-9_]+)',
        match_body):
    icon = (icon_consts if kind == "icons" else consts)[const]
    for e in re.findall(r'"([^"]+)"', exts):
        FALLBACK.setdefault(e, icon)

# --- full Catppuccin table (src/defaults/fileIcons.ts) -------------------------
ts = open(os.path.join(args.ctp, "src/defaults/fileIcons.ts")).read()
CTP_EXT, CTP_NAMES = {}, {}
for key, body in re.findall(r"^  '?([\w.+-]+)'?: \{(.*?)^  \},", ts, re.M | re.S):
    if not os.path.exists(os.path.join(CTP, f"{key}.svg")):
        continue
    for field, dest in (("fileExtensions", CTP_EXT), ("fileNames", CTP_NAMES)):
        m = re.search(field + r":\s*\[(.*?)\]", body, re.S)
        if m:
            for v in re.findall(r"'([^']+)'", m.group(1)):
                dest.setdefault(v.lower(), "ctpfull:" + key)

def resolve_ext(e):
    return EXT.get(e) or FALLBACK.get(e) or CTP_EXT.get(e)

def resolve_name(n):
    return NAMES.get(n) or CTP_NAMES.get(n)

def draw(icon, size):
    """strata-ctp-* (Strata's Catppuccin), ctpfull:* (full Catppuccin set),
    or strata-* (Strata's Lucide)."""
    if icon.startswith("ctpfull:"):
        s = open(os.path.join(CTP, icon[8:] + ".svg")).read()
        return catppuccin_svg(s, SIZES[size]["ctp"])
    if icon.startswith("strata-ctp-"):
        s = open(os.path.join(S_CTP, f"{icon}.svg")).read()
        return catppuccin_svg(s, SIZES[size]["ctp"])
    return lucide(icon[len("strata-"):], SIZES[size]["lucide"])

# --- what each standard name is drawn from ------------------------------------
places = {
    "folder": ("folder", True), "inode-directory": ("folder", True),
    "folder-open": ("folder-open", True), "folder-drag-accept": ("folder-open", True),
    "user-home": ("house", False), "folder-home": ("house", False),
    "folder-download": ("download", False), "user-trash": ("trash", False),
    "user-trash-full": ("trash", False), "drive-harddisk": ("hard-drive", False),
    "drive-removable-media": ("hard-drive", False), "media-optical": ("disc", False),
    "network-workgroup": ("network", False), "folder-remote": ("network", False),
    "user-desktop": ("monitor", False), "computer": ("monitor", False),
    "folder-documents": ("file-text", False), "folder-pictures": ("image", False),
    "folder-music": ("music-2", False), "folder-videos": ("video", False),
    "folder-publicshare": ("globe", False), "folder-templates": ("file-plus", False),
}
generic_mime = {
    "text-x-generic": "file-text", "application-x-generic": "file-type",
    "unknown": "file-type", "image-x-generic": "image", "audio-x-generic": "music-2",
    "video-x-generic": "video", "package-x-generic": "file-archive",
    "text-x-script": "file-terminal", "application-x-executable": "file-terminal",
    "x-office-document": "file-text", "x-office-spreadsheet": "file-spreadsheet",
    "x-office-presentation": "presentation", "font-x-generic": "file-type",
    "text-html": "globe", "application-x-addon": "blocks",
}

# interface.txt: <context> <name> <lucide> [colour]
interface = []
for line in open(args.interface):
    f = line.split("#", 1)[0].split()
    if f:
        ctx, name, icon = f[:3]
        colour = f[3] if len(f) > 3 else "accent"
        lucide_path(icon)   # fail early on a bad name
        interface.append((ctx, name, icon, COLOURS[colour]))

# freedesktop mime type -> icon, via its glob patterns
mime_map = {}
ns = {"m": "http://www.freedesktop.org/standards/shared-mime-info"}
for mt in ET.parse(args.mime).getroot().findall("m:mime-type", ns):
    name = mt.get("type").replace("/", "-")
    for g in mt.findall("m:glob", ns):
        pat = g.get("pattern")
        if g.get("case-sensitive") == "true":
            if pat != pat.lower():
                continue          # e.g. *.C is C++, not C; don't fold it onto *.c
        else:
            pat = pat.lower()
        icon = None
        if pat.startswith("*.") and resolve_ext(pat[2:]):
            icon = resolve_ext(pat[2:])
        elif "*" not in pat:
            icon = resolve_name(pat)
        if icon:
            mime_map[name] = icon
            break

# --- write ---------------------------------------------------------------------
CTX_NAME = dict(places="Places", mimetypes="MimeTypes", actions="Actions",
                status="Status", devices="Devices", emblems="Emblems")
dirs = {}
def put(sub, ctx, name, svg, spec):
    d = os.path.join(out, sub, ctx)
    if (sub, ctx) not in dirs:
        os.makedirs(d, exist_ok=True)
        dirs[(sub, ctx)] = spec
    with open(os.path.join(d, name + ".svg"), "w") as fh:
        fh.write(svg)

for size, cfg in SIZES.items():
    for n, (srcname, fill) in places.items():
        put(size, "places", n, lucide(srcname, cfg["lucide"], fill), cfg["dirspec"])
    for n, srcname in generic_mime.items():
        put(size, "mimetypes", n, lucide(srcname, cfg["lucide"]), cfg["dirspec"])
    for n, icon in mime_map.items():
        put(size, "mimetypes", n, draw(icon, size), cfg["dirspec"])
    for ctx, n, icon, colour in interface:
        put(size, ctx, n, lucide_full(icon, cfg["lucide"], colour), cfg["dirspec"])

symbolic_src = [("places", n, s) for n, (s, _) in places.items()]
symbolic_src += [("mimetypes", n, s) for n, s in generic_mime.items()]
symbolic_src += [(ctx, n, icon) for ctx, n, icon, _ in interface]
for ctx, n, icon in symbolic_src:
    put("symbolic", ctx, n + "-symbolic", symbolic(icon), SYMBOLIC_SPEC)

with open(os.path.join(out, "index.theme"), "w") as f:
    f.write("[Icon Theme]\nName=Strata\nComment=Lucide + Catppuccin icons, "
            f"recolored {accent}\nInherits={args.inherits}\n")
    f.write("Directories=" + ",".join(f"{s}/{c}" for s, c in dirs) + "\n\n")
    for (s, c), spec in dirs.items():
        f.write(f"[{s}/{c}]\nContext={CTX_NAME[c]}\nType=Scalable\n{spec}\n\n")

print(f"places: {len(places)}  interface: {len(interface)}  symbolic: {len(symbolic_src)}  "
      f"mime types mapped: {len(mime_map)} "
      f"(strata table {sum(1 for v in mime_map.values() if not v.startswith('ctpfull:'))}, "
      f"full catppuccin {sum(1 for v in mime_map.values() if v.startswith('ctpfull:'))})")
