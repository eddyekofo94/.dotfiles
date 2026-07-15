if not status is-interactive
    return
end

function __auto_pwd \
    --on-variable PWD \
    --description 'Print directory path after changing cwd'
    pwd
end
