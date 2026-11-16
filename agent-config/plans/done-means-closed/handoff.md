# Handoff (2026-11-16)
Done: done-means-closed built+committed (78e402da); stale verdict-lane tests fixed (d237463a); all unit suites in herdr/verify.sh pass.
Next: herdr/validate_project_picker.sh fails alone, even with HERDR_VALIDATE_WAIT_SECONDS=90, at "popup-created linked worktree focus" (line ~611): workspace appears, focus never moves to it. Real cause, not load. Find it; stop when verify.sh exits 0.
Files: herdr/validate_project_picker.sh, herdr/project_picker.sh, herdr/prototype/picker_client.py. Never edit agent-config/master/orders.md.
