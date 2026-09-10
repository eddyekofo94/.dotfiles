import assert from "node:assert/strict";
import fs from "node:fs";

const extensionSource = fs.readFileSync(
  new URL("../extensions/eddy-compat.ts", import.meta.url),
  "utf8",
);
const helperBlock = extensionSource.match(
  /\/\/ BEGIN CONTEXT DISPLAY HELPERS\n([\s\S]*?)\/\/ END CONTEXT DISPLAY HELPERS/,
)?.[1];
assert.ok(helperBlock, "reload-local context display helpers must remain testable");
const {
  contextTrafficLight,
  contextUsageForDisplay,
  formatTokenCount,
  modelColor,
  weeklyColor,
  weeklyRemainingPercent,
} =
  Function(
    `"use strict";\n${helperBlock}\nreturn { contextTrafficLight, contextUsageForDisplay, formatTokenCount, modelColor, weeklyColor, weeklyRemainingPercent };`,
  )();

assert.deepEqual(contextTrafficLight(null), {
  color: "muted",
  level: "unknown",
  percent: null,
  symbol: "○",
});
assert.deepEqual(contextTrafficLight(69.9), {
  color: "success",
  level: "healthy",
  percent: 69,
  symbol: "●",
});
assert.equal(contextTrafficLight(70).color, "warning");
assert.deepEqual(contextTrafficLight(84.9), {
  color: "warning",
  level: "warning",
  percent: 84,
  symbol: "●",
});
assert.equal(contextTrafficLight(85).color, "error");
assert.equal(contextTrafficLight(120).percent, 120);

assert.equal(formatTokenCount(999), "999");
assert.equal(formatTokenCount(1000), "1.0k");
assert.equal(formatTokenCount(12550), "12.6k");

assert.equal(weeklyRemainingPercent("81"), 81);
assert.equal(weeklyRemainingPercent("0"), 0);
assert.equal(weeklyRemainingPercent("100"), 100);
assert.equal(weeklyRemainingPercent("101"), null);
assert.equal(weeklyRemainingPercent("81.5"), null);
assert.equal(weeklyRemainingPercent(undefined), null);

assert.equal(modelColor("gpt-6-astra"), "warning");
assert.equal(modelColor("flagship"), "warning");
assert.equal(modelColor("claude-opus-5"), "warning");
assert.equal(modelColor("gpt-5.6-sol"), "thinkingXhigh");
assert.equal(modelColor("default"), "thinkingXhigh");
assert.equal(modelColor("gpt-5.6-terra"), "toolTitle");
assert.equal(modelColor("gpt-5.6-luna"), "bashMode");
assert.equal(modelColor("claude-sonnet-5"), "thinkingHigh");
assert.equal(modelColor("claude-haiku-4-5"), "success");
assert.equal(modelColor("fixture"), "accent");

assert.equal(weeklyColor(11), "muted");
assert.equal(weeklyColor(10), "thinkingMax");
assert.equal(weeklyColor(0), "thinkingMax");

const originalFixture = process.env.PI_PILOT_FIXTURE;
const originalContext = process.env.PI_PILOT_CONTEXT_PERCENT;
process.env.PI_PILOT_FIXTURE = "1";
process.env.PI_PILOT_CONTEXT_PERCENT = "70";
assert.deepEqual(contextUsageForDisplay(null, 32768), {
  contextWindow: 32768,
  percent: 70,
  tokens: 22938,
});
process.env.PI_PILOT_FIXTURE = "0";
assert.equal(contextUsageForDisplay(null, 32768), null);
assert.deepEqual(contextUsageForDisplay({ tokens: 0, contextWindow: 1000 }, 1000, "12345678"), {
  approximate: true,
  contextWindow: 1000,
  percent: 0.2,
  tokens: 2,
});
assert.deepEqual(
  contextUsageForDisplay({ tokens: 25, contextWindow: 1000, percent: 2.5 }, 1000, "12345678"),
  { tokens: 25, contextWindow: 1000, percent: 2.5 },
);
if (originalFixture === undefined) delete process.env.PI_PILOT_FIXTURE;
else process.env.PI_PILOT_FIXTURE = originalFixture;
if (originalContext === undefined) delete process.env.PI_PILOT_CONTEXT_PERCENT;
else process.env.PI_PILOT_CONTEXT_PERCENT = originalContext;

assert.ok(extensionSource.includes("ctx.ui.setFooter("));
assert.ok(extensionSource.includes("weekly ${weekly}% left"));
assert.ok(extensionSource.includes("footerData.getGitBranch()"));
assert.ok(extensionSource.includes("ctx.getContextUsage()"));
assert.ok(extensionSource.includes("findRepositoryContext(ctx.cwd)"));
for (const refreshEvent of ["model_select", "agent_end", "session_compact"]) {
  assert.ok(
    extensionSource.includes(`\"${refreshEvent}\"`),
    `compact footer must refresh for ${refreshEvent}`,
  );
}
assert.ok(!extensionSource.includes("ctx.ui.setStatus("));
assert.ok(!extensionSource.includes('pi.registerCommand("details"'));

console.log("Pi session display tests: PASS");
