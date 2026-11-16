# Done means closed (Eddy order 2026-11-16: "something is done, it should be closed")

No new package. orders.md is never edited. Tests: `herdr/tests/test_done_closed.py`.

1. `ensure_master.sh --here` closes `master-prev` tabs and agentless stale `master` tabs after seating; never itself; a live other master still exits 3.
   Proof: test_here_closes_master_prev, test_here_never_closes_itself, test_here_refuses_live_master (herdr call log).
2. `goal_done.sh --tab` resolves the repo from the tab's own cwd, falling back to the agent state file (`cwd`/`repo` for that tab) when the pane cwd is not a git repo; still refuses unmerged and the master.
   Proof: test_tab_from_non_git_caller_cwd, test_tab_unmerged_refused, test_tab_master_refused (run from a non-git cwd).
3. Reaper closes a tab whose record is landed, or idle with nothing owed (no `decide:`/`judge:` wake, not in /tmp/master_hold.txt) after a grace; an open ask stays.
   Proof: test_decide_owed_stays, test_decide_held_stays, test_decide_nothing_owed_closes (`reap_idle.decide`).
4. `landed:` handling and `open-next` call one close path (`close_done.sh`-free: `goal_done.sh --tab`, then open-next).
   Proof: test_open_next_closes_landed_tab (fixture queue + fake herdr log).
5. Run `herdr/verify.sh`, read the output.
