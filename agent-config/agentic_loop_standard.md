# Agentic Loop Standard

Source: Anthropic, "Getting started with loops", June 30, 2026.
Reference: https://claude.com/blog/getting-started-with-loops

## Summary

The article argues that effective coding-agent work should not depend on perfect one-shot prompts. A better pattern is to design loops: repeated cycles of context gathering, work, verification, and repair that continue until a clear stop condition is met.

The useful distinction is not "prompting versus automation" in the abstract. It is deciding which part of the workflow the agent should own:

- Turn-based loop: the user triggers each turn and manually decides what happens next. Best for short tasks, exploration, and unclear work.
- Goal-based loop: the user defines a concrete success condition, and the agent keeps iterating until that condition is met or a turn cap is reached. Best for tasks with measurable completion.
- Time-based loop: the agent reruns work on an interval. Best for recurring checks or external systems that change over time.
- Proactive loop: scheduled or event-triggered work runs without a human present, using goals, verification, and routing to handle recurring well-defined work.

The article's main engineering lesson is that agent quality depends on the harness around the model. Good loops need clean codebase conventions, accessible docs, deterministic checks, explicit stop conditions, and fresh review. When a failure happens, do not only fix that instance; encode the lesson into the workflow so future runs improve.

## Global Rule

For every serious project, default to loop-based work instead of one-shot prompting.

### Cross-agent project instructions

When a repository is used by Codex and Claude Code, keep one canonical project
instruction file:

- `AGENTS.md` owns shared project rules.
- `CLAUDE.md` contains only `@AGENTS.md`, using Claude Code's supported import
  syntax. Add Claude-only instructions after that import only when behavior must
  genuinely differ.
- Do not maintain parallel copies of shared rules. Put task-specific detail in
  referenced standards, workflow, design, or QA documents instead of inflating
  both agent entry points.
- A `CLAUDE.md -> AGENTS.md` symlink is acceptable in a Mac-only repository, but
  the import adapter is the portable default because Windows symlinks require
  additional privileges or Developer Mode.
- If the project has a workflow-status or instruction-audit command, have it
  warn when the adapter drifts without adding a separate validation phase.

Before starting implementation, define:

1. Trigger: why this work is running now.
2. Scope: the one bug, feature slice, milestone, QA pass, data task, or review target being handled.
3. Stop condition: what must be true before the work can be called done.
4. Verification: commands, tests, manual QA, screenshots, audits, or review steps that prove the stop condition.
5. Human handoff: what requires user confirmation before final status changes.

## Unified Intake, Selection, And Authorization

Use one durable work graph for feature ideas, bug reports, and anomalies. A
plain report authorizes intake and read-only investigation, not production-code
changes.

1. Record the observation and gather available reproduction, logs, tests,
   ownership, code-flow, prior-decision, prototype, and affected-surface
   evidence.
2. Link explicit relationships such as `duplicate of`, `symptom of`, `blocked
   by`, `depends on`, `affects`, `shares implementation seam with`,
   `supersedes`, and `resolved by`.
3. Keep clusters provisional until shared reproduction, ownership/seam, traces,
   demonstrated dependencies, or a verified fix supports them. Similarity alone
   is insufficient.
4. Rank candidate goals by dependency, leverage, impact, confidence, and
   readiness. Let the user select one bounded target and settle expected
   behavior, scope, stop condition, and validation.
5. Maintain exactly one active implementation goal per repository. Other items
   may receive intake and investigation, but not concurrent production edits.
   Parallel agents may work only within the active goal.

`grill-me` alone remains decision-only. Invoking `feature-plan` authorizes the
full local build workflow for the selected goal. Once the goal is `Ready To
Act`, agents own the quiet brief, optional tickets and dependencies,
implementation, validation, fresh Standards/Fidelity review, ordinary fixes,
re-review, status updates, and closure evidence. A `ship` qualifier separately
authorizes the project's normal publication steps.

Interrupt the user only for implementation-changing ambiguity, conflict with
settled decisions, material scope expansion, destructive/external authority,
unavailable dependencies, or genuinely subjective/manual acceptance.

## Standard Loops

### Session Start Loop

Use at the start of every coding session.

1. Check repository status.
2. Summarize existing dirty files before editing.
3. Read local instructions such as `AGENTS.md`, `README.md`, project plans, bug trackers, and relevant specs.
4. Pick one bounded target unless the user explicitly asks for broad work.
5. State the intended stop condition before making substantial edits.

### Bug Loop

Use for crashes, regressions, broken UI, bad data, and failing tests.

1. Intake and evidence-cluster the report.
2. Select and settle one bounded root-cause goal.
3. Reproduce it or inspect the recorded evidence.
4. Fix the root-cause seam and directly impacted coverage.
5. Run required verification plus fresh Standards/Fidelity review.
6. Fix actionable findings and re-review automatically.
7. Update linked reports only with evidence; leave genuinely manual validation
   awaiting confirmation.

### Feature Loop

Use for new behavior or meaningful UI/product changes.

1. Intake and investigate the idea without production edits.
2. Select one bounded goal and grill until it is `Ready To Act`; include a QA'd
   prototype inside visual/interaction grills.
3. Silently refresh the brief and optional agent-owned tickets.
4. Implement and validate impacted surfaces.
5. Run fresh Standards/Fidelity review, fix findings, and re-review until pass.
6. Update durable tracking and relationships only for verified work.

### QA Loop

Use for visual, interaction, accessibility, device, browser, or workflow quality.

1. Run the relevant checklist or create one if missing.
2. Record failures as bugs.
3. Fix one failure at a time.
4. Verify with automated checks plus the manual/device/browser step that exposed the issue.
5. Require human confirmation for subjective visual or interaction fixes.

### Data Loop

Use for generated resources, indexes, migrations, audits, and conversions.

1. Run the generator or migration.
2. Run deterministic audits.
3. Compare generated diffs intentionally.
4. Check bundle size, startup impact, and data-loading assumptions.
5. Run project verification before completion.

### Review Loop

Use before declaring risky work complete.

1. Review the active goal's actual diff with fresh context.
2. Run Standards and Fidelity as separate passes against project rules and the
   settled decisions/prototype.
3. Prioritize bugs, regressions, missing tests, rule violations, and fidelity
   gaps.
4. Route real findings directly to fixes without ordinary-fix approval.
5. Rerun affected verification and fresh review until both axes pass.

## Enforcement Rules

- Do not claim a code change is complete without running the project's required verification.
- If no verification command exists, create or propose one.
- Prefer deterministic scripts and tests over reasoning through repeatable checks.
- Keep loops bounded. One target per pass is the default.
- Keep exactly one active implementation goal per repository. Parallelism is
  allowed only within that goal.
- Use manual QA when automated checks cannot prove the behavior.
- Do not mark visual, device, or user-experience fixes confirmed until the user confirms them.
- When a failure repeats, encode the prevention in instructions, tests, scripts, or checklists.
- Do not insert ticket, dependency, phase, ordinary-fix, or repeated-prototype
  approval gates inside an authorized `Ready To Act` goal.
- Project-level `AGENTS.md` rules override global defaults when they are more specific.

## Project Bootstrap Standard

When working in a project that does not already have loop-support files, add project-appropriate equivalents before or alongside substantial implementation work. Do not blindly copy another project's commands. Adapt names, languages, build tools, and QA checklists to the current repository.

Recommended project files:

- `tools/verify_app.py`, `tools/verify.sh`, `scripts/verify`, or the local equivalent: one command that runs the project's required lint, audit, type-check, tests, build, and generation checks.
- `tools/workflow_status.py`, `scripts/workflow-status`, or the local equivalent: a lightweight status/reminder command that reports dirty files, open work, awaiting confirmation, and the next accountable action.
- `project/WORKFLOW_LOOPS.md`, `docs/WORKFLOW_LOOPS.md`, or the local equivalent: bug, feature, QA, data, and review loops tailored to the project.
- `qa/manual_reader_qa.md`, `qa/manual_ui_qa.md`, `docs/manual_qa.md`, or the local equivalent: manual QA checklist for the project's visual, interaction, device, browser, accessibility, or domain-specific behavior.

If a project already has equivalents:

1. Read them before changing them.
2. Preserve project-specific commands and conventions.
3. Improve gaps instead of replacing working local process.
4. Add one-command verification if it is missing.
5. Add explicit stop conditions and human confirmation rules if they are missing.
6. Add manual QA coverage where automated checks cannot prove behavior.

Ask before adding workflow files only when the repository is tiny, read-only, not under version control, or the user's request is explicitly limited to analysis with no file changes. Otherwise, make the smallest useful addition and explain it.
