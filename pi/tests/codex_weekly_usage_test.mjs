import assert from "node:assert/strict";
import { weeklyRemaining } from "../codex_weekly_usage.mjs";

assert.equal(
  weeklyRemaining({
    rateLimits: {
      primary: { usedPercent: 19, windowDurationMins: 10080 },
    },
  }),
  81,
);
assert.equal(
  weeklyRemaining({
    rateLimits: {
      primary: { usedPercent: 20, windowDurationMins: 300 },
      secondary: { usedPercent: 3, windowDurationMins: 10080 },
    },
  }),
  97,
);
assert.equal(
  weeklyRemaining({
    rateLimits: {
      primary: { usedPercent: 20, windowDurationMins: 300 },
    },
  }),
  null,
);
assert.equal(
  weeklyRemaining({
    rateLimitsByLimitId: {
      codex: {
        primary: { usedPercent: 150, windowDurationMins: 10080 },
      },
    },
  }),
  0,
);

console.log("Pi Codex weekly usage tests: PASS");
