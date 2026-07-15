function fpwd --description "List paths under the current directory in fzf and copy selection to clipboard"
    set -l fd_cmd
    if type -q fd
        set fd_cmd fd
    else if type -q fdfind
        set fd_cmd fdfind
    end

    set -l selections
    if test -n "$fd_cmd"
        set selections (
            $fd_cmd -H -td -tf -tl -c=always . \
            | fzf -m --ansi --prompt="Copy Path(s)> "
        )
    else
        set selections (
            find . -not -path '*/.*' \
            | fzf -m --prompt="Copy Path(s)> "
        )
    end

    if test -z "$selections"
        return 0
    end

    # Clean up each path (remove leading ./ if present)
    set -l cleaned_paths
    for path in $selections
        set -a cleaned_paths (string replace -r '^\./' '' -- $path)
    end

    # Join the cleaned paths with newlines
    set -l clipboard_content (string join "\n" -- $cleaned_paths)

    # Copy to clipboard
    echo -n "$clipboard_content" | clipcopy

    # Print confirmation
    if test (count $cleaned_paths) -eq 1
        echo "Copied '$cleaned_paths[1]' to clipboard"
    else
        echo "Copied "(count $cleaned_paths)" paths to clipboard:"
        for path in $cleaned_paths
            echo "  - $path"
        end
    end
end
