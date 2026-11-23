# Sugar Plum palette

The five pastels came from the user's existing Nushell prompt; the dark base is
Catppuccin Mocha. The same names are used in the KDE scheme, terminal, shell,
btop, bat and the preview.

| Name | Hex | Role |
|---|---|---|
| Candy | `#FFB3D9` | selection, git branch, cursor, running badge |
| Lilac | `#C8B6E2` | primary accent, paths, focus |
| Periwinkle | `#AEC6FF` | time, links, updates, directories |
| Orchid | `#E6C3FF` | prompt symbol, headings, magenta ANSI |
| Seafoam | `#B8E6E6` | numbers, values, cyan ANSI |
| Mint | `#B8E6C8` | success, CPU, green ANSI |
| Butter | `#F7E1B5` | warnings, highlights, yellow ANSI |
| Plum | `#1E1E2E` | base / terminal background |
| Mantle | `#181825` | windows, panels |
| Crust | `#11111B` | deepest surfaces |
| Surface | `#313244` / `#45475A` | controls and selection |
| Text | `#EDE6F5` | primary text |
| Muted | `#A6ADC8` | secondary text |

## Terminal ANSI

`black #3A3145 · red #F38BA8 · green #B8E6C8 · yellow #F7E1B5 · blue #AEC6FF ·
magenta #E6C3FF · cyan #B8E6E6 · white #EDE6F5`

Bright: `#5A4C6B · #FFB3D9 · #C9EFD5 · #F9E9C8 · #C2D4FF · #EFD4FF · #CDEFEF ·
#FFFFFF`

The Nushell prompt uses `C8B6E2`, `FFB3D9`, `AEC6FF`, `E6C3FF`, `B8E6E6`,
`F7E1B5` first, so Ghostty, fish, btop and bat were matched to it instead of
replacing it.

## Surfaces

- KDE: Catppuccin structure + `SugarPlum.colors` (candy selection, lilac focus,
  periwinkle links) + `AccentColor 255,179,217`.
- Panel: full width, 40 px, translucent, Breeze panel style, candy folder icons.
- Window buttons: standard Breeze glyphs, right side, Minimize → Maximize → Close.
- Radius: 10–16 px on windows/panel, 9–10 px on task icons.
- Type: Nunito 10 UI, FiraCode Nerd Font 10 fixed.
