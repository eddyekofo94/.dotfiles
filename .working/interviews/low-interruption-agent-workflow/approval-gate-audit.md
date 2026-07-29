# Low-Interruption Workflow Approval-Gate Audit

Date: 2026-07-18

## Scope

- Shared orchestration, intake, diagnosis, planning, review, prototype/grill,
  ticket-bookkeeping, and completion skills under
  `/Users/eddyekofo/.agent-skills`.
- Global Codex instructions and the canonical agentic-loop standard.
- Bible Standard workflow instructions, active-goal tracker, and workflow-status
  command.
- Product source was explicitly out of scope.

## Contradictions Found And Resolved

1. The global route required `prototype -> explicit approval -> to-spec ->
   to-tickets -> implement -> review -> validate`. It now uses unified intake,
   one selected goal, `Ready To Act`, continuous implementation/review, and
   agent-owned optional tickets.
2. `loop`, `diagnosing-bugs`, and `code-review` emitted handoffs between phases.
   They now continue automatically through implementation, validation, fresh
   Standards/Fidelity review, fixes, and re-review.
3. `feature-plan` previously waited for another implementation request after
   planning. Invoking it now authorizes local build mode; the final
   implementation-changing grill answer is the product gate and `Ready To Act`
   starts implementation automatically.
4. `code-review` required the user to supply a fixed point. It now infers the
   narrowest reliable baseline from goal metadata and repository evidence,
   asking only when materially different baselines remain unresolved.
5. `grill-me`, `prototype`, and `spec-ticket` blurred authorization. Standalone
   grill/prototype work is decision-only; inside `feature-plan`, prototype QA is
   part of the grill and the quiet brief/tickets do not create approval gates.
6. A stale universal footer in 37 shared skills reintroduced the old approval
   pipeline. Every exact occurrence was replaced with the shared
   `skill-finish` rule: no closeout inside an authorized active goal.
7. The legacy `ask-eddy` orchestrator still required spec/ticket promotion and
   per-ticket implementation handoffs. It now routes through unified intake,
   ranked goal selection, exactly one active goal, `feature-plan`, and verified
   closure.
8. Bible Standard used an active brief/chunk pointer without goal phase or
   reviewer accountability. Its tracker and status command now report active
   goal, phase, brief, tickets, review state, and next accountable actor and fail
   on duplicate/inconsistent active-goal state.

## Intentional Human Gates Preserved

- Selecting the next bounded goal.
- Answering an implementation-changing product ambiguity not resolved by
  evidence.
- Resolving conflict with settled decisions or material scope expansion.
- Authorizing destructive actions, credentials, purchases, or external
  publication. `ship` separately authorizes normal publication mechanics.
- Supplying an unavailable dependency, environment, data source, or device.
- Confirming genuinely subjective/manual browser, simulator, or device behavior
  that automation cannot prove.

Ticket wording, relationship links, dependency edges, implementation ordering,
ordinary fixes, review findings, and re-review are not human gates.

## Verification Evidence

- Skill validation: `quick_validate.py` passed for all 46 changed shared skill
  folders, including the primary workflow skills and mechanically corrected
  footer consumers.
- Workflow-status tests: four tests passed, covering fenced-template bug counts,
  complete active-goal reporting, duplicate active-goal rejection, and active
  brief rejection without a goal.
- Live status: `python3 tools/workflow_status.py` reported `One-active-goal
  invariant: OK`, no active goal, `Intake / goal selection`, and the next
  accountable actor.
- Whitespace: scoped `git diff --check` passed for shared skills and Bible
  Standard workflow files.
- Legacy route audit: zero exact occurrences remain of the old shared
  `prototype -> user approval -> to-spec -> to-tickets` footer.
- Fresh-agent forward tests passed for feature authorization, multi-report bug
  clustering, one-goal parallelism, inferred review baselines, automatic
  fix/re-review, and manual-only final acceptance.
- No-product-code audit: changed Bible Standard paths are limited to
  `AGENTS.md`, `project/WORKFLOW_LOOPS.md`,
  `.working/interviews/IMPLEMENTATION_TRACKER.md`,
  `tools/workflow_status.py`, and `tools/test_workflow_status.py`; no
  `Sources/App` or design product file changed.

## Result

No contradictory mandatory phase, ticket, ordinary-fix, or repeated-prototype
approval gate remains in the audited active workflow surfaces. Human authority
is preserved only at goal selection, unresolved product/scope/safety boundaries,
external publication, unavailable dependencies, and manual-only acceptance.
