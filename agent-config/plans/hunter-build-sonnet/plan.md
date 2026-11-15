# Hunter-lane data builds open on Sonnet medium

Eddy's rule, 2026-11-15: a data record whose Disposition starts with
"finetune — runs the hunter on one lane" (BS-DATA-TASK-147, -154, ...) opens its
`/build` tab on Sonnet medium. Every other build stays Opus medium.
`HERDR_ALLOW_HIGH=1` still lifts every clamp (the table's own pair answers).

Findings:
- No build call passes `--record` today: `goals.sh` tab_route `*)`, `goal_done.sh`
  `--handoff` and the fill all call `model_route REPO build app`.
- The data repo has no `tools/model_routes.py`; the iOS table answers. So the
  record is read from REPO (the caller's repo), never the table repo.
- `tools/model_routes.py build --record BS-DATA-TASK-147` answers `opus medium`,
  rc 0: no refusal. `tab_launch_guard.py` refuses only Opus off /build|/spec and
  high effort: Sonnet on /build passes. Neither needs a change.

Steps:
1. `herdr/model_route.sh`: add `route_hunt_record REPO ID` (globs
   `REPO/project/*/ID-*.md`, matches `- Disposition: finetune — runs the hunter on one lane`);
   in the clamp, `build` with `--record ID` and a hunt record sets sonnet.
   Proof: new test, model_route sourced, hunt record → `sonnet medium`, other → `opus medium`,
   HERDR_ALLOW_HIGH=1 → table pair.
2. `herdr/goals.sh` tab_route: a `/build <ID>` boot routes `build --record ID`.
   Proof: `goals.sh BS-DATA-TASK-147 --dry-run` prints `--model sonnet --effort medium`.
3. `herdr/goal_done.sh`: `--handoff` routes with `--record`; the fill sets
   sonnet medium per hunt record. Proof: fill dry run with a hunt record → sonnet.
4. Run `herdr/tests/test_model_route.py`, the new test, and the full herdr suite; read output.
5. Commit by path in ~/.dotfiles; no push.
