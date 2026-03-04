function funcdel --description 'Deletes a fish function both permanently and from memory'
    set -l fun_name $argv[1]
    set -l fun_file ~/.config/fish/functions/$fun_name.fish

    # Delete the in-memory function, if it exists
    functions --erase $fun_name

    # Delete the function permanently,
    # if it exists as a file in the regular location
    if test -e $fun_file
        rm $fun_file
    end
end
