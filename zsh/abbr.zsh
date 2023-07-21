abbr ..="cd .." --quiet
abbr ....="cd ../.." --quiet
abbr -S g=git --quiet
abbr -S ga='git add' --quiet
abbr -S gaa='git add --all' --quiet
abbr -S gau='git add --update' --quiet
abbr -S gapa='git add --patch' --quiet
abbr -S gap='git apply' --quiet
abbr -S gb='git branch -vv' --quiet
abbr -S gba='git branch -a -v' --quiet
abbr -S gban='git branch -a -v --no-merged' --quiet
abbr -S gbd='git branch -d' --quiet
abbr -S gbD='git branch -D' --quiet
abbr -S ggsup='git branch --set-upstream-to=origin/(__git.current_branch)' --quiet
abbr -S gbl='git blame -b -w' --quiet
abbr -S gbs='git bisect' --quiet
abbr -S gbsb='git bisect bad' --quiet
abbr -S gbsg='git bisect good' --quiet
abbr -S gbsr='git bisect reset' --quiet
abbr -S gbss='git bisect start' --quiet
abbr -S gc='git commit -v' --quiet
abbr -S gc!='git commit -v --amend' --quiet
abbr -S gcn!='git commit -v --no-edit --amend' --quiet
abbr -S gca='git commit -v -a' --quiet
abbr -S gca!='git commit -v -a --amend' --quiet
abbr -S gcan!='git commit -v -a --no-edit --amend' --quiet
abbr -S gcv='git commit -v --no-verify' --quiet
abbr -S gcav='git commit -a -v --no-verify' --quiet
abbr -S gcav!='git commit -a -v --no-verify --amend' --quiet
abbr -S gcm='git commit -m' --quiet
abbr -S gcam='git commit -a -m' --quiet
abbr -S gcs='git commit -S' --quiet
abbr -S gscam='git commit -S -a -m' --quiet
abbr -S gcfx='git commit --fixup' --quiet
abbr -S gcf='git config --list' --quiet
abbr -S gcl='git clone' --quiet
abbr -S gclean='git clean -di' --quiet
abbr -S gclean!='git clean -dfx' --quiet
abbr -S gclean!!='git reset --hard; and git clean -dfx' --quiet
abbr -S gcount='git shortlog -sn' --quiet
abbr -S gcp='git cherry-pick' --quiet
abbr -S gcpa='git cherry-pick --abort' --quiet
abbr -S gcpc='git cherry-pick --continue' --quiet
abbr -S gd='git diff' --quiet
abbr -S gdca='git diff --cached' --quiet
abbr -S gds='git diff --stat' --quiet
abbr -S gdsc='git diff --stat --cached' --quiet
abbr -S gdt='git diff-tree --no-commit-id --name-only -r' --quiet
abbr -S gdw='git diff --word-diff' --quiet
abbr -S gdwc='git diff --word-diff --cached' --quiet
abbr -S gdto='git difftool' --quiet
abbr -S gignore='git update-index --assume-unchanged' --quiet
abbr -S gf='git fetch' --quiet
abbr -S gfa='git fetch --all --prune' --quiet
abbr -S gfm='git fetch origin (__git.default_branch) --prune; and git merge FETCH_HEAD' --quiet
abbr -S gfo='git fetch origin' --quiet
abbr -S gl='git pull' --quiet
abbr -S ggl='git pull origin (__git.current_branch)' --quiet
abbr -S gll='git pull origin' --quiet
abbr -S glr='git pull --rebase' --quiet
abbr -S glg='git log --stat' --quiet
abbr -S glgg='git log --graph' --quiet
abbr -S glgga='git log --graph --decorate --all' --quiet
abbr -S glo='git log --oneline --decorate --color' --quiet
abbr -S glog='git log --oneline --decorate --color --graph' --quiet
abbr -S gloga='git log --oneline --decorate --color --graph --all' --quiet
abbr -S glom='git log --oneline --decorate --color (__git.default_branch)..' --quiet
abbr -S glod='git log --oneline --decorate --color develop..' --quiet
abbr -S gloo=git\ log\ --pretty=format:\'\%C\(yellow\)\%h\ \%Cred\%ad\ \%Cblue\%an\%Cgreen\%d\ \%Creset\%s\'\ --date=short --quiet
abbr -S gm='git merge' --quiet
abbr -S gmt='git mergetool --no-prompt' --quiet
abbr -S gmom='git merge origin/(__git.default_branch)' --quiet
abbr -S gp='git push' --quiet
abbr -S gp!='git push --force-with-lease' --quiet
abbr -S gpo='git push origin' --quiet
abbr -S gpo!='git push --force-with-lease origin' --quiet
abbr -S gpv='git push --no-verify' --quiet
abbr -S gpv!='git push --no-verify --force-with-lease' --quiet
abbr -S ggp='git push origin (__git.current_branch)' --quiet
abbr -S ggp!='git push origin (__git.current_branch) --force-with-lease' --quiet
abbr -S gpu='git push origin (__git.current_branch) --set-upstream' --quiet
abbr -S gpoat='git push origin --all; and git push origin --tags' --quiet
abbr -S ggpnp='git pull origin (__git.current_branch); and git push origin (__git.current_branch)' --quiet
abbr -S gr='git remote -vv' --quiet
abbr -S gra='git remote add' --quiet
abbr -S grb='git rebase' --quiet
abbr -S grba='git rebase --abort' --quiet
abbr -S grbc='git rebase --continue' --quiet
abbr -S grbi='git rebase --interactive' --quiet
abbr -S grbm='git rebase (__git.default_branch)' --quiet
abbr -S grbmi='git rebase (__git.default_branch) --interactive' --quiet
abbr -S grbmia='git rebase (__git.default_branch) --interactive --autosquash' --quiet
abbr -S grbom='git fetch origin (__git.default_branch); and git rebase FETCH_HEAD' --quiet
abbr -S grbomi='git fetch origin (__git.default_branch); and git rebase FETCH_HEAD --interactive' --quiet
abbr -S grbomia='git fetch origin (__git.default_branch); and git rebase FETCH_HEAD --interactive --autosquash' --quiet
abbr -S grbd='git rebase develop' --quiet
abbr -S grbdi='git rebase develop --interactive' --quiet
abbr -S grbdia='git rebase develop --interactive --autosquash' --quiet
abbr -S grbs='git rebase --skip' --quiet
abbr -S ggu='git pull --rebase origin (__git.current_branch)' --quiet
abbr -S grev='git revert' --quiet
abbr -S grh='git reset' --quiet
abbr -S grhh='git reset --hard' --quiet
abbr -S grhpa='git reset --patch' --quiet
abbr -S grm='git rm' --quiet
abbr -S grmc='git rm --cached' --quiet
abbr -S grmv='git remote rename' --quiet
abbr -S grpo='git remote prune origin' --quiet
abbr -S grrm='git remote remove' --quiet
abbr -S grs='git restore' --quiet
abbr -S grset='git remote set-url' --quiet
abbr -S grss='git restore --source' --quiet
abbr -S grst='git restore --staged' --quiet
abbr -S grup='git remote update' --quiet
abbr -S grv='git remote -v' --quiet
abbr -S gsh='git show' --quiet
abbr -S gsd='git svn dcommit' --quiet
abbr -S gsr='git svn rebase' --quiet
abbr -S gss='git status -s' --quiet
abbr -S gst='git status' --quiet
abbr -S gsta='git stash' --quiet
abbr -S gstd='git stash drop' --quiet
abbr -S gstl='git stash list' --quiet
abbr -S gstp='git stash pop' --quiet
abbr -S gsts='git stash show --text' --quiet
abbr -S gsu='git submodule update' --quiet
abbr -S gsur='git submodule update --recursive' --quiet
abbr -S gsuri='git submodule update --recursive --init' --quiet
abbr -S gts='git tag -s' --quiet
abbr -S gtv='git tag' --quiet
abbr -S gsw='git switch' --quiet
abbr -S gswc='git switch --create' --quiet
abbr -S gunignore='git update-index --no-assume-unchanged' --quiet
abbr -S gup='git pull --rebase' --quiet
abbr -S gupv='git pull --rebase -v' --quiet
abbr -S gupa='git pull --rebase --autostash' --quiet
abbr -S gupav='git pull --rebase --autostash -v' --quiet
abbr -S gwch='git whatchanged -p --abbrev-commit --pretty=medium' --quiet
abbr -S gco='git checkout' --quiet
abbr -S gcb='git checkout -b' --quiet
abbr -S gcod='git checkout develop' --quiet
abbr -S gcom='git checkout (__git.default_branch)' --quiet
abbr -S gfb='git flow bugfix' --quiet
abbr -S gff='git flow feature' --quiet
abbr -S gfr='git flow release' --quiet
abbr -S gfh='git flow hotfix' --quiet
abbr -S gfs='git flow support' --quiet
abbr -S gfbs='git flow bugfix start' --quiet
abbr -S gffs='git flow feature start' --quiet
abbr -S gfrs='git flow release start' --quiet
abbr -S gfhs='git flow hotfix start' --quiet
abbr -S gfss='git flow support start' --quiet
abbr -S gfbt='git flow bugfix track' --quiet
abbr -S gfft='git flow feature track' --quiet
abbr -S gfrt='git flow release track' --quiet
abbr -S gfht='git flow hotfix track' --quiet
abbr -S gfst='git flow support track' --quiet
abbr -S gfp='git flow publish' --quiet
abbr -S gwt='git worktree' --quiet
abbr -S gwta='git worktree add' --quiet
abbr -S gwtls='git worktree list' --quiet
abbr -S gwtlo='git worktree lock' --quiet
abbr -S gwtmv='git worktree move' --quiet
abbr -S gwtpr='git worktree prune' --quiet
abbr -S gwtrm='git worktree remove' --quiet
abbr -S gwtulo='git worktree unlock' --quiet
abbr -S gmr='git push origin (__git.current_branch) --set-upstream -o merge_request.create' --quiet
abbr -S gmwps='git push origin (__git.current_branch) --set-upstream -o merge_request.create -o merge_request.merge_when_pipeline_succeeds' --quiet
abbr -S lg=lazygit --quiet
abbr -S lzd=lazydocker --quiet
abbr -S vim=nvim --quiet
abbr -S vi=vim --quiet
abbr -S bgr=batgrep --quiet
abbr -S cg=cargo --quiet
abbr -S cgc='cargo clean' --quiet
abbr -S cgi='cargo install' --quiet
abbr -S cgn='cargo new' --quiet
abbr -S cgs='cargo search' --quiet
abbr -S cgt='cargo test' --quiet
abbr -S cgu='cargo uninstall' --quiet
abbr -S cgug='cargo upgrade' --quiet
abbr -S h=history --quiet
abbr -S hg='history | grep ' --quiet