set --local repo_dir (path resolve (status dirname)/..)
set --local fisher_installer (mktemp)
if not /bin/sh "$repo_dir/tools/fetch_fisher_verified.sh" >$fisher_installer
    command rm -f -- $fisher_installer
    return 1
end
builtin source $fisher_installer
set --local source_status $status
command rm -f -- $fisher_installer
if test $source_status -ne 0
    return $source_status
end
fisher install jorgebucaran/fisher@a04308be92daa6cfecdbb0ca58b1e8508664cff2
fisher install PatrickF1/fzf.fish@6a6136998879dcc1f29a405dfdd6b92c5f229c39
fisher install pure-fish/pure@1d458fa50ddbe8993376a290a5eb817cee8a31c0
