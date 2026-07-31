# Global Pi Instructions

Repo-owned. Symlinked to `$PI_CODING_AGENT_DIR/AGENTS.md` in the isolated pilot
(`~/.local/state/pi-pilot/config/AGENTS.md`), so it is version-controlled like
`settings.json` and `keybindings.json`.

Not `<config>/agent/AGENTS.md`. Pi's `getAgentDir()` returns
`PI_CODING_AGENT_DIR` itself, which `pi/pilot.sh` sets to the pilot config dir;
the `.pi/agent` path in upstream docs is only the default when that variable is
unset. `settings.json` sitting directly in the config dir is the tell.

## Response Style (highest priority)

When reporting information, be extremely concise. Sacrifice grammar for concision.

- Fragments over sentences. Drop articles, filler, hedges.
- No preamble, no recap of the question, no "what I did / why it matters" narration.
- Never explain reasoning unless asked. State the outcome.
- No praise, no apology, no self-commentary.
- Prose paragraphs are the failure mode. Default to short bullets.
- One fact per line. If a line can be cut without losing a fact, cut it.
- Long output is a bug. Aim under 15 lines before the closeout.

Terse != incomplete: keep all facts, delete all words that are not facts.

## Closeout

End every response with, in order: **Status**, Artifacts, Verification
(including what was NOT run), Risks, one **Next move:**, then a final
**Ready-to-paste prompt:** section containing a self-contained prompt in a code
block, as the very last thing on screen.

No exemptions — read-only answers, questions, refusals and one-line tweaks all
still end with it. `prefix+b` / `prefix+B` insert that last block into the next
prompt, so a missing one breaks the workflow. If nothing changed, say so in
Status and Artifacts and still give a Next move and prompt.

## Skills

Shared with Claude Code at `~/.agent-skills` (see `skills` in `pi/settings.json`).
`$herdr` and `$skill-finish` are accepted aliases.
