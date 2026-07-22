#
# Setup Fisher for plugins.
#
function init_fisher
    argparse 'i/install' -- $argv; or return

    set -q fisher_path || set -gx fisher_path $__fish_config_dir/.fisher
    set -q my_plugins_path || set -gx my_plugins_path $__fish_config_dir/plugins

    if test "$fisher_paths_initialized" != true
        set --local idx (contains -i $__fish_config_dir/functions $fish_function_path || echo 1)
        set fish_function_path $fish_function_path[1..$idx] $fisher_path/functions $fish_function_path[(math $idx + 1)..]

        set --local idx (contains -i $__fish_config_dir/completions $fish_complete_path || echo 1)
        set fish_complete_path $fish_complete_path[1..$idx] $fisher_path/completions $fish_complete_path[(math $idx + 1)..]

        set -g fisher_paths_initialized true
    end

    if not test -d $fisher_path; and set -q _flag_install
        functions -e fisher &>/dev/null
        touch $__fish_config_dir/fish_plugins
        or return 1
        set --local fisher_installer (mktemp)
        set --local repo_dir (path resolve "$__fish_config_dir/..")
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
        mkdir -p $fisher_path
        or return 1
        if test -s $__fish_config_dir/fish_plugins
            fisher update
        else
            fisher install jorgebucaran/fisher@a04308be92daa6cfecdbb0ca58b1e8508664cff2
        end
        set --local install_status $status
        if test $install_status -ne 0
            # This invocation proved the target absent before creating it, so
            # only its incomplete output is eligible for cleanup.
            command find $fisher_path -depth -delete
            return $install_status
        end
    end

    for file in $fisher_path/conf.d/*.fish
        if ! test -f $__fish_config_dir/conf.d/(path basename -- $file)
            and test -f $file && test -r $file
            builtin source $file
        end
    end
end
