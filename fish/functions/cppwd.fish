function cppwd --description "Copy the current directory, or the given paths, to the clipboard"
    set -l targets $argv
    test (count $targets) -gt 0; or set targets $PWD

    set -l resolved
    for target in $targets
        if test -e "$target"
            set -a resolved (path resolve -- "$target")
        else
            echo >&2 "cppwd: no such path: $target"
            return 1
        end
    end

    # Escape so the clipboard can be pasted straight back as command arguments
    set -l joined (string join " " (string escape -- $resolved))
    echo -n $joined | clipcopy

    echo "Copied to clipboard:"
    for path in $resolved
        echo "  $path"
    end
end
