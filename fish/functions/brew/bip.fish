# Install (one or multiple) selected application(s)
# using "brew search" as source input
# mnemonic [B]rew [I]nstall [P]ackage
function bip -d "[B]rew [I]nstall [P]ackage"
    set -l inst (brew search "$argv" | fzf -m)

    if test (count $inst) -gt 0
        for file in (echo $inst)
            brew install $file
        end
    end
end
