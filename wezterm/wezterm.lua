local wezterm = require("wezterm")
local config = {}

local scheme = wezterm.get_builtin_color_schemes()["Catppuccin Mocha"]
-- local wsl_domains = wezterm.default_wsl_domains()
local mux = wezterm.mux

wezterm.on("gui-startup", function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

if wezterm.target_triple == 'x86_64-apple-darwin' then
    config.font_size = 19 -- depends on monitor size
    config.font = wezterm.font {
        family = "Delugia",
        weight = 'Regular',
        stretch = 'Normal',
        style = 'Normal',
    }
elseif wezterm.target_triple == 'x86_64-pc-windows-msvc' then
    -- TODO: add powershell as default
    config.default_prog = { 'powershell.exe', '-NoLogo' }
    config.window_decorations = "RESIZE"
end

config.enable_csi_u_key_encoding = true
config.check_for_updates = true
config.audible_bell = "Disabled"
config.color_scheme = "Catppuccin Mocha"
config.colors = {
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
}
config.font_size = 18 -- depends on monitor size
config.warn_about_missing_glyphs = false
config.bold_brightens_ansi_colors = true
config.hide_tab_bar_if_only_one_tab = true
config.cursor_blink_rate = 800
config.force_reverse_video_cursor = true
config.use_dead_keys = false
config.scrollback_lines = 5000
config.window_close_confirmation = 'NeverPrompt'
-- wsl_domains = wsl_domains,
-- default_domain = "WSL:Ubuntu",
config.inactive_pane_hsb = {
    saturation = 0.8,
    brightness = 0.7,
}
config.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
}


return config
