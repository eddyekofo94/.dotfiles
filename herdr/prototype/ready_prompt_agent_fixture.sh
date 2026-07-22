#!/bin/sh
set -eu

# Present a clean interactive Fish pane with an agent-shaped argv[0].
fish_bin=$(command -v fish)
exec /bin/bash -c 'exec -a codex "$1" --no-config' ready-prompt-fixture "$fish_bin"
