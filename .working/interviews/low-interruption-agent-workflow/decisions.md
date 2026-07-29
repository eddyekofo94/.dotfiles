# Low-Interruption Agent Workflow

## Goal

Define a smooth product workflow in which Eddy settles design and behavior once, then agents autonomously own planning mechanics, implementation, verification, independent code review, and review fixes without repeatedly requesting approval.

## Exit Criteria

Decision-ready: the authorization boundary, agent-owned work, interruption rules, review loop, completion evidence, and remaining human-only gates are explicit enough to encode in the shared personal skills.

## Scope / Non-goals

- Covers feature work from grill through prototype, implementation, review, and verified completion.
- Covers low-friction bug intake, durable bug reporting, relationship-aware triage, and autonomous batch fixing.
- Covers when agents may create internal briefs or tickets without asking Eddy.
- Does not authorize destructive actions, credentials, purchases, publication, or material scope expansion.
- Does not eliminate human confirmation for subjective visual/device acceptance that automation cannot prove.

## Decisions

1. Product authority stays with Eddy; execution mechanics belong to agents.
2. The grill owns design and behavior decisions. For visual work, the prototype is part of the grill rather than a separate downstream ceremony.
3. When the decision record has no implementation-changing open questions and the prototype reflects the settled behavior, the feature becomes `Ready To Act`.
4. Invoking `feature-plan` authorizes the complete bounded workflow. Eddy's final implementation-changing answer during its grill is the single product-approval gate; once the feature is `Ready To Act`, agents proceed through implementation, validation, review, fixes, and re-review without further phase approvals. Invoking `grill-me` alone remains decision-only and does not authorize production-code edits.
5. The coordinating agent silently creates or refreshes one implementation brief. Tickets are agent-owned and optional; create them only for independently reviewable chunks, dependency edges, or externally visible collaboration.
6. The implementation agent owns code changes, tests, required tracking updates, and deterministic validation. It may repair ordinary implementation defects without asking.
7. A fresh review agent reviews both Standards and Fidelity against the settled decision record/prototype. Review findings route directly back to fixes and re-review until the review passes or a real blocker remains.
8. Agents interrupt Eddy only for an implementation-changing product ambiguity, conflict with settled decisions, material scope expansion, destructive/external action requiring authority, unavailable dependency, or genuinely subjective/manual acceptance.
9. Completion requires passing project verification, passing independent review, truthful reporting of unverified manual gates, and updated durable status. A green build alone is insufficient.
10. No intermediate handoff prompts, ticket-approval prompts, or repeated prototype approval are emitted inside the continuous run.
11. `feature-plan` defaults to build mode: local planning, implementation, validation, review, fixes, and local status updates. A `ship` qualifier additionally authorizes the project's normal commit, push, hosted-ticket, and lifecycle-closure steps; absent `ship`, externally visible publication remains out of scope without creating an intermediate approval ceremony.
12. A user bug report is an observation, not automatically one implementation ticket. The agent records the report immediately, gathers available evidence, checks for duplicates and related symptoms, and links it to an existing root-cause cluster or creates a new provisional cluster.
13. Execution tickets correspond to fix seams or independently verifiable changes, not necessarily to individual reports. One root-cause fix may resolve several reports; one report may require several tickets only when separate seams genuinely exist.
14. Impact analysis must follow shared ownership. A Reader report triggers checks across every reader profile that consumes the affected shared component or behavior, while preserving profile-specific exceptions and validation.
15. Reviewing the bug log does not authorize an unbounded batch of fixes. The agent ranks open clusters by dependency, leverage, impact, confidence, and readiness; recommends the best next bounded target; and helps Eddy select one goal. Once selected and behavior is settled, that goal continues autonomously through diagnosis, fixes, impacted coverage, independent review, and linked-report updates.
16. A plain bug or anomaly report authorizes intake and investigation, not production-code changes. The agent records the observation immediately, inspects logs/code/reproduction evidence, maps plausible relationships and impacted surfaces, then returns with knowledgeable questions that cannot be answered from evidence alone.
17. Multiple reports may accumulate without forcing implementation. When Eddy is ready, agent and user select one report or root-cause cluster, settle expected behavior, and define a concrete goal, stop condition, and validation plan. That promotion authorizes the autonomous diagnose-fix-verify-review loop for that one bounded target.
18. Intake tickets and relationship links are agent-owned bookkeeping and require no approval. The selected target's goal is the human decision boundary; ticket wording, dependency edges, implementation ordering, and ordinary fixes remain agent-owned.
19. Features and bugs share one work-intake system. A plain feature idea is recorded and investigated without production implementation: the agent checks existing behavior, prior decisions, related features/bugs, shared ownership, affected profiles, technical constraints, and prototype evidence before asking product questions.
20. Several bugs, anomalies, and feature ideas may accumulate in the same durable work graph. Relationships use explicit meanings such as `duplicate of`, `symptom of`, `blocked by`, `depends on`, `affects`, `shares implementation seam with`, `supersedes`, and `resolved by`.
21. The agent maintains ranked views by subsystem and recommends the next target; Eddy selects one target at a time. Selection starts the goal-settling phase, not immediate coding.
22. Goal settling differs by work type: bugs define correct/expected behavior, reproduction, stop condition, and impacted regression coverage; features use evidence-backed grilling and, for visual/interaction work, a QA'd prototype. Both become the same `Ready To Act` goal afterward.
23. Every `Ready To Act` goal follows one delivery loop: quiet brief and optional tickets, implementation, deterministic and impacted-surface validation, fresh Standards/Fidelity review, automatic fixes and re-review, durable closure evidence, relationship-graph updates, then re-ranking of the remaining intake.
24. Each repository has exactly one active implementation goal. Intake, investigation, and relationship mapping may continue for other items, and parallel agents may work on independent subtasks, testing, research, or review inside the active goal, but unrelated goals do not modify the same repository concurrently.
25. No magic promotion phrase is required. Clear natural language such as `let's take this one`, `make this the next goal`, or `fix this next` selects the target and starts goal settling. Implementation begins automatically only after the goal's expected behavior, scope, stop condition, and validation plan are settled.
26. Relationship clusters remain provisional until evidence supports them. Acceptable evidence includes a shared reproduction path, shared state owner or implementation seam, matching logs/telemetry, a dependency demonstrated by tests or code flow, or one fix resolving multiple reproduced symptoms. Similar appearance alone is insufficient.

## Evidence / Findings

- Past sessions show repeated phase boundaries around prototype approval, spec promotion, ticket generation, lifecycle promotion, implementation, review, and validation.
- The current `grill-me`, `feature-plan`, and `skill-finish` skills already describe most of the desired compact workflow, but older project instructions and ticket lifecycle habits can still force user-mediated stops.
- Bible Standard already has durable decision records, a prototype surface, implementation briefs/specs, verification commands, and Standards/Fidelity review vocabulary.
- Ticket creation is planning machinery, not a product decision, unless publishing hosted issues or changing external collaboration state is involved.
- Existing Bible Standard work already uses a dependency graph, uniquely owned acceptance/validation gates, shared Reader convergence planning, and `project/BUGS_AND_ANOMALIES.md`; the missing piece is a report-to-cluster-to-fix relationship model and a low-friction intake command.
- The same missing relationship layer applies to feature ideas: multiple visible requests may share one underlying capability, while one feature may affect several Reader profiles and existing bug expectations.

## Tradeoffs / Risks

- Fewer approvals increase the importance of a precise `Ready To Act` gate and strict scope control.
- A review agent must receive the settled behavior/prototype and the actual diff; reviewing only coding standards would miss fidelity regressions.
- Fully automatic continuation cannot override platform safety confirmations or external-state authorization requirements.
- Long runs need bounded loops and a clear blocker policy to avoid agents silently expanding scope.
- Over-clustering unrelated symptoms can create an oversized fix; under-clustering creates duplicate tickets and repeated work. Clusters must remain provisional until reproduction or code evidence supports a shared cause.
- One active repository goal trades some theoretical throughput for much lower merge, dirty-worktree, validation, and product-state ambiguity. Parallelism remains available inside the selected goal.

## Validation Plan

- Audit shared skills and project instructions for conflicting mandatory stops between `Ready To Act`, implementation, and review.
- Encode a single authorization boundary and explicit interruption policy.
- Add or update a workflow-status command so it reports current phase, active brief, review state, and the exact next accountable actor.
- Trial the workflow on one bounded feature and record the number and reason for every human interruption.
- Trial bug intake with several related Reader observations, verify duplicate detection and cross-reader impact mapping, then run one autonomous batch-fix pass and confirm that linked reports close only with evidence.
- Verify that a second implementation goal cannot become active while one is open, while read-only intake/investigation and within-goal subagents remain allowed.
- Success target: one design/behavior approval, zero planning/ticket approvals, autonomous implement-review-fix loops, and only genuinely manual/device confirmation at the end.

## Ready To Act

Implemented on 2026-07-18 for unified feature/bug intake, relationship-aware
goal selection, one active repository goal, autonomous delivery, and independent
review. See `approval-gate-audit.md` for the changed surfaces, preserved human
gates, validation evidence, and no-product-code audit.

## Implementation Evidence

- Shared skills now encode unified intake, evidence-backed clustering/ranking,
  one active repository goal, within-goal parallelism, `Ready To Act`
  authorization, quiet briefs, agent-owned tickets/dependencies, fresh
  Standards/Fidelity review, and automatic fix/re-review.
- Global Codex instructions and the canonical loop standard use the same
  authorization boundary.
- Bible Standard's tracker/status surfaces report and validate the active goal,
  phase, brief, tickets, review state, and next accountable actor.
- All 46 changed shared skill folders passed `quick_validate.py`; four
  workflow-status tests passed; the live one-active-goal invariant passed; three
  fresh-agent forward tests reproduced the intended behavior.
- No product code changed.

## Open Questions

None. Project-local instructions may impose narrower safety, publication, or manual-QA gates, but they should not reintroduce ticket, phase, or ordinary-fix approvals.
