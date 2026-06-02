# abbr -a -- ll 'eza --git --group-directories-first --icons --sort=modified --long --all --no-filesize --no-time --no-user --no-permissions'
function ll -d "list long"
    if command -q eza
        command eza --git --group-directories-first --icons --sort=modified --long --all --header $argv
    else if command -v eza &>/dev/null
        command eza -lahF --git --icons auto --header $argv
    else
       command ls -FGlAhpv $argv
    end
end
