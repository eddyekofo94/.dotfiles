function _fzf_preview_image -d "fzf preview: paint an image into a preview pane"
    argparse 'cols=' 'rows=' 'offset=' -- $argv; or return 1

    set -l target $argv[1]
    test -n "$target"; or return 0

    # Callers own the pane geometry: they know how many rows their own header
    # already spent, which decides where the image may start.
    set -l cols $_flag_cols
    string match -qr '^[0-9]+$' -- "$cols"; or set cols 120
    set -l rows $_flag_rows
    string match -qr '^[0-9]+$' -- "$rows"; or set rows 40
    set -l offset $_flag_offset
    string match -qr '^[0-9]+$' -- "$offset"; or set offset 0

    set -l kitten_cmd (command -s kitten)
    if test -z "$kitten_cmd"; and test -x /Applications/kitty.app/Contents/MacOS/kitten
        set kitten_cmd /Applications/kitty.app/Contents/MacOS/kitten
    end

    if test -n "$kitten_cmd"
        if set -q FZF_PREVIEW_TEST_REPORT_GEOMETRY
            printf 'FZF_PREVIEW_IMAGE_PLACE:%sx%s@0x%s\n' "$cols" "$rows" "$offset"
        end
        # Shared-memory transfer keeps the terminal payload small, so a
        # cancelled fzf preview cannot strand a partial image transfer.
        # Production uses Ghostty's real cell geometry. Tests provide a
        # deterministic substitute because their pseudo-terminal cannot
        # answer pixel-size queries.
        set -l window_size_arg
        if set -q FZF_PREVIEW_TEST_WINDOW_SIZE
            set -l pixel_width (math "$cols * 10")
            set -l pixel_height (math "$rows * 20")
            set window_size_arg --use-window-size="$cols,$rows,$pixel_width,$pixel_height"
        end

        "$kitten_cmd" icat --clear --transfer-mode=memory \
            --unicode-placeholder --stdin=no --scale-up $window_size_arg \
            --place=$cols"x"$rows"@0x"$offset "$target" \
            | perl -0777 -pe 's/\n[^\n]*\z/\e[m\n/s'
    else if type -q chafa
        chafa -f symbols --colors full --animate=off --polite=on \
            --size=$cols"x"$rows "$target"
    else
        file -b -- "$target"
    end
end
