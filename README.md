# Sugar Plum

A soft-dark pastel KDE rice for CachyOS / Arch on Wayland, built from the palette
that was already in the user's Nushell prompt.

## What it changes

- **Plasma:** Catppuccin Mocha structure, a Sugar Plum colour scheme, Nunito 10,
  Mignon pastel folder icons with a Papirus-Dark fallback, a full-width translucent taskbar, blur,
  Glide and Magic Lamp.
- **Window decoration:** a small QML decoration (`org.sugarplum.decoration`)
  with three inert pastel dots on the left and Breeze-style Minimize →
  Maximize → Close buttons on the right. KDE-decorated windows only; apps with
  client-side titlebars keep their own.
- **Taskbar (`org.sugarplum.dots`):** real app icons; a three-dot badge at the
  top-right of an app's icon when it is open; clicking a grouped app cycles
  its windows; hovering shows live window thumbnails with a click-to-focus
  list; middle-click closes. Drag a pinned icon to reorder it, right-click a
  task for the full task menu or to pin/unpin it, and icons auto-shrink to fit
  the taskbar. The pinned list persists in the applet configuration.
- **Shells and CLI:** Ghostty frosted glass + Sugar Plum ANSI palette, Nushell
  env accents, fish `conf.d`, btop, bat, fzf, eza, fastfetch, LazyVim Catppuccin.
- **Apps:** GTK gets Breeze-Dark + Sugar Plum icons + Papirus fallback + Nunito;
  Dolphin gets a 7-Zip submenu and Mignon pastel folder icons.
- **Screenshots:** `Print` region, `Shift+Print` full screen, `Alt+Print` active
  window → satty → clipboard + `~/Pictures/Screenshots`.
- **Wallpaper:** Sugar Plum Aurora, an animated dark-pastel blob/star wallpaper
  that reacts to the pointer and pauses for maximized windows. Login uses
  CachyOS `north.png`; Limine uses CachyOS `CachyOS_Moon.jpg`.
- **Optional system half:** login wallpaper (Plasma Login Manager 6.8 only
  exposes a wallpaper, not a full theme) and a cosmetic Limine boot theme.

## Install

```sh
git clone https://github.com/0V3RR1DE0/sugar-plum.git ~/sugar-plum   # or copy this folder
cd ~/sugar-plum
./install.sh
```

Everything is user-level. It downloads Papirus, satty and the Catppuccin KDE
theme. The Aurora cursor helper and the 7-Zip GUI need `cmake`, `g++`, Qt6
development headers and PySide6 (all present here); on a fresh machine those are
the only extra build dependencies. The first run stores the originals under
`backups/originals/`, then applies the rice.

Runtime deps for the helper actions: `spectacle`, `satty` (installed by this
script), `wl-clipboard`, `7z`, `unrar`, `zenity`, ImageMagick (`magick` or
`convert`) and Ghostty/Konsole/xterm. `rar` is optional, only for RAR creation.

```sh
./install.sh --status     # what is present
./install.sh --dry-run    # what apply would do
./install.sh --update     # git pull (if a remote exists) + re-apply
./install.sh --revert     # restore your pre-rice files
```

### Login + Limine (optional, one admin step)

These files live outside `$HOME`:

```sh
pkexec ~/sugar-plum/system/install-system.sh apply
# or: sudo ~/sugar-plum/system/install-system.sh apply
```

It writes only:

- `/etc/plasmalogin.conf` and `/var/lib/plasmalogin/wallpapers/sugar-plum.jpg`
- `/boot/limine.conf` (cosmetic wallpaper/palette/branding block)
- `/boot/sugar-plum/` and `/etc/boot/hooks/post.d/80-sugar-plum-theme`

Backups are in `backups/system-originals/`. It does **not** touch kernels,
initramfs, EFI binaries or boot entries. If config-hash enrollment is on, the
hook runs before the enrollment hook and re-enrolls. Revert:

```sh
pkexec ~/sugar-plum/system/install-system.sh revert
```

## Known limits

- The screenshot shortcuts become active after a logout/login (KGlobalAccel
  reads `[services]` at session start). `Meta+Shift+Print` is the native
  Spectacle region fallback; the rice's bindings are Print / Shift+Print /
  Alt+Print.
- Plasma Login Manager 6.8 only exposes a wallpaper; the greeter remains Breeze.
- Limine is text-based; the theme is wallpaper + terminal palette + branding.
- Third-party KWin effects are deliberately avoided (NVIDIA Wayland stability).
- Window titlebar dots: the QML decoration covers KDE-decorated windows. Apps
  that draw their own titlebar (OpenCode, Chromium, Zen, Electron) ignore KDE
  decorations, so their titlebar cannot be changed from here. Run
  `./install.sh --revert` to return to stock Breeze.
- Desktop icons are faded to 60% by `bin/desktop-icons`; shortcut arrows are
  hidden with a transparent theme emblem. If arrows return after an icon-theme
  change, rerun `./bin/desktop-icons apply`.
- RAR creation is available in the Add to archive GUI only when the proprietary
  `rar` package is installed; extraction works with `unrar` and falls back to 7z.
- The 7z quick actions open a Ghostty window for the live log and close on
  success; errors hold the window open. The GUI opens a styled PySide6 dialog.
- If a Plasma update changes the task-manager QML API, the Sugar Dots applet may
  need a fix; `./install.sh --revert` returns to the stock taskbar.
- Papirus-Dark's large sizes are shared with the `Papirus` base tree; the
  installer keeps both in `~/.cache/sugar-plum/papirus`. The pink folder assets
  are vendored in `assets/papirus-pink/` so a fresh install does not depend on
  the 86 MB Catppuccin folder repo.

## Credits

Catppuccin KDE, Papirus, Mignon folder icons, Satty, KDE Plasma, Nushell/fish.

## License

MIT for the original scripts, QML and configuration. Bundled third-party
assets keep their own licenses — see `THIRD-PARTY.md`. Fonts are SIL OFL
(Nunito); Catppuccin and Papirus are downloaded by the installer and retain
their upstream licenses.

## Sharing

Published at <https://github.com/0V3RR1DE0/sugar-plum>.

Each release also carries a clone-ready bundle:
<https://github.com/0V3RR1DE0/sugar-plum/releases/latest>.

On another machine:

```sh
git clone https://github.com/0V3RR1DE0/sugar-plum.git ~/sugar-plum
cd ~/sugar-plum
./install.sh
```

`backups/` and `state/` are machine-specific and deliberately ignored; the
installer creates fresh ones on each machine. To update:

```sh
cd ~/sugar-plum && ./install.sh --update
```

For an offline copy, create a Git bundle:

```sh
git bundle create ~/sugar-plum.bundle --all
# recipient:
git clone ~/sugar-plum.bundle sugar-plum
```

The optional system half (`./install.sh --system apply`) is per machine. On a
non-CachyOS install the CachyOS wallpaper paths are skipped with a warning.

Never commit `backups/` or `state/`; they are deliberately ignored because they
contain machine-specific originals and install state.
