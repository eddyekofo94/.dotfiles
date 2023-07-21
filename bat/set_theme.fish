mkdir -p "$(bat --config-dir)/themes"
# cd "$(bat --config-dir)/themes"

# Download a theme in '.tmTheme' format, for example:
cp $HOME/.dotfiles/bat/Catppuccin-mocha.tmTheme $HOME/.config/bat/themes/

# Update the binary cache
bat cache --build
