local wezterm = require("wezterm")

--
-- local colors = {
-- 	none = "NONE",
-- 	bg_dark = "#1f2335",
-- 	bg = "#24283b",
-- 	bg_highlight = "#292e42",
-- 	terminal_black = "#414868",
-- 	fg = "#c0caf5",
-- 	fg_dark = "#a9b1d6",
-- 	fg_gutter = "#3b4261",
-- 	dark3 = "#545c7e",
-- 	comment = "#565f89",
-- 	dark5 = "#737aa2",
-- 	blue0 = "#3d59a1",
-- 	blue = "#7aa2f7",
-- 	cyan = "#7dcfff",
-- 	blue1 = "#2ac3de",
-- 	blue2 = "#0db9d7",
-- 	blue5 = "#89ddff",
-- 	blue6 = "#B4F9F8",
-- 	blue7 = "#394b70",
-- 	magenta = "#bb9af7",
-- 	purple = "#9d7cd8",
-- 	orange = "#ff9e64",
-- 	yellow = "#e0af68",
-- 	green = "#9ece6a",
-- 	green1 = "#73daca",
-- 	green2 = "#41a6b5",
-- 	teal = "#1abc9c",
-- 	red = "#f7768e",
-- 	red1 = "#db4b4b",
-- }

return {
    enable_csi_u_key_encoding = true,
    check_for_updates = true,
    font = wezterm.font("Delugia", { weight = "Regular" }),
    color_scheme = "Catppuccin Mocha",
    font_size = 17.5,
    bold_brightens_ansi_colors = true,
    hide_tab_bar_if_only_one_tab = true,
    cursor_blink_rate = 800,
    force_reverse_video_cursor = true,
    window_padding = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },
    -- colors = {
    --     foreground = "#dcd7ba",
    --     background = "#1f1f28",
    --     cursor_bg = "#c8c093",
    --     cursor_fg = "#c8c093",
    --     cursor_border = "#c8c093",
    --     selection_fg = "#c8c093",
    --     selection_bg = "#2d4f67",
    --     scrollbar_thumb = "#16161d",
    --     split = "#16161d",
    --     ansi = { "#090618", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589",
    --         "#c8c093" },
    --     brights = { "#727169", "#e82424", "#98bb6c", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f",
    --         "#dcd7ba" },
    --     indexed = { [16] = "#ffa066",[17] = "#ff5d62" },
    -- },
    -- 	tab_bar = {
    -- 		background = colors.bg,
    -- 		active_tab = { bg_color = colors.bg_visual, fg_color = colors.fg },
    -- 		inactive_tab = { bg_color = colors.bg, fg_color = colors.line_cursor },
    -- 		inactive_tab_hover = {
    -- 			bg_color = colors.black,
    -- 			fg_color = colors.fg_gutter,
    -- 			italic = true,
    -- 		},
    -- 	},
    -- },
}
