import assert from "node:assert/strict";

import { selectSessionRef } from "../integrations/herdr-agent-state.ts";

assert.deepEqual(
  selectSessionRef("session-id", "/isolated/session.jsonl"),
  { agent_session_id: "session-id" },
  "the isolated session ID must win when Pi exposes both references",
);
assert.deepEqual(
  selectSessionRef(undefined, "/isolated/session.jsonl"),
  { agent_session_path: "/isolated/session.jsonl" },
  "a path-only integration context must retain its recovery reference",
);
assert.equal(
  selectSessionRef(undefined, undefined),
  undefined,
  "an absent session reference must stay absent",
);

console.log("Pi Herdr agent session reference tests: PASS");
