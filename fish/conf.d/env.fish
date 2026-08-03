# Checked-in globals are the deterministic owner of application environment.
# Do not persist machine-derived values as universal variables.

set -gx DOT_DIR "$HOME/.dotfiles"
set -gx NVIM_NF true
set -gx PAGER less

if command -q nvim
    set -gx VISUAL nvim
    set -gx EDITOR nvim
    set -gx NVIM_DIR "$XDG_CONFIG_HOME/nvim"

    # An agent's ctrl+g resolves $VISUAL before $EDITOR. The shim captures the
    # pane's closeout before Neovim claims the alternate screen -- after which
    # `herdr pane read` can only see Neovim -- then execs nvim. Outside an
    # agent pane it is a pass-through, so `git commit` and friends behave
    # normally. $EDITOR stays a bare `nvim` for tools matching on the name.
    set -l agent_prompt_editor "$NVIM_DIR/tools/agent_prompt_editor.sh"
    if test -x $agent_prompt_editor
        set -gx VISUAL $agent_prompt_editor
    end
else
    set -gx VISUAL vim
    set -gx EDITOR vim
    set -e NVIM_DIR
end

set --local uname_out (uname -a)
switch $uname_out
    case '*Microsoft*'
        set -g OS WSL
    case '*microsoft*'
        set -g OS WSL2
    case 'Linux*'
        set -g OS Linux
    case 'Darwin*'
        set -g OS Mac
        set -gx BROWSER open
    case '*'
        set -g OS Unknown
end

set -gx GNUPGHOME $XDG_DATA_HOME/gnupg
set -gx LESSHISTFILE $XDG_DATA_HOME/lesshst
set -gx SQLITE_HISTORY $XDG_DATA_HOME/sqlite_history
set -gx WORKON_HOME $XDG_DATA_HOME/venvs
set -gx PYLINTHOME $XDG_CACHE_HOME/pylint

set --local environment_cache "$XDG_CACHE_HOME/fish/dotfiles_environment.fish"
if test -r "$environment_cache"
    source "$environment_cache"
end

set --local java_home_candidates
if set -q JAVA_HOME; and test -d "$JAVA_HOME"
    set --append java_home_candidates $JAVA_HOME
end
if set -q __dotfiles_cached_java_home
    set --append java_home_candidates $__dotfiles_cached_java_home
end
if set -q SDKMAN_DIR
    set --append java_home_candidates "$SDKMAN_DIR/candidates/java/current"
end
set --append java_home_candidates "$HOME/.sdkman/candidates/java/current"

set --local resolved_java_home (__dotfiles_first_existing_directory $java_home_candidates)
if test $status -eq 0
    set -gx JAVA_HOME $resolved_java_home
else
    set -e JAVA_HOME
end
set -e __dotfiles_cached_java_home

if test -r "$HOME/.cargo/env.fish"
    source "$HOME/.cargo/env.fish"
end

set -gx FISH_THEME catppuccin-mocha

set -e LS_COLORS
if set -q __dotfiles_cached_ls_colors
    set -gx LS_COLORS $__dotfiles_cached_ls_colors
end
set -e __dotfiles_cached_ls_colors

set -gx BAT_CONFIG_PATH "$DOT_DIR/bat/bat.conf"
set -gx fifc_editor $EDITOR

set -gx LAZYGIT_DIR "$XDG_CONFIG_HOME/lazygit"

# Image previews. chafa's format=auto picks `symbols` (block art) inside tmux,
# because tmux sets TERM=tmux-256color and rewrites TERM_PROGRAM to "tmux", so
# chafa cannot see that the outer terminal is Ghostty. Name the format instead.
#
# Ghostty speaks the kitty graphics protocol and will not implement sixel, while
# tmux implements sixel but not kitty -- so real pixels only reach Ghostty by
# wrapping kitty sequences in tmux's DCS passthrough (needs allow-passthrough on,
# which tmux.conf sets). tmux does not track those cells, so images can smear or
# outlive a redraw; drop `-f kitty` to fall back to reliable block art.
set -g fifc_chafa_opts -f kitty --passthrough=auto --polite=on
