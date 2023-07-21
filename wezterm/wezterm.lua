local wezterm = require("wezterm")

local scheme = wezterm.get_builtin_color_schemes()["Catppuccin Mocha"]
local wsl_domains = wezterm.default_wsl_domains()
local mux = wezterm.mux

wezterm.on("gui-startup", function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

return {
    enable_csi_u_key_encoding = true,
    check_for_updates = true,
    window_decorations = "RESIZE",
    audible_bell = "Disabled",
    font = wezterm.font {
        -- family = 'FiraCode Nerd Font Mono',
        family = "JetBrains Mono",
        weight = 'Medium',
        stretch = 'Normal',
        style = 'Normal',
        -- harfbuzz_features = { 'cv29', 'cv30', 'ss01', 'ss03', 'ss06', 'ss07', 'ss09' },
    },
    color_scheme = "Catppuccin Mocha",
    colors = {
        tab_bar = {
            background = scheme.background,
            new_tab = { bg_color = scheme.background, fg_color = scheme.ansi[8], intensity = "Bold" },
            new_tab_hover = {
                bg_color = scheme.ansi[1],
                fg_color = scheme.brights[8],
                intensity = "Bold",
            },
            -- format-tab-title
            active_tab = { bg_color = scheme.background, fg_color = scheme.ansi[4] },
            inactive_tab = { bg_color = 'NONE', fg_color = scheme.ansi[8] },
            -- inactive_tab_hover = { bg_color = scheme.ansi[1], fg_color = "#FCE8C3" },
        },
    },
    font_size = 13, -- depends on monitor size
    warn_about_missing_glyphs = false,
    bold_brightens_ansi_colors = true,
    hide_tab_bar_if_only_one_tab = true,
    cursor_blink_rate = 800,
    force_reverse_video_cursor = true,
    use_dead_keys = false,
    scrollback_lines = 5000,
    window_close_confirmation = 'NeverPrompt',
    wsl_domains = wsl_domains,
    default_domain = "WSL:Ubuntu",
    inactive_pane_hsb = {
        saturation = 0.8,
        brightness = 0.7,
    },
    window_padding = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },
}
