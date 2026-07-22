function __dotfiles_first_existing_directory --description 'Print the first existing directory candidate'
    for candidate in $argv
        if test -n "$candidate"; and test -d "$candidate"
            echo $candidate
            return 0
        end
    end
    return 1
end
