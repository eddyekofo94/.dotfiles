#!/bin/sh
set -eu

command_path=$0
if [ -L "$command_path" ]; then
  command_target=$(readlink "$command_path")
  case $command_target in
    /*) command_path=$command_target ;;
    *) command_path=$(dirname -- "$command_path")/$command_target ;;
  esac
fi
pi_dir=$(CDPATH= cd -- "$(dirname -- "$command_path")" && pwd)
exec "$pi_dir/pilot.sh" "$@"
