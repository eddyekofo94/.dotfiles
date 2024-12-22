

#  NOTE: 2024-06-13 - This searches the environment variables
function fenv -d "This searches the environment variables"
  set -l envs
  set envs (env | fzf +m \
                  --query="$argv" --no-multi --select-1 --exit-0 \
                  --preview 'echo {}' --preview-window down:3:wrap \
                  )

  echo (echo "$envs" | cut -d= -f2)
end

function fcd -d "Fuzzy change directory"
    if set -q argv[1]
        set searchdir $argv[1]
    else
        set searchdir $HOME
    end

    # https://github.com/fish-shell/fish-shell/issues/1362
    set -l tmpfile (mktemp)
    find $searchdir \( ! -regex '.*/\..*' \) ! -name __pycache__ -type d | fzf > $tmpfile
    set -l destdir (cat $tmpfile)
    rm -f $tmpfile

    if test -z "$destdir"
        return 1
    end

    cd $destdir
end

function fkill -d "Fuzzy kill"
    set pid (ps -ef | sed 1d | fzf -m | awk '{print $2}')

    if test -n "$pid"
        echo $pid | xargs kill -9
    end 
end

#  FIX: 2024-12-19 - Make fish cinpliat
# cdf - cd into the directory of the selected file
function cdf
    set -l file
    set -l dir
    set file (fzf +m -q "$argv[1]") && set dir (dirname "$file") && cd "$dir"
end

function find_in_files
    set -x RG_PREFIX rg --files-with-matches
    set -l file
    set file (
        FZF_DEFAULT_COMMAND="$RG_PREFIX '$argv'" \
            fzf --sort --preview="[ ! -z {} ] && rg --pretty --context 5 {q} {}" \
                --phony -q "$argv" \
                --bind "change:reload:$RG_PREFIX {q}" \
                --preview-window="70%:wrap"
    ) &&
    open "$file"
end

function fe -d "fzf find edit"
    set -l file
    set file (
      fzf --query="$argv" --no-multi --select-1 --exit-0 \
          --preview 'bat --color=always --line-range :500 {}'
    )
    if test -e $file
        $EDITOR "$file"
    end
end
function fzf_change_directory
    set -l directory
    set directory (
      fd --type d | \
        fzf --query="$1" --no-multi --select-1 --exit-0
    )
    if test -d $directory
        cd "$directory"
        if command -q eza
            eza --git --group-directories-first --long --icons --header --binary --group --sort=modified
        else
            ls -al --color=auto
        end
    end
end

function fif
    # Switch between Ripgrep mode and fzf filtering mode (CTRL-T)
    rm -f /tmp/rg-fzf-{r,f}
    set -x RG_PREFIX "rg --column --line-number --no-heading --color=always --smart-case "
    #INITIAL_QUERY="${*:-}"
    fzf --ansi --disabled --query "$argv" \
        --bind "start:reload:$RG_PREFIX {q}" \
        --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
        --bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ ripgrep ]] &&
        echo "rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-query:echo \{q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r" ||
        echo "unbind(change)+change-prompt(2. fzf> )+enable-search+transform-query:echo \{q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f"' \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --prompt '1. ripgrep> ' \
        --delimiter : \
        --border-label="| Find In Files |" \
        --header 'CTRL-T: Switch between ripgrep/fzf' \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind 'enter:become($EDITOR {1} +{2})'
end

#function path -d "environmental path"
#    echo $PATH | tr ":" "\n" | \
#        awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\") \
#    sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\") \
#    sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\") \
#    sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\") \
#        print }"
#    #sub(\"/.rvm\",  \"$fg_no_bold[red]/.rvm$reset_color\") \
#    #sub(\"/var\", \"$fg_no_bold[yellow]/local$reset_color\") \
#end

#function fpath
#    echo $FPATH | tr ":" "\n" | \
#        awk "{ sub(\"/usr\",   \"$fg_no_bold[green]/usr$reset_color\"); \
#    sub(\"/bin\",   \"$fg_no_bold[blue]/bin$reset_color\"); \
#    sub(\"/opt\",   \"$fg_no_bold[cyan]/opt$reset_color\"); \
#    sub(\"/sbin\",  \"$fg_no_bold[magenta]/sbin$reset_color\"); \
#    sub(\"/local\", \"$fg_no_bold[yellow]/local$reset_color\"); \
#        print }"
#    #sub(\"/.rvm\",  \"$fg_no_bold[red]/.rvm$reset_color\") \
#end
