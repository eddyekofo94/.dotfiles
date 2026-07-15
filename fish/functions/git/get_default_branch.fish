function get_default_branch --description 'Print the default branch name (main or master)'
    git branch -l main master 2>/dev/null | string trim | string replace -r '^\* ' '' | head -n 1
end
