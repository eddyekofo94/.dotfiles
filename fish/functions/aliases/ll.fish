# abbr -a -- ll 'eza --git --group-directories-first --icons --sort=modified --long --all --no-filesize --no-time --no-user --no-permissions'
function ll -d "list long"
    if command -q eza --icons &>/dev/null
        command eza --git --group-directories-first --icons --sort=modified --long --all --no-filesize --no-time --no-user --no-permissions
    else if command -v eza &>/dev/null
        command eza -lahF --git --icons auto
    else
       command ls -FGlAhpv
    end
end
