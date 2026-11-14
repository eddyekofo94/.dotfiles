# Master rotation guard missed a hand-typed /master (retro ios-2026-11-14)
Evidence: master 51b30536 (typed `/master`, no AGENT_ROLE) compacted 12 times, $18.68; ae5d6ea5 34 times. state/ never created.
1. `is_master_main`: also true when transcript_path's first user message is the `/master` command. Proof: new test, 9 compactions, session without AGENT_ROLE arms.
2. `rotate` launch: model from HERDR_MASTER_MODEL (default sonnet) + `--effort medium`, as ensure_master.sh. Proof: new test reads the fake herdr call log.
3. Run tests/master_rotation_test.py; commit path-limited; push.
