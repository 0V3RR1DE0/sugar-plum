-- Sugar Plum for LazyVim: Catppuccin Mocha with the candy/lilac accents.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      styles = {
        comments = { italic = true },
        conditionals = { italic = true },
      },
      color_overrides = {
        mocha = {
          pink = "#ffb3d9",
          mauve = "#c8b6e2",
          blue = "#aec6ff",
          lavender = "#e6c3ff",
          sky = "#aec6ff",
          sapphire = "#aec6ff",
          teal = "#b8e6e6",
          green = "#b8e6c8",
          yellow = "#f7e1b5",
          peach = "#f2c6a0",
          rosewater = "#ffe3ef",
          flamingo = "#ffc6e3",
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-mocha" },
  },
}
