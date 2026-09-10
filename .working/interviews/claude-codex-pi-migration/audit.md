# Claude Code to Codex and Pi parity audit

Date: 2026-09-09

## Decision

- Codex daily-driver mode is `workspace-write` plus `on-request` approvals and
  `auto_review`. This preserves the sandbox while sending eligible boundary
  decisions to OpenAI's reviewer instead of interrupting Eddy.
- Destructive or irreversible actions, secrets, writes outside the active
  workspace, publication, deployment, production, live-store, remote
  infrastructure, and network mutations remain human decisions.
- `cdx` launches that exact mode explicitly. The same defaults also live in
  `~/.codex/config.toml`, so ordinary `codex` receives them.
- `codex --yolo` is removed from `cdx`. It combined full filesystem access with
  no approvals and did not meet the requested safety boundary.
- `cc` now launches Claude with `--permission-mode auto`; its former
  `--allow-dangerously-skip-permissions` flag exposed the same unsafe gap.

## Installed runtimes

| Runtime | Version | Entry point | Configuration ownership |
| --- | --- | --- | --- |
| Claude Code | 2.1.266 | `~/.local/bin/claude` | Repository-managed settings, keybindings, and global instructions |
| Codex CLI | 0.153.4 | `~/.local/bin/codex` | Repository-managed config, global instructions, skills, and hooks |
| Pi pilot | 0.82.1 | `./pi/pilot.sh` | Repository-managed, pinned, and isolated under `~/.local/state/pi-pilot` |

There is deliberately no plain `pi` command. The pilot does not consume or
modify `~/.pi`.

## Parity matrix

| Capability | Claude Code | Codex | Pi pilot | Result |
| --- | --- | --- | --- | --- |
| Autonomous safe work | `defaultMode: auto` | sandbox plus Auto-review | provider/tool policies | Codex configured; Pi remains pilot-scoped |
| External prompt editor | `Ctrl+G` -> `chat:externalEditor` | native `Ctrl+G` | native `Ctrl+G` | All resolve `$VISUAL` to the shared Neovim shim |
| Instructions | `CLAUDE.md` adapter | `AGENTS.md` symlink | isolated `AGENTS.md` symlink | One canonical repository source |
| Personal skills | `~/.claude/skills` | `~/.codex/skills` | seven explicit paths | Claude/Codex share the complete private tree; Pi stays curated |
| Context and token display | custom status command | native status line plus `/status` | native footer and benchmark evidence | Available on all three |
| Session persistence | native | native resume/fork | named resume/tree | Available on all three |
| Compaction | native | native | explicit 16,384-token reserve and 20,000 recent-token window | Available on all three |
| Herdr lifecycle state | Claude hooks | Codex hooks | compatibility extension | Available on all three |
| Ready-prompt replay | `Prefix+b` and `Prefix+B` | same Herdr path | same Herdr path | Shared parser and prompt-editor seam |
| Model picker | native | `/model` | `Ctrl+Shift+M` | Available; keys intentionally differ |
| Provider cost | Claude status/API dependent | token counts and rate limits; no native monetary cost | token counts and provider-reported cost | No exact Codex monetary-cost equivalent |

## Applied changes

- `cdx` now expands to:
  `codex --sandbox workspace-write --ask-for-approval on-request -c approvals_reviewer=auto_review`.
- `cc` now expands to `claude --permission-mode auto`.
- Codex defaults now set `approval_policy = "on-request"`,
  `sandbox_mode = "workspace-write"`, and `approvals_reviewer = "auto_review"`.
- Codex Auto-review policy denies destructive, secret-bearing, publishing,
  production, live-store, remote-infrastructure, and network-mutating actions.
- Codex's status line now shows model/reasoning, directory, Git branch, context
  remaining, used tokens, and five-hour and weekly rate limits when available.
- Codex explicitly maps the external editor to `Ctrl+G`.
- Claude's local keybindings JSON had a missing comma and a trailing comma; it
  is valid again, with both `Ctrl+G` and `Ctrl+X Ctrl+E` mapped to the external
  editor.
- The shared closeout-length regression fixture now derives its cap and width
  from the hook, preventing another cap-change drift.

## Deliberate gaps and remaining checks

- Do not run Codex `/import` for settings or skills: the canonical adapters and
  symlinks already preserve the stronger local setup. `/import` is useful only
  if Eddy wants recent Claude conversations imported.
- Do not enable every shared skill in Pi without a new context-budget review.
  Pi's seven-skill allowlist is a tested isolation decision, not missing data.
- `~/.codex/config.toml` and `~/.claude/keybindings.json` are tracked under
  `agent-config/` and installed through reviewed, backup-preserving symlinks.
- Codex launched with strict configuration and reported Auto-review plus the
  configured footer. Eddy physically confirmed `Ctrl+G` in Codex and Pi plus
  session-scoped closeouts across two independent Herdr windows on 2026-09-10.
- Fish's functional verification passed, but the Starship latency gate remained
  red: 50.334 ms and 60.158 ms p95 against a 50 ms ceiling. The `cdx`
  abbreviation does not execute during prompt rendering, so no causal link was
  found.

## Current commands

```sh
cdx
codex
./pi/pilot.sh --name project-review
```

In Codex, use `Ctrl+G` for the external editor, `/status` for the complete
runtime/permission/token report, and `/statusline` to alter footer fields.

## Primary references

- Codex Auto-review: <https://learn.chatgpt.com/docs/sandboxing/auto-review>
- Codex approvals and security: <https://learn.chatgpt.com/docs/agent-approvals-security>
- Codex CLI commands: <https://learn.chatgpt.com/docs/developer-commands?surface=cli>
- Claude Code import: <https://learn.chatgpt.com/docs/import>
