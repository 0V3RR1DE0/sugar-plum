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
case "$ESP" in
  /*) ;;
  *) echo "refusing invalid ESP_PATH: $ESP" >&2; exit 1 ;;
esac
[ "$ESP" != "/" ] || { echo "refusing ESP_PATH=/" >&2; exit 1; }
[ -d "$ESP" ] || { echo "ESP_PATH is not a directory: $ESP" >&2; exit 1; }
mkdir -p "$BACKUPS"
# A group/world-writable repo lets another local user inject root code.
if [ $((0$(stat -c %a "$REPO") & 0022)) -ne 0 ]; then
  echo "refusing: repo is group/world-writable: $REPO" >&2; exit 1
fi
if [ $((0$(stat -c %a "$BACKUPS") & 0022)) -ne 0 ]; then
  echo "refusing: backup dir is group/world-writable: $BACKUPS" >&2; exit 1
fi
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
  # Set only Image=; preserve autologin and any other greeter keys.
  kwriteconfig6 --file "$1" \
    --group Greeter --group Wallpaper --group org.kde.image --group General \
    --key Image "file:///var/lib/plasmalogin/wallpapers/sugar-plum.jpg"
}

apply_login() {
  [ -f /etc/plasmalogin.conf ] || { warn "PLM config not found; skipping login wallpaper"; return; }
  [ -f /usr/share/wallpapers/cachyos-wallpapers/north.png ] \
    || { warn "CachyOS login wallpaper missing; skipping"; return; }
  backup_once /etc/plasmalogin.conf plasmalogin.conf
  install -d -m 755 /var/lib/plasmalogin/wallpapers
  install -m 644 /usr/share/wallpapers/cachyos-wallpapers/north.png /var/lib/plasmalogin/wallpapers/sugar-plum.jpg
  rewrite_plasmalogin /etc/plasmalogin.conf
  ok "login wallpaper set"
}

apply_limine() {
  [ -f "$ESP/limine.conf" ] || { warn "no $ESP/limine.conf; skipping Limine"; return; }
  [ ! -L "$ESP/limine.conf" ] || { warn "$ESP/limine.conf is a symlink; skipping"; return; }
  command -v limine >/dev/null 2>&1 || { warn "limine binary not found; skipping"; return; }
  [ -f /usr/share/wallpapers/cachyos-wallpapers/CachyOS_Moon.jpg ] \
    || { warn "CachyOS Limine wallpaper missing; skipping"; return; }
  [ -f "$REPO/system/limine-theme.conf" ] \
    || { warn "limine-theme.conf missing; skipping"; return; }
  backup_once "$ESP/limine.conf" limine.conf
  install -d -m 755 "$ESP/sugar-plum"
  install -m 644 /usr/share/wallpapers/cachyos-wallpapers/CachyOS_Moon.jpg "$ESP/sugar-plum/limine.jpg"
  install -m 644 "$REPO/system/limine-theme.conf" "$ESP/sugar-plum/limine-theme.conf"
  install -d -m 755 /etc/boot/hooks/post.d
  install -m 755 "$REPO/system/80-sugar-plum-theme" /etc/boot/hooks/post.d/80-sugar-plum-theme
  ESP_PATH="$ESP" sh /etc/boot/hooks/post.d/80-sugar-plum-theme
  ok "Limine wallpaper + palette applied (cosmetic keys only)"
}

revert_login() {
  # Never restore the (possibly months-old) backup over the live file;
  # remove only the wallpaper key this rice added.
  if [ -f /etc/plasmalogin.conf ]; then
    kwriteconfig6 --file /etc/plasmalogin.conf \
      --group Greeter --group Wallpaper --group org.kde.image --group General \
      --key Image --delete || warn "could not remove login wallpaper key"
  fi
  rm -f /var/lib/plasmalogin/wallpapers/sugar-plum.jpg
  ok "login wallpaper removed"
}

revert_limine() {
  # Remove only this rice's block; restoring the raw backup after a kernel
  # update would drop boot entries.
  if [ -f "$ESP/limine.conf" ]; then
    python3 - "$ESP/limine.conf" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
text = p.read_text()
start, end = "# >>> sugar-plum >>>", "# <<< sugar-plum <<<"
while start in text and end in text:
    a = text.index(start)
    b = text.index(end, a) + len(end)
    text = text[:a] + text[b:]
p.write_text(text.lstrip("\n"))
PY
  fi
  rm -f /etc/boot/hooks/post.d/80-sugar-plum-theme
  rm -rf "$ESP/sugar-plum"
  if grep -q '^ENABLE_ENROLL_LIMINE_CONFIG=yes' /etc/default/limine 2>/dev/null; then
    limine-enroll-config >/dev/null 2>&1 || true
  fi
  ok "Limine theme block removed"
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
