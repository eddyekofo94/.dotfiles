# uv installs commands in $HOME/.local/bin. __init__.fish owns that canonical
# PATH entry, so do not source uv's generated noncanonical
# $HOME/.local/share/../bin alias here.
