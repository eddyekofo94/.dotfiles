function _fzf_preview -d "fzf preview: render a path as a tree, image, hunk, or text"
    argparse 'as=' 'line=' -- $argv; or return 1

    set -l target $argv[1]
    test -n "$target"; or return 0

    set -l as auto
    set -q _flag_as; and set as $_flag_as

    # fzf exports the pane geometry; fall back to something sane when a caller
    # runs this outside a preview window.
    set -l cols $FZF_PREVIEW_COLUMNS
    string match -qr '^[0-9]+$' -- "$cols"; or set cols 120
    set -l rows $FZF_PREVIEW_LINES
    string match -qr '^[0-9]+$' -- "$rows"; or set rows 40

    # A hunk if the path has one, otherwise fall through and render the file
    # itself -- so untracked files still preview instead of coming up blank.
    if test "$as" = diff
        set -l hunk (git diff --color=always -- "$target" 2>/dev/null | sed 1,4d)
        if test -n "$hunk"
            printf '%s\n' $hunk
            return 0
        end
        set as auto
    end

    test -e "$target"; or return 0

    if test "$as" = auto
        if test -d "$target"
            set as dir
        else
            switch (string lower (path extension "$target"))
                case .png .jpg .jpeg .gif .webp .bmp .tif .tiff .avif .jxl .qoi .svg .ico
                    set as image
                case '*'
                    set as text
            end
        end
    end

    switch $as
        case dir
            eza -T -L 2 --color=always -- "$target"

        case image
            set -l kitten_cmd (command -s kitten)
            if test -z "$kitten_cmd"; and test -x /Applications/kitty.app/Contents/MacOS/kitten
                set kitten_cmd /Applications/kitty.app/Contents/MacOS/kitten
            end

            if test -n "$kitten_cmd"
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
                    --place=$cols"x"$rows"@0x0" "$target" \
                    | perl -0777 -pe 's/\n[^\n]*\z/\e[m\n/s'
            else if type -q chafa
                chafa -f symbols --colors full --animate=off --polite=on \
                    --size=$cols"x"$rows "$target"
            else
                file -b -- "$target"
            end

        case text
            if string match -qr '^[0-9]+$' -- "$_flag_line"
                # Centre the match in the pane rather than starting at it.
                set -l context (math "max(8, $rows - 2)")
                set -l before (math "floor(($context - 1) / 2)")
                set -l from (math "max(1, $_flag_line - $before)")
                set -l to (math "$from + $context - 1")
                bat --color=always --style=numbers,changes \
                    --highlight-line "$_flag_line" --line-range "$from:$to" \
                    --wrap=never --terminal-width "$cols" -- "$target"
            else
                bat --color=always --line-range :500 -- "$target"
            end
    end
end
