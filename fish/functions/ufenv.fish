function ufenv -d "fzf the unset environment variables"
    set -l envs
    set envs (env | fzf +m \
                  --query="$argv" --select-1 --multi --exit-0 \
                  '--bind=ctrl-x:execute(set --erase | echo {} | cut -d= -f1)+abort' \
                  --preview 'echo {}' --preview-window down:3:wrap \
                  )

    if test (count $envs) -gt 0
        set -l var (echo "$envs" | cut -d= -f1)

        for env in $envs
            set -l var (echo "$env" | cut -d= -f1)
            echo "set --erase -g $var"
            set --erase -g $var
        end
    end
end
