#!/usr/local/bin/fish

set unameOut (uname -a)

switch $unameOut
    case "*Microsoft*"
        set OS "WSL" #wls must be first since it will have Linux in the name too
    case "*microsoft*"
        set OS "WSL2"
    case "Linux*"
        set OS "Linux"
    case "Darwin*"
        set OS "Mac"
    # Note that the next case has a wildcard which is quoted
    case '*'
        echo $unameOut
end

# NOTE: see if this works with a MacM1 if you ever get it one day!!
if string match -q -- $OS "Mac"; and sysctl -n machdep.cpu.brand_string | grep -q 'Apple M1'; then
    set OS "MacM1"
    echo $OS
end
echo $OS
