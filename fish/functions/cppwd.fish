function cppwd --description "Copy current working directory to clipboard"
    echo -n $PWD | clipcopy
    echo "Copied $PWD to clipboard"
end
