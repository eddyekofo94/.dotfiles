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
            # Ghostty speaks the kitty graphics protocol and will not implement
            # sixel; tmux implements sixel but not kitty. So pixels only arrive by
            # wrapping kitty sequences in tmux's DCS passthrough (allow-passthrough
            # is on in tmux.conf). --passthrough=auto wraps inside tmux and stays
            # bare outside it, and makes chafa emit kitty unicode placeholders, so
            # the image occupies real cells and survives fzf redrawing the pane.
            #
            # --animate=off matters: chafa loops GIFs forever otherwise, and a
            # preview that never returns hangs fzf.
            # chafa separates placeholder rows with `ESC[<n>D ESC D` (cursor back,
            # then IND) rather than newlines, and --relative=off does not change
            # that for kitty. fzf's preview is line-based, so it sees one enormous
            # line and clips it to the pane width -- leaving only row 0, a one-cell
            # strip of the image. Swap those separators for real newlines. Base64
            # payload cannot contain an ESC, so this only ever matches separators.
            if type -q chafa
                chafa -f kitty --passthrough=auto --animate=off \
                    --size=$cols"x"$rows "$target" \
                    | perl -0777 -pe 's/\e\[\d+D\eD/\n/g'
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
