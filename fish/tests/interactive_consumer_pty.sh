#!/bin/sh
set -eu

command -v expect >/dev/null 2>&1 || {
    echo 'Fish interactive PTY: expect is required' >&2
    exit 1
}

package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/fish-interactive-pty.XXXXXX")
trap 'find "$tmp_dir" -depth -delete' EXIT HUP INT TERM

fixture_dir="$tmp_dir/repo"
fixture_home="$tmp_dir/home"
mkdir -p "$fixture_dir" "$fixture_home/.config"
ln -s "$package_dir" "$fixture_home/.config/fish"

printf '%s' \
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' \
    | base64 -D >"$fixture_dir/fixture.png"
printf 'FISH_PTY_TEXT_SENTINEL\n' >"$fixture_dir/fixture.txt"
git -C "$fixture_dir" init -q

env FISH_PTY_FIXTURE="$fixture_dir" FISH_PTY_HOME="$fixture_home" \
    expect <<'EXPECT_EOF'
log_user 0
set timeout 10
set fixture $env(FISH_PTY_FIXTURE)
set fixture_home $env(FISH_PTY_HOME)

proc fail {message} {
    puts stderr "Fish interactive PTY: $message"
    exit 1
}

cd $fixture
spawn env TERM=xterm-256color FZF_PREVIEW_TEST_WINDOW_SIZE=1 \
    FZF_PREVIEW_TEST_REPORT_GEOMETRY=1 \
    HOME=$fixture_home sh -c {stty rows 40 cols 120; exec fish -i}

# Fish probes terminal capabilities before drawing its first prompt. Answer the
# deterministic subset used by this pseudo-terminal, and keep doing so while
# full-screen fzf applications enter and leave alternate-screen mode.
expect_before {
    -exact "\033\[0c" {
        send "\033\[?1;2c"
        exp_continue
    }
    -exact "\033\]11;?\033\\" {
        send "\033\]11;rgb:1e1e/1e1e/2e2e\033\\"
        exp_continue
    }
    -exact "\033\[6n" {
        send "\033\[24;1R"
        exp_continue
    }
    -re {Binary content from file} {
        fail "Ctrl-T sent an image to bat"
    }
}

proc wait_prompt {} {
    global spawn_id
    expect {
        -exact "\033\]133;B\033\\" { return }
        timeout { fail "prompt did not return" }
    }
}

wait_prompt

# Replace only the prompt renderer after startup so subsequent return checks
# are stable. Reader initialization, plugin loading, and bindings remain real.
send "function fish_prompt; printf 'FISH_PTY_READY> '; end; function __fish_pty_report; printf '\\nFISH_PTY_SELECTED:%s\\n' (commandline); commandline -r ''; commandline -f repaint; end; bind \\cx __fish_pty_report; bind -M insert \\cx __fish_pty_report\r"
expect {
    -exact "\033\]133;C;" {}
    timeout { fail "stable prompt could not be installed" }
}
wait_prompt

# Verify interactive-only consumers after Fish's reader has applied the custom
# binding function. This catches shells that merely define functions without
# wiring them into the live reader. The sentinel is assembled at runtime so this
# matches command output rather than the terminal echo of the command itself.
# Both directories are resolved before comparing: $TMPDIR contributes a doubled
# separator and Fish reports the physical path, so the raw strings differ even
# when startup left the cwd alone.
send "test (path resolve \$PWD) = (path resolve \$FISH_PTY_FIXTURE); and functions -q _fzf_search_directory magic-enter fifc; and test \"\$fzf_preview_file_cmd\" = _fzf_preview; and printf 'FISH_PTY_STATE_%s\\n' OK\r"
expect {
    -exact "\033\]133;C;" {}
    timeout { fail "interactive state command did not execute" }
}
expect {
    -exact "FISH_PTY_STATE_OK" {}
    timeout { fail "startup changed cwd or interactive consumers are missing" }
}
wait_prompt

# Autopair is a physical reader interaction rather than a function-existence
# check. Cancel the populated command line without executing it.
send "("
expect {
    -exact "()" {}
    timeout { fail "autopair did not insert the closing parenthesis" }
}
send "\030"
expect {
    -exact "FISH_PTY_SELECTED:()" {}
    timeout { fail "autopair command line could not be cleared" }
}
after 100

# Exercise every retained FZF control byte through the live reader.
send "\022"
expect {
    -re {History>} {}
    timeout { fail "Ctrl-R did not open history search" }
}
send "\033"
wait_prompt

send "\007"
expect {
    -re {Git Status>} {}
    timeout { fail "Ctrl-G did not open Git status search" }
}
send "\033"
wait_prompt

# Ctrl-P must still select a file into the command line, not only open fzf.
send "fixture.txt"
send "\020"
expect {
    -re {Directory[^>]*>} {}
    timeout { fail "Ctrl-P did not open directory search" }
}
expect {
    -exact "1/2 (0)" {}
    timeout { fail "Ctrl-P query did not settle on fixture.txt" }
}
send "\r"
wait_prompt
send "\030"
expect {
    -exact "FISH_PTY_SELECTED:fixture.txt" {}
    timeout { fail "Ctrl-P did not return the selected file" }
}
after 100

# Ctrl-T uses the same retained picker, but the selected PNG must reach the
# canonical Kitty image transport instead of bat. Under tmux the Kitty escape
# is wrapped, so accept either the direct or wrapped protocol prefix.
send "fixture.png"
send "\024"
expect {
    -re {Directory[^>]*>} {}
    timeout { fail "Ctrl-T did not open directory search" }
}
expect {
    -exact "FZF_PREVIEW_GEOMETRY:62,35" {}
    -re {FZF_PREVIEW_GEOMETRY:([0-9]+),([0-9]+)} {
        fail "retained picker exported $expect_out(1,string)x$expect_out(2,string), expected 62x35"
    }
    timeout { fail "retained picker did not export its exact preview geometry" }
}
expect {
    -exact "\033_G" {}
    -exact "\033\033_G" {}
    timeout { fail "Ctrl-T image preview did not emit Kitty image data" }
}
send "\r"
wait_prompt
send "\030"
expect {
    -exact "FISH_PTY_SELECTED:fixture.png" {}
    timeout { fail "Ctrl-T did not return the selected image" }
}
after 100

# Color settings that separate processes read must live in the environment, not
# only in global Fish variables. fish_indent renders the Ctrl-R history preview
# as a child of the reader, so unexported theme colors leave that preview
# monochrome while the shell itself still looks correctly highlighted. Comparing
# byte counts avoids escaping escape sequences. LS_COLORS is the same class of
# setting but is generated into a cache this fixture home does not have, so the
# environment audit covers it instead.
send "set -qgx fish_color_command; and test (printf 'echo hi\\n' | fish_indent --ansi | wc -c) -gt (printf 'echo hi\\n' | fish_indent | wc -c); and printf 'FISH_PTY_COLOR_%s\\n' ENV_OK\r"
expect {
    -exact "FISH_PTY_COLOR_ENV_OK" {}
    timeout { fail "theme colors are not exported, so child previews render monochrome" }
}
wait_prompt

# Vi mode has to reach the reader through a binding function name that
# mode-aware prompts recognize. Starship only forwards $fish_bind_mode when
# $fish_key_bindings names a vi/hybrid function, so naming the user hook here
# silently pins the prompt to insert and the vimcmd symbol never appears.
# The sentinel is assembled at runtime so this matches command output rather
# than the terminal echo of the command itself.
send "contains -- \"\$fish_key_bindings\" fish_vi_key_bindings fish_hybrid_key_bindings; and printf 'FISH_PTY_VI_%s\\n' BINDINGS_OK\r"
expect {
    -exact "FISH_PTY_VI_BINDINGS_OK" {}
    timeout { fail "\$fish_key_bindings does not name a vi binding function" }
}
wait_prompt

# `jj` must leave insert mode in the live reader, which is what drives the
# mode-aware prompt repaint.
send "function __fish_pty_mode; printf '\\nFISH_PTY_MODE:%s\\n' \$fish_bind_mode; commandline -f repaint; end; bind -M default \\cb __fish_pty_mode\r"
wait_prompt
send "jj"
after 200
send "\002"
expect {
    -exact "FISH_PTY_MODE:default" {}
    timeout { fail "jj did not switch the reader to normal mode" }
}
send "i"
after 100

send "exit\r"
expect eof
EXPECT_EOF

printf 'Fish interactive PTY: PASS\n'
