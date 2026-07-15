# Repository Guidelines

## Project Structure & Module Organization

This repository is a package-oriented dotfiles collection for macOS, Linux, and WSL. Top-level directories generally correspond to one tool or environment: `fish/`, `zsh/`, `tmux/`, `ghostty/`, `git/`, and `homebrew/` contain the primary configurations; `mac-os/`, `windows/`, and `wsl/` hold platform-specific settings. Shared shell helpers live under `terminal/`, while many packages expose `env/`, `lib/`, or `setup/` hooks. Keep changes within the owning package and place user-facing usage notes beside it, as in `tmux/README.md`.

## Installation, Validation & Development Commands

There is no compiled build or unified test runner. Work incrementally and validate only the packages you changed.

- `git submodule update --init --recursive` initializes tracked external configurations.
- `zsh -n install_all.zsh` checks the bootstrap script without running installations.
- `fish --no-execute fish/config.fish` parses the main Fish configuration.
- `fish_indent --check path/to/file.fish` checks Fish formatting; omit `--check` to print the formatted result.
- `tmux -f tmux/tmux.conf -L dotfiles-check start-server \; kill-server` parses tmux configuration in an isolated server.
- `git diff --check` catches whitespace errors before review.

`install_all.zsh` installs Homebrew and Cargo dependencies and may alter the machine. Read it first; do not use it as a routine validation command.

## Coding Style & Naming Conventions

Follow nearby files and keep configuration minimal. Fish files use four spaces per `fish/.editorconfig`, LF endings, final newlines, and lowercase snake_case function names such as `find_in_files.fish`. Name tool setup entry points `setup/setup` and dependency manifests `dependencies` where that package pattern already exists. Use comments to explain platform constraints or non-obvious keybindings, not restate commands. Never commit secrets, private keys, tokens, generated caches, or machine-specific environment values.

## Testing Guidelines

Run a syntax or parse check for every edited shell/configuration language, then manually reload the affected tool in a fresh process. For interactive changes, exercise the exact workflow: launch a clean Fish shell, create an isolated tmux session, or restart the terminal. Record commands and observed behavior in the pull request. There is no repository-wide coverage target.

## Commit & Pull Request Guidelines

Recent history uses short, imperative, scoped subjects such as `fish: share one fzf previewer` and `tmux: harden copy-mode`. Keep each commit focused on one tool or behavior. Pull requests should explain the motivation, list platforms tested, include validation commands, link relevant issues, and attach screenshots for visible terminal/theme changes. Call out new dependencies and migration or rollback steps explicitly.
