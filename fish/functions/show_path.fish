function show_path -d "Display PATH with colorized directories"
    set home $HOME
    string split0 $PATH | while read -l p
        if string match -rq "^$home" $p
            set_color purple
        else if string match -rq "/sbin" $p
            set_color magenta
        else if string match -rq "/local" $p
            set_color yellow
        else if string match -rq ".rvm" $p
            set_color red
        else if string match -rq "/opt" $p
            set_color cyan
        else if string match -rq "/bin" $p
            set_color blue
        else if string match -rq "/usr" $p
            set_color green
        else
            set_color normal
        end
        echo $p
    end
    set_color normal
end
