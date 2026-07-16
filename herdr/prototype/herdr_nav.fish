# PROTOTYPE ONLY: preserve Alt-h/j/k/l at an ordinary Fish prompt without
# asking Herdr's direct custom-command matcher to intercept the chord.

function __herdr_nav --argument-names key direction
    if set -q HERDR_NAV_LOG
        printf '%s fish %s herdr-pane\n' (date -u +%Y-%m-%dT%H:%M:%SZ) $key >>$HERDR_NAV_LOG
    end
    command $HERDR_BIN_PATH pane focus --direction $direction --current >/dev/null 2>&1
    commandline -f repaint
end

for mode in default insert
    bind --mode $mode \eh '__herdr_nav h left'
    bind --mode $mode \ej '__herdr_nav j down'
    bind --mode $mode \ek '__herdr_nav k up'
    bind --mode $mode \el '__herdr_nav l right'
end
