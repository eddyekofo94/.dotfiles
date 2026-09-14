# Pi Weekly Usage Live Refresh

## Goal

Keep the Pi footer's Codex weekly allowance current during a running session and make low remaining allowance visually obvious.

## Exit Criteria

- The footer refreshes weekly allowance from Codex after provider activity without restarting Pi.
- A failed or unavailable rate-limit read does not erase the last valid value or break the footer.
- Warning thresholds and colours match Eddy's settled choice.
- Focused tests prove live state replacement, refresh timing, failure behavior, and colour boundaries.
- `./pi/verify.sh` passes.
- Fresh Standards and Fidelity reviews have no blocking findings.
- Physical Ghostty colour/refresh acceptance remains explicit user confirmation.

## Scope / Non-goals

- Scope: the isolated Pi pilot's compact footer, Codex weekly usage reader, refresh lifecycle, tests, documentation, and manual QA.
- Preserve footer layout, startup estimation, provider isolation, and non-Codex behavior.
- Do not modify unrelated current dirty files.
- Eddy's subsequent `ship` instruction authorizes rebasing onto clean local main, focused/full verification, fresh review, local commit/merge, and installing the updated extension. Push remains explicitly prohibited.
- Preserve `~/.dotfiles-sessions/pi-reasoning-level-footer` separately and unchanged.
- Stop when `/reload` can load the installed live-refresh implementation; physical Ghostty acceptance remains a human gate.

## Decisions

- Use Codex's supported `account/rateLimits/read` response as the source of truth.
- Refresh extension-owned in-memory weekly state after each completed provider run and request a footer render; retain the last valid value when refresh fails.
- Use neutral above 20% remaining, amber at 20% or less, and maroon at 10% or less.
- Keep the latest valid allowance in the process environment as a reload handover snapshot; the footer still renders extension-owned state. `/reload` must not restore a stale launch value. No usage cache is written to disk.

## Evidence / Findings

- Eddy's 2026-09-15 screenshots report different weekly values (28% and 20%) while Pi's footer remains stale.
- The current session environment contains `PI_CODEX_WEEKLY_LEFT=20`.
- A live `node pi/codex_weekly_usage.mjs` read returned `19`, proving the upstream Codex value changes while the running footer remains at its launch snapshot.
- `pi/pilot.sh` reads Codex weekly usage once before starting Pi and exports it as `PI_CODEX_WEEKLY_LEFT`.
- `pi/extensions/eddy-compat.ts` reads that immutable process environment value on every render. Its `agent_end` hook reinstalls/rerenders the footer but never fetches or replaces weekly usage.
- The prior `pi-session-info-color-hierarchy` decision intentionally made weekly usage neutral above 10% and maroon at 10% or less; this report requests a changed warning boundary and live behavior.
- Relationship: `refines` `pi-session-info-color-hierarchy` and `shares implementation seam with` `pi/codex_weekly_usage.mjs`, `pi/pilot.sh`, and `pi/extensions/eddy-compat.ts`.

## Tradeoffs / Risks

- Refreshing after every completed provider run adds one short local Codex app-server query per run.
- Polling on a timer would update while idle but adds a long-lived timer and process lifecycle; it is not recommended unless response-bound refresh is insufficient.
- A footer colour change is subjective and requires physical confirmation.

## Validation Plan

- Extend unit coverage for warning and critical weekly colour boundaries.
- Add deterministic extension-state coverage proving a new valid read replaces the launch value and an invalid read preserves the last valid value.
- Prove the completed-agent lifecycle triggers refresh and rendering without a restart.
- Run `./pi/verify.sh`.
- Run fresh Standards and Fidelity review.
- In Ghostty, submit a provider turn and confirm the footer changes without restarting; inspect 21%, 20%, 11%, and 10% fixture colours.

## Local Integration Review

- Fresh independent review found missing event-level tests, loss of non-Codex/fixture footer reinstallation, stale values after `/reload`, and outdated gate claims.
- Fixes restore unconditional `agent_end` footer installation, retain the latest valid allowance across extension reloads through a process-local handover snapshot, and exercise the actual refresh closure/event hook with reader/UI stubs.
- Post-fix focused tests and full `./pi/verify.sh`: PASS. The final full gate ran after all code/test fixes with an isolated `AGENT_CONFIG_HOME` and disposable pilot state. Provider benchmark remained dry-run.
- Independent Codex `gpt-5.6-sol` re-review: Standards PASS; Fidelity PASS; no actionable findings. Source: `review.md`.
- Rebased onto clean local main `01b4a36c`; implementation `fde7dd6a` committed, fast-forward merged locally, and installed. Installed extension loading and main-checkout focused tests pass. `/reload` is ready; physical confirmation remains NOT RUN. No push. Final evidence: `integration.md`. The evidence below is historical.

## Prior Implementation / Verification Evidence

- `pi/extensions/eddy-compat.ts` now owns mutable weekly state initialized from the launch value and refreshes it through `account/rateLimits/read` after each Codex `agent_end`.
- Null, invalid, or thrown refresh results preserve the last valid value; fixture and non-Codex models do not invoke the live reader.
- Weekly colours are neutral above 20%, warning amber from 11% through 20%, and maroon from 0% through 10%.
- Focused weekly/footer/theme tests and `git diff --check`: PASS.
- Full isolated `./pi/verify.sh`: PASS end to end. An isolated `AGENT_CONFIG_HOME` preserved the worktree's source identity, and the existing prepared Herdr binary supplied the ignored runtime prerequisite.
- Fresh review: Standards 0 blocking findings; Fidelity 0 blocking findings. Source: `.working/interviews/pi-weekly-usage-live-refresh/review.md`.
- Physical Ghostty live refresh: PASS 2026-09-15. After `/reload`, completed Codex responses moved the footer from its 20% launch snapshot to upstream-matching 14%, then 13%; Eddy physically confirmed 13%.
- Physical warning colour: PASS at live 13% (amber), confirmed by Eddy 2026-09-15.
- Physical critical boundary: PASS at 10% (dark maroon), confirmed by Eddy 2026-09-15.
- Physical warning entry boundary: PASS at 20% (amber), confirmed by Eddy 2026-09-15.
- Physical neutral boundary: PASS at 21% (neutral), confirmed by Eddy 2026-09-15.
- Physical lower warning boundary: PASS at 11% (amber), confirmed by Eddy 2026-09-15. All settled colour fixtures now pass.
- Physical failed-read retention: owner-accepted without forcing a failure on 2026-09-15 after confirming the feature works. Deterministic event-level tests cover null, invalid, thrown, recovery, concurrency, and reload retention paths.
- 2026-09-15 `/reload` report: INVALID TEST BUILD, not a feature regression. The live settings symlink still targets `/Users/eddyekofo/.dotfiles/pi/settings.json`, whose extension targets main's unchanged launch-snapshot implementation. Main is clean; the feature remains uncommitted in its named worktree because Eddy explicitly prohibited merge/push. The live Codex reader returned 17% while this session retained its 20% launch snapshot.

## Ready To Act

Implemented, merged locally, installed, physically accepted, and Ready for authorized push. Eddy's `push everything` instruction superseded the prior no-push restriction. The reasoning-footer branch remains separately parked and is not merged into this goal.

## Open Questions

None.
