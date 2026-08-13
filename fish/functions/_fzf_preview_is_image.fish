function _fzf_preview_is_image -d "fzf preview: true when a path names an image the previewer can paint"
    set -l target $argv[1]
    test -n "$target"; or return 1

    switch (string lower (path extension -- "$target"))
        case .png .jpg .jpeg .gif .webp .bmp .tif .tiff .avif .jxl .qoi .svg .ico
            return 0
        case '*'
            return 1
    end
end
