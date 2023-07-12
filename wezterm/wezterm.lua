local wezterm = require("wezterm")

local wsl_domains = wezterm.default_wsl_domains()

return {
    enable_csi_u_key_encoding = true,
    check_for_updates = true,
    font = wezterm.font({ "JetBrainsMono", { weight = "Regular" } }),
    color_scheme = "Catppuccin Mocha",
    font_size = 13,
    bold_brightens_ansi_colors = true,
    hide_tab_bar_if_only_one_tab = true,
    cursor_blink_rate = 800,
    force_reverse_video_cursor = true,
    wsl_domains = wsl_domains,
    default_domain = "WSL:Ubuntu",
    window_padding = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },
}
