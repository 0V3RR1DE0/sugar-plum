# Sugar Plum

A soft-dark pastel KDE rice for CachyOS / Arch on Wayland, built from the palette
that was already in the user's Nushell prompt.

## What it changes

- **Plasma:** Catppuccin Mocha structure, a Sugar Plum colour scheme, Nunito 10,
  Papirus-Dark with candy folders, a full-width translucent taskbar, blur,
  Glide and Magic Lamp.
- **Window decoration:** a small QML decoration (`org.sugarplum.decoration`)
  with three inert pastel dots on the left and Breeze-style Minimize →
  Maximize → Close buttons on the right. KDE-decorated windows only; apps with
  client-side titlebars keep their own.
- **Taskbar (`org.sugarplum.dots`):** real app icons; a three-dot badge at the
  top-right of an app's icon when it is open; stable manual order; clicking a
  grouped app cycles its windows; hovering shows a clickable window list;
  middle-click closes. The pinned list lives in
  `config/plasma/org.sugarplum.dots/contents/ui/main.qml`.
- **Shells and CLI:** Ghostty frosted glass + Sugar Plum ANSI palette, Nushell
  env accents, fish `conf.d`, btop, bat, fzf, eza, fastfetch, LazyVim Catppuccin.
- **Apps:** GTK gets Breeze-Dark + Papirus + Nunito; Dolphin gets a 7z service
  menu and Papirus candy folders.
- **Screenshots:** `Print` region, `Shift+Print` full screen, `Alt+Print` active
  window → satty → clipboard + `~/Pictures/Screenshots`.
- **Wallpapers:** 8 comfy Unsplash images, random every 30 minutes. Sources in
  `wallpapers/SOURCES.md`.
- **Optional system half:** login wallpaper (Plasma Login Manager 6.8 only
  exposes a wallpaper, not a full theme) and a cosmetic Limine boot theme.

## Install

```sh
git clone <your-remote> ~/sugar-plum   # or copy this folder
cd ~/sugar-plum
./install.sh
```

Everything is user-level. It downloads Papirus, satty and the Catppuccin KDE
theme; no pacman packages are required. On a fresh machine, the first run stores
the originals under `backups/originals/`, then applies the rice.

```sh
./install.sh --status     # what is present
./install.sh --dry-run    # what apply would do
./install.sh --update     # git pull (if a remote exists) + re-apply
./install.sh --revert     # restore originals and switch back to Breeze
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
  reads `[services]` at session start).
- Plasma Login Manager 6.8 only exposes a wallpaper; the greeter remains Breeze.
- Limine is text-based; the theme is wallpaper + terminal palette + branding.
- Third-party KWin effects are deliberately avoided (NVIDIA Wayland stability).
- Window titlebar dots: the QML decoration covers KDE-decorated windows. Apps
  that draw their own titlebar (OpenCode, Chromium, Zen, Electron) ignore KDE
  decorations, so their titlebar cannot be changed from here. Run
  `./install.sh --revert` to return to stock Breeze.
- The desktop shortcut arrows are drawn by Plasma's Folder View; the icon files
  are translucent but that overlay is not part of the icon theme.
- RAR creation needs the proprietary `rar` package; extraction works with
  `unrar`.
- The 7z quick actions open a Ghostty window for the live log and close on
  success; errors hold the window open.
- If a Plasma update changes the task-manager QML API, the Sugar Dots applet may
  need a fix; `./install.sh --revert` returns to the stock taskbar.
- Papirus-Dark's large sizes are shared with the `Papirus` base tree; the
  installer keeps both in `~/.cache/sugar-plum/papirus`. The pink folder assets
  are vendored in `assets/papirus-pink/` so a fresh install does not depend on
  the 86 MB Catppuccin folder repo.

## Credits

Catppuccin KDE, Papirus, Satty, Unsplash, KDE Plasma, Nushell/fish.

## License

MIT for the scripts and configuration. Fonts: SIL OFL (Nunito). Wallpapers:
Unsplash License (see `wallpapers/SOURCES.md`). Catppuccin and Papirus retain
their own licenses.
