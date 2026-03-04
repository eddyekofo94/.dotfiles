function ls -d list
    if command -q eza --icons &>/dev/null
        command eza --git --group-directories-first --icons --sort=modified $argv
    else if command -v eza &>/dev/null
        command eza --git --icons auto $argv
    else
        # command ls -G $argv
        # NOTE: not sure if working
        switch (uname -s)
            case Darwin
                command /bin/ls -G $argv
            case '*'
                command /bin/ls --group-directories-first --color=auto $argv
        end
    end
end
