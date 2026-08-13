# Global Response And Closeout Instructions

Canonical repository source for Codex, Claude, and the isolated Pi pilot.

## Agentic Loop Standard

Owner — read before implementation:

```sh
/Users/eddyekofo/Documents/Theology/epub_conversion/instructions/agentic_loop_standard.md
```

For every serious project, default to loop-based work instead of one-shot
prompting. The owner file settles the pre-implementation checklist (trigger,
scope, stop condition, verification, human handoff), the loop shapes, and the
encode-the-lesson rule. Do not restate it here.

## Unified Work Intake And Authorization

Owned by the loop standard above, in three sections:

- §Unified Intake, Selection, And Authorization — the work graph, relationship
  links, provisional clustering, goal ranking, one active implementation goal
  per repository, the `grill-me` / `feature-plan` / `ship` authorization split,
  and the short list of reasons to interrupt Eddy.
- §Session Start Loop — repository status, dirty files, local instructions,
  one bounded target, stated stop condition.
- §Enforcement Rules — required verification, manual QA, awaiting user
  confirmation, and encoding prevention for repeated failures.

Read those before intake or implementation. Do not restate them here.

## Project Loop Bootstrap

A project missing loop support needs four things, added before or alongside
substantial implementation work: one verification command, one workflow
status command, one workflow loop document, and one manual QA checklist for
what automated tests cannot cover.

Improve existing equivalents rather than replacing them; keep project-specific
commands and conventions. Adapt the loop shape to the current stack — never
copy Bible Standard's iOS verification or QA into an unrelated repository.

Ask first only when the repository is tiny, read-only, unversioned, or the
request is explicitly analysis-only. Otherwise make the smallest useful
addition and explain it.

Project-level `AGENTS.md` files override these global defaults when they are more specific.

## Universal Skill Completion Contract

Every skill-driven task must end with a concise, workflow-aware handoff, even
when the task is blocked or awaiting the user. Owner — read before closing:

```text
/Users/eddyekofo/.agent-skills/skill-finish/SKILL.md
```

It owns the required closeout fields and their exact labels. Do not restate
them here; the Closeout section below is the shape Eddy's terminal expects.

Route the next prompt from the project workflow state. For Bible Standard, the
default product route is:

```text
unified intake -> ranked goal selection -> grill-with-docs (prototype inside visual grills) -> Ready To Act -> quiet brief and optional agent-owned tickets -> implement/validate -> fresh Standards/Fidelity review -> automatic fix/re-review -> verified closure -> re-rank intake
```

Do not emit a skill closeout or handoff prompt between the internal stages of an
authorized active goal. Do not infer unresolved product decisions, hide skipped
verification, or restart a phase that is already complete.

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
