# fif.fish Bug Analysis: CTRL-T Mode Toggle Broken

**File:** `fish/functions/fif.fish`

---

## Root Cause: Condition always evaluates to false

**Line 10 (inside ctrl-t transform):**
```fish
[ (echo $FZF_PROMPT | grep -q ripgrep) ]
```

**This is always false** — the condition can never match, so the `&&` branch never executes. CTRL-T never switches to fzf mode.

### Why

Three things combine to break it:

1. `grep -q` is quiet mode — it produces **no stdout**, communicates only via exit code
2. `(cmd)` is a fish command substitution — it captures **stdout**
3. `[ "string" ]` tests if string is **non-empty**

So the evaluation is:
```
(echo "1. ripgrep> " | grep -q ripgrep)   → exit code 0 (match), stdout ""
[ "" ]                                       → false (empty string)
```

The exit code of grep is discarded. Only the empty stdout matters → `[ "" ]` is always false.

### Proof

```fish
# BUG: always false
set FZF_PROMPT "1. ripgrep> "
[ (echo $FZF_PROMPT | grep -q ripgrep) ]
echo $status    # → 2   (WRONG, should be 0)

# FIX: check exit code directly
set FZF_PROMPT "1. ripgrep> "
echo $FZF_PROMPT | grep -q ripgrep
echo $status    # → 0   (CORRECT)
```

### Consequence

The `||` branch **always** runs:
```
rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-query:...
```

- `rebind(change)` — already bound (no-op)
- `change-prompt(1. ripgrep>)` — already set (no-op)
- `disable-search` — already disabled (no-op)

**CTRL-T does nothing.** The tool stays permanently in rg mode. This is why the user reports "it still searches inside files."

---

## Reference: Working ZSH Version

The zsh version uses native regex matching (`[[ ! $FZF_PROMPT =~ ripgrep ]]`) which works correctly:

```zsh
--bind 'ctrl-t:transform:[[ ! $FZF_PROMPT =~ ripgrep ]] &&
echo "rebind(change)+change-prompt(1. ripgrep> )+disable-search+transform-query:echo \{q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r" ||
echo "unbind(change)+change-prompt(2. fzf> )+enable-search+transform-query:echo \{q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f"'
```

---

## Fix: 3 Changes

### 1. Fix the condition — remove `[ (grep -q) ]` wrapper

Use `grep`'s exit code directly instead of wrapping it in command substitution + `[ ]`:

```fish
# BEFORE (BROKEN):
[ (echo $FZF_PROMPT | grep -q ripgrep) ] && echo "..." || echo "..."

# AFTER (FIXED):
echo "$FZF_PROMPT" | grep -q ripgrep && echo "..." || echo "..."
```

### 2. Replace `change:reload` with `change:transform` (avoids fragile `unbind`/`rebind`)

Instead of `unbind`/`rebind` in the ctrl-t toggle, use a single `change:transform` that checks the mode at runtime:

```fish
# BEFORE:
--bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \

# AFTER:
--bind "change:transform:echo \"\$FZF_PROMPT\" | grep -q ripgrep && echo \"reload:sleep 0.1; $RG_PREFIX {q} || true\" || echo ignore" \
```

Escaping: `\"\$FZF_PROMPT\"` inside fish double quotes → literal `echo "$FZF_PROMPT"` passed to fzf.

### 3. Remove `unbind(change)` / `rebind(change)` from ctrl-t (no longer needed)

Since `change:transform` handles both modes automatically, drop the unbind/rebind from the ctrl-t action.

---

## Final Desired File

```fish
function fif -d "find entry in files"
    rm -f /tmp/rg-fzf-{r,f}
    touch /tmp/rg-fzf-{r,f}
    set RG_PREFIX "rg --column --line-number --no-heading --color=always --smart-case "
    set INITIAL_QUERY "$argv"
    fzf --ansi --disabled --query "$INITIAL_QUERY" \
        --bind "start:reload:$RG_PREFIX {q}" \
        --bind "change:transform:echo \"\$FZF_PROMPT\" | grep -q ripgrep && echo \"reload:sleep 0.1; $RG_PREFIX {q} || true\" || echo ignore" \
        --bind 'ctrl-t:transform:echo "$FZF_PROMPT" | grep -q ripgrep &&
        echo "change-prompt(2. fzf> )+enable-search+transform-query:echo \{q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f" ||
        echo "change-prompt(1. ripgrep> )+disable-search+transform-query:echo \{q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r"' \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --prompt '1. ripgrep> ' \
        --delimiter : \
        --nth 1 \
        --border-label "| Find In Files |" \
        --header 'CTRL-T: Switch between ripgrep/fzf' \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
        --bind 'enter:become($EDITOR {1} +{2})'
end
```

---

## Behavior after fix

| Component | rg mode | fzf mode |
|-----------|---------|----------|
| `change:transform` | outputs `reload:rg...` → content search | outputs `ignore` → no action |
| Built-in search | disabled (`--disabled`) | enabled (`enable-search`) |
| CTRL-T | switches to fzf mode | switches back to rg mode |
| Typing in fzf mode | — | filters by filename (`--nth 1`) |
