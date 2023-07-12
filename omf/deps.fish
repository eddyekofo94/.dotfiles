curl -L https://get.oh-my.fish > install &&
            fish install --path=~/.local/share/omf --config=~/.config/omf &&
            omf install https://github.com/jhillyerd/plugin-git
        omf install bang-bang;
        omf install https://github.com/edc/bass;
        omf install pisces
