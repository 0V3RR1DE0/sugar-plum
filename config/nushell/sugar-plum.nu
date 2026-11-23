# Sugar Plum — CLI accents + prompt.
# Sourced at the end of ~/.config/nushell/config.nu so it can override the prompt.

$env.COLORTERM = "truecolor"
$env.SUGAR_PLUM = "1"

$env.EZA_COLORS = "di=1;38;2;255;179;217:da=1;38;2;200;182;226:ln=38;2;174;198;255:ex=1;38;2;184;230;200:fi=38;2;237;230;245:pi=38;2;230;195;255:so=38;2;184;230;230:bd=1;38;2;247;225;181:cd=1;38;2;200;182;226:uu=38;2;200;182;226:un=38;2;255;179;217:gu=38;2;184;230;200:gm=38;2;247;225;181:gd=38;2;243;139;168:sn=38;2;200;182;226:sb=38;2;200;182;226:df=38;2;174;198;255:ds=38;2;174;198;255"
$env.FZF_DEFAULT_OPTS = "--height=60% --layout=reverse --border=rounded --color=fg:#c8b6e2,bg:#1e1e2e,hl:#ffb3d9,fg+:#ede6f5,bg+:#313244,hl+:#ffb3d9,info:#aec6ff,prompt:#ffb3d9,pointer:#e6c3ff,marker:#b8e6c8,spinner:#b8e6e6,header:#c8b6e2"
$env.BAT_THEME = "Sugar Plum"

# A soft two-tone prompt: lilac path, candy git, periwinkle time, orchid star.
$env.PROMPT_COMMAND = {||
    let pwd = try {
        let home = $nu.home-dir
        let p = $env.PWD
        if ($p | str starts-with $home) {
            let rest = ($p | str replace $home "~")
            $rest
        } else { $p }
    } catch { $env.PWD }

    let branch = try {
        (^git branch --show-current e> /dev/null | str trim)
    } catch { "" }

    let git = if ($branch | is-empty) { "" } else {
        $"(ansi $env.NU_C_GIT) · ($branch)(ansi reset)"
    }
    $"(ansi $env.NU_C_SYMBOL)✦ (ansi $env.NU_C_PRIMARY)($pwd)(ansi reset)($git)"
}

$env.PROMPT_COMMAND_RIGHT = {||
    $"(ansi $env.NU_C_SYMBOL)✦ (ansi $env.NU_C_TIME)(date now | format date '%H:%M')(ansi reset)"
}
$env.PROMPT_INDICATOR = $" (ansi $env.NU_C_GIT)❯(ansi reset) "
