!#/usr/local/bin/fish

set my_path (pwd)
echo $my_path
for file in  $my_path
    # Your logic: check if file is in the cached/staged list
    if git diff --name-only --cached | grep -qx -- \$file
        echo $my_path

        echo \$file
    else
        echo \$file
    end
end
