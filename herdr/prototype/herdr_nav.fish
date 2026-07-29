# PROTOTYPE ONLY: preserve Alt-h/j/k/l at an ordinary Fish prompt without
# asking Herdr's direct custom-command matcher to intercept the chord.

function __herdr_nav --argument-names key direction
    if set -q HERDR_NAV_LOG
        printf '%s fish %s herdr-pane\n' (date -u +%Y-%m-%dT%H:%M:%SZ) $key >>$HERDR_NAV_LOG
    end
    command $HERDR_BIN_PATH pane focus --direction $direction --current >/dev/null 2>&1
    commandline -f repaint
end

function __herdr_action --argument-names action
    command $HERDR_PROTOTYPE_DIR/shell_action.sh $action >/dev/null 2>&1
    commandline -f repaint
end

# Keep the prototype adapter when an interactive pane starts another Fish.
# Fish bindings and functions are process-local, so a plain nested `fish`
# would otherwise drop every application-owned Herdr chord at once.
function fish
    command fish --init-command "source '$HERDR_PROTOTYPE_DIR/herdr_nav.fish'" $argv
end

for mode in default insert
    bind --mode $mode \eh '__herdr_nav h left'
    bind --mode $mode \ej '__herdr_nav j down'
    bind --mode $mode \ek '__herdr_nav k up'
    bind --mode $mode \el '__herdr_nav l right'
    bind --mode $mode \ev '__herdr_action split-right'
    bind --mode $mode \en '__herdr_action split-adaptive'
    bind --mode $mode \eq '__herdr_action close-pane'
    bind --mode $mode \eo '__herdr_action close-other-panes'
    bind --mode $mode \e= '__herdr_action equalize-panes'
    bind --mode $mode \eX '__herdr_action close-tab'
    bind --mode $mode \e\cx '__herdr_action close-other-tabs'
    bind --mode $mode \ez '__herdr_action zoom'

    # Herdr enables the Kitty keyboard protocol in direct Ghostty sessions.
    # Fish 4.8 does not normalize these CSI-u Alt events to its named `alt-*`
    # bindings, so retain the legacy ESC aliases above and bind the observed
    # protocol forms explicitly as well.
    bind --mode $mode (printf '\e[118;3u') '__herdr_action split-right'
    bind --mode $mode (printf '\e[110;3u') '__herdr_action split-adaptive'
    bind --mode $mode (printf '\e[113;3u') '__herdr_action close-pane'
    bind --mode $mode (printf '\e[111;3u') '__herdr_action close-other-panes'
    bind --mode $mode (printf '\e[61;3u') '__herdr_action equalize-panes'
    bind --mode $mode (printf '\e[122;3u') '__herdr_action zoom'
    bind --mode $mode (printf '\e[88;3u') '__herdr_action close-tab'
    bind --mode $mode (printf '\e[120;4u') '__herdr_action close-tab'
    bind --mode $mode (printf '\e[120;7u') '__herdr_action close-other-tabs'
end
