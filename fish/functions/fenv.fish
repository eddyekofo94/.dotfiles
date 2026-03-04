function fenv -d "fzf the environment variables"
    set -l envs
    set envs (env | fzf +m \
              --query="$argv" --multi --select-1 --exit-0 \
              --reverse \
              --extended \
              '--bind=ctrl-d:execute(set --erase (echo {+} | cut -d= -f1 ))+abort' \
              --bind 'ctrl-y:execute-silent(echo {+} | cut -d= -f1 | pbcopy)+abort' \
              --preview 'echo {}' --preview-window down:3:wrap \
              --header '
                  CTRL-d to unset variable
                  ENTER show message
                  CTRL-y copy clipboard
                  '
                )

    if test (count $envs) -gt 0
        echo (echo "$envs" | cut -d= -f2)
        echo $envs | cut -d= -f1 | pbcopy || return
    end
end
