# Pi coding-agent migration review

**Research date:** 2026-07-29  
**Repository assessed:** `/Users/eddyekofo/.dotfiles`  
**Decision:** whether to replace OpenAI Codex CLI and Claude Code with Pi, while
preserving Eddy's Herdr workflow and `Prefix+b` / `Prefix+B` ready-prompt
replay.

## Recommendation

Do not replace both Codex and Claude Code yet. Add Pi as a **third, isolated
daily-driver candidate**, port only the minimum personal workflow, and promote
it only after it passes representative work and physical Herdr QA.

Pi is a strong fit for the stated desire for an adaptable harness:

- its core is deliberately small in *product surface*;
- it can use many providers and switch models inside one session;
- its TypeScript extension API can add tools, commands, shortcuts, lifecycle
  handlers, custom compaction, and TUI components without forking Pi;
- its sessions and compaction are unusually transparent: append-only JSONL,
  tree navigation, explicit summaries, and full local history;
- it directly supports the Agent Skills format and both `AGENTS.md` and
  `CLAUDE.md`.

But “minimal” does not mean “all the capabilities Eddy currently uses, with
less machinery.” Pi deliberately omits built-in MCP, subagents, background
shell work, plan mode, permission prompts, and a sandbox. Those are exactly
some of the mature capabilities Codex and Claude Code currently provide.
Recreating them with extensions transfers maintenance and security ownership
to Eddy. Pi's own philosophy states these omissions explicitly.
[Pi README: philosophy](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md#philosophy)
[Pi security model](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md)

The practical decision is therefore:

> **Pilot Pi for its transparent session model and first-class extension API;
> retain Codex and Claude as fallbacks until Pi proves workflow, safety,
> provider-cost, and Herdr parity.**

## Identity and version boundary

“Pi” here means the open-source Pi agent harness originally associated with
Mario Zechner / `badlogic/pi-mono`. As of this research snapshot, the canonical
project is **`earendil-works/pi`**, and the current CLI package is
**`@earendil-works/pi-coding-agent`**. The old
`@mariozechner/pi-coding-agent` npm package is not the current package.
[Canonical repository](https://github.com/earendil-works/pi)
[Current package manifest](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/package.json)
[Current npm metadata](https://registry.npmjs.org/@earendil-works%2fpi-coding-agent/latest)
[Legacy npm metadata](https://registry.npmjs.org/@mariozechner%2fpi-coding-agent/latest)

The source snapshot inspected for this report was commit
`d7b02636a0c7e8e615d0cff70679d18d2ff59573`, with CLI version `0.82.1`.
The latest first-party release at inspection time was `v0.82.1`.
[Pi v0.82.1 release](https://github.com/earendil-works/pi/releases/tag/v0.82.1)

This ownership/package-scope transition is itself a reason to pin the pilot
version and avoid a same-day full migration.

## What “lightweight” means here

Pi is lightweight mainly in **policy and architecture**, not necessarily in
installed bytes:

- The default model-facing tool surface is only `read`, `write`, `edit`, and
  `bash`.
- Features are added through skills, prompt templates, extensions, and
  packages rather than accumulated in the core.
- It runs as an interactive TUI, print/JSON process, JSONL RPC server, or
  embeddable SDK.
[Pi README](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md)

The current npm build requires Node.js `>=22.19.0`. Its published package
metadata reports about 13 MB unpacked before its shrinkwrapped dependency
closure. A clean local `npm install --ignore-scripts` probe for `0.82.1`
occupied approximately **172 MB**. The official macOS arm64 standalone archive
is approximately **31.7 MB compressed**. These are installation observations,
not runtime-memory or startup-speed benchmarks.
[Package manifest](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/package.json)
[Release assets](https://github.com/earendil-works/pi/releases/tag/v0.82.1)

Codex is a native Rust executable described by OpenAI as a zero-dependency
install. Claude Code also ships as a native binary; Anthropic's npm package now
installs that platform binary rather than running the CLI under Node.
[Codex Rust CLI](https://github.com/openai/codex/blob/main/codex-rs/README.md)
[Claude Code installation](https://code.claude.com/docs/en/installation)

So the defensible claim is:

- Pi is **conceptually leaner and easier to reshape**.
- Pi is **not yet proven lighter in disk, RAM, startup time, or operational
  burden** on this Mac.

Those performance claims need an on-machine comparison, not marketing
language.

## Capability comparison

| Area | Pi 0.82.1 | Codex CLI | Claude Code | Migration implication |
|---|---|---|---|---|
| Core design | Minimal harness plus extensions | Integrated coding agent and OpenAI surfaces | Integrated coding agent and Anthropic surfaces | Pi gives the most direct ownership of behavior |
| Models/providers | Broad built-in multi-provider catalog, custom providers, model switching | OpenAI/Codex-centered | Anthropic plus supported cloud providers | Pi is strongest when one UI across providers matters |
| Skills | Agent Skills, progressive disclosure, explicit `/skill:name` | Agent Skills, progressive disclosure | Agent Skills plus Claude-specific invocation controls | Most instructional skills can be shared |
| Project instructions | `AGENTS.md` or `CLAUDE.md`, walking ancestors | `AGENTS.md` hierarchy | `CLAUDE.md`, rules, memory | Existing `AGENTS.md` can carry over directly |
| Extensions | In-process TypeScript: tools, commands, shortcuts, events, UI, providers, session control | Skills/plugins, MCP, hooks, SDK/app-server | Skills/plugins, hooks, MCP, LSP, subagents | Pi is the most hackable TUI, but Eddy owns the code |
| Sessions | Local JSONL tree, names, resume, fork, clone, import/export | Persisted/resumable threads | Persisted sessions, resume, branch, checkpoints | Pi's format is the easiest to inspect and adapt |
| Compaction | Automatic/manual, configurable threshold and retained tail, extension hooks | Automatic context management/compaction | Automatic/manual compaction and `/context` inspection | Pi is transparent, configurable, and still lossy |
| MCP | Deliberately not built in | Built in | Built in with tool search and hooks | Major Pi regression unless a reviewed adapter is added |
| Subagents | Deliberately not built in; example/third-party extensions spawn Pi processes | Built-in configurable subagents | Built-in subagents; experimental agent teams | Major Pi regression for Eddy's review/research loops |
| Background work | No background bash by design; author recommends tmux | Built-in agent orchestration varies by surface | Background tasks, subagents, monitors | Herdr can host processes, but orchestration must be rebuilt |
| Permissions/sandbox | Project-resource trust only; no execution sandbox or permission system | Approval modes and OS sandboxing | Tool permissions plus OS-level Bash sandbox | Pi is materially weaker by default |
| TUI customization | First-class extension UI, editor, widgets, footer, overlays | More constrained product surface | Plugins/hooks, but less direct TUI replacement | Strong reason to pilot Pi |
| Programmatic integration | SDK and strict JSONL RPC mode | SDK and app server | Agent SDK and non-interactive CLI | All can integrate; Pi's runtime is especially open |

Primary references:
[Pi usage and omissions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/usage.md)
[Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
[Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
[Codex skills](https://learn.chatgpt.com/docs/build-skills)
[Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
[Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
[Claude Code feature overview](https://code.claude.com/docs/en/features-overview)
[Claude Code permissions](https://code.claude.com/docs/en/permissions)

## Reasons to migrate

### 1. One harness can use many providers

Pi can select models from Anthropic, OpenAI, Google, Bedrock, Vertex, Azure,
OpenRouter, local `llama.cpp`, and many other providers. It can change model
and thinking level within a persisted session. It also exposes custom-provider
registration through configuration or extensions.
[Pi providers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/providers.md)
[Pi custom providers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/custom-provider.md)

This separates “which model should solve this?” from “which vendor's terminal
application am I currently inside?” That is the most compelling architectural
reason to adopt Pi.

### 2. Extension seams are direct and unusually broad

An extension is a TypeScript module running in Pi's process. It can:

- register or replace model-facing tools;
- add slash commands and keyboard shortcuts;
- observe or block tool calls;
- intercept and transform user input;
- modify the system prompt or per-call context;
- override compaction and branch summaries;
- add widgets, overlays, custom editors, status lines, or a footer;
- create, fork, navigate, and switch sessions;
- prefill the editor without submitting.

The relevant editor API is `ctx.ui.setEditorText()` /
`ctx.ui.pasteToEditor()`, and the shortcut API is
`pi.registerShortcut()`. Pi ships first-party example extensions for a
permission gate, plan mode, subagents, handoffs, and custom editor workflows.
[Extension API](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
[First-party extension examples](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions)
[Handoff example](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/handoff.ts)

That makes Eddy's “ready-to-paste, never auto-submit” policy feasible as a
native Pi behavior instead of a fragile terminal-only convention.

### 3. Sessions are understandable and recoverable

Pi automatically saves sessions as JSONL under a directory organized by
working directory. Entries form a tree with IDs and parent IDs. `/tree`
branches inside one session file; `/fork` and `/clone` create separate session
files. `/resume`, names, `--session`, import, export, and explicit session IDs
make recovery inspectable rather than opaque.
[Pi sessions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/sessions.md)
[Pi session format](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session-format.md)

This fits the current Herdr principle well: each physical Ghostty window owns
an independent named Herdr session, and each Pi process can own an independent
named Pi session. Neither window needs to attach to the same agent transcript.

### 4. Compaction is explicit and adaptable

Pi supports `/compact [instructions]` and automatic compaction. By default it
compacts when estimated context exceeds:

```text
context window - 16,384 reserved response tokens
```

It keeps roughly the most recent 20,000 tokens, summarizes older turns, records
the summary as a session entry, and reloads the model context from the summary
plus retained messages. Context overflow also triggers compact-and-retry.
These thresholds are configurable.
[Pi compaction](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/compaction.md)
[Pi compaction settings](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/settings.md#compaction)

Compaction is lossy for the model, but it does not delete the underlying JSONL
history. `/tree` can revisit old branches, and extension events can replace or
augment the summarizer. Pi also tracks read and modified files cumulatively in
default compaction details.

For Eddy's workflow, a custom compaction extension could enforce the existing
durable handoff shape: goal, constraints, progress, decisions, verification,
open manual gates, and exact changed files. Pi already uses a closely related
structured default summary.

### 5. Skills can be shared instead of rewritten wholesale

Pi implements the Agent Skills standard. At startup it injects only skill names
and descriptions; the full `SKILL.md` is read on demand. It supports
`/skill:name`, global and project skill directories, package-provided skills,
and explicit skill paths in settings. The documentation explicitly describes
pointing Pi at Claude Code or Codex skill directories.
[Pi skills](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md)

Eddy's `/Users/eddyekofo/.agent-skills` can therefore remain the source of
truth and be added to Pi's `skills` setting. Duplicating the skill tree into
`~/.pi/agent/skills` is unnecessary.

The existing `~/.codex/skills` and `~/.claude/skills` paths are both symlinks
to that same directory. Pi can load either path, but using the canonical
`~/.agent-skills` path avoids duplicate discovery. A curated include/exclude
list is still required because discovery compatibility does not supply
Codex-/Claude-specific tools.

### 6. `AGENTS.md` carries over

Pi loads a global `~/.pi/agent/AGENTS.md`, then finds `AGENTS.md` or
`CLAUDE.md` while walking from parent directories to the current directory.
It can reload context files without restarting via `/reload`.
[Pi context files](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/usage.md#context-files)

The repository's current loop, dirty-work, no-commit/push, verification, and
skill-finish rules can therefore govern Pi too.

### 7. Herdr already has a maintained Pi integration

The installed Herdr `0.7.4` reports `pi` as a supported integration target:

```text
herdr integration install pi
```

An isolated inspection of that managed integration produced
`~/.pi/agent/extensions/herdr-agent-state.ts` version 5. It reports the Pi
session file/ID and working, idle, and blocked lifecycle state to Herdr. This
is important local evidence: Pi does not need a new agent-state protocol merely
to appear in Herdr's navigator and cross-session overview.

The integration is not currently installed in Eddy's real Pi directory, and
this research did not install it. Installation and live-state behavior remain
pilot gates.

## Reasons not to migrate

### 1. Pi removes safety features rather than making them lighter

Pi's project-trust prompt controls whether project-local settings, skills,
packages, and extensions load. It explicitly **does not** constrain what the
model can do after startup. Built-in tools and extensions run with the full
permissions of the Pi process.
[Pi security](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md)

Codex has approval and sandbox policies, and Claude Code combines tool
allow/ask/deny rules with OS-level Bash filesystem/network sandboxing.
[Codex security](https://learn.chatgpt.com/docs/security)
[Claude Code permissions and sandboxing](https://code.claude.com/docs/en/permissions)

For trusted personal repositories this may be an acceptable trade. For
untrusted checkouts, unattended work, browsers, credentials, or destructive
commands, Pi is a regression unless it is run inside a real container,
micro-VM, or policy sandbox. Pi documents Gondolin, Docker, and OpenShell, but
operating those is additional work.
[Pi containerization](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/containerization.md)

### 2. MCP and subagents are not native

Pi intentionally has no built-in MCP client and no built-in subagents.
First-party examples demonstrate that extensions can implement them, but an
example is not the same as a maintained, secure product contract.
[Pi philosophy](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md#philosophy)
[Pi subagent example](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions/subagent)

Codex and Claude Code both expose maintained MCP integration and native
subagent systems. Claude Code additionally has hooks across tool, session,
permission, and compaction lifecycles and experimental communicating agent
teams.
[Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
[Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
[Claude Code MCP](https://code.claude.com/docs/en/mcp)
[Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
[Claude Code hooks](https://code.claude.com/docs/en/hooks-guide)

Eddy's `research`, fresh Standards/Fidelity review, connector use, and
parallel-agent loops currently depend on capabilities beyond Pi's default four
tools. A full switch before those are deliberately ported would make the
workflow less capable.

### 3. Skill file compatibility is not tool compatibility

Pi can discover the existing skills, but it cannot automatically provide tools
named by those skills. A portable skill that uses ordinary filesystem and shell
operations should work. A skill that assumes Codex collaboration tools,
OpenAI-specific connectors, Claude's `Agent` tool, structured approval UI,
MCP tool names, or a particular sandbox contract needs an adapter or a
Pi-specific variant.

Pi also warns that models do not always load a matching skill automatically;
`/skill:name` forces invocation. Unknown frontmatter is ignored, and
`allowed-tools` is experimental.
[Pi skill loading and validation](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md)

The correct migration unit is therefore **one skill plus its required
capabilities**, not “the directory appeared in Pi's startup header.”

### 4. Provider portability does not guarantee product parity

Running a Claude or OpenAI model inside Pi changes the harness, system prompt,
tools, context construction, permission flow, and orchestration. The model name
may be the same while the resulting agent behavior differs.

There is also an important cost distinction: Pi's current provider
documentation says ChatGPT Plus/Pro can authenticate for Codex, but Claude
Pro/Max use through this third-party harness draws from Anthropic **extra
usage billed per token**, not the included Claude plan limits.
[Pi provider subscriptions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/providers.md#subscriptions)

That alone can make “replace Claude Code with Pi using Claude” financially
worse for a heavy Claude Max user.

### 5. Extensibility creates a personal maintenance surface

Pi packages and extensions execute arbitrary code with the user's permissions.
Third-party packages may add the missing MCP, subagent, memory, or permission
features, but every package expands trusted code and upgrade risk.
[Pi packages security](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/packages.md)

The safest Pi setup for Eddy is not a marketplace recreation of Claude Code.
It is a very small, reviewed extension set owned in this dotfiles repository.

### 6. “No background bash; use tmux” does not map exactly to Herdr

Pi's author recommends tmux for observable parallel work. Eddy has deliberately
moved to Herdr rather than carrying tmux forward. Herdr can host independent
Pi processes, but Pi's official guidance and examples do not prove Herdr
session discovery, focus, status, messaging, or recovery.
[Pi philosophy](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md#philosophy)

Those behaviors must be validated against the existing Herdr integration,
especially native agent detection and cross-session status.

## How Pi would handle Eddy's skills

Keep one shared skill source, but expose only a reviewed pilot subset:

```json
{
  "skills": [
    "/Users/eddyekofo/.agent-skills/skill-finish",
    "/Users/eddyekofo/.agent-skills/herdr"
  ]
}
```

This belongs in a pilot-only Pi config directory first, not immediately in
`~/.pi/agent/settings.json`. `PI_CODING_AGENT_DIR` can point Pi at an isolated
configuration root, and `PI_CODING_AGENT_SESSION_DIR` can isolate pilot
sessions.
[Pi environment variables](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/environment-variables.md)

Pi accepts individual skill files or directories in the `skills` array, so
later stages should add explicit vetted paths from the canonical tree rather
than recursively loading all 40 current skill directories. This preserves one
source of truth without accidentally advertising harness-bound skills.

Classify every skill into three groups:

1. **Portable:** instructions plus `read`/`edit`/`write`/`bash`.
2. **Adaptable:** needs a small Pi extension, CLI wrapper, or renamed tool.
3. **Harness-bound:** depends materially on Codex/Claude connectors,
   orchestration, sandbox, or UI and should stay on its current harness.

Do not fork portable skills just to rename Codex concepts. Keep shared
behavior in the existing `SKILL.md`; put only the capability adapter in Pi.

High-priority proof skills for this setup:

- `research`: needs trustworthy browsing/search capability and background
  delegation, neither native in Pi.
- `feature-plan`: needs durable intake, one-goal governance, implementation
  authorization, verification, and review orchestration.
- `code-review`: needs genuinely fresh Standards/Fidelity passes, normally
  independent context.
- `skill-finish`: mostly prompt/output contract and should be portable.
- `herdr`: mostly local instructions and shell/API calls and should be
  adaptable.

Until `research` and `code-review` have trustworthy Pi equivalents, Pi cannot
replace the current full loop.

## How Pi compaction differs operationally

Pi's compaction model is a good fit but must be treated as two layers:

```text
Durable truth: full JSONL tree + repository tracking files
Active model context: summary + retained recent messages
```

The full transcript remains recoverable, but the model reasons only over the
compacted representation. Therefore:

- important decisions must still be written to repository artifacts;
- manual/device QA gates must not exist only in chat;
- a custom compaction prompt should preserve active-goal state and exclusions;
- compaction is not a replacement for `.working/ACTIVE_GOAL.md`,
  `.working/UNIFIED_INTAKE.md`, decisions, review, or closure records.

Pi exposes `session_before_compact` and `session_compact` extension events, and
an extension can provide its own compaction result. That is enough to encode
Eddy's structured continuation contract after the base pilot works.
[Pi compaction extension events](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md#session_before_compact--session_compact)

The proof must also cover an active skill: after compaction, Pi must still know
which skill contract is in force, what stages remain, and that the final
`skill-finish` handoff is mandatory. A preserved transcript alone is not enough
if the active model context silently drops those obligations.

## Adapting `Prefix+b` and `Prefix+B`

### Current semantics to preserve

The existing Herdr implementation is outside Codex/Claude:

- `Prefix+b` runs `herdr/prototype/ready_prompt.sh`;
- the helper inspects the focused pane, extracts the newest labeled
  `Ready-to-paste prompt`, applies consume-once state, and sends it as
  bracketed paste;
- the prompt remains in the composer and is **not submitted**;
- `Prefix+B` clears supported agent context, waits for two stable empty
  composer snapshots, and then inserts the handoff without submission;
- uncertain, active, typed, or unsupported states fail closed.

Local sources:

- `herdr/config.toml`
- `herdr/prototype/ready_prompt.sh`
- `tmux/scripts/ready_prompt.sh`
- `.working/interviews/ready-prompt-replay-regression/decisions.md`

### Feasibility for Pi

`Prefix+b` is straightforward. Pi's editor accepts pasted text, and Pi itself
supports text/image paste. The Herdr helper already uses a bracketed-paste
envelope, so the required work is to:

- recognize the actual Pi foreground-process shapes for both the standalone
  binary and npm/Node launch;
- include Pi in the fail-closed supported-agent set;
- prove exact multiline insertion with no Enter and no agent turn.
[Pi editor behavior](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/usage.md#editor)

`Prefix+B` must not blindly reuse the current Codex/Claude `/clear` logic.
Pi has no `/clear` command; its supported fresh-context operation is `/new`,
which starts a new persisted session. Pi also exposes `ctx.newSession()` and
`ctx.ui.setEditorText()` / `pasteToEditor()` to extensions, so there are two
viable designs.
[Pi session commands](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/sessions.md#session-commands)
[Pi extension session control](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md#ctxnewsessionoptions)

Recommended design:

1. Keep Herdr as the owner of `Prefix+b/B` and prompt extraction.
2. For lowercase, retain the existing bracketed-paste transport.
3. Prefer one small reviewed Pi extension command for uppercase. It should
   create a new session through `ctx.newSession()` and prefill the replacement
   editor through `pasteToEditor()` or `setEditorText()`. The command may
   execute; the handoff itself must remain unsubmitted.
4. Retain “submit `/new`, verify the new session, then bracket-paste” only as a
   fallback design. It depends on terminal readiness recognition and is more
   brittle than Pi's native session/editor APIs.
5. Keep Codex/Claude branches unchanged.

Do not bind Pi's internal Ctrl shortcuts directly to `Prefix+b/B`. The Herdr
binding is already the correct cross-agent owner and keeps the behavior
consistent across physical windows.

### Required replay tests

- Standalone Pi and npm-launched Pi are both recognized.
- Lowercase inserts two exact lines and does not create a user-message session
  entry.
- Repeating lowercase hits consume-once protection.
- Uppercase starts a distinct fresh Pi session, preserves the old JSONL, and
  inserts the same two lines without submitting them.
- Typed composer text, active streaming, queued input, startup, failed
  `/new`, ambiguous process identity, and non-Pi panes fail closed.
- The action affects only the focused Herdr pane/session.
- Two physical Ghostty windows remain independent.
- `Prefix+A` reports the Pi agent with correct session, status, cwd, focus,
  read, and message behavior.

## Adaptable staged migration plan

### Stage 0 — Freeze the decision boundary

**Action:** no default-agent changes. Record installed Codex/Claude versions,
provider/account usage, current skills, MCP/connectors, subagent workflows,
Herdr agent detection, and representative tasks.

**Proof gate:** a migration matrix identifies every capability as retain,
port, replace, or intentionally drop. No unknown current dependency can be
silently lost.

**Rollback:** not needed; read-only.

### Stage 1 — Isolated, pinned Pi install

**Action:** install the official macOS arm64 standalone `v0.82.1` in a
versioned, reversible location. Use isolated
`PI_CODING_AGENT_DIR` and `PI_CODING_AGENT_SESSION_DIR`. Disable install
telemetry during the pilot and keep project trust at `ask`. Do not install
third-party Pi packages.

**Proof gate:**

- checksum matches the release `SHA256SUMS`;
- `pi --version` is pinned;
- startup, exit, and resume work in Ghostty + Herdr;
- no existing Codex, Claude, Fish, or Herdr config changed.

**Rollback:** remove the isolated binary/config/session directories.

### Stage 2 — Provider and quality comparison

**Action:** configure only the provider accounts Eddy already intends to test.
Run the same bounded tasks through:

- Codex in Codex CLI;
- the same OpenAI model in Pi where available;
- Claude in Claude Code;
- the same Claude model in Pi only after confirming extra-usage cost.

Use identical repository state, task prompts, stop conditions, and
verification.

**Proof gate:** compare correctness, tool reliability, edit quality, context
use, elapsed time, tokens/cost, startup time, and peak memory. Pi must win on
the actual desired dimensions, not merely feel simpler.

**Rollback:** log out of Pi providers and retain native clients.

### Stage 3 — Shared instructions and portable skills

**Action:** point the isolated Pi settings at
explicit vetted skill directories under `/Users/eddyekofo/.agent-skills`.
Load the current `AGENTS.md`. Start with portable skills only; do not scan the
entire shared tree or advertise harness-bound skills.

**Proof gate:**

- expected skill names and descriptions appear once;
- `/skill:skill-finish` and one local shell-oriented skill follow their
  contracts;
- a small input adapter maps Eddy's known `$skill-name` form to Pi's canonical
  `/skill:skill-name` command and fails closed for unknown or disabled skills;
- modifying a shared skill is visible after `/reload`;
- there are no duplicated skill trees or shadow copies;
- missing tools cause a clear failure, not invented behavior.

**Rollback:** remove the single `skills` setting.

### Stage 4 — Session and compaction proof

**Action:** create two named Pi sessions in one repository. Exercise `/resume`,
`/tree`, `/fork`, `/clone`, manual `/compact`, auto-compaction with a temporary
low threshold, process exit, and restart.

**Proof gate:**

- sessions remain distinct and resume by name;
- the source JSONL remains intact after compaction;
- the active context contains the summary and retained tail;
- goal, constraints, dirty files, decisions, completed verification, and
  manual gates survive compaction;
- no two physical windows attach to the same Pi session unintentionally.

**Rollback:** retain JSONL as evidence, then delete only the isolated pilot
session directory if desired.

### Stage 5 — Minimal Eddy-owned Pi extension

**Action:** create one local extension package only for proven gaps:

- deterministic skill/capability diagnostics;
- the `$skill-name` to `/skill:skill-name` input adapter for the enabled
  catalog only;
- structured compaction preserving the loop contract;
- optional `Prefix+B` new-session-and-prefill endpoint if terminal readiness
  cannot be made reliable;
- any adapter proven necessary after testing Herdr's managed Pi integration.

Do not add MCP, subagents, plan mode, permissions, and a full workflow suite in
one extension.

**Proof gate:** focused automated tests, typecheck, pinned Pi API version,
malicious/invalid input tests, and fresh Standards/Fidelity review.

**Rollback:** disable the extension path in pilot settings.

### Stage 6 — Herdr `Prefix+b/B` and agent overview

**Action:** install Herdr's managed Pi integration in the isolated pilot config,
then extend the existing process-aware replay helper for Pi. Preserve current
Codex/Claude behavior and tmux fallback. Reuse the integration's reported
session ID/path and lifecycle state instead of creating a parallel status
protocol.

**Proof gate:**

- all replay tests listed above pass;
- `herdr/verify.sh` and `fish/scripts/verify.sh` pass;
- physical two-window QA proves navigation and typing remain independent;
- physical lower/uppercase replay leaves the prompt visible and unsubmitted;
- recovery after closing/reopening Ghostty restores the intended Pi session;
- fresh Standards/Fidelity review has zero findings.

**Rollback:** remove only Pi recognition/branching; Codex/Claude replay remains
available.

### Stage 7 — Port one independent-agent workflow

**Action:** port exactly one bounded background workflow, preferably
`research` or the read-only side of `code-review`. Prefer a small Eddy-owned
Pi-process extension or explicit Herdr process over a broad third-party
package.

**Proof gate:** isolated context, cancellation, output artifact, status
visibility, no accidental edits, token accounting, and parent handoff all
match the current workflow.

**Rollback:** route that skill back to Codex/Claude.

### Stage 8 — Promotion decision

Promote Pi to the default launcher only if all of these are true:

- it is measurably lighter on Eddy's Mac or materially simpler to operate;
- provider quality/cost is acceptable;
- required skills work, not merely load;
- security is acceptable for the repositories in scope;
- `Prefix+b/B`, session recovery, and cross-session agent overview pass
  physical QA;
- at least one fresh Standards/Fidelity loop works end to end;
- Codex and Claude remain callable as explicit fallback commands.

If MCP, mature subagents, sandboxing, or Claude subscription economics remain
decisive, adopt Pi only as a specialist harness. That is still a successful
outcome.

## Suggested dual-run shape

During the pilot:

```text
codex   -> full Codex workflow and OpenAI integrations
claude  -> full Claude Code workflow and included subscription usage
pi      -> pinned isolated pilot, shared portable skills, Eddy-owned extensions
```

Do not rename `codex` or `claude`, rewrite their auth, migrate their sessions,
or make Pi own all Herdr agent launching at first. Use an explicit Fish
function or launcher only after the isolated Pi binary is installed, and keep
the command reversible.

## Decision rule

Choose **full migration** only if Pi passes every proof gate and the missing
built-ins are either unnecessary or replaced by a small reviewed local
extension set.

Choose **hybrid adoption** if Pi's multi-provider sessions and custom TUI are
excellent but Codex/Claude remain better for connectors, sandboxed work,
subagents, or subscription economics.

Choose **no migration** if the pilot becomes an effort to rebuild Codex and
Claude Code inside Pi. At that point the harness is extensible, but the
personal system is no longer lightweight.

## Research limitations

- No production Pi configuration, provider login, API request, Herdr binding,
  or existing skill was changed.
- Runtime RAM, startup latency, model quality, and actual provider cost were
  not benchmarked; the plan makes them explicit proof gates.
- Pi's documented provider catalogs and OAuth behavior can change independently
  of Codex and Claude Code. Verify them again at pilot activation.
- First-party Pi examples prove extension feasibility, not that a third-party
  extension is safe or maintained.
- Herdr does not appear in Pi's official compatibility documentation; all
  Herdr behavior remains a local physical-QA requirement.

## Primary-source index

- [Pi repository](https://github.com/earendil-works/pi)
- [Pi coding-agent README](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/README.md)
- [Pi sessions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/sessions.md)
- [Pi session format](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/session-format.md)
- [Pi compaction](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/compaction.md)
- [Pi skills](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/skills.md)
- [Pi extensions](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)
- [Pi providers](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/providers.md)
- [Pi security](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/security.md)
- [Pi containerization](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/containerization.md)
- [Pi keybindings](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/keybindings.md)
- [Pi RPC](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/rpc.md)
- [Codex skills](https://learn.chatgpt.com/docs/build-skills)
- [Codex AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Codex MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli)
- [Codex subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Codex security](https://learn.chatgpt.com/docs/security)
- [Codex native CLI](https://github.com/openai/codex/blob/main/codex-rs/README.md)
- [Claude Code sessions](https://code.claude.com/docs/en/sessions)
- [Claude Code feature overview](https://code.claude.com/docs/en/features-overview)
- [Claude Code permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code installation](https://code.claude.com/docs/en/installation)
