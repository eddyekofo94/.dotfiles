# Global Response And Closeout Instructions

Canonical repository source for Codex, Claude, and the isolated Pi pilot.

## Agentic Loop Standard

Apply the loop standard in:

```sh
/Users/eddyekofo/Documents/Theology/epub_conversion/instructions/agentic_loop_standard.md
```

For every serious project, default to loop-based work instead of one-shot prompting.

Before implementation, establish:

1. Trigger: why this work is running now.
2. Scope: the one bug, feature slice, milestone, QA pass, data task, or review target being handled.
3. Stop condition: what must be true before the work can be called done.
4. Verification: commands, tests, manual QA, screenshots, audits, or review steps that prove the stop condition.
5. Human handoff: what requires user confirmation before final status changes.

## Unified Work Intake And Authorization

- Record plain feature ideas, bug reports, and anomalies immediately in the
  repository's existing durable tracker/work graph. They authorize evidence
  gathering and read-only investigation, not production-code edits.
- Search for duplicates and evidence-backed relationships before creating
  execution work. Use explicit links such as `duplicate of`, `symptom of`,
  `blocked by`, `depends on`, `affects`, `shares implementation seam with`,
  `supersedes`, and `resolved by`. Similar appearance alone does not justify a
  shared root-cause cluster.
- Rank candidate goals by dependency, leverage, impact, confidence, and
  readiness. Recommend the best bounded target; Eddy selects one target and
  settles its expected behavior, scope, stop condition, and validation plan.
- Maintain exactly one active implementation goal per repository. Other intake
  and investigation may continue read-only. Parallel agents may work only on
  independent subtasks, tests, research, or review within the active goal.
- Invoking `grill-me` alone is decision-only. Invoking `feature-plan` authorizes
  build mode for the selected goal: once it is `Ready To Act`, continue through
  brief, implementation, validation, fresh Standards/Fidelity review, fixes,
  re-review, and durable closure without intermediate phase approvals.
- Tickets, dependency edges, relationship links, implementation ordering, and
  ordinary review fixes are agent-owned bookkeeping. A `ship` qualifier is
  required before normal commit/push/hosted-ticket/lifecycle publication steps;
  otherwise keep externally visible mutations out of scope.
- Interrupt only for implementation-changing ambiguity, conflict with settled
  decisions, material scope expansion, destructive/external authority,
  unavailable dependencies, or genuinely subjective/manual acceptance.

At session start:

- Check repository status before edits.
- Summarize existing dirty files.
- Read project-local instructions and tracking files.
- Pick one bounded target unless the user explicitly asks for broad work.
- State or infer the stop condition before substantial edits.

Before claiming code changes complete:

- Run the project's required verification commands.
- If no verification command exists, create or propose one.
- Update local bug, milestone, spec, or QA tracking where the project uses them.
- Use manual QA for visual, interaction, browser, device, accessibility, or subjective UX changes.
- Leave visual/device/user-confirmed items awaiting confirmation until the user confirms them.

When a repeated failure is found, encode the prevention in durable instructions, tests, scripts, or checklists instead of only fixing the individual occurrence.

## Project Loop Bootstrap

When a project lacks loop-support files, add project-appropriate equivalents before or alongside substantial implementation work:

- one verification command, such as `tools/verify_app.py`, `tools/verify.py`, `tools/verify.sh`, `scripts/verify`, or the local equivalent
- one workflow status/reminder command, such as `tools/workflow_status.py` or the local equivalent
- one workflow loop document, such as `project/WORKFLOW_LOOPS.md`, `docs/WORKFLOW_LOOPS.md`, or the local equivalent
- one manual QA checklist for visual, interaction, device, browser, accessibility, or domain-specific behavior where automated tests are insufficient

If equivalents already exist, read and improve them rather than replacing them. Preserve project-specific commands and conventions. Do not blindly copy Bible Standard's iOS-specific verification or QA into unrelated repositories; adapt the loop shape to the current stack.

Ask before adding workflow files only when the repository is tiny, read-only, not under version control, or the user's request is explicitly analysis-only. Otherwise, make the smallest useful addition and explain it.

Project-level `AGENTS.md` files override these global defaults when they are more specific.

## Universal Skill Completion Contract

Every skill-driven task must end with a concise, workflow-aware handoff, even
when the task is blocked or awaiting the user. Use the reusable contract in:

```text
/Users/eddyekofo/.agent-skills/skill-finish/SKILL.md
```

The closeout must include:

1. Status: `DONE`, `PARTIAL`, `BLOCKED`, or `AWAITING USER APPROVAL`.
2. Summary of what was accomplished.
3. Artifacts changed, with paths or links.
4. Actual verification results.
5. Open risks, deferred scope, and user-confirmation items.
6. Exactly one recommended next skill or human action.
7. A ready-to-paste prompt containing the next scope, source artifacts, stop
   condition, and validation plan.

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
