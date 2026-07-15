# abbr -a -- ll 'eza --git --group-directories-first --icons --sort=modified --long --all --no-filesize --no-time --no-user --no-permissions'
function ll -d "list long"
    set -l targets $argv
    if test (count $targets) -eq 0
        set targets .
    end

    if command -q eza
        command eza --git --group-directories-first --icons --sort=modified --long --all --header $targets
        or command /bin/ls -FGlAhpv $targets
    else if command -v eza &>/dev/null
        command eza -lahF --git --icons auto --header $targets
        or command /bin/ls -FGlAhpv $targets
    else
       command /bin/ls -FGlAhpv $targets
    end
end
