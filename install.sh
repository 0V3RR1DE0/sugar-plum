#!/usr/bin/env bash
# Sugar Plum — reversible CachyOS/Arch KDE rice.
# User-level by default. Login + Limine live behind `--system` (root).
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE="$REPO/state"
ORIGINALS="$REPO/backups/originals"
ORIG="$STATE/originals.tsv"
NEW="$STATE/new.tsv"
BLOCKS="$STATE/blocks.tsv"
CAT_CACHE="$HOME/.cache/sugar-plum/catppuccin-kde"
PAP_CACHE="$HOME/.local/share/sugar-plum/papirus"
PAP_SCRIPT="$HOME/.local/bin/papirus-folders"
SAT_URL="https://github.com/Satty-org/Satty/releases/download/v0.22.0/satty-x86_64-unknown-linux-gnu.tar.gz"
SAT_SHA256="eb7a028c4a5ce331c2f355add8e2b807a7d697fe4495f7e1965786a4f6bcd5b8"
PAP_SCRIPT_SHA256="b30a6848a00690302accffc050549218b0b114d3178b28bd3a16891817821b06"
CAT_COMMIT="6606b5179cfc1e9ba5c3b6b70e15c468e2dddca2"
LIBEXEC="$HOME/.local/share"

mkdir -p "$STATE" "$ORIGINALS" "$HOME/.local/bin"
touch "$ORIG" "$NEW" "$BLOCKS"

say()  { printf '\033[38;5;218m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[38;5;150m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[38;5;222m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[38;5;211m✗\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

backup_once() {
  local path="$1"
  if cut -f1 "$NEW" 2>/dev/null | grep -Fxq -- "$path"; then return 0; fi
  if cut -f1 "$ORIG" 2>/dev/null | grep -Fxq -- "$path"; then return 0; fi
  local key; key="$(printf '%s' "$path" | sed 's|/|__|g')"
  if [ -f "$path" ] || [ -L "$path" ]; then
    cp -a -- "$path" "$ORIGINALS/$key"
    printf '%s\tbackup\n' "$path" >> "$ORIG"
    say "backup $path"
  else
    printf '%s\tabsent\n' "$path" >> "$ORIG"
  fi
}

track_new() {
  local path="$1" kind="${2:-file}"
  if cut -f1 "$NEW" 2>/dev/null | grep -Fxq -- "$path"; then return 0; fi
  printf '%s\t%s\n' "$path" "$kind" >> "$NEW"
}

link_file() {
  local src="$1" dest="$2"
  backup_once "$dest"
  mkdir -p -- "$(dirname -- "$dest")"
  # ln -sfn nests inside an existing real directory; replace it instead.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    rm -rf -- "$dest"
  fi
  ln -sfn -- "$src" "$dest"
  track_new "$dest" symlink
}

copy_new() {
  local src="$1" dest="$2" mode="${3:-644}"
  if cut -f1 "$NEW" 2>/dev/null | grep -Fxq -- "$dest"; then
    install -Dm"$mode" -- "$src" "$dest"
  else
    backup_once "$dest"
    install -Dm"$mode" -- "$src" "$dest"
    track_new "$dest" file
  fi
}

block_set() {
  local file="$1" tag="$2" content="$3" where="${4:-bottom}"
  backup_once "$file"
  mkdir -p -- "$(dirname -- "$file")"
  [ -f "$file" ] || : > "$file"
  local tmp; tmp="$(mktemp)"
  printf '%s\n' "$content" > "$tmp"
  python3 - "$file" "$tag" "$tmp" "$where" <<'PY'
import sys, pathlib
p, tag, content_path, where = sys.argv[1:5]
path = pathlib.Path(p)
text = path.read_text() if path.exists() else ""
start, end = f"# >>> {tag} >>>", f"# <<< {tag} <<<"
if start in text and end in text:
    a = text.index(start); b = text.index(end) + len(end)
    text = (text[:a] + text[b:]).lstrip("\n")
block = start + "\n" + pathlib.Path(content_path).read_text().rstrip("\n") + "\n" + end + "\n"
lines = text.splitlines()
if where == "top":
    # keep the first two comment lines of config files that have a header
    at = 2 if len(lines) >= 2 and lines[0].startswith("#") and lines[1].startswith("#") else 0
    text = "\n".join(lines[:at]) + ("\n\n" if at else "") + block + "\n".join(lines[at:])
else:
    text = text.rstrip() + "\n\n" + block
path.write_text(text)
PY
  rm -f "$tmp"
  cut -f1 "$BLOCKS" 2>/dev/null | grep -Fxq -- "$file" || printf '%s\n' "$file" >> "$BLOCKS"
  ok "block $file ($tag)"
}

set_ini_key() {
  local file="$1" key="$2" value="$3"
  backup_once "$file"
  python3 - "$file" "$key" "$value" <<'PY'
import sys, re, pathlib
p, key, value = sys.argv[1:4]
path = pathlib.Path(p)
text = path.read_text() if path.exists() else ""
pat = re.compile(rf'(?m)^{re.escape(key)}\s*=.*$')
line = f'{key} = {value}'
text = pat.sub(line, text, count=1) if pat.search(text) else text.rstrip() + "\n" + line + "\n"
path.write_text(text)
PY
}

install_fonts() {
  local dest="$HOME/.local/share/fonts/SugarPlum"
  mkdir -p "$dest"
  install -m644 "$REPO"/assets/fonts/Nunito*.ttf "$dest"/
  track_new "$dest" dir
  have fc-cache && fc-cache -f >/dev/null 2>&1 || true
  ok "Nunito installed"
}

install_satty() {
  local bin="$HOME/.local/bin/satty"
  if [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -q '0\.22\.0'; then
    ok "satty already installed"
    return
  fi
  local tmp; tmp="$(mktemp -d)"
  say "downloading satty"
  curl -fsSL "$SAT_URL" -o "$tmp/satty.tar.gz" || die "satty download failed"
  printf '%s  %s\n' "$SAT_SHA256" "$tmp/satty.tar.gz" | sha256sum -c - >/dev/null \
    || die "satty checksum mismatch"
  if tar -tzf "$tmp/satty.tar.gz" | grep -qE '(^/|(^|/)\.\.(/|$))'; then
    die "satty archive contains unsafe paths"
  fi
  tar xzf "$tmp/satty.tar.gz" -C "$tmp" --no-same-owner --no-same-permissions
  install -Dm755 "$tmp/satty" "$bin"
  track_new "$bin" file
  rm -rf "$tmp"
  ok "satty installed"
}

install_papirus() {
  local theme="$PAP_CACHE/Papirus-Dark"
  if [ ! -d "$PAP_CACHE/.git" ] && [ -d "$HOME/.cache/sugar-plum/papirus/.git" ]; then
    say "moving Papirus out of the cache"
    mkdir -p "$(dirname "$PAP_CACHE")"
    mv "$HOME/.cache/sugar-plum/papirus" "$PAP_CACHE"
  fi
  if [ ! -d "$PAP_CACHE/.git" ]; then
    say "fetching Papirus-Dark"
    git clone --depth 1 --filter=blob:none --sparse -q https://github.com/PapirusDevelopmentTeam/papirus-icon-theme "$PAP_CACHE" || die "Papirus clone failed"
    git -C "$PAP_CACHE" sparse-checkout set Papirus-Dark Papirus/32x32 Papirus/48x48 Papirus/64x64
  fi
  [ -d "$theme" ] || die "Papirus-Dark checkout missing"
  track_new "$PAP_CACHE" dir

  local pink="$theme/48x48/places/folder-cat-mocha-pink.svg"
  if [ ! -e "$pink" ]; then
    say "adding candy folder assets"
    for size in 22x22 24x24 32x32 48x48 64x64; do
      mkdir -p "$theme/$size/places"
      cp "$REPO"/assets/papirus-pink/"$size"/places/* "$theme/$size/places/" 2>/dev/null || true
    done
  fi

  if ! printf '%s  %s\n' "$PAP_SCRIPT_SHA256" "$PAP_SCRIPT" | sha256sum -c - >/dev/null 2>&1; then
    local ptmp; ptmp="$(mktemp)"
    curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders -o "$ptmp" || die "papirus-folders download failed"
    printf '%s  %s\n' "$PAP_SCRIPT_SHA256" "$ptmp" | sha256sum -c - >/dev/null \
      || die "papirus-folders checksum mismatch"
    install -Dm755 "$ptmp" "$PAP_SCRIPT"
    rm -f "$ptmp"
    track_new "$PAP_SCRIPT" file
  fi

  backup_once "$HOME/.local/share/icons/Papirus-Dark"
  mkdir -p "$HOME/.local/share/icons"
  if [ -e "$HOME/.local/share/icons/Papirus-Dark" ] && [ ! -L "$HOME/.local/share/icons/Papirus-Dark" ]; then
    rm -rf "$HOME/.local/share/icons/Papirus-Dark"
  fi
  ln -sfn "$theme" "$HOME/.local/share/icons/Papirus-Dark"
  track_new "$HOME/.local/share/icons/Papirus-Dark" symlink
  find "$PAP_CACHE" -name icon-theme.cache -delete 2>/dev/null || true
  "$PAP_SCRIPT" -C cat-mocha-pink --theme Papirus-Dark >/dev/null 2>&1 || warn "folder color apply failed"
  ok "Papirus-Dark + candy folders"
}


install_catppuccin() {
  if [ ! -d "$CAT_CACHE/.git" ]; then
    say "fetching Catppuccin KDE"
    mkdir -p "$CAT_CACHE"
    git -C "$CAT_CACHE" init -q
    git -C "$CAT_CACHE" remote get-url origin >/dev/null 2>&1 \
      || git -C "$CAT_CACHE" remote add origin https://github.com/catppuccin/kde
  fi
  git -C "$CAT_CACHE" fetch --depth 1 -q origin "$CAT_COMMIT" || die "Catppuccin KDE fetch failed"
  git -C "$CAT_CACHE" checkout -q FETCH_HEAD || die "Catppuccin KDE checkout failed"
  backup_once "$HOME/.config/kwinrc"
  ( cd "$CAT_CACHE" && ./install.sh -q -n 1 3 2 auto ) || die "Catppuccin KDE installer failed"
  track_new "$HOME/.local/share/color-schemes/CatppuccinMochaPink.colors" file
  track_new "$HOME/.local/share/aurorae/themes/CatppuccinMocha-Classic" dir
  track_new "$HOME/.local/share/plasma/look-and-feel/Catppuccin-Mocha-Pink" dir
  ok "Catppuccin Mocha Pink + Classic"
}

install_cursor() {
  local dest="$HOME/.local/share/icons/catppuccin-mocha-pink-cursors"
  backup_once "$HOME/.config/kcminputrc"
  backup_once "$dest"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then rm -rf "$dest"; fi
  link_file "$REPO/assets/cursors/catppuccin-mocha-pink-cursors" "$dest"
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme catppuccin-mocha-pink-cursors
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 24
  command -v plasma-apply-cursortheme >/dev/null 2>&1 && plasma-apply-cursortheme catppuccin-mocha-pink-cursors >/dev/null 2>&1 || true
  ok "Catppuccin pink cursor"
}

apply_kde() {
  local f
  for f in kdeglobals kwinrc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc kglobalshortcutsrc; do
    backup_once "$HOME/.config/$f"
  done

  install_fonts
  install_papirus
  install_catppuccin
  install_cursor

  mkdir -p "$HOME/.local/share/color-schemes"
  copy_new "$REPO/config/kde/SugarPlum.colors" "$HOME/.local/share/color-schemes/SugarPlum.colors"
  link_file "$REPO/config/icons/SugarPlum" "$HOME/.local/share/icons/SugarPlum"

  kwriteconfig6 --file kdeglobals --group General --key AccentColor "255,179,217"
  kwriteconfig6 --file kdeglobals --group Icons --key Theme SugarPlum
  kwriteconfig6 --file kdeglobals --group General --key font "Nunito,10,-1,5,50,0,0,0,0,0"
  kwriteconfig6 --file kdeglobals --group General --key fixed "FiraCode Nerd Font,10,-1,5,50,0,0,0,0,0"
  kwriteconfig6 --file kdeglobals --group General --key menuFont "Nunito,10,-1,5,50,0,0,0,0,0"
  kwriteconfig6 --file kdeglobals --group General --key toolBarFont "Nunito,10,-1,5,50,0,0,0,0,0"
  kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "Nunito,8,-1,5,50,0,0,0,0,0"
  kwriteconfig6 --file kdeglobals --group WM --key activeFont "Nunito,10,-1,5,50,0,0,0,0,0"
  kwriteconfig6 --file kdeglobals --group WM --key inactiveFont "Nunito,10,-1,5,50,0,0,0,0,0"

  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto true
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ""
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX
  link_file "$REPO/config/kwin/decorations/org.sugarplum.decoration" \
    "$HOME/.local/share/kwin/decorations/org.sugarplum.decoration"
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme org.sugarplum.decoration
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
  local e
  for e in blur glide magiclamp slidingpopups; do
    kwriteconfig6 --file kwinrc --group Plugins --key "${e}Enabled" true
  done
  kwriteconfig6 --file kwinrc --group Plugins --key squashEnabled false
  kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled false
  kwriteconfig6 --file kwinrc --group Effect-blur --key blurStrength 7
  kwriteconfig6 --file kwinrc --group Effect-blur --key noiseStrength 3

  plasma-apply-colorscheme SugarPlum >/dev/null 2>&1 || warn "could not apply Sugar Plum color scheme"
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true

  mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  copy_new "$REPO/config/gtk/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
  copy_new "$REPO/config/gtk/settings-4.ini" "$HOME/.config/gtk-4.0/settings.ini"
  ok "KDE theme, fonts, window buttons, effects"
}

apply_shells() {
  backup_once "$HOME/.config/nushell/config.nu"
  backup_once "$HOME/.config/ghostty/config"
  backup_once "$HOME/.config/btop/btop.conf"
  backup_once "$HOME/.config/bat/config"

  link_file "$REPO/config/nushell/sugar-plum.nu" "$HOME/.config/nushell/sugar-plum.nu"
  link_file "$REPO/config/fish/conf.d/90-sugar-plum.fish" "$HOME/.config/fish/conf.d/90-sugar-plum.fish"
  link_file "$REPO/config/ghostty/sugar-plum.conf" "$HOME/.config/ghostty/sugar-plum.conf"
  link_file "$REPO/config/btop/themes/sugar-plum.theme" "$HOME/.config/btop/themes/sugar-plum.theme"
  link_file "$REPO/config/bat/themes/Sugar Plum.tmTheme" "$HOME/.config/bat/themes/Sugar Plum.tmTheme"
  link_file "$REPO/config/nvim/sugar-plum.lua" "$HOME/.config/nvim/lua/plugins/sugar-plum.lua"
  link_file "$REPO/config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

  block_set "$HOME/.config/nushell/config.nu" sugar-plum "source $HOME/.config/nushell/sugar-plum.nu" bottom
  block_set "$HOME/.config/ghostty/config" sugar-plum "config-file = sugar-plum.conf" bottom

  set_ini_key "$HOME/.config/btop/btop.conf" color_theme '"sugar-plum"'

  if ! cut -f1 "$NEW" 2>/dev/null | grep -Fxq "$HOME/.config/bat/config"; then
    backup_once "$HOME/.config/bat/config"
    printf -- '--theme="Sugar Plum"\n' > "$HOME/.config/bat/config"
    track_new "$HOME/.config/bat/config" file
  fi
  have bat && bat cache --build >/dev/null 2>&1 || true
  ok "Nu, fish, Ghostty, btop, bat, fastfetch, Neovim"
}

apply_scripts() {
  chmod +x "$REPO/bin/7z-menu" "$REPO/bin/screenshot"
  link_file "$REPO/bin/7z-menu" "$HOME/.local/bin/sugar-7z"
  link_file "$REPO/bin/7z-gui" "$HOME/.local/bin/sugar-7z-gui"
  link_file "$REPO/bin/screenshot" "$HOME/.local/bin/sugar-screenshot"

  mkdir -p "$HOME/.local/share/kio/servicemenus" "$HOME/.local/share/applications"
  # Retire the old pre-repo 7-Zip menu; it duplicated the Sugar Plum actions.
  local stale="$HOME/.local/share/kio/servicemenus/7z-extract.desktop"
  [ -f "$stale" ] && mv -f -- "$stale" "$stale.disabled"
  local f dest
  for f in "$REPO"/config/servicemenus/*.desktop; do
    dest="$HOME/.local/share/kio/servicemenus/$(basename "$f")"
    backup_once "$dest"
    sed "s|@BIN@|$HOME/.local/bin/sugar-7z|g; s|@GUI@|$HOME/.local/bin/sugar-7z-gui|g" "$f" > "$dest"
    chmod 755 "$dest"
    track_new "$dest" file
  done
  for f in "$REPO"/config/applications/*.desktop; do
    dest="$HOME/.local/share/applications/$(basename "$f")"
    backup_once "$dest"
    sed "s|@BIN@|$HOME/.local/bin/sugar-screenshot|g" "$f" > "$dest"
    track_new "$dest" file
  done

  # Use KConfig instead of rewriting the whole file with configparser.
  # Keep Spectacle's native region action as a fallback on a different chord.
  kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key _launch none
  kwriteconfig6 --file kglobalshortcutsrc --group services --group org.kde.spectacle.desktop --key RectangularRegionScreenShot "Meta+Shift+Print"
  while IFS='|' read -r file key default label; do
    kwriteconfig6 --file kglobalshortcutsrc --group services --group "$file" --key _launch "$key,$default,$label"
  done <<'EOF'
sugar-screenshot-region.desktop|Print|Print|Sugar Screenshot (Region)
sugar-screenshot-full.desktop|Shift+Print|Shift+Print|Sugar Screenshot (Full Screen)
sugar-screenshot-window.desktop|Alt+Print|Alt+Print|Sugar Screenshot (Window)
EOF
  have kbuildsycoca6 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
  # Best-effort live registration; a relogin still guarantees it.
  if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
      --method org.kde.KGlobalAccel.setShortcut \
      "['org.kde.spectacle.desktop', 'RectangularRegionScreenShot']" "[318767113]" 1 >/dev/null 2>&1 || true
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
      --method org.kde.KGlobalAccel.setShortcut \
      "['sugar-screenshot-region.desktop', '_launch']" "[16777225]" 1 >/dev/null 2>&1 || true
  fi
  ok "screenshot + 7z actions, shortcuts (relogin guarantees activation)"
}

apply_panel() {
  local applet="$LIBEXEC/plasma/plasmoids/org.sugarplum.dots"
  link_file "$REPO/config/plasma/org.sugarplum.dots" "$applet"

  if ! pgrep -x plasmashell >/dev/null 2>&1; then
    warn "plasmashell is not running; skipping panel surgery"
    return
  fi
  say "swapping task manager for Sugar Dots"
  systemctl --user stop plasma-plasmashell >/dev/null 2>&1 || true
  sleep 1
  if ! python3 - "$HOME" <<'PY'
import sys, pathlib, configparser
home = pathlib.Path(sys.argv[1])
p = home/".config/plasma-org.kde.plasma.desktop-appletsrc"
c = configparser.RawConfigParser(strict=False); c.optionxform = str
c.read(p)
# Kickoff icon + compact clock for the found applets
for s in list(c.sections()):
    if c.has_option(s, "plugin") and c.get(s, "plugin") == "org.kde.plasma.kickoff":
        g = s + "][Configuration][General"
        if not c.has_section(g): c.add_section(g)
        c.set(g, "icon", "sugar-plum-menu")
    if c.has_option(s, "plugin") and c.get(s, "plugin") == "org.kde.plasma.digitalclock":
        g = s + "][Configuration][General"
        if not c.has_section(g): c.add_section(g)
        c.set(g, "showDate", "false")
        c.set(g, "fontSize", "9")

panels = []
for s in c.sections():
    if s.endswith("]") and c.has_option(s, "plugin") and c.get(s, "plugin") == "org.kde.panel":
        panels.append(s)
target = None
for s in c.sections():
    if c.has_option(s, "plugin") and c.get(s, "plugin") == "org.kde.plasma.icontasks":
        target = s; break
if target is None:
    for s in c.sections():
        if c.has_option(s, "plugin") and c.get(s, "plugin") == "org.sugarplum.dots":
            target = s; break
if target is None:
    sys.exit(2)
already_dots = c.get(target, "plugin") == "org.sugarplum.dots"
c.set(target, "plugin", "org.sugarplum.dots")
applet_id = target.rsplit("][", 1)[-1]
# Only clear the applet configuration when converting from icontasks.
# Clearing it on every apply wipes the pinned Launchers list.
if not already_dots:
    for s in list(c.sections()):
        if s.startswith(target + "][Configuration"):
            c.remove_section(s)
panel_section = panels[0] if panels else None
parts = target.rsplit("][", 2)
if len(parts) == 3:
    candidate = parts[0] + "]"
    if candidate in panels:
        panel_section = candidate
# remove extra dots applets (e.g. a test one), keep target
for s in list(c.sections()):
    if c.has_option(s, "plugin") and c.get(s, "plugin") == "org.sugarplum.dots" and s != target:
        extra = s.rsplit("][", 1)[-1]
        c.remove_section(s)
        for t in list(c.sections()):
            if t.startswith(s + "]["):
                c.remove_section(t)
        if panel_section:
            g = panel_section + "][General"
            if c.has_option(g, "AppletOrder"):
                order = [x for x in c.get(g, "AppletOrder").split(";") if x != extra]
                c.set(g, "AppletOrder", ";".join(order))
if panel_section:
    g = panel_section + "][General"
    if not c.has_option(g, "AppletOrder"):
        c.set(g, "AppletOrder", applet_id)
    elif applet_id not in c.get(g, "AppletOrder").split(";"):
        c.set(g, "AppletOrder", c.get(g, "AppletOrder").rstrip(";") + ";" + applet_id)
with p.open("w") as f: c.write(f, space_around_delimiters=False)
print("panel-ok")
PY
  then
    warn "no panel task manager found; leaving the panel alone"
  fi
  systemctl --user start plasma-plasmashell >/dev/null 2>&1 || true
  sleep 5

  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
  var ps = panels();
  for (var i=0;i<ps.length;i++) {
    ps[i].floating = false;
    ps[i].height = 40;
    ps[i].lengthMode = "fill";
    ps[i].opacity = "translucent";
  }
  print("panel-style");' >/dev/null 2>&1 || warn "could not set panel style"

  if qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
      var p=panels()[0]; var ws=p.widgets(); var found=false;
      for (var i=0;i<ws.length;i++) { if (ws[i].type === "org.sugarplum.dots") found=true; }
      print(found ? "dots-ok" : "dots-missing");' 2>/dev/null | grep -q dots-ok; then
    ok "Sugar Dots taskbar loaded"
  else
    warn "Sugar Dots did not load; panel may need a logout"
  fi
}

apply_wallpaper() {
  local build="$HOME/.cache/sugar-plum/aurora-build"
  local module="$HOME/.local/lib/qt6/qml/org/sugarplum/cursor"
  if ! command -v cmake >/dev/null 2>&1 || ! pkg-config --exists Qt6Quick 2>/dev/null; then
    warn "Qt6 build tools missing; falling back to the static CachyOS wallpaper"
    have plasma-apply-wallpaperimage && plasma-apply-wallpaperimage -f preserveAspectCrop /usr/share/wallpapers/cachyos-wallpapers/north.png >/dev/null 2>&1 || true
    return 0
  fi
  say "building Sugar Plum Aurora wallpaper"
  rm -rf "$module"
  cmake -S "$REPO/config/plasma/org.sugarplum.aurora/plugin" -B "$build" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/.local" >/dev/null 2>&1 || { warn "cursor helper configure failed"; return 0; }
  cmake --build "$build" -j"$(nproc 2>/dev/null || echo 2)" >/dev/null 2>&1 || { warn "cursor helper build failed"; return 0; }
  cmake --install "$build" >/dev/null 2>&1 || { warn "cursor helper install failed"; return 0; }
  track_new "$module" dir
  link_file "$REPO/config/plasma-workspace/env/sugar-plum-qml.sh" \
    "$HOME/.config/plasma-workspace/env/sugar-plum-qml.sh"
  link_file "$REPO/config/plasma/org.sugarplum.aurora" \
    "$HOME/.local/share/plasma/wallpapers/org.sugarplum.aurora"
  systemctl --user set-environment QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}" 2>/dev/null || true
  if pgrep -x plasmashell >/dev/null 2>&1; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
      'var ds=desktops(); for(var i=0;i<ds.length;i++){ ds[i].wallpaperPlugin="org.sugarplum.aurora"; } print("wall-ok");' >/dev/null 2>&1 \
      && ok "animated Aurora wallpaper" || warn "could not select Aurora wallpaper"
  fi
}

status() {
  printf '%-38s %s\n' "repo" "$REPO"
  for p in \
    "$HOME/.local/share/color-schemes/SugarPlum.colors" \
    "$HOME/.local/share/icons/Papirus-Dark" \
    "$HOME/.local/share/plasma/plasmoids/org.sugarplum.dots" \
    "$HOME/.local/share/kwin/decorations/org.sugarplum.decoration" \
    "$HOME/.local/bin/sugar-7z" "$HOME/.local/bin/sugar-7z-gui" "$HOME/.local/bin/sugar-screenshot" \
    "$HOME/.local/share/icons/SugarPlum-Desktop" \
    "$HOME/.config/plasma-workspace/env/sugar-plum-qml.sh" \
    "$HOME/.config/fish/conf.d/90-sugar-plum.fish" \
    "$HOME/.config/nushell/sugar-plum.nu" \
    "$HOME/.config/ghostty/sugar-plum.conf" \
    "$HOME/.config/btop/themes/sugar-plum.theme" \
    "$HOME/.config/nvim/lua/plugins/sugar-plum.lua" \
    "$HOME/.local/share/plasma/wallpapers/org.sugarplum.aurora" \
    "$HOME/.local/lib/qt6/qml/org/sugarplum/cursor"; do
    # -e follows links, so a dangling symlink is reported missing.
    [ -e "$p" ] && printf '%-38s ok\n' "${p#$HOME/}" || printf '%-38s missing\n' "${p#$HOME/}"
  done
  printf '%-38s %s\n' "color scheme" "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || true)"
  printf '%-38s %s\n' "icon theme" "$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || true)"
  printf '%-38s %s\n' "font" "$(kreadconfig6 --file kdeglobals --group General --key font 2>/dev/null || true)"
  printf '%-38s %s\n' "bat theme" "$(bat --list-themes 2>/dev/null | grep -Fqx 'Sugar Plum' && echo ok || echo missing)"
  printf '%-38s %s\n' "wallpaper plugins" "$(grep '^wallpaperplugin=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | cut -d= -f2 | sort -u | tr '\n' ' ' || true)"
  printf '%-38s %s\n' "system step" "$([ -e "$REPO/state/system-applied" ] && echo applied || echo 'not applied (needs sudo)')"
}

revert_all() {
  "$REPO/bin/desktop-icons" revert 2>/dev/null || true
  say "reverting Sugar Plum (user level)"
  # Plasma holds appletsrc in memory and rewrites it on restart.
  systemctl --user stop plasma-plasmashell >/dev/null 2>&1 || true
  trap 'systemctl --user start plasma-plasmashell >/dev/null 2>&1 || true' EXIT
  local file path kind how key real
  if [ -f "$BLOCKS" ]; then
    while IFS= read -r file; do
      [ -f "$file" ] || continue
      python3 - "$file" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); text = p.read_text() if p.exists() else ""
start, end = "# >>> sugar-plum >>>", "# <<< sugar-plum <<<"
if start in text and end in text:
    a = text.index(start); b = text.index(end) + len(end)
    p.write_text((text[:a] + text[b:]).lstrip("\n"))
PY
    done < "$BLOCKS"
  fi

  if [ -f "$NEW" ]; then
    tac "$NEW" 2>/dev/null | while IFS=$'\t' read -r path kind; do
      [ -n "$path" ] || continue
      real="$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")"
      case "$real" in "$HOME"/*) ;; *) warn "refusing to remove $path"; continue ;; esac
      # A stale record must never turn into deleting real user data.
      if [ "$kind" = "symlink" ] && [ -d "$path" ] && [ ! -L "$path" ]; then
        warn "not removing $path: recorded as symlink but is a directory"
        continue
      fi
      if [ "$kind" = "dir" ] && [ ! -L "$path" ]; then
        rm -rf -- "$path" || warn "could not remove $path"
      else
        rm -f -- "$path" || warn "could not remove $path"
      fi
    done
  fi

  if [ -f "$ORIG" ]; then
    tac "$ORIG" 2>/dev/null | while IFS=$'\t' read -r path how; do
      [ -n "$path" ] || continue
      real="$(realpath -m -- "$path" 2>/dev/null || printf '%s' "$path")"
      case "$real" in "$HOME"/*) ;; *) warn "refusing to restore $path"; continue ;; esac
      if [ "$how" = "backup" ]; then
        key="$(printf '%s' "$path" | sed 's|/|__|g')"
        [ -e "$ORIGINALS/$key" ] || continue
        mkdir -p -- "$(dirname -- "$path")"
        rm -rf -- "$path"
        cp -a -- "$ORIGINALS/$key" "$path" || warn "could not restore $path"
      elif [ "$how" = "absent" ]; then
        if [ -L "$path" ] || [ -f "$path" ]; then rm -f -- "$path"; fi
      fi
    done
  fi

  # kdeglobals and kwinrc are restored from their originals above; do not
  # overwrite the user's pre-rice look with hardcoded Breeze values.
  have kbuildsycoca6 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
  have bat && bat cache --build >/dev/null 2>&1 || true
  systemctl --user start plasma-plasmashell >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  trap - EXIT
  sleep 2
  ok "user-level Sugar Plum removed"
  warn "log out/in for shortcuts; run ./install.sh --system --revert for login + Limine"
}

case "${1:-apply}" in
  apply|--apply)
    apply_kde
    apply_shells
    "$REPO/bin/desktop-icons" apply || warn "desktop icon pass skipped"
    apply_panel
    apply_wallpaper
    apply_scripts
    ok "Sugar Plum applied"
    warn "log out/in to activate the screenshot shortcuts"
    if [ -e "$REPO/state/system-applied" ]; then
      ok "login + Limine already applied (revert: sudo ./install.sh --system --revert)"
    else
      warn "run ./install.sh --system for login + Limine"
    fi
    ;;
  update|--update)
    if git -C "$REPO" remote get-url origin >/dev/null 2>&1; then
      git -C "$REPO" pull --ff-only || die "git pull failed"
    else
      warn "no git remote; applying the local tree"
    fi
    exec "$0" apply
    ;;
  revert)
    revert_all
    ;;
  status|--status)
    status
    ;;
  dry-run|--dry-run)
    echo "Would install: Nunito, satty, Papirus-Dark + candy folders"
    echo "Would apply: Catppuccin Mocha Pink, Sugar Plum colors, Nunito, IAX buttons, blur/glide"
    echo "Would theme: Plasma, panel (3-dot tasks), Ghostty, Nu, fish, btop, bat, fzf/eza, Neovim, GTK"
    echo "Would add: screenshot shortcuts, 7z GUI/menu, Aurora animated wallpaper, preview"
    echo "Would NOT touch: login, Limine (use --system), packages, other users"
    ;;
  --revert)
    revert_all
    ;;
  --system)
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
      exec sudo "$REPO/system/install-system.sh" "${2:-apply}"
    fi
    exec "$REPO/system/install-system.sh" "${2:-apply}"
    ;;
  -h|--help)
    cat <<EOF
Sugar Plum — reversible KDE rice

  ./install.sh              apply user-level rice
  ./install.sh --update     pull (if a remote exists) and re-apply
  ./install.sh --revert     restore originals, switch back to Breeze
  ./install.sh --status     show what is installed
  ./install.sh --dry-run    list what apply would do
  sudo ./install.sh --system            login wallpaper + Limine theme
  sudo ./install.sh --system --revert   undo login + Limine

Repo: $REPO
EOF
    ;;
  *) die "unknown command: $1 (try --help)" ;;
esac
