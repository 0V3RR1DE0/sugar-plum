#!/usr/bin/env bash
# Sugar Plum system half: login wallpaper + Limine theme. Run as root.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ESP="$(sed -n 's/^ESP_PATH="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' /etc/default/limine 2>/dev/null | head -n1)"
ESP="${ESP:-/boot}"
BACKUPS="$REPO/backups/system-originals"
MARK="$REPO/state/system-applied"
MODE="${1:-apply}"

[ "$(id -u)" -eq 0 ] || { echo "run this with sudo (or ./install.sh --system)" >&2; exit 1; }
mkdir -p "$BACKUPS"
say()  { printf '\033[38;5;218m▸\033[0m %s\n' "$*"; }
ok()   { printf '\033[38;5;150m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[38;5;222m!\033[0m %s\n' "$*" >&2; }

backup_once() {
  local src="$1" name="$2"
  [ -e "$BACKUPS/$name" ] && return 0
  [ -f "$src" ] || return 0
  cp -a -- "$src" "$BACKUPS/$name"
  say "backup $src"
}

rewrite_plasmalogin() {
  python3 - "$1" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text() if p.exists() else ""
header = "[Greeter][Wallpaper][org.kde.image][General]"
lines = text.splitlines()
out, skip = [], False
for line in lines:
    if line.strip() == header:
        skip = True
        continue
    if skip and line.lstrip().startswith("["):
        skip = False
    if not skip:
        out.append(line)
while out and not out[-1].strip():
    out.pop()
out += ["", header, "Image=file:///var/lib/plasmalogin/wallpapers/sugar-plum.jpg", ""]
p.write_text("\n".join(out))
PY
}

apply_login() {
  [ -f /etc/plasmalogin.conf ] || { warn "PLM config not found; skipping login wallpaper"; return; }
  backup_once /etc/plasmalogin.conf plasmalogin.conf
  install -d -m 755 /var/lib/plasmalogin/wallpapers
  install -m 644 "$REPO/wallpapers/sakura-mirror.jpg" /var/lib/plasmalogin/wallpapers/sugar-plum.jpg
  rewrite_plasmalogin /etc/plasmalogin.conf
  ok "login wallpaper set"
}

apply_limine() {
  [ -f "$ESP/limine.conf" ] || { warn "no $ESP/limine.conf; skipping Limine"; return; }
  command -v limine >/dev/null 2>&1 || { warn "limine binary not found; skipping"; return; }
  backup_once "$ESP/limine.conf" limine.conf
  install -d -m 755 "$ESP/sugar-plum"
  install -m 644 "$REPO/wallpapers/quiet-moon.jpg" "$ESP/sugar-plum/limine.jpg"
  install -m 644 "$REPO/system/limine-theme.conf" "$ESP/sugar-plum/limine-theme.conf"
  install -d -m 755 /etc/boot/hooks/post.d
  install -m 755 "$REPO/system/80-sugar-plum-theme" /etc/boot/hooks/post.d/80-sugar-plum-theme
  ESP_PATH="$ESP" sh /etc/boot/hooks/post.d/80-sugar-plum-theme
  ok "Limine wallpaper + palette applied (cosmetic keys only)"
}

revert_login() {
  [ -f "$BACKUPS/plasmalogin.conf" ] && cp -a "$BACKUPS/plasmalogin.conf" /etc/plasmalogin.conf
  rm -f /var/lib/plasmalogin/wallpapers/sugar-plum.jpg
  ok "login restored"
}

revert_limine() {
  [ -f "$BACKUPS/limine.conf" ] && cp -a "$BACKUPS/limine.conf" "$ESP/limine.conf"
  rm -f /etc/boot/hooks/post.d/80-sugar-plum-theme
  rm -rf "$ESP/sugar-plum"
  if grep -q '^ENABLE_ENROLL_LIMINE_CONFIG=yes' /etc/default/limine 2>/dev/null; then
    limine-enroll-config >/dev/null 2>&1 || true
  fi
  ok "Limine restored"
}

case "$MODE" in
  apply)
    apply_login
    apply_limine
    mkdir -p "$(dirname "$MARK")"; touch "$MARK"
    ok "system half applied — check the login screen on next logout, Limine on reboot"
    ;;
  revert)
    revert_login
    revert_limine
    rm -f "$MARK"
    ok "system half reverted"
    ;;
  *) echo "usage: $0 [apply|revert]" >&2; exit 1 ;;
esac
