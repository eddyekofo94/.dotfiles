# Source - https://stackoverflow.com/a/39757011
# Posted by faho
# Retrieved 2025-12-13, License - CC BY-SA 3.0

function rm_from_path
    # This only uses the first argument
    # if you want more, use a for-loop
    # Or you might want to error `if set -q argv[2]`
    # The "--" here is to protect from arguments or $PATH components that start with "-"
    set -l index (contains -i -- $argv[1] $PATH)
    # If the contains call fails, it returns nothing, so $index will have no elements
    # (all variables in fish are lists)
    if set -q index[1]
        set -e PATH[$index]
    else
        return 1
    end
end
