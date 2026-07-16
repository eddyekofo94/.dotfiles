# Fish manual QA

- Open a fresh interactive Fish shell and confirm the Starship prompt and right
  prompt render once without flicker.
- Change into a Git repository and a non-repository directory; confirm prompt
  information updates without delayed or orphaned output.
- Run `true`, a failing command, and `cd ..`; confirm post-exec and directory
  hooks behave normally.
- Open a second terminal or tmux pane and confirm keybindings, fzf bindings, and
  abbreviations are available.
- After several minutes of normal use, run `fish/scripts/workflow_status.sh` and
  confirm no unexpected Fish workers accumulate.
- Run `fif` without an initial query. Confirm it stays idle until two characters
  are entered, then returns content matches after roughly 50 milliseconds.
- Confirm `fif` does not search through symlinked directories by default, then
  run `fif --follow PATH QUERY` and confirm linked content is included.
- Confirm a single argument such as `fif FZF` is treated as a query even when a
  directory with the same case-insensitive name exists. Use `fif --path DIR`
  when starting interactively in an explicit directory without a query.
- Move rapidly through several `fif` results and confirm previews update without
  visible configuration startup, stale output, or delayed terminal redraws.
- In tmux, run `fe` over a directory containing PNGs and move rapidly between
  images. Confirm each preview redraws with clear pixels, without black
  placeholder glyphs, heavy pixelation, stale image fragments, or visible
  control text such as `033[m`.
- In the same directory, press Ctrl-T and confirm PNGs use the same image
  previewer instead of showing a `bat` binary-content warning.
- In `fe` and Ctrl-T, type a query and press Ctrl-U. Confirm it clears the query
  using fzf's native behavior. Confirm Ctrl-F scrolls the preview forward one
  page and Ctrl-B scrolls it backward one page.
