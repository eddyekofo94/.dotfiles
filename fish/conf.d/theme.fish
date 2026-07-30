if not status is-interactive
    return
end

# Sole owner of the effective Catppuccin Mocha Fish colors.
#
# Exported, not merely global: separate processes read these from the
# environment. `fish_indent --ansi` (the Ctrl-R history preview) renders
# monochrome without them, and nested Fish inherits the theme this way.
set -gx fish_color_normal cdd6f4
set -gx fish_color_command 89b4fa
set -gx fish_color_param f2cdcd
set -gx fish_color_keyword cba6f7
set -gx fish_color_quote a6e3a1
set -gx fish_color_redirection f5c2e7
set -gx fish_color_end fab387
set -gx fish_color_comment 7f849c
set -gx fish_color_error f38ba8
set -gx fish_color_gray 6c7086
set -gx fish_color_selection --background=313244
set -gx fish_color_search_match --background=313244
set -gx fish_color_option a6e3a1
set -gx fish_color_operator f5c2e7
set -gx fish_color_escape eba0ac
set -gx fish_color_autosuggestion 6c7086
set -gx fish_color_cancel f38ba8
set -gx fish_color_cwd f9e2af
set -gx fish_color_user 94e2d5
set -gx fish_color_host 89b4fa
set -gx fish_color_host_remote a6e3a1
set -gx fish_color_status f38ba8
set -gx fish_pager_color_progress 6c7086
set -gx fish_pager_color_prefix f5c2e7
set -gx fish_pager_color_completion cdd6f4
set -gx fish_pager_color_description 6c7086
